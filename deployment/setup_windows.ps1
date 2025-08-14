# Windows Machine Setup Script for AI Image Generation Demo
# This script configures a fresh Windows machine for the Snapdragon vs Intel demonstration

param(
    [switch]$Force,
    [string]$ConfigPath = ".\config"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AI Image Generation Demo - Windows Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to safely remove files with error handling
function Safe-RemoveItem {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            Remove-Item $Path -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up: $Path" -ForegroundColor Green
        }
    } catch {
        Write-Host "Note: Could not remove $Path (file may be in use)" -ForegroundColor Yellow
    }
}

# Function to install Python if not present
function Install-Python {
    Write-Host "Checking Python installation..." -ForegroundColor Yellow
    
    try {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python found: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "Python not found in PATH" -ForegroundColor Red
    }
    
    Write-Host "Installing Python 3.11..." -ForegroundColor Yellow
    
    # Download Python installer
    $pythonUrl = "https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-installer.exe"
    
    try {
        Write-Host "Downloading Python installer..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        
        # Install Python silently
        Write-Host "Installing Python (this may take a few minutes)..." -ForegroundColor Yellow
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "Python installation completed" -ForegroundColor Green
        
        # Clean up installer (with better error handling)
        Safe-RemoveItem -Path $pythonInstaller
        
        return $true
        
    } catch {
        Write-Host "Failed to install Python: $_" -ForegroundColor Red
        # Try to clean up even if installation failed
        Safe-RemoveItem -Path $pythonInstaller
        return $false
    }
}

# Function to install Git if not present
function Install-Git {
    Write-Host "Checking Git installation..." -ForegroundColor Yellow
    
    try {
        $gitVersion = git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Git found: $gitVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "Git not found" -ForegroundColor Red
    }
    
    Write-Host "Installing Git..." -ForegroundColor Yellow
    
    # Download Git installer
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"
    
    try {
        Write-Host "Downloading Git installer..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
        
        # Install Git silently
        Write-Host "Installing Git..." -ForegroundColor Yellow
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "Git installation completed" -ForegroundColor Green
        
        # Clean up installer
        Safe-RemoveItem -Path $gitInstaller
        
        return $true
        
    } catch {
        Write-Host "Failed to install Git: $_" -ForegroundColor Red
        Safe-RemoveItem -Path $gitInstaller
        return $false
    }
}

# Function to detect platform architecture
function Get-PlatformArchitecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    $processor = (Get-WmiObject -Class Win32_Processor).Name
    
    if ($processor -like "*Snapdragon*" -or $processor -like "*Qualcomm*" -or $arch -eq "ARM64") {
        return "ARM64"
    } else {
        return "x86_64"
    }
}

# Function to create demo directory structure
function Setup-DemoDirectory {
    Write-Host "Setting up demo directory..." -ForegroundColor Yellow
    
    $demoPath = "C:\AIDemo"
    
    if (Test-Path $demoPath) {
        if ($Force) {
            Remove-Item $demoPath -Recurse -Force
            Write-Host "Removed existing demo directory" -ForegroundColor Yellow
        } else {
            Write-Host "Demo directory already exists. Use -Force to overwrite." -ForegroundColor Red
            return $false
        }
    }
    
    # Create directory structure
    New-Item -ItemType Directory -Path $demoPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\client" -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\models" -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\cache" -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\logs" -Force | Out-Null
    
    Write-Host "Demo directory created at: $demoPath" -ForegroundColor Green
    return $demoPath
}

