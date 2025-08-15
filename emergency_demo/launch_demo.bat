@echo off
REM Standalone Demo Launcher for AI Image Generation Battle
REM This batch file starts the standalone demo server

title AI Image Generation Battle - Standalone Demo

echo ============================================================
echo AI IMAGE GENERATION BATTLE - STANDALONE DEMO
echo ============================================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7 or later and try again
    echo.
    pause
    exit /b 1
)

REM Check if we're in the right directory
if not exist "index.html" (
    echo ERROR: index.html not found!
    echo Please make sure you're running this from the emergency_demo directory
    echo.
    pause
    exit /b 1
)

if not exist "assets" (
    echo WARNING: assets directory not found!
    echo Image generation may not work properly
    echo.
)

REM Check for required files
if not exist "server.py" (
    echo ERROR: server.py not found!
    echo The demo server script is missing
    echo.
    pause
    exit /b 1
)

if not exist "static\js\demo.js" (
    echo ERROR: demo.js not found!
    echo The demo JavaScript is missing
    echo.
    pause
    exit /b 1
)

echo Starting Standalone Demo Server...
echo.
echo Features:
echo - Platform selection (Intel vs Snapdragon)
echo - Realistic performance simulation
echo - 40 pregenerated "futuristic retail store" images
echo - Complete UI state management
echo.
echo The demo will open automatically in your browser
echo Press Ctrl+C in this window to stop the server
echo.

REM Start the Python server
python server.py

REM If we get here, the server has stopped
echo.
echo Demo server stopped.
pause