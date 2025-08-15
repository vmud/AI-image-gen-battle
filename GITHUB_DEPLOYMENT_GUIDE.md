# 🚀 Production Deployment via GitHub

## Overview
This guide provides step-by-step instructions for deploying the AI Image Generation Demo to production client machines using GitHub cloning.

---

## Prerequisites

### On Client Machine (Windows)
- [ ] Windows 10/11 (Intel or Snapdragon)
- [ ] Administrator access
- [ ] Internet connection for initial setup
- [ ] At least 10GB free disk space

### Required Software
- [ ] Git for Windows (will be installed if missing)
- [ ] Python 3.10 or 3.11 (will be installed if missing)

---

## Step-by-Step Deployment Process

### Step 1: Install Git (if not already installed)

**Option A: Check if Git is installed**
```powershell
# Open PowerShell as Administrator
git --version
```

**Option B: Install Git if needed**
1. Download Git from: https://git-scm.com/download/win
2. Run installer with default settings
3. Restart PowerShell/Command Prompt after installation

### Step 2: Clone Repository

```powershell
# Navigate to desired installation directory
cd C:\

# Clone the repository
git clone https://github.com/vmud/AI-image-gen-battle.git

# Navigate to project directory
cd AI-image-gen-battle
```

### Step 3: Run Platform Detection & Setup

```powershell
# Detect platform and run appropriate setup
# This script auto-detects Intel vs Snapdragon

# Option A: Quick Start (Recommended)
powershell -ExecutionPolicy Bypass -File deployment\common\scripts\setup.ps1

# Option B: Manual platform selection
# For Intel:
powershell -ExecutionPolicy Bypass -File deployment\intel\scripts\prepare_intel.ps1

# For Snapdragon:
powershell -ExecutionPolicy Bypass -File deployment\snapdragon\scripts\prepare_snapdragon.ps1
```

### Step 4: Install Dependencies

```powershell
# The setup script will automatically install dependencies
# If manual installation is needed:
powershell -ExecutionPolicy Bypass -File deployment\common\scripts\install_dependencies.ps1
```

### Step 5: Prepare Models

```powershell
# Download and prepare AI models
powershell -ExecutionPolicy Bypass -File deployment\common\scripts\prepare_models.ps1
```

### Step 6: Launch Demo

**For Intel Machines:**
```powershell
cd src\windows-client
python launch_intel_demo.py
```

**For Snapdragon Machines:**
```powershell
cd src\windows-client
python demo_client.py
```

---

## Automated Deployment Script

Create a single deployment script for production:

**deploy_from_github.ps1:**
```powershell
# Production Deployment Script
param(
    [string]$InstallPath = "C:\AI-Demo",
    [switch]$SkipGitCheck = $false
)

Write-Host "=== AI Demo Production Deployment ===" -ForegroundColor Cyan
Write-Host "Deployment Path: $InstallPath" -ForegroundColor Yellow

# Step 1: Check Git
if (-not $SkipGitCheck) {
    Write-Host "`nChecking Git installation..." -ForegroundColor Yellow
    try {
        git --version | Out-Null
        Write-Host "✓ Git is installed" -ForegroundColor Green
    } catch {
        Write-Host "✗ Git not found. Installing..." -ForegroundColor Red
        # Download and install Git
        $gitInstaller = "$env:TEMP\Git-Setup.exe"
        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-2.45.2-64-bit.exe" -OutFile $gitInstaller
        Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT" -Wait
        Write-Host "✓ Git installed" -ForegroundColor Green
    }
}

# Step 2: Clone Repository
Write-Host "`nCloning repository..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
    Write-Host "Directory exists. Pulling latest changes..." -ForegroundColor Yellow
    cd $InstallPath
    git pull origin main
} else {
    git clone https://github.com/vmud/AI-image-gen-battle.git $InstallPath
    cd $InstallPath
}
Write-Host "✓ Repository ready" -ForegroundColor Green

# Step 3: Detect Platform
Write-Host "`nDetecting platform..." -ForegroundColor Yellow
$cpuInfo = Get-WmiObject Win32_Processor | Select-Object -First 1
if ($cpuInfo.Name -like "*Intel*") {
    $platform = "Intel"
} elseif ($cpuInfo.Name -like "*Snapdragon*" -or $cpuInfo.Name -like "*Qualcomm*") {
    $platform = "Snapdragon"
} else {
    $platform = "Unknown"
}
Write-Host "✓ Platform detected: $platform" -ForegroundColor Green

# Step 4: Run Setup
Write-Host "`nRunning setup for $platform..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File "$InstallPath\deployment\common\scripts\setup.ps1"

