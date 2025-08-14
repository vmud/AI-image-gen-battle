# Enhanced Setup Script with Real-time Logging
# This version provides detailed progress feedback and logging

param(
    [switch]$Force,
    [string]$ConfigPath = ".\config"
)

# Setup logging
$logPath = "C:\AIDemo\setup.log"
$global:logFile = $null

function Write-LoggedHost {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Write to console
    Write-Host $Message -ForegroundColor $ForegroundColor
    
    # Write to log file
    if ($global:logFile) {
        $logMessage | Out-File -FilePath $global:logFile -Append -Encoding UTF8
    }
}

function Initialize-Logging {
    # Create log directory if it doesn't exist
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $global:logFile = $logPath
    
    Write-LoggedHost "============================================" -ForegroundColor Cyan
    Write-LoggedHost "AI Demo Setup - Enhanced Logging Version" -ForegroundColor Cyan
    Write-LoggedHost "============================================" -ForegroundColor Cyan
    Write-LoggedHost "Log file: $logPath" -ForegroundColor Gray
    Write-LoggedHost ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Python {
    Write-LoggedHost "[CHECKING] Checking Python installation..." -ForegroundColor Yellow
    
    try {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LoggedHost "[OK] Python found: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-LoggedHost "[ERROR] Python not found in PATH" -ForegroundColor Red
    }
    
    Write-LoggedHost "[INSTALLING] Installing Python 3.9 (best compatibility)..." -ForegroundColor Yellow
    
    # Download Python installer with progress
    $pythonUrl = "https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-installer.exe"
    
    try {
        Write-LoggedHost "[DOWNLOAD] Downloading Python installer..." -ForegroundColor Yellow
        
        # Create WebClient for progress tracking
        $webClient = New-Object System.Net.WebClient
        
        # Register progress event
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $percent = $Event.SourceEventArgs.ProgressPercentage
            if ($percent % 10 -eq 0) {  # Show every 10%
                Write-Host "   Download progress: $percent%" -ForegroundColor Gray
            }
        } | Out-Null
        
        $webClient.DownloadFile($pythonUrl, $pythonInstaller)
        $webClient.Dispose()
        
        Write-LoggedHost "[OK] Download completed" -ForegroundColor Green
        
        # Install Python with progress monitoring
        Write-LoggedHost "[SETUP] Installing Python (monitoring process)..." -ForegroundColor Yellow
        
        # Start installation process
        $process = Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -PassThru
        
        # Monitor process with progress dots
        Write-LoggedHost "   Installation in progress" -ForegroundColor Gray -NoNewline
        while (-not $process.HasExited) {
            Start-Sleep -Seconds 2
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
        Write-Host ""  # New line after dots
        
        if ($process.ExitCode -eq 0) {
            Write-LoggedHost "[OK] Python installation completed successfully" -ForegroundColor Green
        } else {
            Write-LoggedHost "[ERROR] Python installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
        
        # Refresh environment variables
        Write-LoggedHost "[REFRESH] Refreshing environment variables..." -ForegroundColor Yellow
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"
        
        # Clean up installer
        if (Test-Path $pythonInstaller) {
            Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
            Write-LoggedHost "[CLEANUP] Cleaned up installer" -ForegroundColor Green
        }
        
        return $true
        
    } catch {
        Write-LoggedHost "[ERROR] Failed to install Python: $_" -ForegroundColor Red
        return $false
    }
}

function Install-Git {
    Write-LoggedHost "[CHECKING] Checking Git installation..." -ForegroundColor Yellow
    
    try {
        $gitVersion = git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LoggedHost "[OK] Git found: $gitVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-LoggedHost "[ERROR] Git not found" -ForegroundColor Red
    }
    
    Write-LoggedHost "[INSTALLING] Installing Git..." -ForegroundColor Yellow
    
    # Download Git installer with progress
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"
    
    try {
        Write-LoggedHost "[DOWNLOAD] Downloading Git installer..." -ForegroundColor Yellow
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $percent = $Event.SourceEventArgs.ProgressPercentage
            if ($percent % 10 -eq 0) {
                Write-Host "   Download progress: $percent%" -ForegroundColor Gray
            }
        } | Out-Null
        
        $webClient.DownloadFile($gitUrl, $gitInstaller)
        $webClient.Dispose()
        
        Write-LoggedHost "[OK] Download completed" -ForegroundColor Green
        
        # Install Git with progress monitoring
        Write-LoggedHost "[SETUP] Installing Git (monitoring process)..." -ForegroundColor Yellow
        
        $process = Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-" -PassThru
        
        Write-LoggedHost "   Installation in progress" -ForegroundColor Gray -NoNewline
        while (-not $process.HasExited) {
            Start-Sleep -Seconds 2
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
        Write-Host ""
        
        if ($process.ExitCode -eq 0) {
            Write-LoggedHost "[OK] Git installation completed successfully" -ForegroundColor Green
        } else {
            Write-LoggedHost "[ERROR] Git installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
        
        # Refresh environment variables
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"
        
        # Clean up
        if (Test-Path $gitInstaller) {
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
            Write-LoggedHost "[CLEANUP] Cleaned up installer" -ForegroundColor Green
        }
        
        return $true
        
    } catch {
        Write-LoggedHost "[ERROR] Failed to install Git: $_" -ForegroundColor Red
        return $false
    }
}

function Get-PlatformArchitecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    $processor = (Get-WmiObject -Class Win32_Processor).Name
    
    if ($processor -like "*Snapdragon*" -or $processor -like "*Qualcomm*" -or $arch -eq "ARM64") {
        return "ARM64"
    } else {
        return "x86_64"
    }
}

function Setup-DemoDirectory {
    Write-LoggedHost "[SETUP] Setting up demo directory..." -ForegroundColor Yellow
    
    $demoPath = "C:\AIDemo"
    
    if (Test-Path $demoPath) {
        if ($Force) {
            Write-LoggedHost "[CLEANUP] Removing existing demo directory..." -ForegroundColor Yellow
            Remove-Item $demoPath -Recurse -Force
            Write-LoggedHost "[OK] Removed existing demo directory" -ForegroundColor Yellow
        } else {
            Write-LoggedHost "[ERROR] Demo directory already exists. Use -Force to overwrite." -ForegroundColor Red
            return $false
        }
    }
    
    # Create directory structure
    Write-LoggedHost "[CREATE] Creating directory structure..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $demoPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\client" -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\models" -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\cache" -Force | Out-Null
    New-Item -ItemType Directory -Path "$demoPath\logs" -Force | Out-Null
    
    Write-LoggedHost "[OK] Demo directory created at: $demoPath" -ForegroundColor Green
    return $demoPath
}

function Install-PythonDependencies {
    param([string]$DemoPath)
    
    Write-LoggedHost "[PYTHON] Installing Python dependencies..." -ForegroundColor Yellow
    
    # Detect platform
    $architecture = Get-PlatformArchitecture
    Write-LoggedHost "[PLATFORM] Detected architecture: $architecture" -ForegroundColor Cyan
    
    # Check Python version
    try {
        $pythonVersion = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        Write-LoggedHost "[PYTHON] Python version detected: $pythonVersion" -ForegroundColor Cyan
    } catch {
        Write-LoggedHost "[WARNING] Could not detect Python version" -ForegroundColor Yellow
        $pythonVersion = "unknown"
    }
    
    # Create platform-specific requirements
    if ($architecture -eq "ARM64") {
        Write-LoggedHost "[CONFIG] Creating Snapdragon-optimized requirements..." -ForegroundColor Yellow
        $requirements = @"
# Core AI libraries with version constraints for compatibility
torch==2.0.1
torchvision==0.15.2
diffusers==0.21.4
transformers==4.30.0
accelerate==0.20.3
safetensors==0.3.1
# Image processing
Pillow==9.5.0
numpy==1.24.3
opencv-python==4.7.0.72
# System monitoring
psutil==5.9.5
# Web framework
flask==2.3.2
flask-socketio==5.3.4
requests==2.31.0
websocket-client==1.6.1
python-socketio==5.9.0
# Note: DirectML not available for ARM64, using NPU-optimized runtime
onnxruntime==1.15.1
# Windows ML for Snapdragon NPU support
winml>=1.0.0
"@
    } else {
        Write-LoggedHost "[CONFIG] Creating Intel-optimized requirements..." -ForegroundColor Yellow
        $requirements = @"
# Core AI libraries with version constraints for compatibility
torch==2.0.1
torchvision==0.15.2
diffusers==0.21.4
transformers==4.30.0
accelerate==0.20.3
safetensors==0.3.1
# Image processing
Pillow==9.5.0
numpy==1.24.3
opencv-python==4.7.0.72
# System monitoring
psutil==5.9.5
# Web framework
flask==2.3.2
flask-socketio==5.3.4
requests==2.31.0
websocket-client==1.6.1
python-socketio==5.9.0
# ONNX runtime - DirectML will be added separately for Intel
onnxruntime==1.15.1
# Additional Intel optimization libraries
intel-extension-for-pytorch==2.0.0; platform_machine=="x86_64"
"@
    }

    $requirementsPath = Join-Path $DemoPath "requirements.txt"
    $requirements | Out-File -FilePath $requirementsPath -Encoding UTF8
    Write-LoggedHost "[OK] Requirements file created" -ForegroundColor Green
    
    try {
        # Create virtual environment
        Set-Location $DemoPath
        Write-LoggedHost "[VENV] Creating virtual environment..." -ForegroundColor Yellow
        python -m venv venv
        
        # Activate virtual environment
        Write-LoggedHost "[VENV] Activating virtual environment..." -ForegroundColor Yellow
        $activateScript = Join-Path $DemoPath "venv\Scripts\Activate.ps1"
        & $activateScript
        
        # Upgrade pip first
        Write-LoggedHost "[UPGRADE] Upgrading pip..." -ForegroundColor Yellow
        python -m pip install --upgrade pip setuptools wheel --quiet
        
        # Install packages in groups for better progress tracking
        Write-LoggedHost "[PACKAGES] Installing AI/ML libraries (this will take several minutes)..." -ForegroundColor Yellow
        $logMessage = "   [TIP] You can monitor detailed progress in: $logPath"
        Write-LoggedHost $logMessage -ForegroundColor Gray
        
        # Install PyTorch first (largest package)
        Write-LoggedHost "   [PYTORCH] Installing PyTorch..." -ForegroundColor Yellow
        $result = pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu --no-warn-script-location 2>&1
        $result | Out-File -FilePath $logPath -Append -Encoding UTF8
        
        if ($LASTEXITCODE -eq 0) {
            Write-LoggedHost "   [OK] PyTorch installed successfully" -ForegroundColor Green
        } else {
            Write-LoggedHost "   [WARNING] PyTorch installation had issues, continuing..." -ForegroundColor Yellow
        }
        
        # Install remaining packages
        Write-LoggedHost "   [PACKAGES] Installing remaining packages..." -ForegroundColor Yellow
        $result = pip install -r requirements.txt --no-warn-script-location 2>&1
        $result | Out-File -FilePath $logPath -Append -Encoding UTF8
        
        # Try to install DirectML separately for x86_64
        if ($architecture -eq "x86_64") {
            Write-LoggedHost "   [CHECK] Checking DirectML compatibility..." -ForegroundColor Yellow
            
            $compatibleVersions = @("3.8", "3.9", "3.10")
            if ($pythonVersion -in $compatibleVersions) {
                Write-LoggedHost "   [DIRECTML] Attempting DirectML installation for hardware acceleration..." -ForegroundColor Yellow
                
                $directmlInstalled = $false
                try {
                    $result = pip install directml --no-warn-script-location 2>&1
                    $result | Out-File -FilePath $logPath -Append -Encoding UTF8
                    
                    if ($LASTEXITCODE -eq 0) {
                        $result = pip install onnxruntime-directml --no-warn-script-location 2>&1
                        $result | Out-File -FilePath $logPath -Append -Encoding UTF8
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-LoggedHost "   [OK] DirectML acceleration installed successfully" -ForegroundColor Green
                            $directmlInstalled = $true
                        }
                    }
                } catch {
                    # Silently continue
                }
                
                if (-not $directmlInstalled) {
                    Write-LoggedHost "   [ERROR] DirectML installation failed - this is REQUIRED for Intel hardware acceleration" -ForegroundColor Red
                    Write-LoggedHost "   [INFO] Run .\deployment\diagnose.ps1 to troubleshoot" -ForegroundColor Yellow
                    
                    $continue = Read-Host "   [?] Continue without DirectML? (y/n)"
                    if ($continue -ne "y") {
                        Write-LoggedHost "[ERROR] Setup cancelled. Please resolve DirectML issues and run again." -ForegroundColor Red
                        exit 1
                    }
                }
            } else {
                Write-LoggedHost "   [ERROR] Python $pythonVersion is not compatible with DirectML (requires 3.8-3.10)" -ForegroundColor Red
                Write-LoggedHost "   [INFO] This script installs Python 3.9 - please run again" -ForegroundColor Yellow
                return $false
            }
        } else {
            # Snapdragon ARM64 platform
            Write-LoggedHost "   [NPU] Configuring Snapdragon NPU acceleration..." -ForegroundColor Yellow
            
            try {
                Write-LoggedHost "   [NPU] Installing Snapdragon NPU runtime..." -ForegroundColor Yellow
                
                $result = pip install winml --no-warn-script-location 2>&1
                $result | Out-File -FilePath $logPath -Append -Encoding UTF8
                
                $result = pip install onnxruntime-qnn --no-warn-script-location 2>&1
                $result | Out-File -FilePath $logPath -Append -Encoding UTF8
                
                if ($LASTEXITCODE -eq 0) {
                    Write-LoggedHost "   [OK] Snapdragon NPU acceleration configured successfully" -ForegroundColor Green
                } else {
                    Write-LoggedHost "   [WARNING] Standard NPU runtime installed - demo will use available acceleration" -ForegroundColor Yellow
                }
            } catch {
                Write-LoggedHost "   [WARNING] Using standard ARM64 optimizations" -ForegroundColor Yellow
            }
        }
        
        Write-LoggedHost "[OK] Python dependencies installed successfully" -ForegroundColor Green
        return $true
        
    } catch {
        Write-LoggedHost "[WARNING] Some packages may have failed to install: $_" -ForegroundColor Yellow
        Write-LoggedHost "[INFO] Check $logPath for detailed error information" -ForegroundColor Yellow
        return $true  # Continue anyway
    }
}

function Configure-Firewall {
    Write-LoggedHost "[FIREWALL] Configuring Windows Firewall..." -ForegroundColor Yellow
    
    try {
        New-NetFirewallRule -DisplayName "AI Demo - Python HTTP" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        New-NetFirewallRule -DisplayName "AI Demo - WebSocket" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        
        Write-LoggedHost "[OK] Firewall rules configured" -ForegroundColor Green
        return $true
        
    } catch {
        Write-LoggedHost "[WARNING] Could not configure firewall automatically: $_" -ForegroundColor Yellow
        return $false
    }
}

function Configure-PowerSettings {
    Write-LoggedHost "[POWER] Configuring power settings for demo..." -ForegroundColor Yellow
    
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        powercfg /change standby-timeout-ac 0 2>$null
        powercfg /change standby-timeout-dc 0 2>$null
        powercfg /change hibernate-timeout-ac 0 2>$null
        powercfg /change hibernate-timeout-dc 0 2>$null
        powercfg /change monitor-timeout-ac 0 2>$null
        powercfg /change monitor-timeout-dc 0 2>$null
        
        Write-LoggedHost "[OK] Power settings optimized for demo" -ForegroundColor Green
        return $true
        
    } catch {
        Write-LoggedHost "[WARNING] Could not configure all power settings: $_" -ForegroundColor Yellow
        return $false
    }
}

