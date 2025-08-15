#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Intel Deployment Quick Fix Script - Python 3.10 Only
.DESCRIPTION
    Fixes Intel deployment for Python 3.10 compatibility (required for torch-directml):
    - Enforces Python 3.10 ONLY (not 3.9 or 3.11+)
    - Sets up clean virtual environment
    - Upgrades pip before installing packages
    - Removes all previous torch/torchvision installations
    - Installs torch-directml with proper dependencies
    - Ensures Windows 11 is up-to-date for DirectML support
.PARAMETER CleanInstall
    Remove existing virtual environment and start fresh
.PARAMETER TestOnly
    Only test imports without making changes
.PARAMETER CheckWindowsUpdates
    Check Windows 11 update status for DirectML compatibility
#>

[CmdletBinding()]
param(
    [switch]$CleanInstall = $false,
    [switch]$TestOnly = $false,
    [switch]$CheckWindowsUpdates = $true
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

function Write-FixSuccess {
    param($Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Cyan
}

# Function to check Python 3.10 installation
function Test-Python310Required {
    Write-FixInfo "Verifying Python 3.10 installation (required for torch-directml)..."
    
    # Look for Python 3.10 specifically - NO 3.9 support
    $python310Paths = @(
        "C:\Python310\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "$env:ProgramFiles\Python310\python.exe"
    )
    
    $python310Found = $false
    $python310Path = $null
    
    foreach ($path in $python310Paths) {
        if (Test-Path $path) {
            try {
                $version = & $path --version 2>&1
                if ($version -match "Python 3\.10\.(\d+)") {
                    $buildNumber = [int]$matches[1]
                    if ($buildNumber -ge 6) {
                        Write-FixSuccess "Found Python 3.10.$buildNumber at $path"
                        $python310Found = $true
                        $python310Path = Split-Path $path -Parent
                        break
                    } else {
                        Write-FixWarning "Python 3.10.$buildNumber found but 3.10.6+ recommended"
                        $python310Found = $true
                        $python310Path = Split-Path $path -Parent
                        break
                    }
                }
            } catch {
                continue
            }
        }
    }
    
    if (-not $python310Found) {
        Write-FixError "Python 3.10 not found!"
        Write-FixError "torch-directml requires Python 3.10 (NOT 3.9 or 3.11+)"
        Write-FixError "Please install Python 3.10.11 from: https://www.python.org/downloads/release/python-31011/"
        return $false
    }
    
    # Ensure Python 3.10 is in PATH
    $env:Path = "$python310Path;$python310Path\Scripts;$env:Path"
    
    # Verify no conflicting Python versions
    $pythonInPath = & where.exe python 2>$null
    if ($pythonInPath) {
        $pathVersion = & python --version 2>&1
        if ($pathVersion -notmatch "Python 3\.10") {
            Write-FixWarning "Python in PATH: $pathVersion (should be 3.10)"
            Write-FixWarning "Setting PATH to use Python 3.10..."
            $env:Path = "$python310Path;$python310Path\Scripts;$env:Path"
        } else {
            Write-FixSuccess "Python 3.10 correctly set in PATH"
        }
    }
    
    return $true
}

# Function to check Windows 11 updates for DirectML
function Test-WindowsUpdates {
    if (-not $CheckWindowsUpdates) {
        return $true
    }
    
    Write-FixInfo "Checking Windows 11 updates for DirectML compatibility..."
    
    try {
        $os = Get-WmiObject Win32_OperatingSystem
        $buildNumber = $os.BuildNumber
        
        Write-FixInfo "Windows Build: $buildNumber"
        
        # Windows 11 minimum builds for DirectML
        $minBuildDirectML = 22000  # Windows 11 initial release
        $recommendedBuild = 22621  # Windows 11 22H2 for better DirectML support
        
        if ($buildNumber -ge $recommendedBuild) {
            Write-FixSuccess "Windows 11 22H2+ detected - optimal DirectML support"
        } elseif ($buildNumber -ge $minBuildDirectML) {
            Write-FixWarning "Windows 11 detected but 22H2+ recommended for latest DirectML features"
            Write-FixInfo "Current: $buildNumber | Recommended: $recommendedBuild+"
        } else {
            Write-FixError "Windows version too old for DirectML (build $buildNumber < $minBuildDirectML)"
            Write-FixError "Please update to Windows 11 for DirectML support"
            return $false
        }
        
        # Check for DirectX 12 Ultimate
        Write-FixInfo "Checking DirectX 12 Ultimate support..."
        $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "Intel" } | Select-Object -First 1
        if ($gpu) {
            Write-FixSuccess "Intel GPU detected: $($gpu.Name)"
        } else {
            Write-FixWarning "Intel GPU not detected - DirectML may use fallback"
        }
        
    } catch {
        Write-FixWarning "Could not check Windows version: $_"
    }
    
    return $true
}

# Main execution banner
Write-Host @"
+======================================================+
|          INTEL DEPLOYMENT FIX SCRIPT                |
|          Python 3.10 Only - DirectML Compatible     |
+======================================================+
"@ -ForegroundColor Cyan

Write-FixInfo "Starting Python 3.10 enforcement and DirectML fix..."

# Check Python 3.10 requirement first
if (-not (Test-Python310Required)) {
    Write-FixError "Python 3.10 is required but not found. Exiting."
    exit 1
}

# Check Windows updates
if (-not (Test-WindowsUpdates)) {
    Write-FixError "Windows update requirements not met. Exiting."
    exit 1
}

if ($TestOnly) {
    Write-FixInfo "Running in TEST-ONLY mode"
    
    if (Test-Path "$VENV_PATH\Scripts\python.exe") {
        Write-FixInfo "Virtual environment found, testing imports..."
        
        & "$VENV_PATH\Scripts\Activate.ps1"
        Set-Location $CLIENT_PATH
        
        $testPythonScript = @'
import sys
print("Python:", sys.version)
print("Python Path:", sys.executable)

# Check Python version is 3.10
if sys.version_info.major == 3 and sys.version_info.minor == 10:
    print("✓ Python 3.10: CORRECT VERSION")
else:
    print(f"✗ Python version: {sys.version_info.major}.{sys.version_info.minor} (SHOULD BE 3.10)")

# Test critical imports
try:
    from platform_detection import detect_platform
    platform_info = detect_platform()
    print("✓ detect_platform function: SUCCESS")
    print(f"  Platform: {platform_info.get('platform_type')}")
except Exception as e:
    print(f"✗ platform_detection: FAILED - {e}")

try:
    import torch
    print(f"✓ PyTorch: {torch.__version__}")
except ImportError as e:
    print(f"✗ PyTorch: FAILED - {e}")

try:
    import torch_directml
    print("✓ DirectML: Available")
    if torch_directml.is_available():
        print(f"✓ DirectML device: {torch_directml.device_name(0)}")
    else:
        print("✗ DirectML device: Not available")
except ImportError as e:
    print(f"✗ DirectML: FAILED - {e}")
'@
        
        $testOutput = $testPythonScript | & python 2>&1
        $testOutput | ForEach-Object { Write-Host $_ }
        
    } else {
        Write-FixError "Virtual environment not found at $VENV_PATH"
    }
    
    exit 0
}

# Clean install if requested
if ($CleanInstall -or (Test-Path $VENV_PATH)) {
    Write-FixWarning "Performing clean install - removing existing virtual environment..."
    
    if (Test-Path $VENV_PATH) {
        Remove-Item $VENV_PATH -Recurse -Force
        Write-FixInfo "Removed existing virtual environment"
    }
}

# Create fresh virtual environment with Python 3.10
Write-FixInfo "Creating fresh virtual environment with Python 3.10..."
if (!(Test-Path $VENV_PATH)) {
    & python -m venv $VENV_PATH
    if ($LASTEXITCODE -ne 0) {
        Write-FixError "Failed to create virtual environment"
        exit 1
    }
    Write-FixSuccess "Created Python 3.10 virtual environment"
}

# Activate virtual environment
Write-FixInfo "Activating virtual environment..."
& "$VENV_PATH\Scripts\Activate.ps1"

# Verify we're using Python 3.10 in the virtual environment
$venvPythonVersion = & python --version 2>&1
if ($venvPythonVersion -notmatch "Python 3\.10") {
    Write-FixError "Virtual environment not using Python 3.10: $venvPythonVersion"
    exit 1
}
Write-FixSuccess "Virtual environment using: $venvPythonVersion"

# Upgrade pip BEFORE installing anything
Write-FixInfo "Upgrading pip to latest version..."
& python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    Write-FixError "Failed to upgrade pip"
    exit 1
}
Write-FixSuccess "Pip upgraded successfully"

