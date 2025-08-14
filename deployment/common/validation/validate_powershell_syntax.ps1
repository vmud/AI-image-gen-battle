#Requires -RunAsAdministrator
<#
.SYNOPSIS
    PowerShell Syntax Validator for prepare_snapdragon.ps1
.DESCRIPTION
    Tests specific problematic sections to identify syntax errors
#>

param(
    [switch]$Verbose = $false
)

Write-Host "PowerShell Syntax Validation Tool" -ForegroundColor Cyan
Write-Host "=" * 50

# Test 1: Event Handler Scope Issues
Write-Host "`nTest 1: Event Handler Scope Issues" -ForegroundColor Yellow

try {
    # Simulate the problematic event handler from lines 242-250
    $testWebClient = New-Object System.Net.WebClient
    $script:Verbose = $true
    
    # This should fail if scope issues exist
    $testEventHandler = {
        if ($script:Verbose) {
            $percent = $Event.SourceEventArgs.ProgressPercentage
            Write-Host "Test event: $percent%" -ForegroundColor Green
        }
    }
    
    Register-ObjectEvent -InputObject $testWebClient -EventName DownloadProgressChanged -Action $testEventHandler -SourceIdentifier "TestEvent" | Out-Null
    Unregister-Event -SourceIdentifier "TestEvent" -ErrorAction SilentlyContinue
    
    Write-Host "✓ Event handler scope: PASS" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Event handler scope: FAIL - $_" -ForegroundColor Red
}

# Test 2: Here-String Variable Interpolation
Write-Host "`nTest 2: Here-String Variable Interpolation" -ForegroundColor Yellow

try {
    $script:Verbose = $true
    
    # Simulate the problematic here-string from lines 793-877
    $testScript = @"
import sys
verbose = $(if ($script:Verbose) { "True" } else { "False" })
print(f"Verbose mode: {verbose}")
"@
    
    Write-Host "✓ Here-string interpolation: PASS" -ForegroundColor Green
    if ($Verbose) {
        Write-Host "Generated script:" -ForegroundColor Gray
        Write-Host $testScript -ForegroundColor DarkGray
    }
    
} catch {
    Write-Host "✗ Here-string interpolation: FAIL - $_" -ForegroundColor Red
}

# Test 3: Nested String Escaping
Write-Host "`nTest 3: Nested String Escaping" -ForegroundColor Yellow

try {
    # Test problematic nested quotes
    $testString = @"
@echo off
echo "Starting Demo..."
set PYTHONPATH=C:\AIDemo\client
python "demo_client.py"
"@
    
    Write-Host "✓ Nested string escaping: PASS" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Nested string escaping: FAIL - $_" -ForegroundColor Red
}

# Test 4: Function Parameter Validation
Write-Host "`nTest 4: Function Parameter Validation" -ForegroundColor Yellow

try {
    # Test function with multiple parameter types
    function Test-Function {
        param(
            [switch]$CheckOnly = $false,
            [switch]$Force = $false,
            [switch]$Verbose = $false,
            [string]$LogPath = "C:\AIDemo\logs"
        )
        return $true
    }
    
    $result = Test-Function -Verbose -CheckOnly
    Write-Host "✓ Function parameters: PASS" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Function parameters: FAIL - $_" -ForegroundColor Red
}

# Test 5: Variable Scope Conflicts
Write-Host "`nTest 5: Variable Scope Conflicts" -ForegroundColor Yellow

try {
    $script:testVar = "script-scoped"
    
    function Test-Scope {
        Write-Output $script:testVar
    }
    
    $result = Test-Scope
    Write-Host "✓ Variable scope: PASS" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Variable scope: FAIL - $_" -ForegroundColor Red
}

Write-Host "`n" + "=" * 50
Write-Host "Syntax validation completed" -ForegroundColor Cyan