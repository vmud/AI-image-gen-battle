# AI Demo - Production Deployment Script via GitHub
# Version: 1.0.0
# Usage: .\deploy_from_github.ps1 [-InstallPath "C:\AI-Demo"] [-SkipGitCheck] [-ForceReinstall] [-Branch "main"]

param(
    [string]$InstallPath = "C:\AI-Demo",
    [switch]$SkipGitCheck = $false,
    [switch]$ForceReinstall = $false,
    [string]$Branch = "main"
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Color functions
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

# Banner
Write-Info @"
╔══════════════════════════════════════════════════════════════╗
║       AI Image Generation Demo - Production Deployment       ║
║                    GitHub Cloning Method                     ║
╚══════════════════════════════════════════════════════════════╝
"@

Write-Info "Deployment Configuration:"
Write-Host "  Install Path: $InstallPath" -ForegroundColor White
Write-Host "  Branch: $Branch" -ForegroundColor White
Write-Host "  Force Reinstall: $ForceReinstall" -ForegroundColor White
Write-Host ""

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check admin privileges
if (-not (Test-Administrator)) {
    Write-Error "This script requires Administrator privileges."
    Write-Warning "Please run PowerShell as Administrator and try again."
    exit 1
}

# Function to install Git if needed
function Install-Git {
    Write-Info "`nChecking Git installation..."
    
    try {
        $gitVersion = git --version 2>$null
        Write-Success "✓ Git is already installed: $gitVersion"
        return $true
    } catch {
        Write-Warning "Git not found. Installing Git for Windows..."
        
        try {
            # Download Git installer
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.45.2.windows.1/Git-2.45.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\Git-Setup.exe"
            
            Write-Info "Downloading Git installer..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
            
            Write-Info "Installing Git (this may take a few minutes)..."
            Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS" -Wait
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            # Verify installation
            $gitVersion = git --version 2>$null
            Write-Success "✓ Git installed successfully: $gitVersion"
            return $true
            
        } catch {
            Write-Error "Failed to install Git: $_"
            Write-Warning "Please install Git manually from: https://git-scm.com/download/win"
            return $false
        }
    }
}

# Note: Python installation is handled by the prepare scripts
# This is just a quick check to provide early feedback
function Test-Python {
    Write-Info "`nChecking for Python..."
    
    try {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion -match "Python (3\.\d+\.\d+)") {
            Write-Info "Found: $pythonVersion"
            Write-Info "The prepare script will handle Python environment setup"
            return $true
        }
    } catch {
        Write-Warning "Python not found in PATH"
        Write-Info "The prepare script will attempt to install Python if needed"
    }
    return $true  # Let prepare script handle it
}

# Function to clone or update repository
function Setup-Repository {
    Write-Info "`nSetting up repository..."
    
    if ($ForceReinstall -and (Test-Path $InstallPath)) {
        Write-Warning "Force reinstall requested. Removing existing installation..."
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    if (Test-Path "$InstallPath\.git") {
        Write-Info "Repository exists. Updating to latest version..."
        Push-Location $InstallPath
        try {
            git fetch origin
            git checkout $Branch
            git pull origin $Branch
            Write-Success "✓ Repository updated successfully"
        } catch {
            Write-Error "Failed to update repository: $_"
            Pop-Location
            return $false
        }
        Pop-Location
    } else {
        Write-Info "Cloning repository from GitHub..."
        try {
            # Ensure parent directory exists
            $parentPath = Split-Path $InstallPath -Parent
            if (-not (Test-Path $parentPath)) {
                New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
            }
            
            git clone -b $Branch https://github.com/vmud/AI-image-gen-battle.git $InstallPath
            Write-Success "✓ Repository cloned successfully"
        } catch {
            Write-Error "Failed to clone repository: $_"
            return $false
        }
    }
    
    return $true
}

# Function to detect platform
function Get-Platform {
    Write-Info "`nDetecting system platform..."
    
    try {
        $cpuInfo = Get-WmiObject Win32_Processor | Select-Object -First 1
        $cpuName = $cpuInfo.Name
        
        if ($cpuName -like "*Intel*") {
            Write-Success "✓ Platform detected: Intel"
            return "Intel"
        } elseif ($cpuName -like "*Snapdragon*" -or $cpuName -like "*Qualcomm*" -or $cpuName -like "*ARM*") {
            Write-Success "✓ Platform detected: Snapdragon/ARM"
            return "Snapdragon"
        } else {
            Write-Warning "Unknown processor: $cpuName"
            Write-Info "Defaulting to Intel configuration"
            return "Intel"
        }
    } catch {
        Write-Warning "Could not detect platform: $_"
        Write-Info "Defaulting to Intel configuration"
        return "Intel"
    }
}

# Function to run setup scripts
function Run-Setup {
    param([string]$Platform)
    
    Write-Info "`nRunning setup for $Platform platform..."
    
    Push-Location $InstallPath
    try {
        # The prepare scripts handle everything: Python check, venv creation, 
        # dependency installation, model downloads, etc.
        
        if ($Platform -eq "Intel") {
            $platformScript = "deployment\intel\scripts\prepare_intel.ps1"
            Write-Info "Running Intel platform setup..."
        } else {
            $platformScript = "deployment\snapdragon\scripts\prepare_snapdragon.ps1"
            Write-Info "Running Snapdragon platform setup..."
        }
        
        if (Test-Path $platformScript) {
            Write-Info "Executing: $platformScript"
            Write-Info "This will handle Python setup, dependencies, and model preparation..."
            
            # Execute the prepare script which handles everything
            & powershell -ExecutionPolicy Bypass -File $platformScript
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Platform setup completed successfully"
                return $true
            } else {
                Write-Warning "Platform setup completed with warnings. Check output above."
                return $true  # Continue even with warnings
            }
        } else {
            Write-Error "Platform script not found: $platformScript"
            Write-Info "Attempting fallback to common setup..."
            
            # Fallback to common setup if platform script missing
            $setupScript = "deployment\common\scripts\setup.ps1"
            if (Test-Path $setupScript) {
                & powershell -ExecutionPolicy Bypass -File $setupScript
                return $true
            }
            return $false
        }
    } catch {
        Write-Error "Setup failed: $_"
        return $false
    } finally {
        Pop-Location
    }
}

