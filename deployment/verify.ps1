# Setup Verification Script
# Verifies the demo environment is properly configured

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AI Demo Setup Verification" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$errors = @()
$warnings = @()

# Check if demo directory exists
Write-Host "`nChecking demo directory..." -ForegroundColor Yellow
if (Test-Path "C:\AIDemo") {
    Write-Host "✅ Demo directory exists" -ForegroundColor Green
    
    # Check subdirectories
    $requiredDirs = @("client", "models", "cache", "logs", "venv")
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path "C:\AIDemo\$dir")) {
            $warnings += "Missing directory: C:\AIDemo\$dir"
        }
    }
} else {
    $errors += "Demo directory C:\AIDemo not found"
}

# Check Python
Write-Host "`nChecking Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python installed: $pythonVersion" -ForegroundColor Green
    
    # Check version compatibility
    $versionNum = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    if ($versionNum -eq "3.9") {
        Write-Host "✅ Python 3.9 - optimal for AI libraries" -ForegroundColor Green
    } elseif ($versionNum -in @("3.8", "3.10")) {
        Write-Host "⚠️ Python $versionNum - compatible but 3.9 recommended" -ForegroundColor Yellow
        $warnings += "Python 3.9 recommended for best compatibility"
    } else {
        $errors += "Python $versionNum not compatible with DirectML"
    }
} catch {
    $errors += "Python not installed or not in PATH"
}

# Check platform
Write-Host "`nChecking platform..." -ForegroundColor Yellow
$arch = $env:PROCESSOR_ARCHITECTURE
$processor = (Get-WmiObject -Class Win32_Processor).Name

Write-Host "Architecture: $arch" -ForegroundColor White
Write-Host "Processor: $processor" -ForegroundColor White

if ($processor -like "*Snapdragon*" -or $processor -like "*Qualcomm*" -or $arch -eq "ARM64") {
    Write-Host "✅ Snapdragon platform detected" -ForegroundColor Green
    $platform = "Snapdragon"
    
    # Check NPU support for Snapdragon
    Write-Host "`nChecking Snapdragon NPU support..." -ForegroundColor Yellow
    $testNPU = python -c "import onnxruntime as ort; providers = ort.get_available_providers(); print('NPU OK' if 'QNNExecutionProvider' in providers or 'CPUExecutionProvider' in providers else 'NO NPU')" 2>&1
    if ($testNPU -match "NPU OK") {
        Write-Host "✅ NPU support available" -ForegroundColor Green
    } else {
        $warnings += "NPU acceleration not available - will use CPU fallback"
        Write-Host "⚠️ NPU not available, will use CPU fallback" -ForegroundColor Yellow
    }
} elseif ($processor -like "*Intel*") {
    Write-Host "✅ Intel platform detected" -ForegroundColor Green
    $platform = "Intel"
    
    # Check DirectML for Intel
    Write-Host "`nChecking DirectML (required for Intel)..." -ForegroundColor Yellow
    $testDirectML = python -c "import directml; print('DirectML OK')" 2>&1
    if ($testDirectML -match "DirectML OK") {
        Write-Host "✅ DirectML installed" -ForegroundColor Green
    } else {
        $errors += "DirectML not installed - REQUIRED for Intel acceleration"
        Write-Host "❌ DirectML not found" -ForegroundColor Red
        Write-Host "Run .\diagnose.ps1 to fix this issue" -ForegroundColor Yellow
    }
} else {
    $warnings += "Unknown platform: $processor"
}

# Check key Python packages
Write-Host "`nChecking Python packages..." -ForegroundColor Yellow
$packages = @("torch", "diffusers", "flask", "psutil", "PIL", "numpy")

foreach ($package in $packages) {
    $check = python -c "import $package; print('OK')" 2>&1
    if ($check -match "OK") {
        Write-Host "✅ $package installed" -ForegroundColor Green
    } else {
        $errors += "Python package missing: $package"
        Write-Host "❌ $package not found" -ForegroundColor Red
    }
}

# Check network ports
Write-Host "`nChecking network ports..." -ForegroundColor Yellow
$port5000 = Test-NetConnection -ComputerName localhost -Port 5000 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
$port5001 = Test-NetConnection -ComputerName localhost -Port 5001 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

if (($null -ne $port5000 -and $port5000.TcpTestSucceeded) -or ($null -ne $port5001 -and $port5001.TcpTestSucceeded)) {
    $warnings += "Demo ports may already be in use"
    Write-Host "⚠️ Ports 5000/5001 may be in use" -ForegroundColor Yellow
} else {
    Write-Host "✅ Demo ports available" -ForegroundColor Green
}

# Check client files
Write-Host "`nChecking client files..." -ForegroundColor Yellow
if (Test-Path "C:\AIDemo\client\demo_client.py") {
    Write-Host "✅ Demo client script found" -ForegroundColor Green
} else {
    $errors += "Demo client script not found at C:\AIDemo\client\demo_client.py"
}

if (Test-Path "C:\AIDemo\client\platform_detection.py") {
    Write-Host "✅ Platform detection script found" -ForegroundColor Green
} else {
    $errors += "Platform detection script not found"
}

# Summary
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✅ ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host "Your $platform system is ready for the AI demo" -ForegroundColor Green
    Write-Host "`nTo start the demo client:" -ForegroundColor Yellow
    Write-Host "cd C:\AIDemo" -ForegroundColor White
    Write-Host ".\venv\Scripts\Activate.ps1" -ForegroundColor White
    Write-Host "python client\demo_client.py" -ForegroundColor White
} else {
    if ($errors.Count -gt 0) {
        Write-Host "`n❌ ERRORS FOUND:" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  - $err" -ForegroundColor Red
        }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host "`n⚠️ WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n❌ Setup verification FAILED" -ForegroundColor Red
    Write-Host "Please address the issues above and run setup again" -ForegroundColor Yellow
    
    if ($platform -eq "Intel" -and $errors -match "DirectML") {
        Write-Host "`nFor DirectML issues, run:" -ForegroundColor Yellow
        Write-Host ".\diagnose.ps1" -ForegroundColor Cyan
    }
}
