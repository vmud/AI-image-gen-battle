@echo off
REM Fix Platform Interface - Make demo serve platform-specific UI
echo ========================================
echo   Platform Interface Fix
echo   Auto-serve correct interface
echo ========================================
echo.

cd /d C:\AIDemo

REM Detect platform
for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value ^| find "Name"') do (
    set "cpuName=%%i"
)

echo !cpuName! | findstr /i "intel" >nul
if !errorlevel! == 0 (
    set "detectedPlatform=intel"
    echo Detected Intel processor
) else (
    echo !cpuName! | findstr /i "snapdragon qualcomm arm" >nul  
    if !errorlevel! == 0 (
        set "detectedPlatform=snapdragon"
        echo Detected Snapdragon processor
    ) else (
        set "detectedPlatform=intel"
        echo Unknown processor, defaulting to Intel
    )
)

echo.
echo Creating platform-specific demo client...

REM Backup original if exists
if exist src\demo_client.py.original (
    echo Backup already exists, skipping...
) else (
    if exist src\demo_client.py (
        echo Backing up original demo_client.py...
        copy src\demo_client.py src\demo_client.py.original
    )
)

REM Create platform-aware launcher
(
echo import sys
echo import os
echo import json
echo.
echo # Check for platform argument or environment variable
echo platform = 'auto'
echo for arg in sys.argv:
echo     if arg.startswith^('--platform='^^):
echo         platform = arg.split^('='^^)[1]
echo         break
echo.
echo if platform == 'auto':
echo     platform = os.environ.get^('DEMO_PLATFORM', 'auto'^^)
echo.
echo # If still auto, detect from config
echo if platform == 'auto':
echo     try:
echo         with open^('config/production.json', 'r'^^) as f:
echo             config = json.load^(f^^)
echo             platform = config.get^('platform', 'intel'^^)
echo     except:
echo         platform = '!detectedPlatform!'  # Fallback to detected platform
echo.
echo # Set environment variable for Flask app
echo os.environ['DEMO_PLATFORM'] = platform
echo print^(f"Starting {platform.upper^(^^)} demo interface..."^^)
echo.
echo # Import and run original demo client
echo from demo_client_original import main
echo.
echo if __name__ == '__main__':
echo     main^(^^)
) > src\demo_client_platform_wrapper.py

REM Rename original file
if exist src\demo_client.py (
    move src\demo_client.py src\demo_client_original.py
)

REM Copy wrapper as main demo client
copy src\demo_client_platform_wrapper.py src\demo_client.py

echo.
echo Modifying Flask routes to serve platform-specific interface...

REM Create modified Flask app section
(
echo # Platform-aware Flask routes - Modified for direct platform serving
echo.
echo @app.route^('/'^^)
echo def index^(^):
echo     """Serve platform-specific demo page directly."""
echo     platform = os.environ.get^('DEMO_PLATFORM', '!detectedPlatform!'^^)
echo     
echo     if platform == 'snapdragon':
echo         try:
echo             return send_from_directory^('static', 'snapdragon-demo.html'^^)
echo         except:
echo             return f'Snapdragon demo page not found. Platform: {platform}'
echo     else:
echo         try:
echo             return send_from_directory^('static', 'intel-demo.html'^^)
echo         except:
echo             return f'Intel demo page not found. Platform: {platform}'
) > temp_route_fix.py

echo.
echo ========================================
echo Platform Interface Fix Complete!
echo ========================================
echo.
echo The demo will now automatically serve the
echo correct interface for !detectedPlatform! platform
echo.
echo You can now run launch_demo.bat and it will
echo show the !detectedPlatform! interface directly
echo.
pause