function Create-StartupScript {
    param([string]$DemoPath)
    
    Write-LoggedHost "[SCRIPT] Creating demo startup script..." -ForegroundColor Yellow
    
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

    $startupPath = Join-Path $DemoPath "start_demo.bat"
    $startupScript | Out-File -FilePath $startupPath -Encoding ASCII
    
    # Create desktop shortcut
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $desktopPath = Join-Path $env:USERPROFILE "Desktop"
        $shortcutPath = Join-Path $desktopPath "AI Demo.lnk"
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $startupPath
        $Shortcut.WorkingDirectory = $DemoPath
        $Shortcut.IconLocation = "shell32.dll,13"
        $Shortcut.Save()
        Write-LoggedHost "[OK] Desktop shortcut created" -ForegroundColor Green
    } catch {
        Write-LoggedHost "[WARNING] Could not create desktop shortcut: $_" -ForegroundColor Yellow
    }
    
    Write-LoggedHost "[OK] Startup script created" -ForegroundColor Green
    return $true
}

# Main execution
function Main {
    Initialize-Logging
    
    Write-LoggedHost "[START] Starting Windows machine setup for AI demo..." -ForegroundColor Cyan
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-LoggedHost "[ERROR] This script requires administrator privileges. Please run as administrator." -ForegroundColor Red
        exit 1
    }
    
    Write-LoggedHost "[OK] Running with administrator privileges" -ForegroundColor Green
    
    # Install prerequisites
    if (-not (Install-Python)) {
        Write-LoggedHost "[ERROR] Failed to install Python. Exiting." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Install-Git)) {
        Write-LoggedHost "[ERROR] Failed to install Git. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Setup demo directory
    $demoPath = Setup-DemoDirectory
    if (-not $demoPath) {
        Write-LoggedHost "[ERROR] Failed to setup demo directory. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Install Python dependencies
    if (-not (Install-PythonDependencies -DemoPath $demoPath)) {
        Write-LoggedHost "[WARNING] Some Python dependencies may have issues, but continuing..." -ForegroundColor Yellow
    }
    
    # Configure system settings
    Configure-Firewall | Out-Null
    Configure-PowerSettings | Out-Null
    
    # Create startup script
    Create-StartupScript -DemoPath $demoPath | Out-Null
    
    Write-LoggedHost "============================================" -ForegroundColor Green
    Write-LoggedHost "[SUCCESS] Windows setup completed successfully!" -ForegroundColor Green
    Write-LoggedHost "============================================" -ForegroundColor Green
    Write-LoggedHost "[INFO] Demo directory: $demoPath" -ForegroundColor Yellow
    Write-LoggedHost "[INFO] Log file: $logPath" -ForegroundColor Yellow
    Write-LoggedHost "[INFO] Platform detected: $(Get-PlatformArchitecture)" -ForegroundColor Cyan
    Write-LoggedHost ""
    Write-LoggedHost "[NEXT STEPS]:" -ForegroundColor Cyan
    $clientPath = Join-Path $demoPath "client\"
    Write-LoggedHost "1. Copy demo client files to $clientPath" -ForegroundColor White
    Write-LoggedHost "2. Run: .\deployment\prepare_models.ps1" -ForegroundColor White
    Write-LoggedHost "3. Run: .\deployment\verify_setup.ps1" -ForegroundColor White
}

# Run main setup
Main