# Function to create desktop shortcut
function Create-Shortcut {
    param([string]$Platform)
    
    Write-Info "`nCreating desktop shortcut..."
    
    try {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = "$desktop\AI Demo.lnk"
        
        # Remove existing shortcut if present
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
        }
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        
        # Use the venv Python if it exists
        $venvPython = "$InstallPath\venv\Scripts\python.exe"
        if (Test-Path $venvPython) {
            $pythonCmd = "`"$venvPython`""
        } else {
            $pythonCmd = "python"
        }
        
        $Shortcut.TargetPath = "powershell.exe"
        
        if ($Platform -eq "Intel") {
            $Shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -Command `"cd '$InstallPath\src\windows-client'; $pythonCmd launch_intel_demo.py`""
        } else {
            $Shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -Command `"cd '$InstallPath\src\windows-client'; $pythonCmd demo_client.py`""
        }
        
        $Shortcut.WorkingDirectory = "$InstallPath\src\windows-client"
        $Shortcut.IconLocation = "shell32.dll,13"
        $Shortcut.Description = "AI Image Generation Demo"
        $Shortcut.Save()
        
        Write-Success "✓ Desktop shortcut created"
        return $true
    } catch {
        Write-Warning "Could not create desktop shortcut: $_"
        return $false
    }
}

# Function to run diagnostics
function Run-Diagnostics {
    Write-Info "`nRunning diagnostic checks..."
    
    Push-Location "$InstallPath\src\windows-client"
    try {
        # Check if venv exists (created by prepare script)
        $venvPath = "$InstallPath\venv"
        $pythonExe = if (Test-Path "$venvPath\Scripts\python.exe") {
            "$venvPath\Scripts\python.exe"
        } else {
            "python"
        }
        
        if (Test-Path "demo_diagnostic.py") {
            & $pythonExe demo_diagnostic.py --quick 2>$null
            Write-Success "✓ Diagnostics completed"
        } else {
            Write-Warning "Diagnostic script not found"
        }
    } catch {
        Write-Warning "Diagnostics check skipped: $_"
    } finally {
        Pop-Location
    }
}

# Main deployment flow
Write-Info "`n=== Starting Deployment Process ===`n"

# Step 1: Install Git if needed
if (-not $SkipGitCheck) {
    if (-not (Install-Git)) {
        Write-Error "Git installation is required to proceed"
        exit 1
    }
}

# Step 2: Quick Python check (prepare scripts handle installation)
Test-Python

# Step 3: Setup repository
if (-not (Setup-Repository)) {
    Write-Error "Repository setup failed"
    exit 1
}

# Step 4: Detect platform
$platform = Get-Platform

# Step 5: Run setup
if (-not (Run-Setup -Platform $platform)) {
    Write-Warning "Setup completed with warnings. Please check the output above."
}

# Step 6: Create shortcut
Create-Shortcut -Platform $platform

# Step 7: Run diagnostics
Run-Diagnostics

# Deployment summary
Write-Info "`n=== Deployment Complete ===`n"
Write-Success "AI Demo has been successfully deployed!"
Write-Host ""
Write-Info "Installation Details:"
Write-Host "  Location: $InstallPath" -ForegroundColor White
Write-Host "  Platform: $platform" -ForegroundColor White
Write-Host "  Branch: $Branch" -ForegroundColor White
Write-Host ""
Write-Info "To launch the demo:"
Write-Host "  1. Use the desktop shortcut 'AI Demo'" -ForegroundColor White
Write-Host "  2. Or run from PowerShell:" -ForegroundColor White
Write-Host "     cd $InstallPath\src\windows-client" -ForegroundColor Gray

if ($platform -eq "Intel") {
    Write-Host "     python launch_intel_demo.py" -ForegroundColor Gray
} else {
    Write-Host "     python demo_client.py" -ForegroundColor Gray
}

Write-Host ""
Write-Info "For updates, run:"
Write-Host "  cd $InstallPath" -ForegroundColor Gray
Write-Host "  git pull origin $Branch" -ForegroundColor Gray
Write-Host ""
Write-Success "Thank you for using AI Image Generation Demo!"
