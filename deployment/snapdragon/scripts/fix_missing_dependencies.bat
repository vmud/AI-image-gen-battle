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
pip install flask-cors>=3.0.0,<5.0.0
pip install eventlet>=0.33.0,<0.36.0

echo.
echo Verifying installation...
python -c "import flask_cors; print('flask-cors:', flask_cors.__version__)"
python -c "import eventlet; print('eventlet:', eventlet.__version__)"

echo.
echo ========================================
echo Dependencies fixed! 
echo You can now run launch_demo.bat
echo ========================================
echo.
pause
