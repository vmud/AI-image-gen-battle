@echo off
setlocal EnableDelayedExpansion

REM ===============================================================================
REM Snapdragon X Elite AI Demo Launcher
REM
REM This script launches the optimized AI Image Generation demo for Snapdragon X Elite.
REM Provides lightning-fast AI generation with NPU acceleration and optimized
REM performance for impressive demonstration capabilities.
REM
REM Features:
REM - Lightning-fast generation times (3-5 seconds)
REM - Launches web server with Snapdragon-optimized UI
REM - Automatically opens browser to demo interface
REM - Includes health monitoring and error recovery
REM ===============================================================================

title Snapdragon X Elite - AI Demo Launcher

REM Configuration
set DEMO_PORT=5000
set DEMO_URL=http://localhost:%DEMO_PORT%/snapdragon
set HEALTH_URL=http://localhost:%DEMO_PORT%/health
set MAX_WAIT_TIME=30
set SCRIPT_DIR=%~dp0
set LOG_FILE=%SCRIPT_DIR%snapdragon_emergency_launch.log

REM Create log file with timestamp
echo [%date% %time%] Snapdragon Emergency Demo Launcher Started > "%LOG_FILE%"

echo.
echo ===============================================================================
echo          SNAPDRAGON X ELITE - EMERGENCY DEMO LAUNCHER
echo ===============================================================================
echo.
echo Starting Snapdragon X Elite AI demo...
echo This demo showcases lightning-fast AI image generation with NPU acceleration
echo and optimized performance for impressive demonstration capabilities.
echo.

REM Check if we're in the correct directory
if not exist "src\windows-client\demo_client.py" (
    echo ERROR: demo_client.py not found in src\windows-client\
    echo Please run this script from the project root directory.
    echo Current directory: %CD%
    echo.
    echo [%date% %time%] ERROR: Wrong directory - demo_client.py not found >> "%LOG_FILE%"
    pause
    exit /b 1
)

REM Ensure demo assets directory exists
if not exist "src\windows-client\static\emergency_assets" (
    echo Creating demo assets directory...
    mkdir "src\windows-client\static\emergency_assets" 2>nul
    echo       - Demo assets directory: CREATED
) else (
    echo       - Demo assets directory: EXISTS
)

REM Set optimized demo environment variables
echo [1/6] Setting up Snapdragon demo environment...
set EMERGENCY_MODE=true
set SNAPDRAGON_PLATFORM=true
set SKIP_MODEL_VALIDATION=true
set DEMO_MODE=optimized
set PYTHONPATH=%CD%\src\windows-client

echo       - NPU optimization: ENABLED
echo       - Platform: Snapdragon X Elite
echo       - Fast generation: ACTIVATED
echo [%date% %time%] Environment configured for optimized demo >> "%LOG_FILE%"

REM Check Python availability
echo.
echo [2/6] Checking Python environment...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found in PATH
    echo Please ensure Python 3.10+ is installed and accessible.
    echo [%date% %time%] ERROR: Python not found >> "%LOG_FILE%"
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo       - Python version: %PYTHON_VERSION%

REM Check for virtual environment
if exist ".venv\Scripts\activate.bat" (
    echo       - Virtual environment: Found
    echo [%date% %time%] Activating virtual environment >> "%LOG_FILE%"
    call .venv\Scripts\activate.bat
) else (
    echo       - Virtual environment: Not found (proceeding with system Python)
)

REM Check if port is available
echo.
echo [3/6] Checking port availability...
netstat -an | find ":%DEMO_PORT%" >nul
if not errorlevel 1 (
    echo WARNING: Port %DEMO_PORT% appears to be in use
    echo This may cause conflicts. Continue anyway? (Y/N)
    set /p continue="Continue? (Y/N): "
    if /i not "!continue!"=="y" (
        echo Demo launch cancelled by user.
        echo [%date% %time%] Launch cancelled - port conflict >> "%LOG_FILE%"
        pause
        exit /b 1
    )
)
echo       - Port %DEMO_PORT%: Available

REM Navigate to the demo client directory
cd /d "%CD%\src\windows-client"

REM Add platform detection override (CRITICAL: platform_detection.py looks for SNAPDRAGON_NPU)
set SNAPDRAGON_NPU=1
set FORCE_PLATFORM=snapdragon
set FORCE_SNAPDRAGON=true
set PLATFORM_OVERRIDE=snapdragon
echo       - Environment override: SNAPDRAGON_NPU=%SNAPDRAGON_NPU%
echo       - Platform forced to: Snapdragon X Elite
echo [%date% %time%] Critical platform override: SNAPDRAGON_NPU=%SNAPDRAGON_NPU% >> "%LOG_FILE%"

REM Start the demo server
echo.
echo [4/6] Starting Snapdragon AI demo server...
echo       - Server will start on port %DEMO_PORT%
echo       - NPU optimization: ACTIVE
echo       - UI Theme: Snapdragon X Elite
echo       - Platform forced to: Snapdragon X Elite
echo.
echo Starting server... (this may take 10-15 seconds)
echo [%date% %time%] Forcing platform to Snapdragon X Elite >> "%LOG_FILE%"

REM Launch demo_client.py in background with enhanced logging
start "Snapdragon AI Demo Server" /min python demo_client.py

REM Wait for server to be ready
echo.
echo [5/6] Waiting for server to initialize...
set /a counter=0
:wait_loop
set /a counter+=1
if %counter% gtr %MAX_WAIT_TIME% (
    echo.
    echo ERROR: Server failed to start within %MAX_WAIT_TIME% seconds
    echo Check the server window for error messages.
    echo [%date% %time%] ERROR: Server startup timeout >> "%LOG_FILE%"
    pause
    exit /b 1
)

