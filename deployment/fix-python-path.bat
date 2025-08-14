@echo off
echo ============================================
echo Python Path Fix for AI Demo
echo ============================================
echo.
echo This will fix Python path issues after uninstalling Python 3.11
echo.
pause

powershell -ExecutionPolicy Bypass -File ".\fix_python_path.ps1"

echo.
echo ============================================
echo Fix attempt completed!
echo ============================================
echo.
echo Next steps:
echo 1. Close and reopen PowerShell/Command Prompt
echo 2. Run: python --version
echo 3. Run: .\prepare_models.ps1
echo.
pause