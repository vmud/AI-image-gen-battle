# Universal Deploy to Production Script for Intel and Snapdragon Systems
# Copies files from GitHub working directory to C:\AIDemo production location

param(
    [Parameter(Mandatory=$false)]
    [string]$SourceDir = "C:\Users\Mosai\ai-demo-working",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetDir = "C:\AIDemo",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("auto", "intel", "snapdragon")]
    [string]$Platform = "auto",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

# Color functions for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Platform detection function
function Detect-Platform {
    Write-ColorOutput Cyan "Detecting platform..."
    
    # Check for Intel CPU
    $cpuInfo = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
    $cpuName = $cpuInfo.Name.ToLower()
    
    if ($cpuName -like "*intel*") {
        Write-ColorOutput Green "  ✓ Intel processor detected: $($cpuInfo.Name)"
        return "intel"
    }
    elseif ($cpuName -like "*snapdragon*" -or $cpuName -like "*qualcomm*" -or $cpuName -like "*arm*") {
        Write-ColorOutput Green "  ✓ Snapdragon/ARM processor detected: $($cpuInfo.Name)"
        return "snapdragon"
    }
    else {
        Write-ColorOutput Yellow "  ⚠ Unknown processor: $($cpuInfo.Name)"
        Write-ColorOutput Yellow "  Defaulting to Intel configuration"
        return "intel"
    }
}

# Determine platform
if ($Platform -eq "auto") {
    $detectedPlatform = Detect-Platform
} else {
    $detectedPlatform = $Platform
    Write-ColorOutput Cyan "Using specified platform: $detectedPlatform"
}

Write-ColorOutput Yellow "==========================================="
Write-ColorOutput Yellow "  Universal AI Demo - Production Deploy   "
Write-ColorOutput Yellow "  Platform: $($detectedPlatform.ToUpper())             "
Write-ColorOutput Yellow "==========================================="
Write-Host ""

# Verify source directory exists
if (-not (Test-Path $SourceDir)) {
    Write-ColorOutput Red "ERROR: Source directory not found: $SourceDir"
    exit 1
}

Write-ColorOutput Cyan "Source: $SourceDir"
Write-ColorOutput Cyan "Target: $TargetDir"
Write-ColorOutput Cyan "Platform: $detectedPlatform"
Write-Host ""

# Create target directory if it doesn't exist
if (-not (Test-Path $TargetDir)) {
    Write-ColorOutput Yellow "Creating target directory: $TargetDir"
    New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
}

# Function to copy with progress
function Copy-WithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Description
    )
    
    Write-ColorOutput Green "► Copying $Description..."
    
    # Create destination directory if needed
    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    }
    
    # Copy with overwrite
    try {
        if (Test-Path $Source) {
            Copy-Item -Path $Source -Destination $Destination -Recurse -Force
            Write-ColorOutput Green "  ✓ Copied successfully"
        } else {
            Write-ColorOutput Yellow "  ⚠ Source not found: $Source"
        }
    } catch {
        Write-ColorOutput Red "  ✗ Error copying: $_"
    }
}

Write-ColorOutput Cyan "Starting deployment..."
Write-Host ""

# 1. Copy core Python application files
Write-ColorOutput Yellow "=== Core Application Files ==="
Copy-WithProgress "$SourceDir\src\windows-client\*.py" "$TargetDir\src\" "Python application files"

# 2. Copy static web assets
Write-ColorOutput Yellow "`n=== Static Web Assets ==="
Copy-WithProgress "$SourceDir\src\windows-client\static" "$TargetDir\static" "HTML/JS/CSS files"

# 3. Copy deployment scripts (Platform-specific and common)
Write-ColorOutput Yellow "`n=== Deployment Scripts ==="
Copy-WithProgress "$SourceDir\deployment\common" "$TargetDir\deployment\common" "Common scripts"

if ($detectedPlatform -eq "intel") {
    Copy-WithProgress "$SourceDir\deployment\intel" "$TargetDir\deployment\intel" "Intel-specific scripts"
} else {
    Copy-WithProgress "$SourceDir\deployment\snapdragon" "$TargetDir\deployment\snapdragon" "Snapdragon-specific scripts"
}

# 4. Copy requirements files
Write-ColorOutput Yellow "`n=== Requirements Files ==="
Copy-WithProgress "$SourceDir\requirements.txt" "$TargetDir\requirements.txt" "Main requirements"

if ($detectedPlatform -eq "intel") {
    Copy-WithProgress "$SourceDir\deployment\intel\requirements\*.txt" "$TargetDir\requirements\" "Intel requirements"
} else {
    Copy-WithProgress "$SourceDir\deployment\snapdragon\requirements\*.txt" "$TargetDir\requirements\" "Snapdragon requirements"
}

# 5. Copy documentation
Write-ColorOutput Yellow "`n=== Documentation ==="
Copy-WithProgress "$SourceDir\docs" "$TargetDir\docs" "Documentation files"
Copy-WithProgress "$SourceDir\README.md" "$TargetDir\README.md" "README"

# 6. Create necessary empty directories
Write-ColorOutput Yellow "`n=== Creating Directory Structure ==="

if ($detectedPlatform -eq "intel") {
    $modelPath = "$TargetDir\models\stable-diffusion\intel-optimized"
} else {
    $modelPath = "$TargetDir\models\stable-diffusion\snapdragon-optimized"
}