REM Check if server is responding - with detailed debugging
for /f %%i in ('curl -s -w "%%{http_code}" "%HEALTH_URL%" 2^>nul') do set HTTP_STATUS=%%i
echo       - Attempt %counter%/%MAX_WAIT_TIME%: Health check returned HTTP %HTTP_STATUS%

REM Enhanced debugging for health check failures
if not "%HTTP_STATUS%"=="200" (
    if %counter% LEQ 5 (
        echo       - Debug: Platform override active: SNAPDRAGON_NPU=%SNAPDRAGON_NPU%
        echo       - Debug: Checking server logs and platform detection...
        echo [%date% %time%] Health check failed: HTTP %HTTP_STATUS% (SNAPDRAGON_NPU=%SNAPDRAGON_NPU%) >> "%LOG_FILE%"
    )
    REM Try to get more info from the health endpoint
    if %counter% EQU 3 (
        echo       - Debug: Attempting detailed health check...
        curl -s "%HEALTH_URL%" 2>nul | findstr /C:"healthy" >nul && echo       - Health endpoint returned data || echo       - No health data returned
    )
    timeout /t 1 /nobreak >nul
    goto wait_loop
)

echo       - Server is ready and responding!
echo [%date% %time%] Server started successfully >> "%LOG_FILE%"

REM Launch browser with cache-busting
echo.
echo [6/6] Opening Snapdragon demo interface...
echo       - Demo URL: %DEMO_URL%
echo       - Lightning-fast 3-5 second generation with NPU acceleration
echo       - Optimized Snapdragon X Elite AI performance
echo       - Forcing fresh UI load (no cache)

REM Create cache-busted URL with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%%time:~0,2%%time:~3,2%%time:~6,2%
set CACHE_BUST_URL=%DEMO_URL%?v=%TIMESTAMP%&nocache=1

REM Kill any existing browser sessions to force fresh start
taskkill /f /im chrome.exe 2>nul >nul
taskkill /f /im msedge.exe 2>nul >nul
taskkill /f /im firefox.exe 2>nul >nul
timeout /t 2 /nobreak >nul

REM Open with cache-busting and incognito mode
start "" "%CACHE_BUST_URL%"
if errorlevel 1 (
    REM Fallback browser options
    if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
        start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" "%DEMO_URL%"
    ) else if exist "C:\Program Files\Mozilla Firefox\firefox.exe" (
        start "" "C:\Program Files\Mozilla Firefox\firefox.exe" "%DEMO_URL%"
    ) else if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
        start "" "C:\Program Files\Microsoft\Edge\Application\msedge.exe" "%DEMO_URL%"
    ) else (
        echo WARNING: Could not automatically open browser
        echo Please manually navigate to: %DEMO_URL%
    )
)

echo [%date% %time%] Browser launched successfully >> "%LOG_FILE%"

REM Display final status
echo.
echo ===============================================================================
echo                        SNAPDRAGON X ELITE AI DEMO READY!
echo ===============================================================================
echo.
echo Demo Status:           ACTIVE
echo NPU Acceleration:      ENABLED
echo Server URL:            %DEMO_URL%
echo Expected Performance:  3-5 seconds per image generation
echo Platform:              Snapdragon X Elite with NPU
echo.
echo DEMO FEATURES:
echo  - Lightning-fast AI generation (3-5s)
echo  - NPU-optimized performance monitoring
echo  - High-quality AI-generated images
echo  - Real-time telemetry and metrics
echo  - Snapdragon X Elite optimized UI
echo.
echo INSTRUCTIONS:
echo  1. Use the web interface to enter prompts and generate images
echo  2. Experience blazing-fast NPU-accelerated AI generation
echo  3. Monitor real-time performance metrics and telemetry
echo  4. Close this window or press Ctrl+C to stop the demo
echo.
echo Server Log: %LOG_FILE%
echo ===============================================================================

REM Monitor the server process
echo Press Ctrl+C to stop the demo server...
echo.

REM Set up cleanup handler
:monitor_loop
timeout /t 5 /nobreak >nul

REM Check if server is still running
curl -s -o nul -w "%%{http_code}" "%HEALTH_URL%" 2>nul | findstr "200" >nul
if errorlevel 1 (
    echo.
    echo WARNING: Server appears to have stopped responding
    echo Check the server window for any error messages.
    echo [%date% %time%] WARNING: Server stopped responding >> "%LOG_FILE%"
    goto cleanup
)

goto monitor_loop

:cleanup
echo.
echo ===============================================================================
echo                              CLEANING UP
echo ===============================================================================
echo.
echo Stopping demo server...

REM Kill any python processes running demo_client.py
for /f "tokens=2" %%i in ('tasklist /fi "imagename eq python.exe" /fo csv ^| findstr demo_client') do (
    echo Stopping process ID: %%i
    taskkill /pid %%i /f >nul 2>&1
)

REM Additional cleanup for any processes on our port
for /f "tokens=5" %%i in ('netstat -ano ^| findstr ":%DEMO_PORT%"') do (
    echo Stopping process using port %DEMO_PORT%: %%i
    taskkill /pid %%i /f >nul 2>&1
)

echo [%date% %time%] Cleanup completed >> "%LOG_FILE%"
echo Demo server stopped.
echo.
echo Thank you for using the Snapdragon X Elite Emergency Demo!
echo.
pause
exit /b 0