#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create Intel Demo Launcher Scripts
.DESCRIPTION
    Creates comprehensive launcher scripts for Intel AI demo
.NOTES
    This script creates the final launcher components for the Intel demo
#>

param(
    [string]$DemoBase = "C:\AIDemo",
    [string]$ClientPath = "C:\AIDemo\client",
    [string]$VenvPath = "C:\AIDemo\venv"
)

# Create batch file starter
$batchScript = @"
@echo off
echo ====================================================
echo  Intel AI Image Generation Demo
echo  DirectML GPU-Accelerated
echo  Expected Performance: 35-45 seconds per image
echo ====================================================
echo.
cd /d "$ClientPath"
call "$VenvPath\Scripts\activate.bat"
python launch_intel_demo.py
pause
"@

Write-Host "Creating batch launcher..." -ForegroundColor Green
$batchScript | Out-File -FilePath "$DemoBase\start_intel_demo.bat" -Encoding ASCII

# Create PowerShell starter with comprehensive error handling
$psScript = @"
# Intel AI Demo Client Launcher with Enhanced Features
param([switch]`$Verbose = `$false)

Write-Host '====================================================' -ForegroundColor Cyan
Write-Host ' Intel AI Image Generation Demo' -ForegroundColor White
Write-Host ' DirectML GPU-Accelerated • Core Ultra Optimized' -ForegroundColor Yellow
Write-Host '====================================================' -ForegroundColor Cyan
Write-Host ''

try {
    # Change to client directory
    Set-Location '$ClientPath'
    Write-Host 'Activating Python environment...' -ForegroundColor Green
    
    # Activate virtual environment
    & '$VenvPath\Scripts\Activate.ps1'
    
    # Launch with comprehensive environment setup
    Write-Host 'Launching Intel AI demo with comprehensive validation...' -ForegroundColor Green
    python launch_intel_demo.py
    
} catch {
    Write-Host ''
    Write-Host 'ERROR: Demo launch failed' -ForegroundColor Red
    Write-Host 'Error details: ' -ForegroundColor Yellow -NoNewline
    Write-Host `$_.Exception.Message -ForegroundColor White
    Write-Host ''
    Write-Host 'Troubleshooting steps:' -ForegroundColor Yellow
    Write-Host '1. Re-run prepare_intel.ps1 script' -ForegroundColor White
    Write-Host '2. Check DirectML installation' -ForegroundColor White
    Write-Host '3. Verify Python 3.10 is installed' -ForegroundColor White
    Write-Host ''
    Read-Host 'Press Enter to exit'
}
"@

Write-Host "Creating PowerShell launcher..." -ForegroundColor Green
$psScript | Out-File -FilePath "$DemoBase\start_intel_demo.ps1" -Encoding UTF8

# Create desktop shortcut launcher
$shortcutScript = @"
@echo off
echo Launching Intel AI Demo...
start "" "$DemoBase\start_intel_demo.bat"
"@

Write-Host "Creating desktop shortcut..." -ForegroundColor Green
$shortcutScript | Out-File -FilePath "$DemoBase\Intel_AI_Demo.bat" -Encoding ASCII

Write-Host "All Intel demo launchers created successfully!" -ForegroundColor Green
Write-Host "Launch the demo with: $DemoBase\start_intel_demo.bat" -ForegroundColor Yellow
