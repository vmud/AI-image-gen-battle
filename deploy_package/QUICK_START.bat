@echo off
title AI Demo Setup
echo ========================================
echo AI Image Generation Demo - Quick Setup
echo ========================================
echo.
echo This will set up your Windows machine for the AI demo.
echo Make sure you are running as Administrator!
echo.
pause
echo.
echo Running setup script...
powershell -ExecutionPolicy Bypass -File setup_windows.ps1
echo.
echo Setup complete! Check above for any errors.
pause
