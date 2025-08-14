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
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        
        # Install Python silently
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "Python installation completed" -ForegroundColor Green
        Remove-Item $pythonInstaller -Force
        return $true
        
    } catch {
        Write-Host "Failed to install Python: $_" -ForegroundColor Red
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
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
        
        # Install Git silently
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "Git installation completed" -ForegroundColor Green
        Remove-Item $gitInstaller -Force
        return $true
        
    } catch {
        Write-Host "Failed to install Git: $_" -ForegroundColor Red
        return $false
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

# Function to install Python dependencies
function Install-PythonDependencies {
    param([string]$DemoPath)
    
    Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
    
    # Create requirements.txt
    $requirements = @"
torch>=2.0.0
torchvision>=0.15.0
diffusers>=0.21.0
transformers>=4.25.0
accelerate>=0.16.0
xformers>=0.0.16
safetensors>=0.3.0
Pillow>=9.3.0
numpy>=1.24.0
opencv-python>=4.7.0
psutil>=5.9.0
flask>=2.2.0
flask-socketio>=5.3.0
requests>=2.28.0
websocket-client>=1.4.0
python-socketio>=5.7.0
directml>=1.12.0
onnxruntime-directml>=1.16.0
"@

    $requirementsPath = "$DemoPath\requirements.txt"
    $requirements | Out-File -FilePath $requirementsPath -Encoding UTF8
    
    try {
        # Create virtual environment
        Set-Location $DemoPath
        python -m venv venv
        
        # Activate virtual environment and install dependencies
        & "$DemoPath\venv\Scripts\Activate.ps1"
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        
        Write-Host "Python dependencies installed successfully" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Failed to install Python dependencies: $_" -ForegroundColor Red
        return $false
    }
}

# Function to configure Windows firewall
function Configure-Firewall {
    Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
    
    try {
        # Allow Python through firewall
        New-NetFirewallRule -DisplayName "AI Demo - Python" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -Force | Out-Null
        New-NetFirewallRule -DisplayName "AI Demo - WebSocket" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow -Force | Out-Null
        
        Write-Host "Firewall rules configured" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Failed to configure firewall: $_" -ForegroundColor Red
        return $false
    }
}

# Function to disable Windows power management
function Configure-PowerSettings {
    Write-Host "Configuring power settings for demo..." -ForegroundColor Yellow
    
    try {
        # Set high performance power plan
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        
        # Disable sleep and hibernation
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 0
        powercfg /change hibernate-timeout-ac 0
        powercfg /change hibernate-timeout-dc 0
        
        # Disable display timeout
        powercfg /change monitor-timeout-ac 0
        powercfg /change monitor-timeout-dc 0
        
        Write-Host "Power settings optimized for demo" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Failed to configure power settings: $_" -ForegroundColor Red
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
python client\demo_client.py
pause
"@

    $startupPath = "$DemoPath\start_demo.bat"
    $startupScript | Out-File -FilePath $startupPath -Encoding ASCII
    
    # Create desktop shortcut
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\AI Demo.lnk")
    $Shortcut.TargetPath = $startupPath
    $Shortcut.WorkingDirectory = $DemoPath
    $Shortcut.IconLocation = "shell32.dll,13"
    $Shortcut.Save()
    
    Write-Host "Startup script and desktop shortcut created" -ForegroundColor Green
    return $true
}

# Function to run platform detection
function Run-PlatformDetection {
    param([string]$DemoPath)
    
    Write-Host "Running platform detection..." -ForegroundColor Yellow
    
    try {
        Set-Location $DemoPath
        & "$DemoPath\venv\Scripts\Activate.ps1"
        python client\platform_detection.py
        
        Write-Host "Platform detection completed" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Platform detection failed: $_" -ForegroundColor Red
        return $false
    }
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
        Write-Host "Failed to install Python dependencies. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Configure system settings
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
}

# Run main setup
Main