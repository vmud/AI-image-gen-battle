# Python Version Compatibility Fix

## Problem
After uninstalling Python 3.11, Poetry is still trying to use the old Python installation path, causing package verification failures.

## Root Cause
- Python 3.11+ is **incompatible** with DirectML on Windows
- Snapdragon ARM64 systems require Python 3.9 or 3.10
- Poetry cached the old Python path in its virtual environment

## Quick Fix Solutions

### Option 1: Automated Repair (Recommended)
```powershell
# Run the automated repair script
.\fix_poetry_python.ps1

# If Poetry environment is working but you want to force recreation:
.\fix_poetry_python.ps1 -Force

# If you have a specific Python installation to use:
.\fix_poetry_python.ps1 -PythonPath "C:\Python310\python.exe"
```

### Option 2: Manual Poetry Reset
```powershell
# Remove broken Poetry environment
poetry env remove --all

# Find compatible Python installation
Get-ChildItem "C:\Python3*\python.exe" | ForEach-Object { & $_.FullName --version }

# Set Poetry to use compatible Python (example paths)
poetry env use C:\Python310\python.exe
# OR
poetry env use C:\Python39\python.exe

# Reinstall dependencies
poetry install --no-dev
```

### Option 3: Fresh Poetry Installation
```powershell
# Uninstall Poetry
pip uninstall poetry

# Install fresh Poetry
pip install poetry

# Run setup script
.\poetry_setup.ps1
```

## Compatible Python Versions

### ✅ Compatible (Recommended)
- **Python 3.10.x** - Best choice for Snapdragon
- **Python 3.9.x** - Also compatible

### ❌ Incompatible
- **Python 3.11+** - Breaks DirectML compatibility
- **Python 3.8-** - Too old for modern ML packages

## Download Compatible Python

1. Go to: https://www.python.org/downloads/
2. Download **Python 3.10.11** (latest 3.10.x)
3. During installation:
   - ✅ Check "Add Python to PATH"  
   - ✅ Check "Install for all users"
4. Verify installation: `python --version`

## Verification Steps

After fixing Poetry:

```powershell
# Check Poetry environment
poetry env info

# Test Python in Poetry environment
poetry run python --version

# Verify packages can be installed
poetry install --no-dev --dry-run

# Run model preparation script
.\prepare_models.ps1
```

## Troubleshooting

### Issue: "poetry: command not found"
**Solution:** Add Poetry to PATH or reinstall:
```powershell
$env:PATH += ";$env:APPDATA\Python\Scripts"
```

### Issue: Multiple Python versions detected
**Solution:** Specify exact Python path:
```powershell
.\fix_poetry_python.ps1 -PythonPath "C:\Python310\python.exe"
```

### Issue: Poetry still uses old Python
**Solution:** Force environment recreation:
```powershell
poetry env remove --all
poetry env use python
poetry install --no-dev
```

## Fallback: Use pip Instead

If Poetry continues to have issues, the main script will automatically fall back to pip with enhanced dependency resolution:

```powershell
# The script will detect Poetry issues and use pip-tools instead
.\prepare_models.ps1

# Manual pip fallback with dependency resolution
pip install pip-tools
pip-sync requirements.txt
```

## Prevention

To avoid this issue in the future:
1. Always use Python 3.9 or 3.10 on Snapdragon systems
2. Don't uninstall Python without updating Poetry first
3. Use `poetry env use python` when changing Python versions