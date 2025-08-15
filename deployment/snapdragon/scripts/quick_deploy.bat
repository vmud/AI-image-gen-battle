@echo off
REM Quick Deploy - Copy files from GitHub working directory to C:\AIDemo

echo ============================================
echo   Quick Deploy to C:\AIDemo (Snapdragon)
echo ============================================
echo.

REM Run the PowerShell deployment script
powershell -ExecutionPolicy Bypass -File "C:\Users\Mosai\ai-demo-working\deployment\snapdragon\scripts\deploy_to_production.ps1"

echo.
echo Deployment complete!
pause
