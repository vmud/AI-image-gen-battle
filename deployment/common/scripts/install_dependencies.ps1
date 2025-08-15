# Standalone Dependency Installation Script
# Fixes missing modules like 'diffusers' by installing all required packages

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("poetry", "pip", "auto")]
    [string]$Method = "auto",
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AI Demo Dependency Installation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Function to test if a Python package is available
function Test-PythonPackage {
    param([string]$PackageName)
    try {
        python -c "import $PackageName; print('Package available: ' + '$PackageName')" 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to get package version
function Get-PythonPackageVersion {
    param([string]$PackageName)
    try {
        $version = python -c "import $PackageName; print($PackageName.__version__)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $version.Trim()
        }
    } catch { }
    return "Not installed"
}

# Check current Python version and validate compatibility
Write-Host "[INFO] Validating Python installation..." -ForegroundColor Yellow

try {
    $pythonVersion = python --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed"
    }
    
    if ($pythonVersion -match "Python (\d+\.\d+)") {
        $versionNum = [version]$matches[1]
        if ($versionNum -ge [version]"3.11") {
            Write-Host "[ERROR] Python $($matches[1]) is incompatible with DirectML!" -ForegroundColor Red
            Write-Host "[SOLUTION] Run .\fix_python_path.ps1 to install compatible Python" -ForegroundColor Yellow
            exit 1
        } elseif ($versionNum -lt [version]"3.9") {
            Write-Host "[ERROR] Python $($matches[1]) is too old for ML packages!" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "[SUCCESS] Python $($matches[1]) is compatible" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "[ERROR] Python not found or not working!" -ForegroundColor Red
    Write-Host "[SOLUTION] Run .\fix_python_path.ps1 to fix Python installation" -ForegroundColor Yellow
    exit 1
}

# Check current package status
Write-Host "`n[INFO] Checking current package status..." -ForegroundColor Yellow

$requiredPackages = @(
    "torch", "torchvision", "diffusers", "transformers", 
    "huggingface_hub", "accelerate", "safetensors", "optimum", "onnxruntime"
)

$missingPackages = @()
$installedPackages = @()

foreach ($package in $requiredPackages) {
    if (Test-PythonPackage $package) {
        $version = Get-PythonPackageVersion $package
        $installedPackages += "$package ($version)"
        Write-Host "   ✓ $package - $version" -ForegroundColor Green
    } else {
        $missingPackages += $package
        Write-Host "   ✗ $package - Missing" -ForegroundColor Red
    }
}

if ($missingPackages.Count -eq 0 -and -not $Force) {
    Write-Host "`n[SUCCESS] All required packages are already installed!" -ForegroundColor Green
    Write-Host "Installed packages:" -ForegroundColor Cyan
    $installedPackages | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    exit 0
}

$missingList = $missingPackages -join ", "
Write-Host "`n[INFO] Missing packages: $missingList" -ForegroundColor Yellow

# Determine installation method
if ($Method -eq "auto") {
    # Check if Poetry is available and working
    try {
        $poetryVersion = poetry --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[AUTO-DETECT] Found $poetryVersion" -ForegroundColor Gray
            # Test if Poetry environment works
            try {
                poetry run python --version 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $Method = "poetry"
                    Write-Host "[AUTO-DETECT] Using Poetry for installation" -ForegroundColor Cyan
                } else {
                    $Method = "pip"
                    Write-Host "[AUTO-DETECT] Poetry environment broken, using pip" -ForegroundColor Yellow
                }
            } catch {
                $Method = "pip"
                Write-Host "[AUTO-DETECT] Poetry environment issues, using pip" -ForegroundColor Yellow
            }
        } else {
            $Method = "pip"
            Write-Host "[AUTO-DETECT] Poetry not found, using pip" -ForegroundColor Yellow
        }
    } catch {
        $Method = "pip"
        Write-Host "[AUTO-DETECT] Using pip installation" -ForegroundColor Yellow
    }
}

# Install packages using selected method
Write-Host "`n[INFO] Installing packages using $Method..." -ForegroundColor Yellow

if ($Method -eq "poetry") {
    Write-Host "Installing with Poetry..." -ForegroundColor Cyan
    
    # Navigate to deployment directory
    $originalPath = Get-Location
    Set-Location $PSScriptRoot
    
    try {
        # Ensure Poetry environment exists
        Write-Host "   Setting up Poetry environment..." -ForegroundColor Gray
        poetry env use python 2>$null | Out-Null
        
        # Install dependencies
        Write-Host "   Installing Poetry dependencies..." -ForegroundColor Gray
        poetry install --no-dev
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Poetry installation completed" -ForegroundColor Green
        } else {
            throw "Poetry installation failed"
        }
        
        # Try to install Snapdragon extras if needed
        try {
            Write-Host "   Installing Snapdragon extras..." -ForegroundColor Gray
            poetry install --extras snapdragon --quiet 2>$null
        } catch {
            Write-Host "[INFO] Snapdragon extras not available (normal for Intel systems)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "[ERROR] Poetry installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[FALLBACK] Switching to pip installation..." -ForegroundColor Yellow
        $Method = "pip"
    } finally {
        Set-Location $originalPath
    }
}

