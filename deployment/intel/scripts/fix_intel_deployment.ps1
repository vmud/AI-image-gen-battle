#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Intel Deployment Quick Fix Script
.DESCRIPTION
    Fixes common issues with Intel deployment script including:
    - Package version conflicts
    - Missing DirectML packages
    - Import errors in Python modules
.PARAMETER CleanInstall
    Remove existing virtual environment and start fresh
.PARAMETER TestOnly
    Only test imports without making changes
#>

[CmdletBinding()]
param(
    [switch]$CleanInstall = $false,
    [switch]$TestOnly = $false
)

# Constants
$DEMO_BASE = "C:\AIDemo"
$VENV_PATH = "$DEMO_BASE\venv"
$CLIENT_PATH = "$DEMO_BASE\client"

function Write-FixInfo {
    param($Message)
    Write-Host "[FIX] $Message" -ForegroundColor Green
}

function Write-FixError {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-FixWarning {
    param($Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

Write-Host @"
+======================================================+
|          INTEL DEPLOYMENT FIX SCRIPT                |
|          Addressing Common Setup Issues              |
+======================================================+
"@ -ForegroundColor Cyan

# Test if we need to fix the environment
Write-FixInfo "Testing current Python environment..."

if ($TestOnly) {
    Write-FixInfo "Running in TEST-ONLY mode"
    
    if (Test-Path "$VENV_PATH\Scripts\python.exe") {
        Write-FixInfo "Virtual environment found, testing imports..."
        
        & "$VENV_PATH\Scripts\Activate.ps1"
        Set-Location $CLIENT_PATH
        
        $testScript = @"
import sys
print(f'Python: {sys.version}')
print(f'Python Path: {sys.executable}')

# Test basic imports
try:
    import platform_detection
    print('✓ platform_detection import: SUCCESS')
    
    # Test the detect_platform function
    from platform_detection import detect_platform
    platform_info = detect_platform()
    print('✓ detect_platform function: SUCCESS')
    print(f'  Platform: {platform_info.get("platform_type")}')
    print(f'  Name: {platform_info.get("name")}')
    
except ImportError as e:
    print(f'✗ platform_detection import: FAILED - {e}')

try:
    import torch
    print(f'✓ PyTorch: {torch.__version__}')
except ImportError as e:
    print(f'✗ PyTorch: FAILED - {e}')

try:
    import torch_directml
    print(f'✓ DirectML: Available')
    
    if torch_directml.is_available():
        print(f'✓ DirectML device: {torch_directml.device_name(0)}')
    else:
        print('✗ DirectML device: Not available')
        
except ImportError as e:
    print(f'✗ DirectML: FAILED - {e}')

try:
    from diffusers import StableDiffusionXLPipeline
    print('✓ Diffusers: SUCCESS')
except ImportError as e:
    print(f'✗ Diffusers: FAILED - {e}')
"@
        
        $testOutput = $testScript | & python 2>&1
        $testOutput | ForEach-Object { Write-Host $_ }
        
    } else {
        Write-FixError "Virtual environment not found at $VENV_PATH"
    }
    
    exit 0
}

# Clean install if requested
if ($CleanInstall) {
    Write-FixWarning "Performing clean install - removing existing virtual environment..."
    
    if (Test-Path $VENV_PATH) {
        Remove-Item $VENV_PATH -Recurse -Force
        Write-FixInfo "Removed existing virtual environment"
    }
}

# Fix package installation issues
Write-FixInfo "Fixing package installation issues..."

if (!(Test-Path $VENV_PATH)) {
    Write-FixInfo "Creating new virtual environment..."
    & python -m venv $VENV_PATH
}

# Activate virtual environment
& "$VENV_PATH\Scripts\Activate.ps1"

# Uninstall conflicting packages first
Write-FixInfo "Removing potentially conflicting packages..."
$packagesToRemove = @("torch", "torchvision", "torch-directml")

foreach ($package in $packagesToRemove) {
    try {
        & pip uninstall $package -y 2>$null
        Write-FixInfo "Removed $package"
    } catch {
        # Package may not be installed
    }
}

# Install compatible versions in correct order
Write-FixInfo "Installing compatible PyTorch versions..."

try {
    # Install PyTorch 2.0.1 and torchvision 0.15.2 (compatible versions)
    & pip install torch==2.0.1 torchvision==0.15.2 --index-url https://download.pytorch.org/whl/cpu
    Write-FixInfo "Installed compatible PyTorch and torchvision"
    
    # Install DirectML
    & pip install torch-directml --index-url https://download.pytorch.org/whl/directml --pre
    Write-FixInfo "Installed DirectML"
    
    # Install other required packages
    $otherPackages = @(
        "huggingface_hub==0.24.6",
        "transformers==4.36.2", 
        "diffusers==0.25.1",
        "accelerate==0.25.0",
        "safetensors==0.4.1",
        "flask",
        "requests",
        "psutil",
        "numpy",
        "pillow"
    )
    
    foreach ($package in $otherPackages) {
        & pip install $package
        Write-FixInfo "Installed $package"
    }
    
} catch {
    Write-FixError "Package installation failed: $_"
    exit 1
}

# Test the fixed installation
Write-FixInfo "Testing fixed installation..."
Set-Location $CLIENT_PATH

$finalTestScript = @"
print('=== POST-FIX VERIFICATION ===')

try:
    from platform_detection import detect_platform
    platform_info = detect_platform()
    print(f'✓ Platform detection: {platform_info.get("platform_type")}')
except Exception as e:
    print(f'✗ Platform detection failed: {e}')

try:
    import torch
    import torch_directml
    print(f'✓ PyTorch: {torch.__version__}')
    print(f'✓ DirectML: Available')
    
    if torch_directml.is_available():
        device = torch_directml.device()
        print(f'✓ DirectML device: {device}')
    else:
        print('! DirectML device not available')
        
except Exception as e:
    print(f'✗ DirectML test failed: {e}')

print('=== VERIFICATION COMPLETE ===')
"@

$finalOutput = $finalTestScript | & python 2>&1
$finalOutput | ForEach-Object { Write-Host $_ }

Write-FixInfo "Intel deployment fix completed!"
Write-FixInfo "You can now run the main deployment script again"