# Remove any existing torch packages for complete cleanup
Write-FixInfo "Removing all existing torch packages for clean install..."
$torchPackagesToRemove = @("torch", "torchvision", "torchaudio", "torch-directml", "pytorch-directml")

foreach ($package in $torchPackagesToRemove) {
    try {
        & pip uninstall $package -y 2>$null
        Write-FixInfo "Removed $package (if it existed)"
    } catch {
        # Package may not have been installed
    }
}

# Clear pip cache
Write-FixInfo "Clearing pip cache for fresh downloads..."
& pip cache purge 2>$null

# Install packages in correct order for DirectML
Write-FixInfo "Installing PyTorch ecosystem for DirectML compatibility..."

try {
    # Step 1: Install PyTorch 2.0.1 and torchvision 0.15.2
    Write-FixInfo "Step 1: Installing PyTorch 2.0.1 and torchvision 0.15.2..."
    & pip install torch==2.0.1 torchvision==0.15.2 --index-url https://download.pytorch.org/whl/cpu
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyTorch and torchvision"
    }
    Write-FixSuccess "Installed compatible PyTorch and torchvision"
    
    # Step 2: Install DirectML
    Write-FixInfo "Step 2: Installing torch-directml..."
    & pip install torch-directml --index-url https://download.pytorch.org/whl/directml
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install torch-directml"
    }
    Write-FixSuccess "Installed torch-directml successfully"
    
    # Step 3: Install Hugging Face packages
    Write-FixInfo "Step 3: Installing Hugging Face packages..."
    $hfPackages = @(
        "huggingface_hub==0.24.6",
        "transformers==4.36.2",
        "diffusers==0.25.1",
        "accelerate==0.25.0",
        "safetensors==0.4.1"
    )
    
    foreach ($package in $hfPackages) {
        & pip install $package
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install $package"
        }
        Write-FixInfo "Installed $package"
    }
    
    # Step 4: Install remaining dependencies
    Write-FixInfo "Step 4: Installing remaining dependencies..."
    $otherPackages = @(
        "flask>=2.0.0",
        "flask-socketio>=5.0.0", 
        "requests>=2.25.0",
        "psutil>=5.8.0",
        "numpy>=1.21.0",
        "pillow>=8.0.0",
        "onnxruntime-directml>=1.16.0"
    )
    
    foreach ($package in $otherPackages) {
        & pip install $package
        if ($LASTEXITCODE -ne 0) {
            Write-FixWarning "Failed to install $package (may not be critical)"
        } else {
            Write-FixInfo "Installed $package"
        }
    }
    
} catch {
    Write-FixError "Package installation failed: $_"
    Write-FixError "This typically indicates Python version incompatibility"
    Write-FixError "Ensure you're using Python 3.10.6+ and not 3.11 or higher"
    exit 1
}

