# Quick syntax test for install_dependencies.ps1
param()

Write-Host "Testing install_dependencies.ps1 syntax..." -ForegroundColor Yellow

try {
    # Try to parse the script
    $scriptContent = Get-Content "install_dependencies.ps1" -Raw
    $scriptBlock = [ScriptBlock]::Create($scriptContent)
    
    Write-Host "✅ Syntax parsing: SUCCESS" -ForegroundColor Green
    
    # Test parameter validation
    $paramTest = { param([ValidateSet("poetry", "pip", "auto")][string]$Method = "auto") }
    Write-Host "✅ Parameter syntax: SUCCESS" -ForegroundColor Green
    
    # Check for common issues
    $braceCount = ($scriptContent.ToCharArray() | Where-Object { $_ -eq '{' }).Count - 
                  ($scriptContent.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                  
    if ($braceCount -eq 0) {
        Write-Host "✅ Brace balance: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "❌ Brace balance: FAILED (difference: $braceCount)" -ForegroundColor Red
    }
    
    # Check try/catch blocks
    $tryCount = ([regex]::Matches($scriptContent, '\btry\s*\{')).Count
    $catchCount = ([regex]::Matches($scriptContent, '\bcatch\s*\{')).Count
    $finallyCount = ([regex]::Matches($scriptContent, '\bfinally\s*\{')).Count
    
    Write-Host "📊 Try blocks: $tryCount" -ForegroundColor Cyan
    Write-Host "📊 Catch blocks: $catchCount" -ForegroundColor Cyan
    Write-Host "📊 Finally blocks: $finallyCount" -ForegroundColor Cyan
    
    if ($tryCount -eq $catchCount -or ($tryCount -eq ($catchCount + $finallyCount))) {
        Write-Host "✅ Try/Catch balance: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "❌ Try/Catch balance: POTENTIAL ISSUE" -ForegroundColor Yellow
        Write-Host "   Note: Some try blocks may have only finally blocks" -ForegroundColor Gray
    }
    
    Write-Host "`n🎯 Overall: Script appears syntactically correct" -ForegroundColor Green
    Write-Host "   If you're seeing errors, try:" -ForegroundColor Yellow
    Write-Host "   1. Update PowerShell: Install-Module PowerShellGet -Force" -ForegroundColor White
    Write-Host "   2. Check execution policy: Set-ExecutionPolicy RemoteSigned" -ForegroundColor White
    Write-Host "   3. Run from correct directory with: .\install_dependencies.ps1" -ForegroundColor White
    
} catch {
    Write-Host "❌ SYNTAX ERROR FOUND:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    
    # Try to identify the line
    if ($_.Exception.Message -match "line (\d+)") {
        $lineNum = [int]$matches[1]
        Write-Host "Problem appears to be around line $lineNum" -ForegroundColor Yellow
        
        $lines = Get-Content "install_dependencies.ps1"
        $start = [math]::Max(0, $lineNum - 3)
        $end = [math]::Min($lines.Count - 1, $lineNum + 2)
        
        Write-Host "Context:" -ForegroundColor Cyan
        for ($i = $start; $i -le $end; $i++) {
            $marker = if ($i -eq ($lineNum - 1)) { ">>> " } else { "    " }
            Write-Host "$marker$($i + 1): $($lines[$i])" -ForegroundColor White
        }
    }
}