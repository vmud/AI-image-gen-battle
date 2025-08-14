# Fix Python Path References After Uninstall
# Comprehensive script to remove all references to old Python installations

param(
    [Parameter(Mandatory=$false)]
    [string]$OldPythonPath = "C:\Program Files\Python311"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Python Path Reference Cleaner" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "[INFO] Cleaning references to: $OldPythonPath" -ForegroundColor Yellow

# Function to safely remove from PATH
function Remove-FromPath {
    param($PathToRemove)
    
    Write-Host "[INFO] Checking system and user PATH variables..." -ForegroundColor Yellow
    
    # Clean User PATH
    try {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -and $userPath.Contains($PathToRemove)) {
            $newUserPath = $userPath -split ';' | Where-Object { $_ -notlike "*$PathToRemove*" } | Where-Object { $_.Trim() -ne "" }
            $cleanUserPath = $newUserPath -join ';'
            [Environment]::SetEnvironmentVariable("PATH", $cleanUserPath, "User")
            Write-Host "[SUCCESS] Removed from User PATH: $PathToRemove" -ForegroundColor Green
        }
    } catch {
        Write-Host "[WARNING] Could not modify User PATH: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Clean System PATH (requires admin)
    try {
        $systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($systemPath -and $systemPath.Contains($PathToRemove)) {
            $newSystemPath = $systemPath -split ';' | Where-Object { $_ -notlike "*$PathToRemove*" } | Where-Object { $_.Trim() -ne "" }
            $cleanSystemPath = $newSystemPath -join ';'
            [Environment]::SetEnvironmentVariable("PATH", $cleanSystemPath, "Machine")
            Write-Host "[SUCCESS] Removed from System PATH: $PathToRemove" -ForegroundColor Green
        }
    } catch {
        Write-Host "[WARNING] Could not modify System PATH (may need admin rights): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Update current session PATH
    $env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notlike "*$PathToRemove*" } | Where-Object { $_.Trim() -ne "" }) -join ';'
}

# 1. Clean PATH variables
Write-Host "`n[STEP 1] Cleaning PATH environment variables..." -ForegroundColor Cyan
Remove-FromPath $OldPythonPath
Remove-FromPath "$OldPythonPath\Scripts"

# 2. Clean Poetry configuration
Write-Host "`n[STEP 2] Cleaning Poetry configuration..." -ForegroundColor Cyan
try {
    # Remove all Poetry environments
    Write-Host "   Removing all Poetry virtual environments..." -ForegroundColor Gray
    poetry env remove --all 2>$null | Out-Null
    
    # Clear Poetry cache
    Write-Host "   Clearing Poetry cache..." -ForegroundColor Gray
    poetry cache clear pypi --all --no-interaction 2>$null | Out-Null
    
    Write-Host "[SUCCESS] Poetry configuration cleaned" -ForegroundColor Green
} catch {
    Write-Host "[INFO] Poetry not found or already clean" -ForegroundColor Yellow
}

# 3. Clean Windows Registry Python entries
Write-Host "`n[STEP 3] Cleaning Windows Registry..." -ForegroundColor Cyan
try {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Python\PythonCore\3.11",
        "HKCU:\SOFTWARE\Python\PythonCore\3.11",
        "HKLM:\SOFTWARE\Wow6432Node\Python\PythonCore\3.11"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            try {
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                Write-Host "[SUCCESS] Removed registry entry: $regPath" -ForegroundColor Green
            } catch {
                Write-Host "[WARNING] Could not remove registry entry: $regPath" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "[WARNING] Registry cleaning failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. Clean py launcher configuration
Write-Host "`n[STEP 4] Checking py launcher configuration..." -ForegroundColor Cyan
try {
    $pyConfigPath = "$env:LOCALAPPDATA\py.ini"
    if (Test-Path $pyConfigPath) {
        $content = Get-Content $pyConfigPath
        $filteredContent = $content | Where-Object { $_ -notlike "*3.11*" -and $_ -notlike "*$OldPythonPath*" }
        if ($filteredContent.Count -ne $content.Count) {
            $filteredContent | Out-File $pyConfigPath -Encoding UTF8
            Write-Host "[SUCCESS] Cleaned py launcher configuration" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "[INFO] No py launcher configuration found" -ForegroundColor Gray
}

# 5. Find and configure working Python
Write-Host "`n[STEP 5] Finding compatible Python installation..." -ForegroundColor Cyan

$pythonCandidates = @()

# Search for Python installations
$searchPaths = @(
    "C:\Python3*\python.exe",
    "C:\Users\*\AppData\Local\Programs\Python\Python3*\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe",
    "C:\Program Files\Python3*\python.exe"
)

foreach ($path in $searchPaths) {
    $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*$OldPythonPath*" }
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
                        Write-Host "[FOUND] Compatible: $($pythonExe.FullName) - $version" -ForegroundColor Green
                    }
                }
            } catch {
                # Skip invalid Python installations
            }
        }
    }
}

