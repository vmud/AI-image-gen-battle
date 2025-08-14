# PowerShell script to fix naming conflicts in prepare_snapdragon.ps1
# This script will rename conflicting functions to avoid infinite recursion and cmdlet conflicts

$filePath = ".\deployment\prepare_snapdragon.ps1"
$content = Get-Content $filePath -Raw

# Fix 1: Rename Write-Progress to Write-StepProgress (fixes infinite recursion)
$content = $content -replace 'function Write-Progress \{', 'function Write-StepProgress {'
$content = $content -replace '(?<!Write-Host.*)(Write-Progress) "', 'Write-StepProgress "'

# Fix 2: Rename Write-Error to Write-ErrorMsg (avoids cmdlet conflict)  
$content = $content -replace 'function Write-Error \{', 'function Write-ErrorMsg {'
$content = $content -replace '(?<!Write-Host.*\[X\].*)(Write-Error) "', 'Write-ErrorMsg "'
$content = $content -replace '(?<!catch.*)(Write-Error) "', 'Write-ErrorMsg "'

# Fix 3: Rename Write-Warning to Write-WarningMsg (avoids cmdlet conflict)
$content = $content -replace 'function Write-Warning \{', 'function Write-WarningMsg {'
$content = $content -replace '(?<!Write-Host.*\[!\].*)(Write-Warning) "', 'Write-WarningMsg "'

# Save the fixed content
$content | Set-Content $filePath -Encoding UTF8
Write-Host "Fixed naming conflicts in prepare_snapdragon.ps1" -ForegroundColor Green