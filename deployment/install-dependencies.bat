@echo off
echo ============================================
echo AI Demo Dependency Installation
echo ============================================
echo.
echo This will install all required Python packages for the AI demo
echo including torch, diffusers, transformers, and other ML packages.
echo.
pause

powershell -ExecutionPolicy Bypass -File ".\install_dependencies.ps1"

echo.
echo ============================================
echo Installation completed!
echo ============================================
echo.
echo Next steps:
echo 1. Check the output above for any errors
echo 2. Run: .\prepare_models.ps1
echo.
pause