if ($Method -eq "pip") {
    Write-Host "Installing with pip..." -ForegroundColor Cyan
    
    # Upgrade pip first
    Write-Host "   Upgrading pip..." -ForegroundColor Gray
    python -m pip install --upgrade pip --quiet
    
    # Install pip-tools for better dependency resolution
    Write-Host "   Installing pip-tools..." -ForegroundColor Gray
    pip install pip-tools --quiet
    
    # Create comprehensive requirements file
    $requirementsContent = @"
# Core ML Framework - PyTorch CPU version for compatibility
torch==2.1.2 --index-url https://download.pytorch.org/whl/cpu
torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu

# HuggingFace Ecosystem - Fixed compatible versions
huggingface_hub==0.24.6
transformers==4.36.2
diffusers==0.25.1
accelerate==0.25.0
safetensors==0.4.1

# ONNX Runtime and Optimum for AI acceleration
onnxruntime>=1.16.0
optimum[onnxruntime]==1.16.2

# Web Framework for demo server
flask>=2.0.0,<3.0.0
flask-socketio>=5.0.0,<6.0.0
flask-cors>=3.0.0,<5.0.0
eventlet>=0.33.0,<0.36.0

# Additional useful packages
pillow>=8.0.0
numpy>=1.21.0
requests>=2.25.0
psutil>=5.8.0
"@
    
    $requirementsPath = "$env:TEMP\ai_demo_requirements.txt"
    $requirementsContent | Out-File -FilePath $requirementsPath -Encoding UTF8
    
    try {
        Write-Host "   Resolving dependencies with pip-tools..." -ForegroundColor Gray
        
        # Use pip-sync for clean installation
        pip-sync $requirementsPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Pip installation completed" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] pip-sync had issues, trying direct installation..." -ForegroundColor Yellow
            
            # Fallback to direct pip install
            pip install -r $requirementsPath --upgrade
            
            if ($LASTEXITCODE -ne 0) {
                throw "Direct pip installation also failed"
            }
        }
        
        # Try to install optional Snapdragon packages
        Write-Host "   Attempting Snapdragon NPU packages..." -ForegroundColor Gray
        pip install onnxruntime-qnn qai-hub --quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Snapdragon NPU packages installed" -ForegroundColor Green
        } else {
            Write-Host "[INFO] Snapdragon NPU packages not available (normal for Intel systems)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "[ERROR] All installation methods failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    } finally {
        Remove-Item $requirementsPath -ErrorAction SilentlyContinue
    }
}

# Verify installation
Write-Host "`n[INFO] Verifying installation..." -ForegroundColor Yellow

$verificationPassed = $true
$newlyInstalled = @()

foreach ($package in $requiredPackages) {
    if (Test-PythonPackage $package) {
        $version = Get-PythonPackageVersion $package
        Write-Host "   ✓ $package - $version" -ForegroundColor Green
        if ($package -in $missingPackages) {
            $newlyInstalled += "$package ($version)"
        }
    } else {
        Write-Host "   ✗ $package - Still missing!" -ForegroundColor Red
        $verificationPassed = $false
    }
}

# Show results
Write-Host "`n============================================" -ForegroundColor Cyan

if ($verificationPassed) {
    Write-Host "Installation Successful!" -ForegroundColor Green
    
    if ($newlyInstalled.Count -gt 0) {
        Write-Host "`nNewly installed packages:" -ForegroundColor Yellow
        $newlyInstalled | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
    }
    
    Write-Host "`nAll required packages are now available!" -ForegroundColor Green
    Write-Host "You can now run: .\prepare_models.ps1" -ForegroundColor Cyan
} else {
    Write-Host "Installation Issues Detected!" -ForegroundColor Red
    Write-Host "`nSome packages are still missing. Try:" -ForegroundColor Yellow
    Write-Host "1. Run this script with -Force: .\install_dependencies.ps1 -Force" -ForegroundColor White
    Write-Host "2. Check Python installation: .\fix_python_path.ps1" -ForegroundColor White
    Write-Host "3. Manual install: pip install diffusers transformers torch" -ForegroundColor White
}

Write-Host "============================================" -ForegroundColor Cyan
