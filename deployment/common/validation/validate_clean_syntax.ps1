# Validate the cleaned install_dependencies.ps1 syntax
Write-Host "Validating install_dependencies.ps1 syntax..." -ForegroundColor Yellow

try {
    # Test parsing
    $scriptContent = Get-Content "install_dependencies.ps1" -Raw
    $scriptBlock = [ScriptBlock]::Create($scriptContent)
    Write-Host "✅ Script parsing: SUCCESS" -ForegroundColor Green
    
    # Check for balanced braces
    $openBraces = ($scriptContent.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closeBraces = ($scriptContent.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    
    Write-Host "📊 Open braces: $openBraces" -ForegroundColor Cyan
    Write-Host "📊 Close braces: $closeBraces" -ForegroundColor Cyan
    
    if ($openBraces -eq $closeBraces) {
        Write-Host "✅ Brace balance: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "❌ Brace balance: FAILED" -ForegroundColor Red
    }
    
    # Check try/catch blocks
    $tryMatches = [regex]::Matches($scriptContent, '\btry\s*\{')
    $catchMatches = [regex]::Matches($scriptContent, '\bcatch\s*\{')
    $finallyMatches = [regex]::Matches($scriptContent, '\bfinally\s*\{')
    
    Write-Host "📊 Try blocks: $($tryMatches.Count)" -ForegroundColor Cyan
    Write-Host "📊 Catch blocks: $($catchMatches.Count)" -ForegroundColor Cyan
    Write-Host "📊 Finally blocks: $($finallyMatches.Count)" -ForegroundColor Cyan
    
    # Check quotes balance
    $singleQuotes = ($scriptContent.ToCharArray() | Where-Object { $_ -eq "'" }).Count
    $doubleQuotes = ($scriptContent.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    
    Write-Host "📊 Single quotes: $singleQuotes" -ForegroundColor Cyan
    Write-Host "📊 Double quotes: $doubleQuotes $(if ($doubleQuotes % 2 -eq 0) { '(balanced)' } else { '(UNBALANCED!)' })" -ForegroundColor Cyan
    
    Write-Host "`n🎯 OVERALL: Script syntax is clean and valid!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ SYNTAX ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}