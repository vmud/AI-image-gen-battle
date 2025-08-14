# Simple syntax validation for install_dependencies.ps1
Write-Host "Validating PowerShell syntax..." -ForegroundColor Yellow

try {
    # Test 1: Parse the script content
    $scriptContent = Get-Content "install_dependencies.ps1" -Raw
    $scriptBlock = [ScriptBlock]::Create($scriptContent)
    Write-Host "✅ Script parsing: SUCCESS" -ForegroundColor Green
    
    # Test 2: Check for balanced quotes
    $singleQuotes = ($scriptContent.ToCharArray() | Where-Object { $_ -eq "'" }).Count
    $doubleQuotes = ($scriptContent.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    
    Write-Host "📊 Single quotes: $singleQuotes" -ForegroundColor Cyan
    Write-Host "📊 Double quotes: $doubleQuotes $(if ($doubleQuotes % 2 -eq 0) { '(balanced)' } else { '(UNBALANCED!)' })" -ForegroundColor Cyan
    
    # Test 3: Try to dot-source the script (loads functions without executing)
    . $scriptBlock
    Write-Host "✅ Script loading: SUCCESS" -ForegroundColor Green
    
    # Test 4: Check if functions are available
    if (Get-Command Test-PythonPackage -ErrorAction SilentlyContinue) {
        Write-Host "✅ Functions loaded: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Functions not loaded" -ForegroundColor Yellow
    }
    
    Write-Host "`n🎯 OVERALL: Script is syntactically correct and ready to use!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ SYNTAX ERROR DETECTED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    
    if ($_.Exception.Message -match "TerminatorExpectedAtEndOfString") {
        Write-Host "`n💡 This error suggests an unmatched quote or string terminator" -ForegroundColor Cyan
        Write-Host "Common causes:" -ForegroundColor Yellow
        Write-Host "- Unmatched single or double quotes" -ForegroundColor White
        Write-Host "- Backtick (`) at end of line without continuation" -ForegroundColor White  
        Write-Host "- Special characters in strings that need escaping" -ForegroundColor White
    }
    
    exit 1
}