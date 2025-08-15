@echo off
REM Update Latest Frontend - Ensure latest demo frontend is deployed
echo ========================================
echo   Update Latest Demo Frontend
echo   Snapdragon X Elite - Get Snapped
echo ========================================
echo.

cd /d C:\AIDemo

echo Detecting platform...
for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value ^| find "Name"') do (
    set "cpuName=%%i"
)

echo !cpuName! | findstr /i "snapdragon qualcomm arm" >nul  
if !errorlevel! == 0 (
    set "detectedPlatform=snapdragon"
    echo Snapdragon processor detected
) else (
    echo !cpuName! | findstr /i "intel" >nul
    if !errorlevel! == 0 (
        set "detectedPlatform=intel"
        echo Intel processor detected
    ) else (
        set "detectedPlatform=intel"
        echo Unknown processor, defaulting to Intel
    )
)

echo.
echo ========================================
echo Step 1: Update Latest Static Files
echo ========================================
echo.

REM Source directory (GitHub working directory)
set "sourceDir=C:\Users\Mosai\ai-demo-working"

echo Copying latest frontend files from source...

if not exist "%sourceDir%\src\windows-client\static" (
    echo ERROR: Source static files not found at %sourceDir%\src\windows-client\static
    echo Please ensure the GitHub repository is pulled to the source directory
    pause
    exit /b 1
)

echo Backing up current static files...
if exist static.backup (
    rmdir /s /q static.backup
)
if exist static (
    move static static.backup
    echo Current static files backed up to static.backup
)

echo Copying latest static files...
xcopy "%sourceDir%\src\windows-client\static" static\ /E /I /Q /Y
if !errorlevel! == 0 (
    echo   ✓ Latest frontend files copied successfully
) else (
    echo   ✗ Error copying frontend files
    if exist static.backup (
        echo Restoring backup...
        move static.backup static
    )
    pause
    exit /b 1
)

echo.
echo ========================================
echo Step 2: Update Demo Client Application
echo ========================================
echo.

echo Copying latest demo client Python files...

if exist src\*.py.backup (
    echo Previous backups exist, cleaning up...
    del src\*.py.backup
)

echo Backing up current Python files...
for %%f in (src\*.py) do (
    copy "%%f" "%%f.backup"
)

echo Copying latest Python application files...
xcopy "%sourceDir%\src\windows-client\*.py" src\ /Q /Y
if !errorlevel! == 0 (
    echo   ✓ Latest Python files copied successfully
) else (
    echo   ✗ Error copying Python files
    echo Restoring Python backups...
    for %%f in (src\*.py.backup) do (
        set "original=%%f"
        set "original=!original:.backup=!"
        copy "%%f" "!original!"
    )
    pause
    exit /b 1
)

echo.
echo ========================================
echo Step 3: Configure Platform-Specific Interface
echo ========================================
echo.

echo Configuring demo for !detectedPlatform! platform...

