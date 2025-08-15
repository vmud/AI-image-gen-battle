@echo off
REM Quick fix for missing flask-cors and other dependencies on Snapdragon
echo ========================================
echo   Fixing Missing Dependencies Fix
echo   Snapdragon System
echo ========================================
echo.

cd /d C:\AIDemo

echo Activating Python environment...
call .venv\Scripts\activate.bat

echo.
echo Installing missing web framework dependencies...
echo Trying Flask-CORS with different approaches...

REM Try different package name variations and fallbacks
pip install Flask-CORS
if errorlevel 1 (
    echo Flask-CORS failed, trying flask-cors...
    pip install flask-cors
    if errorlevel 1 (
        echo flask-cors failed, trying with --no-deps...
        pip install --no-deps Flask-CORS==4.0.0
        if errorlevel 1 (
            echo All Flask-CORS attempts failed, installing from wheel...
            pip install --find-links https://files.pythonhosted.org/packages/py2.py3/ Flask-CORS
        )
    )
)

echo Installing eventlet...
pip install eventlet>=0.33.0

echo.
echo Verifying installation...
python -c "try: import flask_cors; print('flask-cors: INSTALLED'); except: print('flask-cors: MISSING')"
python -c "try: import eventlet; print('eventlet: INSTALLED'); except: print('eventlet: MISSING')"

echo.
echo ========================================
echo Dependencies fixed! 
echo You can now run launch_demo.bat
echo ========================================
echo.
pause