# Step 5: Create Desktop Shortcut
Write-Host "`nCreating desktop shortcut..." -ForegroundColor Yellow
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcut = "$desktop\AI Demo.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcut)
$Shortcut.TargetPath = "powershell.exe"
if ($platform -eq "Intel") {
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$InstallPath\src\windows-client\launch_intel_demo.py`""
} else {
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$InstallPath\src\windows-client\demo_client.py`""
}
$Shortcut.WorkingDirectory = "$InstallPath\src\windows-client"
$Shortcut.IconLocation = "shell32.dll,13"
$Shortcut.Save()
Write-Host "✓ Desktop shortcut created" -ForegroundColor Green

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Launch the demo from the desktop shortcut or:" -ForegroundColor Cyan
Write-Host "  cd $InstallPath\src\windows-client" -ForegroundColor White
if ($platform -eq "Intel") {
    Write-Host "  python launch_intel_demo.py" -ForegroundColor White
} else {
    Write-Host "  python demo_client.py" -ForegroundColor White
}
```

---

## Quick Deployment Commands

### One-Line Deployment (Copy & Paste)

**For Production Deployment:**
```powershell
# Download and run deployment script
irm https://raw.githubusercontent.com/vmud/AI-image-gen-battle/main/deploy_from_github.ps1 | iex
```

**Alternative Manual Steps:**
```powershell
# Complete deployment in one command
git clone https://github.com/vmud/AI-image-gen-battle.git C:\AI-Demo && cd C:\AI-Demo && powershell -ExecutionPolicy Bypass -File deployment\common\scripts\setup.ps1
```

---

## Update Existing Installation

```powershell
# Navigate to installation directory
cd C:\AI-Demo  # Or wherever you installed it

# Pull latest changes
git pull origin main

# Re-run setup to update dependencies if needed
powershell -ExecutionPolicy Bypass -File deployment\common\scripts\setup.ps1
```

---

## Verification Steps

### 1. Verify Installation
```powershell
# Run diagnostic
cd src\windows-client
python demo_diagnostic.py
```

### 2. Check Dependencies
```powershell
# Verify all dependencies
python deployment\common\validation\verify_dependencies.py
```

### 3. Test Launch
```powershell
# Test without full launch
python demo_client.py --test
```

---

## Troubleshooting

### Common Issues & Solutions

#### Issue 1: Git Clone Fails
```powershell
# If authentication fails, use personal access token
git clone https://[YOUR_TOKEN]@github.com/vmud/AI-image-gen-battle.git

# Or use SSH if configured
git clone git@github.com:vmud/AI-image-gen-battle.git
```

#### Issue 2: PowerShell Execution Policy
```powershell
# Temporarily bypass for session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Or permanently for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

#### Issue 3: Python Not Found
```powershell
# Install Python via winget
winget install Python.Python.3.11

# Or download from python.org
Start-Process "https://www.python.org/downloads/"
```

#### Issue 4: Missing Dependencies
```powershell
# Force reinstall all dependencies
pip install --force-reinstall -r deployment\common\requirements\requirements-core.txt
```

#### Issue 5: Network/Proxy Issues
```powershell
# Configure Git for proxy
git config --global http.proxy http://proxy.company.com:8080
git config --global https.proxy http://proxy.company.com:8080

# Configure pip for proxy
pip config set global.proxy http://proxy.company.com:8080
```

---

## Batch Deployment (Multiple Machines)

### Using Group Policy or SCCM

**deploy_batch.ps1:**
```powershell
# For deploying to multiple machines via network
param(
    [string[]]$ComputerNames,
    [PSCredential]$Credential
)

foreach ($computer in $ComputerNames) {
    Write-Host "Deploying to $computer..." -ForegroundColor Cyan
    
    Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
        # Clone and setup
        git clone https://github.com/vmud/AI-image-gen-battle.git C:\AI-Demo
        cd C:\AI-Demo
        powershell -ExecutionPolicy Bypass -File deployment\common\scripts\setup.ps1
    }
    
    Write-Host "✓ Completed $computer" -ForegroundColor Green
}
```

---

## Security Considerations

### For Production Environments

1. **Use Deploy Keys**: Instead of personal tokens
```bash
# Generate deploy key on client
ssh-keygen -t ed25519 -C "deploy@company.com"
# Add public key to GitHub repo settings
```

2. **Private Repository Access**:
```powershell
# Use GitHub App or OAuth token
git clone https://x-access-token:[TOKEN]@github.com/vmud/AI-image-gen-battle.git
```

3. **Firewall Rules**:
```powershell
# Allow Git and Python through firewall
New-NetFirewallRule -DisplayName "Git" -Direction Outbound -Program "C:\Program Files\Git\bin\git.exe" -Action Allow
New-NetFirewallRule -DisplayName "Python" -Direction Outbound -Program "C:\Python311\python.exe" -Action Allow
```

---

## Post-Deployment Configuration

