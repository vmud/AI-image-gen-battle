# Fix Poetry Python Path After Python Version Change
# This script handles Poetry environment issues when Python versions are changed

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,
    [Parameter(Mandatory=$false)]
    [string]$PythonPath = ""
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Poetry Python Path Repair Tool" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Function to find valid Python installations
function Find-ValidPython {
    $pythonCandidates = @()
    
    # Common Python installation paths
    $searchPaths = @(
        "C:\Python3*\python.exe",
        "C:\Users\*\AppData\Local\Programs\Python\Python3*\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe",
        "C:\Program Files\Python3*\python.exe",
        "C:\Program Files (x86)\Python3*\python.exe"
    )
    
    Write-Host "[INFO] Searching for Python installations..." -ForegroundColor Yellow
    
    foreach ($path in $searchPaths) {
        $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($pythonExe in $found) {
            if (Test-Path $pythonExe.FullName) {
                try {
                    $version = & $pythonExe.FullName --version 2>$null
                    if ($version -match "Python (\d+\.\d+)") {
                        $versionNum = [version]$matches[1]
                        if ($versionNum -ge [version]"3.9" -and $versionNum -lt [version]"3.11") {
                            $pythonCandidates += @{
                                Path = $pythonExe.FullName
                                Version = $version.Trim()
                                VersionNum = $versionNum
                            }
                            Write-Host "   Found: $($pythonExe.FullName) - $version" -ForegroundColor Green
                        } elseif ($versionNum -ge [version]"3.11") {
                            Write-Host "   Found: $($pythonExe.FullName) - $version [INCOMPATIBLE - too new]" -ForegroundColor Yellow
                        } else {
                            Write-Host "   Found: $($pythonExe.FullName) - $version [INCOMPATIBLE - too old]" -ForegroundColor Yellow
                        }
                    }
                } catch {
                    Write-Host "   Found: $($pythonExe.FullName) [INVALID - cannot execute]" -ForegroundColor Red
                }
            }
        }
    }
    
    # Also check system PATH
    try {
        $systemPython = Get-Command python -ErrorAction Stop
        $version = & python --version 2>$null
        if ($version -match "Python (\d+\.\d+)") {
            $versionNum = [version]$matches[1]
            if ($versionNum -ge [version]"3.9" -and $versionNum -lt [version]"3.11") {
                $pythonCandidates += @{
                    Path = $systemPython.Source
                    Version = $version.Trim()
                    VersionNum = $versionNum
                    IsSystem = $true
                }
                Write-Host "   Found: $($systemPython.Source) - $version [SYSTEM PATH]" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "   No Python found in system PATH" -ForegroundColor Gray
    }
    
    return $pythonCandidates | Sort-Object VersionNum -Descending
}

# Check current Poetry configuration
Write-Host "[INFO] Checking current Poetry configuration..." -ForegroundColor Yellow

try {
    $poetryEnvInfo = poetry env info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Current Poetry environment:" -ForegroundColor Cyan
        Write-Host $poetryEnvInfo -ForegroundColor Gray
        
        # Check if current environment is broken
        try {
            $poetryPython = poetry run python --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Poetry environment is working: $poetryPython" -ForegroundColor Green
                if (-not $Force) {
                    Write-Host "[INFO] Poetry environment appears to be working. Use -Force to recreate anyway." -ForegroundColor Yellow
                    exit 0
                }
            } else {
                throw "Poetry Python execution failed"
            }
        } catch {
            Write-Host "[ERROR] Poetry environment is broken - Python not accessible" -ForegroundColor Red
            $needsRepair = $true
        }
    } else {
        Write-Host "[INFO] No Poetry environment found or Poetry not available" -ForegroundColor Yellow
        $needsRepair = $true
    }
} catch {
    Write-Host "[ERROR] Poetry command failed: $($_.Exception.Message)" -ForegroundColor Red
    $needsRepair = $true
}