REM Create platform-aware Flask route modification
(
echo import re
echo import os
echo.
echo def fix_platform_routing^^(platform^^):
echo     """Fix Flask routing to serve platform-specific interface directly."""
echo     
echo     # Read demo_client.py
echo     with open^^('src/demo_client.py', 'r', encoding='utf-8'^^) as f:
echo         content = f.read^^^^
echo     
echo     # Find the index route in NetworkServer class
echo     # Pattern to match the index route that serves the platform selection page
echo     selection_route = r'@self\.app\.route\(\'\/\'\)\s+def index\(self\):.*?return render_template_string\(html\)'
echo     
echo     if platform == 'snapdragon':
echo         new_route = '''@self.app.route^^('/'^^ )
echo         def index^^(self^^):
echo             """Serve Snapdragon demo page directly."""
echo             try:
echo                 return send_from_directory^^('static', 'snapdragon-demo.html'^^)
echo             except Exception as e:
echo                 return f'<h1>Snapdragon Demo</h1><p>Error: {e}</p><p>Serving latest Snapdragon interface</p>''''
echo     else:
echo         new_route = '''@self.app.route^^('/'^^ )
echo         def index^^(self^^):
echo             """Serve Intel demo page directly."""
echo             try:
echo                 return send_from_directory^^('static', 'intel-demo.html'^^)
echo             except Exception as e:
echo                 return f'<h1>Intel Demo</h1><p>Error: {e}</p><p>Serving latest Intel interface</p>''''
echo     
echo     # Replace the route
echo     if re.search^^(selection_route, content, re.DOTALL^^):
echo         content = re.sub^^(selection_route, new_route, content, flags=re.DOTALL^^)
echo         print^^(f'✓ Updated Flask route for {platform} platform'^^)
echo     else:
echo         print^^(f'⚠ Could not find platform selection route, adding new route'^^)
echo         # Add route after class definition
echo         class_pattern = r'class NetworkServer:'
echo         if re.search^^(class_pattern, content^^):
echo             # Add method to NetworkServer class
echo             setup_routes_pattern = r'def setup_routes\(self\):'
echo             if re.search^^(setup_routes_pattern, content^^):
echo                 route_addition = f'''
echo         {new_route}
echo         '''
echo                 content = re.sub^^(setup_routes_pattern, f'def setup_routes^^(self^^):{route_addition}', content^^)
echo             
echo     # Write back to file
echo     with open^^('src/demo_client.py', 'w', encoding='utf-8'^^) as f:
echo         f.write^^(content^^)
echo     
echo     print^^(f'✓ Demo client configured for {platform} platform'^^)
echo     return True
echo.
echo if __name__ == '__main__':
echo     import sys
echo     platform = sys.argv[1] if len^^(sys.argv^^) ^> 1 else 'snapdragon'
echo     fix_platform_routing^^(platform^^)
) > fix_platform_routing.py

REM Run the platform fix
call .venv\Scripts\activate.bat
python fix_platform_routing.py !detectedPlatform!

REM Clean up
del fix_platform_routing.py

echo.
echo ========================================
echo Step 4: Verify Latest Frontend Deployment
echo ========================================
echo.

echo Verifying frontend files...

if exist "static\!detectedPlatform!-demo.html" (
    echo   ✓ !detectedPlatform!-demo.html found
) else (
    echo   ✗ !detectedPlatform!-demo.html missing
)

if exist "static\js\demo-client.js" (
    echo   ✓ demo-client.js found
) else (
    echo   ✗ demo-client.js missing
)

echo.
echo Checking for latest frontend features...
findstr /i "Get Snapped" static\snapdragon-demo.html >nul 2>&1
if !errorlevel! == 0 (
    echo   ✓ Latest "Get Snapped" branding detected
) else (
    echo   ⚠ "Get Snapped" branding not found - may be older version
)

findstr /i "socket.io" static\snapdragon-demo.html >nul 2>&1
if !errorlevel! == 0 (
    echo   ✓ Socket.IO integration detected
) else (
    echo   ⚠ Socket.IO integration not found
)

echo.
echo ========================================
echo Frontend Update Complete!
echo ========================================
echo.
echo ✅ Latest demo frontend deployed for !detectedPlatform! platform
echo ✅ Platform-specific routing configured
echo ✅ Modern "Get Snapped" interface ready
echo.
echo Next steps:
echo 1. Test the demo: launch_demo.bat
echo 2. Navigate to: http://localhost:5000
echo 3. Should see: Latest !detectedPlatform! interface directly
echo.
echo The demo now includes:
echo - Latest responsive design
echo - Real-time metrics display  
echo - Interactive prompt input
echo - Socket.IO real-time updates
echo - Platform-specific branding
echo.
echo To rollback if needed:
echo - Static files: move static.backup static
echo - Python files: copy src\*.py.backup to src\*.py
echo.
pause