### 1. Configure Auto-Updates
```powershell
# Schedule daily updates
schtasks /create /tn "AI-Demo-Update" /tr "powershell.exe -File C:\AI-Demo\update.ps1" /sc daily /st 02:00
```

### 2. Setup Monitoring
```powershell
# Enable diagnostic logging
Set-Content -Path "C:\AI-Demo\diagnostic.config" -Value @"
{
    "logging": {
        "enabled": true,
        "level": "INFO",
        "path": "C:\\AI-Demo\\logs",
        "rotation": "daily"
    },
    "monitoring": {
        "performance": true,
        "errors": true,
        "usage": true
    }
}
"@
```

### 3. Performance Optimization
```powershell
# Create performance profile
$perfConfig = @{
    "cache_models" = $true
    "gpu_acceleration" = $true
    "batch_processing" = $true
    "max_workers" = 4
}
$perfConfig | ConvertTo-Json | Out-File "C:\AI-Demo\performance.json"
```

---

## Rollback Procedure

If deployment fails or issues occur:

```powershell
# Step 1: Create backup before update
cd C:\AI-Demo
git tag backup-$(Get-Date -Format "yyyyMMdd-HHmmss")

# Step 2: If rollback needed
git reset --hard backup-[DATE]

# Step 3: Clean and reinstall dependencies
pip uninstall -y -r deployment\common\requirements\requirements-core.txt
pip install -r deployment\common\requirements\requirements-core.txt
```

---

## Deployment Checklist

### Pre-Deployment
- [ ] Verify GitHub repository access
- [ ] Check network connectivity
- [ ] Ensure administrator privileges
- [ ] Review system requirements
- [ ] Backup existing installation (if updating)

### During Deployment
- [ ] Git installation successful
- [ ] Repository cloned successfully
- [ ] Platform detected correctly
- [ ] Dependencies installed
- [ ] Models downloaded
- [ ] Desktop shortcut created

### Post-Deployment
- [ ] Demo launches successfully
- [ ] Diagnostic tests pass
- [ ] Performance acceptable
- [ ] Logging configured
- [ ] Documentation accessible

---

## Support & Contact

### Quick Support Commands
```powershell
# Generate support bundle
cd C:\AI-Demo
powershell -File deployment\common\scripts\diagnose.ps1 > support_bundle.txt

# Check system compatibility
python src\windows-client\platform_detection.py

# Run full diagnostic
python src\windows-client\demo_diagnostic.py --full
```

### Log Locations
- Installation logs: `C:\AI-Demo\deployment.log`
- Application logs: `C:\AI-Demo\src\windows-client\diagnostic.log`
- Error logs: `C:\AI-Demo\error.log`

### Remote Support
```powershell
# Enable remote diagnostics
python deployment\common\scripts\remote_deploy.py --enable-support
```

---

## Version Control

### Check Current Version
```powershell
cd C:\AI-Demo
git describe --tags --always
```

### Update to Specific Version
```powershell
# List available versions
git tag -l

# Switch to specific version
git checkout v1.2.3
```

### Create Local Branch for Customizations
```powershell
git checkout -b company-customizations
# Make your changes
git add .
git commit -m "Company-specific configurations"
```

---

## License & Compliance

This deployment guide is part of the AI Image Generation Demo project.
- License: [Check repository for license information]
- Compliance: Ensure deployment meets your organization's IT policies
- Data Privacy: No user data is transmitted externally by default

---

## Appendix: PowerShell Script Library

### A. Complete Uninstall Script
```powershell
# uninstall.ps1
param([string]$InstallPath = "C:\AI-Demo")

Write-Host "Uninstalling AI Demo..." -ForegroundColor Yellow
# Stop any running processes
Get-Process | Where-Object {$_.Path -like "$InstallPath*"} | Stop-Process -Force
# Remove directory
Remove-Item -Path $InstallPath -Recurse -Force
# Remove desktop shortcut
Remove-Item -Path "$([Environment]::GetFolderPath('Desktop'))\AI Demo.lnk" -Force
# Clean Python cache
pip cache purge
Write-Host "✓ Uninstall complete" -ForegroundColor Green
```

### B. Health Check Script
```powershell
# health_check.ps1
$tests = @{
    "Git" = { git --version }
    "Python" = { python --version }
    "Repository" = { Test-Path "C:\AI-Demo\.git" }
    "Dependencies" = { pip list | Select-String "torch" }
    "Models" = { Test-Path "C:\AI-Demo\models" }
}

foreach ($test in $tests.GetEnumerator()) {
    try {
        & $test.Value | Out-Null
        Write-Host "✓ $($test.Key) - OK" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($test.Key) - FAILED" -ForegroundColor Red
    }
}
```

---

Last Updated: August 2025
Version: 1.0.0