# If user provided specific Python path, validate it
if ($PythonPath) {
    Write-Host "[INFO] Using user-specified Python path: $PythonPath" -ForegroundColor Yellow
    if (-not (Test-Path $PythonPath)) {
        Write-Host "[ERROR] Specified Python path does not exist: $PythonPath" -ForegroundColor Red
        exit 1
    }
    
    try {
        $version = & $PythonPath --version 2>$null
        if ($version -match "Python (\d+\.\d+)") {
            $versionNum = [version]$matches[1]
            if ($versionNum -ge [version]"3.9" -and $versionNum -lt [version]"3.11") {
                Write-Host "[SUCCESS] Specified Python is compatible: $version" -ForegroundColor Green
                $selectedPython = $PythonPath
            } else {
                Write-Host "[ERROR] Specified Python version is incompatible: $version" -ForegroundColor Red
                Write-Host "Required: Python 3.9.x or 3.10.x (3.11+ breaks DirectML compatibility)" -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "[ERROR] Could not determine Python version" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[ERROR] Specified Python is not executable" -ForegroundColor Red
        exit 1
    }
} else {
    # Auto-detect Python
    $validPythons = Find-ValidPython
    
    if ($validPythons.Count -eq 0) {
        Write-Host "[ERROR] No compatible Python installation found!" -ForegroundColor Red
        Write-Host "Please install Python 3.9 or 3.10 for DirectML compatibility" -ForegroundColor Yellow
        Write-Host "Download from: https://www.python.org/downloads/" -ForegroundColor Cyan
        exit 1
    }
    
    Write-Host "`n[INFO] Compatible Python installations found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $validPythons.Count; $i++) {
        $python = $validPythons[$i]
        $marker = if ($python.IsSystem) { " [SYSTEM]" } else { "" }
        Write-Host "  $($i + 1). $($python.Version) - $($python.Path)$marker" -ForegroundColor White
    }
    
    # Auto-select best option or prompt user
    if ($validPythons.Count -eq 1) {
        $selectedPython = $validPythons[0].Path
        Write-Host "`n[AUTO-SELECT] Using: $($validPythons[0].Version) - $selectedPython" -ForegroundColor Green
    } else {
        Write-Host "`n[AUTO-SELECT] Using newest compatible version: $($validPythons[0].Version)" -ForegroundColor Green
        $selectedPython = $validPythons[0].Path
    }
}

# Repair Poetry environment
Write-Host "`n[INFO] Repairing Poetry environment..." -ForegroundColor Yellow

try {
    # Remove existing broken environment
    Write-Host "   Removing broken Poetry environment..." -ForegroundColor Gray
    poetry env remove --all 2>$null | Out-Null
    
    # Create new environment with correct Python
    Write-Host "   Creating new Poetry environment with Python: $selectedPython" -ForegroundColor Gray
    poetry env use $selectedPython
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Poetry environment"
    }
    
    # Verify new environment
    Write-Host "   Verifying new environment..." -ForegroundColor Gray
    $newEnvInfo = poetry env info --path
    $newPythonVersion = poetry run python --version
    
    Write-Host "[SUCCESS] Poetry environment created successfully!" -ForegroundColor Green
    Write-Host "   Environment path: $newEnvInfo" -ForegroundColor Cyan
    Write-Host "   Python version: $newPythonVersion" -ForegroundColor Cyan
    
    # Install dependencies in new environment
    Write-Host "`n[INFO] Installing dependencies in new environment..." -ForegroundColor Yellow
    poetry install --no-dev
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Dependencies installed successfully" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Some dependencies may have failed to install" -ForegroundColor Yellow
        Write-Host "Run 'poetry install --no-dev' manually to retry" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "[ERROR] Failed to repair Poetry environment: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host "`n[FALLBACK] Alternative solutions:" -ForegroundColor Yellow
    Write-Host "1. Install Poetry fresh: pip install poetry" -ForegroundColor White
    Write-Host "2. Use pip instead: ./prepare_models.ps1 will fallback automatically" -ForegroundColor White
    Write-Host "3. Manual setup: python -m venv venv && venv\\Scripts\\activate" -ForegroundColor White
    exit 1
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Poetry Python Path Repair Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run 'poetry shell' to activate the environment" -ForegroundColor White
Write-Host "2. Run './prepare_models.ps1' to continue with model setup" -ForegroundColor White
Write-Host "3. Poetry will now use the correct Python version" -ForegroundColor White