if ($pythonCandidates.Count -eq 0) {
    Write-Host "[ERROR] No compatible Python installation found!" -ForegroundColor Red
    Write-Host "`nRecommended actions:" -ForegroundColor Yellow
    Write-Host "1. Download Python 3.10.11 from: https://www.python.org/downloads/" -ForegroundColor White
    Write-Host "2. During installation, check 'Add Python to PATH'" -ForegroundColor White
    Write-Host "3. Restart PowerShell and run this script again" -ForegroundColor White
    exit 1
}

# Select best Python and configure system
$bestPython = $pythonCandidates | Sort-Object VersionNum -Descending | Select-Object -First 1
Write-Host "`n[SUCCESS] Using Python: $($bestPython.Version) at $($bestPython.Path)" -ForegroundColor Green

# Add to PATH if not already there
$pythonDir = Split-Path $bestPython.Path -Parent
$pythonScriptsDir = Join-Path $pythonDir "Scripts"

$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$pathsToAdd = @()

if (-not $currentPath.Contains($pythonDir)) {
    $pathsToAdd += $pythonDir
}
if (Test-Path $pythonScriptsDir -and -not $currentPath.Contains($pythonScriptsDir)) {
    $pathsToAdd += $pythonScriptsDir
}

if ($pathsToAdd.Count -gt 0) {
    $newPath = $currentPath + ";" + ($pathsToAdd -join ";")
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    $env:PATH = $env:PATH + ";" + ($pathsToAdd -join ";")
    Write-Host "[SUCCESS] Added to PATH: $($pathsToAdd -join ', ')" -ForegroundColor Green
}

# 6. Configure Poetry with working Python
Write-Host "`n[STEP 6] Configuring Poetry with working Python..." -ForegroundColor Cyan
try {
    # Set Poetry to use the working Python
    poetry env use $bestPython.Path
    
    # Verify Poetry is working
    $poetryPython = poetry run python --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Poetry configured: $poetryPython" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Poetry configuration may need manual setup" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Poetry not found - install with: pip install poetry" -ForegroundColor Yellow
}

# 7. Final verification
Write-Host "`n[STEP 7] Verification..." -ForegroundColor Cyan

Write-Host "Testing python command..." -ForegroundColor Gray
try {
    $currentPython = python --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] python command works: $currentPython" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] python command not working - may need to restart PowerShell" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] python command not available" -ForegroundColor Yellow
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Python Path Cleanup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nRecommended next steps:" -ForegroundColor Yellow
Write-Host "1. Restart PowerShell to refresh environment variables" -ForegroundColor White
Write-Host "2. Verify: python --version" -ForegroundColor White
Write-Host "3. Run: .\poetry_setup.ps1" -ForegroundColor White
Write-Host "4. Run: .\prepare_models.ps1" -ForegroundColor White

if ($pathsToAdd.Count -gt 0) {
    Write-Host "`n[IMPORTANT] Environment variables were modified." -ForegroundColor Red
    Write-Host "Please restart PowerShell for changes to take effect." -ForegroundColor Red
}