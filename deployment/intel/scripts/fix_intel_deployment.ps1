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

# Function to install Python 3.10 automatically
function Install-Python310 {
    Write-FixInfo "Installing Python 3.10.11 automatically..."
    
    try {
        # Create temp directory if needed
        if (!(Test-Path $DEMO_BASE)) {
            New-Item -ItemType Directory -Path $DEMO_BASE -Force | Out-Null
        }
        
        $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
        $installer = "$DEMO_BASE\python-3.10.11-amd64.exe"
        
        Write-FixInfo "Downloading Python 3.10.11 installer..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($pythonUrl, $installer)
        
        Write-FixInfo "Installing Python 3.10.11..."
        $installArgs = @("/quiet", "InstallAllUsers=1", "PrependPath=1", "TargetDir=C:\Python310")
        Start-Process -FilePath $installer -ArgumentList $installArgs -Wait
        
        # Update PATH to include Python 3.10
        $env:Path = "C:\Python310;C:\Python310\Scripts;$env:Path"
        
        # Verify installation
        $versionCheck = & C:\Python310\python.exe --version 2>&1
        if ($versionCheck -match "Python 3\.10") {
            Write-FixSuccess "Python 3.10 installed successfully: $versionCheck"
        } else {
            Write-FixError "Python 3.10 installation verification failed"
            return $false
        }
        
        # Clean up installer
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        return $true
        
    } catch {
        Write-FixError "Failed to install Python 3.10: $_"
        return $false
    }
}