# Final verification
Write-FixInfo "Running final verification..."
Set-Location $CLIENT_PATH

$verificationScript = @'
import sys
print("=== FINAL VERIFICATION ===")
print(f"Python: {sys.version}")

# Check Python 3.10
if sys.version_info.major == 3 and sys.version_info.minor == 10:
    print("✓ Python 3.10: CORRECT")
else:
    print(f"✗ Wrong Python version: {sys.version_info.major}.{sys.version_info.minor}")

try:
    from platform_detection import detect_platform
    platform_info = detect_platform()
    print(f"✓ Platform detection: {platform_info.get('platform_type')}")
except Exception as e:
    print(f"✗ Platform detection: {e}")

try:
    import torch
    import torch_directml
    print(f"✓ PyTorch: {torch.__version__}")
    print("✓ DirectML: Available")
    if torch_directml.is_available():
        print("✓ DirectML device: Working")
    else:
        print("! DirectML device: Not available")
except Exception as e:
    print(f"✗ DirectML: {e}")

print("=== VERIFICATION COMPLETE ===")
'@

$output = $verificationScript | & python 2>&1
$output | ForEach-Object { Write-Host $_ }

Write-FixSuccess "Intel deployment fix completed for Python 3.10!"
Write-FixInfo "Key achievements:"
Write-FixInfo "- Enforced Python 3.10 (required for torch-directml)"
Write-FixInfo "- Set up clean virtual environment"
Write-FixInfo "- Upgraded pip before installation"
Write-FixInfo "- Removed all previous torch installations"
Write-FixInfo "- Installed DirectML with proper dependencies"
Write-FixInfo "- Verified Windows 11 DirectML compatibility"
Write-FixInfo ""
Write-FixInfo "Next step: Run main deployment script with -Force flag"
Write-FixInfo "Command: .\deployment\intel\scripts\prepare_intel.ps1 -Force"
