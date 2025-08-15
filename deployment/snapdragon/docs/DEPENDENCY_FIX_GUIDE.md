# Snapdragon Dependency Fix Guide

## Issue: Missing flask-cors Module

### Problem
After running `launch_demo.bat` on Snapdragon system, you encounter:
```
ModuleNotFoundError: No module named 'flask_cors'
```

### Root Cause
The Snapdragon requirements file was missing essential web framework dependencies that are required by `demo_client.py`:
- `flask-cors` - CORS support for web API
- `eventlet` - Async networking for SocketIO

### Quick Fix (Immediate Solution)

Run the dependency fix script:
```batch
C:\AIDemo\deployment\snapdragon\scripts\fix_missing_dependencies.bat
```

This script will:
1. Activate the Python virtual environment
2. Install the missing dependencies
3. Verify successful installation

### Manual Fix (Alternative)

If you prefer to install manually:
```batch
cd C:\AIDemo
call .venv\Scripts\activate.bat
pip install flask-cors>=3.0.0,<5.0.0
pip install eventlet>=0.33.0,<0.36.0
```

### Long-term Fix (Prevent Future Issues)

The issue has been fixed in the requirements files. For future deployments:

1. **Updated Snapdragon requirements** now include all necessary web dependencies
2. **Re-run setup_environment.bat** to install complete dependency set
3. **Use latest deployment script** which includes the corrected requirements

### Verification

After applying the fix, verify installation:
```batch
cd C:\AIDemo
call .venv\Scripts\activate.bat
python -c "import flask_cors; print('flask-cors:', flask_cors.__version__)"
python -c "import eventlet; print('eventlet:', eventlet.__version__)"
```

Expected output:
```
flask-cors: 4.x.x
eventlet: 0.33.x
```

### Updated Requirements Structure

#### Fixed Snapdragon Requirements (`requirements-snapdragon.txt`):
```txt
# Web framework for demo
flask==2.3.3                   # Stable web framework
flask-socketio==5.3.6          # WebSocket support
flask-cors>=3.0.0,<5.0.0       # CORS support for web API (ADDED)
eventlet>=0.33.0,<0.36.0       # Async networking for SocketIO (ADDED)
```

#### Intel Requirements (Reference - Uses Core):
```txt
# Intel requirements include core dependencies via:
-r requirements-core.txt        # Includes flask-cors and eventlet
```

### Testing the Fix

After applying the fix, test the demo:
```batch
cd C:\AIDemo
launch_demo.bat
```

Expected output:
```
Starting AI Demo (snapdragon)...
 * Running on http://0.0.0.0:5000
 * Debug mode: off
INFO:werkzeug: * Running on all addresses (0.0.0.0)
INFO:werkzeug: * Running on http://127.0.0.1:5000
INFO:werkzeug: * Running on http://[your-ip]:5000
```

### Prevention for Future Deployments

1. **Use the updated deployment script** which includes corrected requirements
2. **The fix is permanent** - future deployments will include all necessary dependencies
3. **Requirements files are now consistent** between Intel and Snapdragon platforms

### Additional Dependencies Check

If you encounter other missing modules, check the full dependency list:

**Core Web Dependencies:**
- `flask` >= 2.0.0
- `flask-socketio` >= 5.0.0
- `flask-cors` >= 3.0.0 ✅ **FIXED**
- `eventlet` >= 0.33.0 ✅ **FIXED**

**AI/ML Dependencies:**
- `torch` == 2.1.2
- `transformers` == 4.36.2
- `diffusers` == 0.25.1
- `onnxruntime` == 1.18.1

### Support

If you continue to experience dependency issues:
1. Run the dependency fix script
2. Check Python version (should be 3.10)
3. Verify virtual environment activation
4. Check network connectivity for pip installs

The dependency issue has been resolved and future deployments will include all necessary packages automatically.