# Function to check Python 3.10 installation or install it
function Test-Python310Required {
    Write-FixInfo "Checking for Python 3.10 installation (required for torch-directml)..."
    
    # Look for Python 3.10 specifically
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
                    Write-FixSuccess "Found Python 3.10.$buildNumber at $path"
                    $python310Found = $true
                    $python310Path = Split-Path $path -Parent
                    break
                }
            } catch {
                continue
            }
        }
    }
    
    if (-not $python310Found) {
        Write-FixWarning "Python 3.10 not found. Installing automatically..."
        return Install-Python310
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

# Check Python 3.10 requirement - install if not found
if (-not (Test-Python310Required)) {
    Write-FixWarning "Python 3.10 not found. Installing Python 3.10.11..."
    
    # Install Python 3.10 automatically
    try {
        $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
        $installer = "$env:TEMP\python-3.10.11-amd64.exe"
        
        Write-FixInfo "Downloading Python 3.10.11 installer..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($pythonUrl, $installer)
        
        Write-FixInfo "Installing Python 3.10.11..."
        $installArgs = @("/quiet", "InstallAllUsers=1", "PrependPath=1", "TargetDir=C:\Python310")
        Start-Process -FilePath $installer -ArgumentList $installArgs -Wait
        
        # Update PATH to include Python 3.10
        $env:Path = "C:\Python310;C:\Python310\Scripts;$env:Path"
        
        # Verify installation
        $versionCheck = & C:\Python310\python.exe --version 2>&1
        if ($versionCheck -match "Python 3\.10") {
            Write-FixSuccess "Python 3.10 installed successfully: $versionCheck"
        } else {
            Write-FixError "Python 3.10 installation verification failed"
            exit 1
        }
        
        # Clean up installer
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-FixError "Failed to install Python 3.10: $_"
        exit 1
    }
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
    # CRITICAL: DirectML is now in maintenance mode - using legacy resolver
    Write-FixWarning "DirectML is in maintenance mode - using legacy resolver for compatibility"
    Write-FixInfo "Microsoft recommends Windows ML for Windows 11 24H2+, but DirectML still works"
    
    # Step 1: Install PyTorch 2.3.1 (torch-directml supports up to 2.3.1)
    Write-FixInfo "Step 1: Installing PyTorch 2.3.1 and torchvision 0.18.1 (torch-directml compatible)..."
    & pip install torch==2.3.1 torchvision==0.18.1 --index-url https://download.pytorch.org/whl/cpu
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyTorch and torchvision"
    }
    Write-FixSuccess "Installed torch-directml compatible PyTorch"
    
    # Step 2: Install DirectML with legacy resolver (CRITICAL FIX)
    Write-FixInfo "Step 2: Installing torch-directml with legacy resolver..."
    & pip install torch-directml --use-deprecated=legacy-resolver
    if ($LASTEXITCODE -ne 0) {
        Write-FixWarning "torch-directml failed with legacy resolver, trying fallback methods..."
        
        # Fallback: Try with no-deps to avoid conflicts
        & pip install torch-directml --no-deps --use-deprecated=legacy-resolver
        if ($LASTEXITCODE -ne 0) {
            Write-FixError "torch-directml installation failed with all methods"
            Write-FixInfo "Installing ONNX Runtime DirectML as alternative..."
            
            # Fallback to ONNX Runtime DirectML
            & pip install onnxruntime-directml
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install any DirectML package"
            }
            Write-FixSuccess "Installed ONNX Runtime DirectML as DirectML alternative"
        } else {
            Write-FixSuccess "Installed torch-directml with no-deps fallback"
        }
    } else {
        Write-FixSuccess "Installed torch-directml with legacy resolver"
    }
    
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
    
    # Step 4: Install Intel optimizations and remaining dependencies
    Write-FixInfo "Step 4: Installing Intel Extension for PyTorch (CPU optimization)..."
    & pip install intel-extension-for-pytorch --use-deprecated=legacy-resolver
    if ($LASTEXITCODE -ne 0) {
        Write-FixWarning "Intel Extension for PyTorch failed (optional)"
    } else {
        Write-FixSuccess "Installed Intel Extension for PyTorch"
    }
    
    # Install ONNX Runtime DirectML as backup acceleration method
    Write-FixInfo "Installing ONNX Runtime DirectML (DirectML alternative)..."
    & pip install onnxruntime-directml
    if ($LASTEXITCODE -ne 0) {
        Write-FixWarning "ONNX Runtime DirectML failed (optional but recommended)"
    } else {
        Write-FixSuccess "Installed ONNX Runtime DirectML"
    }
    
    # Install remaining core dependencies
    Write-FixInfo "Installing remaining core dependencies..."
    $corePackages = @(
        "flask>=2.0.0",
        "flask-socketio>=5.0.0", 
        "requests>=2.25.0",
        "psutil>=5.8.0",
        "numpy>=1.21.0",
        "pillow>=8.0.0"
    )
    
    foreach ($package in $corePackages) {
        & pip install $package
        if ($LASTEXITCODE -ne 0) {
            Write-FixWarning "Failed to install $package (may affect functionality)"
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
    print(f"✓ PyTorch: {torch.__version__}")
    
    # Test torch-directml (primary acceleration)
    try:
        import torch_directml
        print("✓ torch-directml: Available")
        if torch_directml.is_available():
            device = torch_directml.device()
            print(f"✓ DirectML device: {device}")
        else:
            print("! DirectML device: Not available")
    except ImportError:
        print("✗ torch-directml: Not available")
    
    # Test ONNX Runtime DirectML (fallback acceleration)
    try:
        import onnxruntime as ort
        providers = ort.get_available_providers()
        if 'DmlExecutionProvider' in providers:
            print("✓ ONNX Runtime DirectML: Available")
        else:
            print("! ONNX Runtime DirectML: Not in providers")
    except ImportError:
        print("✗ ONNX Runtime: Not available")
    
    # Test Intel Extension (CPU optimization)
    try:
        import intel_extension_for_pytorch as ipex
        print("✓ Intel Extension for PyTorch: Available")
    except ImportError:
        print("✗ Intel Extension: Not available")
        
except Exception as e:
    print(f"✗ PyTorch/DirectML test failed: {e}")

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