# Function to check DirectML compatibility
function Test-DirectMLCompatibility {
    Write-Host "Checking DirectML compatibility..." -ForegroundColor Yellow
    
    try {
        # Check Windows version (requires Windows 10 v1903 or later)
        $osVersion = [System.Environment]::OSVersion.Version
        $build = (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
        
        if ($build -lt 18362) {
            Write-Host "DirectML requires Windows 10 v1903 (build 18362) or later. Current build: $build" -ForegroundColor Red
            return $false
        }
        
        # Check if DirectX 12 is available
        try {
            $dxdiagOutput = dxdiag /t "$env:TEMP\dxdiag.txt" 2>$null
            Start-Sleep -Seconds 3
            if (Test-Path "$env:TEMP\dxdiag.txt") {
                $dxContent = Get-Content "$env:TEMP\dxdiag.txt" -Raw
                Remove-Item "$env:TEMP\dxdiag.txt" -Force -ErrorAction SilentlyContinue
                
                if ($dxContent -match "DirectX 12") {
                    Write-Host "DirectX 12 support detected" -ForegroundColor Green
                } else {
                    Write-Host "DirectX 12 not detected - DirectML may not work properly" -ForegroundColor Yellow
                    return $false
                }
            }
        } catch {
            Write-Host "Could not verify DirectX version" -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "System appears compatible with DirectML" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Error checking DirectML compatibility: $_" -ForegroundColor Red
        return $false
    }
}

# Function to install a single package with retry logic
function Install-PackageWithRetry {
    param(
        [string]$PackageName,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        Write-Host "  [$attempt/$MaxRetries] Installing $PackageName..." -ForegroundColor Cyan
        
        try {
            $result = pip install $PackageName --verbose --no-warn-script-location 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $PackageName installed successfully" -ForegroundColor Green
                return $true
            } else {
                throw "pip install failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Host "  ✗ Attempt $attempt failed: $_" -ForegroundColor Red
            
            if ($attempt -lt $MaxRetries) {
                $delay = $DelaySeconds * [Math]::Pow(2, $attempt - 1)  # Exponential backoff
                Write-Host "  Retrying in $delay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $delay
            }
            $attempt++
        }
    }
    
    Write-Host "  ✗ Failed to install $PackageName after $MaxRetries attempts" -ForegroundColor Red
    return $false
}

# Function to install Python dependencies with enhanced error handling and progress
function Install-PythonDependencies {
    param([string]$DemoPath)
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "PYTHON DEPENDENCIES INSTALLATION" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Detect platform
    $architecture = Get-PlatformArchitecture
    Write-Host "Detected architecture: $architecture" -ForegroundColor Cyan
    
    # Check DirectML compatibility for Intel systems
    $directMLSupported = $false
    if ($architecture -eq "x86_64") {
        $directMLSupported = Test-DirectMLCompatibility
        if ($directMLSupported) {
            Write-Host "DirectML acceleration will be enabled" -ForegroundColor Green
        } else {
            Write-Host "DirectML not supported - using CPU-only mode" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ARM64 detected - DirectML not available, using optimized CPU mode" -ForegroundColor Cyan
    }
    
    try {
        # Create virtual environment
        Set-Location $DemoPath
        Write-Host "`nCreating virtual environment..." -ForegroundColor Yellow
        python -m venv venv
        
        # Activate virtual environment
        Write-Host "Activating virtual environment..." -ForegroundColor Yellow
        & "$DemoPath\venv\Scripts\Activate.ps1"
        
        # Upgrade pip first with verbose output
        Write-Host "`nUpgrading pip..." -ForegroundColor Yellow
        pip install --upgrade pip --verbose
        
        # Define core packages (required for basic functionality)
        $corePackages = @(
            "torch>=2.0.0",
            "torchvision>=0.15.0",
            "diffusers>=0.21.0",
            "transformers>=4.25.0",
            "accelerate>=0.16.0",
            "safetensors>=0.3.0",
            "Pillow>=9.3.0",
            "numpy>=1.24.0",
            "requests>=2.28.0"
        )
        
        # Define optional packages (nice to have)
        $optionalPackages = @(
            "opencv-python>=4.7.0",
            "psutil>=5.9.0",
            "flask>=2.2.0",
            "flask-socketio>=5.3.0",
            "websocket-client>=1.4.0",
            "python-socketio>=5.7.0"
        )
        
        # Define platform-specific packages
        $platformPackages = @()
        if ($architecture -eq "ARM64") {
            $platformPackages = @("onnxruntime>=1.16.0")
        } elseif ($directMLSupported) {
            $platformPackages = @(
                "directml>=1.12.0",
                "onnxruntime-directml>=1.16.0",
                "xformers>=0.0.16"
            )
        } else {
            $platformPackages = @("onnxruntime>=1.16.0")
        }
        
        # Install core packages
        Write-Host "`n📦 Installing core packages..." -ForegroundColor Yellow
        $coreSuccess = 0
        $coreTotal = $corePackages.Count
        
        foreach ($package in $corePackages) {
            if (Install-PackageWithRetry -PackageName $package) {
                $coreSuccess++
            }
        }
        
        Write-Host "`n📊 Core packages: $coreSuccess/$coreTotal installed successfully" -ForegroundColor $(if($coreSuccess -eq $coreTotal) { "Green" } else { "Yellow" })
        
        if ($coreSuccess -lt ($coreTotal * 0.8)) {
            Write-Host "❌ Too many core packages failed. Demo may not work properly." -ForegroundColor Red
            return $false
        }
        
        # Install optional packages
        Write-Host "`n🔧 Installing optional packages..." -ForegroundColor Yellow
        $optionalSuccess = 0
        
        foreach ($package in $optionalPackages) {
            if (Install-PackageWithRetry -PackageName $package) {
                $optionalSuccess++
            }
        }
        
        Write-Host "`n📊 Optional packages: $optionalSuccess/$($optionalPackages.Count) installed successfully" -ForegroundColor Green
        
        # Install platform-specific packages
        if ($platformPackages.Count -gt 0) {
            Write-Host "`n⚡ Installing platform-specific packages..." -ForegroundColor Yellow
            $platformSuccess = 0
            
            foreach ($package in $platformPackages) {
                if (Install-PackageWithRetry -PackageName $package) {
                    $platformSuccess++
                } else {
                    if ($package -like "*directml*") {
                        Write-Host "❌ DirectML installation failed. Falling back to CPU-only mode." -ForegroundColor Yellow
                        Write-Host "   This is common on older systems or without proper DirectX support." -ForegroundColor Yellow
                        
                        # Try to install CPU-only alternative
                        Write-Host "   Installing CPU-only alternative..." -ForegroundColor Yellow
                        Install-PackageWithRetry -PackageName "onnxruntime>=1.16.0" | Out-Null
                    }
                }
            }
            
            Write-Host "`n📊 Platform packages: $platformSuccess/$($platformPackages.Count) installed successfully" -ForegroundColor Green
        }
        
        # Validate installation
        Write-Host "`n🔍 Validating installation..." -ForegroundColor Yellow
        
        try {
            python -c "import torch; print(f'PyTorch {torch.__version__} - Device: {torch.device(\"cuda\" if torch.cuda.is_available() else \"cpu\")}')"
            python -c "import diffusers; print(f'Diffusers {diffusers.__version__}')"
            Write-Host "✓ Core AI packages validated successfully" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Package validation had issues, but basic functionality should work" -ForegroundColor Yellow
        }
        
        Write-Host "`n============================================" -ForegroundColor Green
        Write-Host "INSTALLATION SUMMARY" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "Platform: $architecture" -ForegroundColor White
        Write-Host "DirectML Support: $(if($directMLSupported) { 'Yes' } else { 'No' })" -ForegroundColor White
        Write-Host "Core Packages: $coreSuccess/$coreTotal" -ForegroundColor White
        Write-Host "Optional Packages: $optionalSuccess/$($optionalPackages.Count)" -ForegroundColor White
        if ($platformPackages.Count -gt 0) {
            Write-Host "Platform Packages: $platformSuccess/$($platformPackages.Count)" -ForegroundColor White
        }
        Write-Host "============================================" -ForegroundColor Green
        
        return $true
        
    } catch {
        Write-Host "❌ Fatal error during package installation: $_" -ForegroundColor Red
        Write-Host "📋 Please check the error details above and try manual installation if needed" -ForegroundColor Yellow
        return $false
    }
}

# Function to configure Windows firewall with better error handling
function Configure-Firewall {
    Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
    
    try {
        # Use New-NetFirewallRule with proper error handling
        New-NetFirewallRule -DisplayName "AI Demo - Python HTTP" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        New-NetFirewallRule -DisplayName "AI Demo - WebSocket" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "Firewall rules configured" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Warning: Could not configure firewall automatically: $_" -ForegroundColor Yellow
        Write-Host "You may need to allow Python through Windows Firewall manually" -ForegroundColor Yellow
        return $false
    }
}

# Function to disable Windows power management
function Configure-PowerSettings {
    Write-Host "Configuring power settings for demo..." -ForegroundColor Yellow
    
    try {
        # Set high performance power plan (use GUID that works on all systems)
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        
        # Disable sleep and hibernation
        powercfg /change standby-timeout-ac 0 2>$null
        powercfg /change standby-timeout-dc 0 2>$null
        powercfg /change hibernate-timeout-ac 0 2>$null
        powercfg /change hibernate-timeout-dc 0 2>$null
        
        # Disable display timeout
        powercfg /change monitor-timeout-ac 0 2>$null
        powercfg /change monitor-timeout-dc 0 2>$null
        
        Write-Host "Power settings optimized for demo" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Warning: Could not configure all power settings: $_" -ForegroundColor Yellow
        return $false
    }
}

# Function to create startup script
function Create-StartupScript {
    param([string]$DemoPath)
    
    Write-Host "Creating demo startup script..." -ForegroundColor Yellow
    
    $startupScript = @"
@echo off
title AI Image Generation Demo Client
cd /d $DemoPath
call venv\Scripts\activate.bat
echo Starting AI Demo Client...
echo Platform: $(Get-PlatformArchitecture)
echo Ready for demonstration!
echo.
python client\demo_client.py
pause
"@

    $startupPath = "$DemoPath\start_demo.bat"
    $startupScript | Out-File -FilePath $startupPath -Encoding ASCII
    
    # Create desktop shortcut with better error handling
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\AI Demo.lnk")
        $Shortcut.TargetPath = $startupPath
        $Shortcut.WorkingDirectory = $DemoPath
        $Shortcut.IconLocation = "shell32.dll,13"
        $Shortcut.Save()
        Write-Host "Desktop shortcut created" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not create desktop shortcut: $_" -ForegroundColor Yellow
    }
    
    Write-Host "Startup script created" -ForegroundColor Green
    return $true
}

# Main setup process
function Main {
    Write-Host "Starting Windows machine setup for AI demo..." -ForegroundColor Cyan
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Host "This script requires administrator privileges. Please run as administrator." -ForegroundColor Red
        exit 1
    }
    
    # Install prerequisites
    if (-not (Install-Python)) {
        Write-Host "Failed to install Python. Exiting." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Install-Git)) {
        Write-Host "Failed to install Git. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Setup demo directory
    $demoPath = Setup-DemoDirectory
    if (-not $demoPath) {
        Write-Host "Failed to setup demo directory. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Install Python dependencies
    if (-not (Install-PythonDependencies -DemoPath $demoPath)) {
        Write-Host "Warning: Some Python dependencies may have issues, but continuing..." -ForegroundColor Yellow
    }
    
    # Configure system settings (continue even if some fail)
    Configure-Firewall | Out-Null
    Configure-PowerSettings | Out-Null
    
    # Create startup script
    Create-StartupScript -DemoPath $demoPath | Out-Null
    
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Windows setup completed successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Demo directory: $demoPath" -ForegroundColor Yellow
    Write-Host "Desktop shortcut: AI Demo.lnk" -ForegroundColor Yellow
    Write-Host "To start the demo, run: $demoPath\start_demo.bat" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Copy demo client files to $demoPath\client\" -ForegroundColor White
    Write-Host "2. Download Stable Diffusion model to $demoPath\models\" -ForegroundColor White
    Write-Host "3. Run platform detection and configuration" -ForegroundColor White
    Write-Host "4. Test the demo client" -ForegroundColor White
    Write-Host ""
    Write-Host "Platform detected: $(Get-PlatformArchitecture)" -ForegroundColor Cyan
}

# Run main setup
Main