@echo off
REM Universal Quick Deploy - Works for both Intel and Snapdragon
REM Automatically detects platform and deploys accordingly

echo =================================================
echo   Universal AI Demo Deploy (Intel/Snapdragon)
echo =================================================
echo.

REM Run the universal PowerShell deployment script
powershell -ExecutionPolicy Bypass -File "C:\Users\Mosai\ai-demo-working\deployment\common\scripts\deploy_to_production.ps1"

echo.
echo Deployment complete!
echo Platform configuration has been automatically detected.
pause
