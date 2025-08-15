@echo off
REM Universal Quick Deploy - Works for both Intel and Snapdragon
REM Automatically detects platform and deploys accordingly

echo =================================================
echo   Universal AI Demo Deploy (Intel/Snapdragon)
echo =================================================
echo.

REM Run the universal batch deployment script
call "C:\Users\Mosai\ai-demo-working\deployment\common\scripts\deploy_to_production.bat"

echo.
echo Batch deployment complete!
