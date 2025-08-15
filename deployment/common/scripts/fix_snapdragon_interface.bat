@echo off
REM Simple fix for Snapdragon interface - Modify Flask route to auto-serve Snapdragon demo
echo ========================================
echo   Snapdragon Interface Fix
echo   Auto-serve Snapdragon interface
echo ========================================
echo.

cd /d C:\AIDemo

echo Detecting platform...
for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value ^| find "Name"') do (
    set "cpuName=%%i"
)

echo !cpuName! | findstr /i "snapdragon qualcomm arm" >nul  
if !errorlevel! == 0 (
    set "isSnapdragon=true"
    echo Snapdragon processor detected - applying fix
) else (
    echo Intel processor detected - no fix needed
    echo This script is only for Snapdragon systems
    pause
    exit /b 0
)

echo.
echo Backing up original demo_client.py...
if not exist src\demo_client.py.backup (
    copy src\demo_client.py src\demo_client.py.backup
    echo Backup created
) else (
    echo Backup already exists
)

echo.
echo Modifying Flask route to auto-serve Snapdragon interface...

REM Create temporary Python script to do the replacement
(
echo import re
echo.
echo # Read the file
echo with open^('src/demo_client.py', 'r', encoding='utf-8'^) as f:
echo     content = f.read^(^^)
echo.
echo # Find and replace the index route
echo old_route = r"@self\.app\.route\('/'\)\s+def index\(self\):.*?return render_template_string\(html\)"
echo.
echo new_route = '''@self.app.route^('/'^^)
echo         def index^(self^^):
echo             \"\"\"Serve Snapdragon demo page directly.\"\"\"
echo             try:
echo                 return send_from_directory^('static', 'snapdragon-demo.html'^^)
echo             except Exception as e:
echo                 return f'Snapdragon demo page not found: {e}' '''
echo.
echo # Replace the route
echo content = re.sub^(old_route, new_route, content, flags=re.DOTALL^^)
echo.
echo # Write back to file
echo with open^('src/demo_client.py', 'w', encoding='utf-8'^) as f:
echo     f.write^(content^^)
echo.
echo print^('Flask route updated to serve Snapdragon interface directly'^^)
) > fix_route.py

REM Run the Python script to fix the route
call .venv\Scripts\activate.bat
python fix_route.py

REM Clean up
del fix_route.py

echo.
echo ========================================
echo Snapdragon Interface Fix Complete!
echo ========================================
echo.
echo The demo will now automatically serve
echo the Snapdragon interface at the root URL
echo.
echo Test by running: launch_demo.bat
echo Then navigate to: http://localhost:5000
echo.
echo To revert: copy src\demo_client.py.backup src\demo_client.py
echo.
pause
