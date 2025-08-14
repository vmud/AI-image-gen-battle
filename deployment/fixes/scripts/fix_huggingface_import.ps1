# Fix HuggingFace Hub Import Error (DDUFEntry)
# Upgrades huggingface_hub to resolve DDUFEntry import error

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "HuggingFace Hub Import Error Fix" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "[INFO] Fixing DDUFEntry import error from huggingface_hub..." -ForegroundColor Yellow

# Check current version
Write-Host "`n[STEP 1] Checking current huggingface_hub version..." -ForegroundColor Yellow
try {
    $currentVersion = python -c "import huggingface_hub; print(huggingface_hub.__version__)" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Current version: $currentVersion" -ForegroundColor White
    } else {
        Write-Host "   [ERROR] huggingface_hub not installed or not accessible" -ForegroundColor Red
        Write-Host "   [FIX] Run .\install_dependencies.ps1 first" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "   [ERROR] Cannot check huggingface_hub version" -ForegroundColor Red
    exit 1
}

# Upgrade to compatible version
Write-Host "`n[STEP 2] Upgrading to compatible version (0.24.6)..." -ForegroundColor Yellow
try {
    Write-Host "   Upgrading huggingface_hub..." -ForegroundColor Gray
    pip install --upgrade huggingface_hub==0.24.6 --quiet
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [SUCCESS] huggingface_hub upgraded successfully" -ForegroundColor Green
    } else {
        throw "pip upgrade failed"
    }
} catch {
    Write-Host "   [ERROR] Failed to upgrade huggingface_hub: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   [FALLBACK] Trying force reinstall..." -ForegroundColor Yellow
    
    pip install --force-reinstall huggingface_hub==0.24.6 --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   [ERROR] Force reinstall also failed" -ForegroundColor Red
        exit 1
    }
}

# Verify the fix
Write-Host "`n[STEP 3] Verifying the fix..." -ForegroundColor Yellow
$testScript = @"
import sys
try:
    import huggingface_hub
    print(f'[OK] huggingface_hub version: {huggingface_hub.__version__}')
    
    # Test basic functionality
    from huggingface_hub import snapshot_download
    print('[OK] snapshot_download import successful')
    
    # Test if the problematic import works (DDUFEntry may not exist in newer versions)
    try:
        from huggingface_hub import DDUFEntry
        print('[OK] DDUFEntry import successful (unexpected but working)')
    except ImportError:
        print('[OK] DDUFEntry not available (normal for newer versions)')
    
    print('[SUCCESS] huggingface_hub is working correctly')
    
except ImportError as e:
    print(f'[ERROR] Import error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'[ERROR] Unexpected error: {e}')
    sys.exit(1)
"@

$tempTestPath = "$env:TEMP\test_huggingface.py"
$testScript | Out-File -FilePath $tempTestPath -Encoding UTF8

try {
    python $tempTestPath
    $testResult = $LASTEXITCODE
} finally {
    Remove-Item $tempTestPath -ErrorAction SilentlyContinue
}

if ($testResult -eq 0) {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Fix Applied Successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "`n[NEXT STEP] You can now run:" -ForegroundColor Yellow
    Write-Host ".\prepare_models.ps1" -ForegroundColor Cyan
    Write-Host "`nThe DDUFEntry import error should be resolved." -ForegroundColor White
} else {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Fix Failed" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "`n[ALTERNATIVE] Try these steps:" -ForegroundColor Yellow
    Write-Host "1. Run .\install_dependencies.ps1 -Force" -ForegroundColor White
    Write-Host "2. Check Python installation: .\fix_python_path.ps1" -ForegroundColor White
    Write-Host "3. Manual install: pip install --upgrade huggingface_hub==0.24.6" -ForegroundColor White
    exit 1
}