# Poetry Setup and Lock File Generation
# This script ensures Poetry is properly configured for the AI Demo project

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Poetry Setup for AI Demo Dependencies" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check if Poetry is installed
try {
    $poetryVersion = poetry --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Poetry found: $poetryVersion" -ForegroundColor Green
    } else {
        throw "Poetry not found"
    }
}
catch {
    Write-Host "[INFO] Installing Poetry..." -ForegroundColor Yellow
    
    try {
        # Install Poetry using the official installer
        $installerScript = Invoke-WebRequest -Uri "https://install.python-poetry.org" -UseBasicParsing
        $installerScript.Content | python -
        
        # Add Poetry to PATH
        $env:PATH = "$env:APPDATA\Python\Scripts;$env:PATH"
        
        Write-Host "[SUCCESS] Poetry installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to install Poetry: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Navigate to the deployment directory
$deploymentDir = $PSScriptRoot
Set-Location $deploymentDir

# Configure Poetry for this project
Write-Host "[INFO] Configuring Poetry settings..." -ForegroundColor Yellow

# Create virtual environment in project directory for easier management
poetry config virtualenvs.in-project true --local
poetry config virtualenvs.prefer-active-python true --local

# Configure package sources
Write-Host "[INFO] Configuring PyTorch CPU source..." -ForegroundColor Yellow
poetry source add --priority=supplemental pytorch-cpu https://download.pytorch.org/whl/cpu

# Install dependencies
if ($Force -or -not (Test-Path "poetry.lock")) {
    Write-Host "[INFO] Installing dependencies and generating lock file..." -ForegroundColor Yellow
    
    try {
        # Install base dependencies
        poetry install --no-dev
        
        Write-Host "[SUCCESS] Dependencies installed successfully" -ForegroundColor Green
        Write-Host "[INFO] Lock file generated at: $(Join-Path $deploymentDir 'poetry.lock')" -ForegroundColor Cyan
    }
    catch {
        Write-Host "[ERROR] Failed to install dependencies: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[INFO] Using existing poetry.lock file" -ForegroundColor Cyan
    
    try {
        # Sync dependencies from lock file
        poetry install --no-dev --sync
        Write-Host "[SUCCESS] Dependencies synchronized" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to sync dependencies: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify critical packages
Write-Host "[INFO] Verifying critical packages..." -ForegroundColor Yellow

$verifyScript = @'
import sys
try:
    import torch
    print(f"PyTorch: {torch.__version__}")
    
    import transformers
    print(f"Transformers: {transformers.__version__}")
    
    import diffusers
    print(f"Diffusers: {diffusers.__version__}")
    
    import optimum
    print(f"Optimum: {optimum.__version__}")
    
    import onnxruntime
    print(f"ONNX Runtime: {onnxruntime.__version__}")
    
    providers = onnxruntime.get_available_providers()
    print(f"Available providers: {', '.join(providers)}")
    
    print("✓ All critical packages verified")
    
except Exception as e:
    print(f"✗ Verification failed: {e}")
    sys.exit(1)
'@

$tempVerifyPath = "$env:TEMP\verify_poetry_install.py"
$verifyScript | Out-File -FilePath $tempVerifyPath -Encoding UTF8

try {
    poetry run python $tempVerifyPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Package verification completed" -ForegroundColor Green
    } else {
        throw "Verification failed"
    }
}
catch {
    Write-Host "[ERROR] Package verification failed" -ForegroundColor Red
    exit 1
}
finally {
    Remove-Item $tempVerifyPath -ErrorAction SilentlyContinue
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Poetry setup completed successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run 'poetry shell' to activate the virtual environment" -ForegroundColor White
Write-Host "2. Run './prepare_models.ps1' to download and optimize models" -ForegroundColor White
Write-Host "3. Poetry will automatically use the configured environment" -ForegroundColor White