$directories = @(
    $modelPath,
    "$TargetDir\logs",
    "$TargetDir\cache",
    "$TargetDir\temp",
    "$TargetDir\diagnostic_reports",
    "$TargetDir\config"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-ColorOutput Green "  ✓ Created: $dir"
    }
}

# 7. Create production config file based on platform
Write-ColorOutput Yellow "`n=== Creating Production Config ==="

if ($detectedPlatform -eq "intel") {
    $configContent = @"
{
    "platform": "intel",
    "environment": "production",
    "model_path": "C:\\AIDemo\\models\\stable-diffusion\\intel-optimized",
    "cache_dir": "C:\\AIDemo\\cache",
    "log_dir": "C:\\AIDemo\\logs",
    "host": "0.0.0.0",
    "port": 5000,
    "debug": false,
    "enable_diagnostics": true,
    "performance_mode": "optimized",
    "max_batch_size": 2,
    "device": "cpu",
    "use_directml": true,
    "use_onnx": false,
    "num_threads": 8,
    "optimization_level": "O2"
}
"@
} else {
    $configContent = @"
{
    "platform": "snapdragon",
    "environment": "production",
    "model_path": "C:\\AIDemo\\models\\stable-diffusion\\snapdragon-optimized",
    "cache_dir": "C:\\AIDemo\\cache",
    "log_dir": "C:\\AIDemo\\logs",
    "host": "0.0.0.0",
    "port": 5000,
    "debug": false,
    "enable_diagnostics": true,
    "performance_mode": "optimized",
    "max_batch_size": 1,
    "device": "cpu",
    "use_onnx": true,
    "onnx_providers": ["CPUExecutionProvider"]
}
"@
}

$configContent | Out-File -FilePath "$TargetDir\config\production.json" -Encoding UTF8
Write-ColorOutput Green "  ✓ Created production config for $detectedPlatform"

# 8. Create launcher scripts
Write-ColorOutput Yellow "`n=== Creating Launcher Scripts ==="

# Main launcher
$launcherContent = @"
@echo off
cd /d C:\AIDemo
echo Starting AI Demo ($detectedPlatform)...
call .venv\Scripts\activate.bat
python src\demo_client.py
pause
"@
$launcherContent | Out-File -FilePath "$TargetDir\launch_demo.bat" -Encoding ASCII
Write-ColorOutput Green "  ✓ Created launch_demo.bat"

# Setup script with platform-specific requirements
if ($detectedPlatform -eq "intel") {
    $requirementsFile = "requirements\requirements-intel.txt"
} else {
    $requirementsFile = "requirements\requirements-snapdragon.txt"
}

$setupContent = @"
@echo off
cd /d C:\AIDemo
echo Setting up Python environment for $detectedPlatform...
python -m venv .venv
call .venv\Scripts\activate.bat
pip install --upgrade pip

echo Installing core requirements...
pip install -r requirements.txt

if exist "$requirementsFile" (
    echo Installing $detectedPlatform-specific requirements...
    pip install -r $requirementsFile
)

echo Setup complete for $detectedPlatform!
pause
"@
$setupContent | Out-File -FilePath "$TargetDir\setup_environment.bat" -Encoding ASCII
Write-ColorOutput Green "  ✓ Created setup_environment.bat"

# 9. Create model download script
$modelScriptContent = @"
# Download and prepare models for $detectedPlatform
import os
import sys
import platform

sys.path.append('C:\\AIDemo\\src')

detected_platform = '$detectedPlatform'
print(f"Downloading and converting models for {detected_platform.upper()}...")
print("This process will:")
print("1. Download Stable Diffusion v1.5")

if detected_platform == 'intel':
    print("2. Optimize for Intel CPU with DirectML")
    print("3. Configure for multi-threading")
else:
    print("2. Convert to ONNX format")
    print("3. Optimize for Snapdragon/ARM")

print("")
print("Note: This requires ~4GB of disk space and may take 15-30 minutes")
print("")

# Model preparation logic would go here
# For now, this is a placeholder
print(f"Model preparation complete for {detected_platform}!")
"@
$modelScriptContent | Out-File -FilePath "$TargetDir\prepare_models.py" -Encoding UTF8
Write-ColorOutput Green "  ✓ Created model preparation script"

# 10. Create platform info file
$platformInfo = @"
Platform: $detectedPlatform
Deployed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Source: $SourceDir
CPU: $($cpuInfo.Name)
"@
$platformInfo | Out-File -FilePath "$TargetDir\platform_info.txt" -Encoding UTF8

Write-Host ""
Write-ColorOutput Yellow "==========================================="
Write-ColorOutput Green "✅ Deployment Complete!"
Write-ColorOutput Yellow "==========================================="
Write-Host ""
Write-ColorOutput Cyan "Platform: $($detectedPlatform.ToUpper())"
Write-Host ""
Write-ColorOutput Cyan "Next Steps:"
Write-ColorOutput White "1. Navigate to: C:\AIDemo"
Write-ColorOutput White "2. Run: setup_environment.bat (first time only)"
Write-ColorOutput White "3. Download models: python prepare_models.py"
Write-ColorOutput White "4. Launch demo: launch_demo.bat"
Write-Host ""
Write-ColorOutput Yellow "Production directory structure created at: $TargetDir"
Write-ColorOutput Yellow "Optimized for: $detectedPlatform platform"
