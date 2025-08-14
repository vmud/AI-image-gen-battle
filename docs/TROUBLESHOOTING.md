# 🔧 Troubleshooting Guide - AI Demo Setup Issues

## 📋 **Enhanced Installation System (v2.0)**

The setup script now includes enhanced package installation with:
- ✅ **DirectML Compatibility Checking** - Validates Windows version and DirectX support
- ✅ **Progressive Package Installation** - Installs packages individually with detailed progress
- ✅ **Automatic Fallback** - Gracefully handles DirectML failures on incompatible systems
- ✅ **Retry Mechanism** - Exponential backoff for network failures
- ✅ **Verbose Output** - Real-time progress indicators and detailed error messages

## 🚀 **Common Installation Issues & Solutions**

### ❌ **Issue 1: DirectML Not Available (Intel x86 Systems)**
```
ERROR: Could not find a version that satisfies the requirement directml>=1.12.0
```

**New Enhanced Fix:**
The updated script now automatically:
1. Checks DirectML compatibility before installation
2. Validates Windows version (requires v1903+) and DirectX 12 support
3. Falls back to CPU-only mode if DirectML fails
4. Provides clear error messages explaining why DirectML failed

```powershell
# The enhanced script will show:
# "DirectML not supported - using CPU-only mode"
# "System appears compatible with DirectML"
```

### ❌ **Issue 2: Package Installation Failures**
```
ERROR: Network connection failed / Package not found
```

**New Enhanced Fix:**
- **Progressive Installation**: Each package installed individually
- **Retry Logic**: 3 attempts with exponential backoff (2s, 4s, 8s)
- **Graceful Degradation**: Core packages required, optional packages can fail
- **Detailed Feedback**: Shows exactly which packages succeeded/failed

### ❌ **Issue 3: ARM64 Compatibility (Snapdragon)**
```
ERROR: No matching distribution found for directml>=1.12.0
```

**Enhanced ARM64 Support:**
- Automatically detects ARM64 architecture
- Skips DirectML (x86-only) packages
- Uses optimized CPU-only packages
- Still provides excellent performance with NPU acceleration

## 🚀 **Quick Fix Instructions**

### **Step 1: Use the Fixed Script**

Replace the original setup script with the fixed version:

```powershell
# Download the fixed script
# Use: setup_windows_fixed.ps1 instead of setup_windows.ps1
```

### **Step 2: Manual Cleanup (if needed)**

If the original script left issues:

```powershell
# Clean up any stuck Python installers
Get-Process | Where-Object {$_.Name -like "*python*"} | Stop-Process -Force -ErrorAction SilentlyContinue

# Remove temp files manually
Remove-Item "$env:TEMP\python-installer.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\git-installer.exe" -Force -ErrorAction SilentlyContinue
```

### **Step 3: Run Fixed Setup**

```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Run the fixed script
.\setup_windows_fixed.ps1 -Force
```

## 🔍 **Platform-Specific Solutions**

### **For Snapdragon X Elite (ARM64):**

1. **Skip DirectML packages** (not compatible with ARM64)
2. **Use CPU-based PyTorch** (still benefits from NPU acceleration)
3. **Install ARM64-compatible packages only**

```powershell
# The fixed script automatically detects ARM64 and uses compatible packages
```

### **For Intel Core Ultra (x86_64):**

1. **Include DirectML packages** (full GPU acceleration)
2. **Use standard x86_64 packages**
3. **Enable all optimization features**

## 🛠️ **Manual Package Installation (if needed)**

If the automated script still has issues, install packages manually:

```powershell
# Navigate to demo directory
cd C:\AIDemo
venv\Scripts\activate

# Install core packages first
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
pip install diffusers transformers accelerate
pip install flask flask-socketio requests psutil
pip install Pillow numpy opencv-python

# For Snapdragon (ARM64) - skip DirectML
pip install onnxruntime

# For Intel (x86_64) - include DirectML
pip install directml onnxruntime-directml
```

## 🔧 **Common Error Solutions**

### **Error: "Python not found"**
```powershell
# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Or restart PowerShell
```

### **Error: "Access denied"**
```powershell
# Make sure PowerShell is running as Administrator
# Right-click PowerShell → "Run as administrator"
```

### **Error: "Package installation failed"**
```powershell
# Update pip first
python -m pip install --upgrade pip

# Install packages one by one to identify issues
pip install torch
pip install diffusers
# etc.
```

### **Error: "Firewall configuration failed"**
```powershell
# Configure manually through Windows Settings
# Settings → Privacy & Security → Windows Security → Firewall & network protection
# Allow Python through firewall on port 5000
```

## 📊 **Verification Steps**

After running the fixed script, verify everything works:

```powershell
# 1. Check Python installation
python --version

# 2. Check virtual environment
cd C:\AIDemo
venv\Scripts\activate
python -c "import torch; print('PyTorch:', torch.__version__)"

# 3. Check platform detection
python client\platform_detection.py

# 4. Test demo client
python client\demo_client.py
```

## 🎯 **Expected Results After Fix**

✅ **Python 3.11 installed successfully**  
✅ **Virtual environment created**  
✅ **ARM64-compatible packages installed**  
✅ **Firewall configured (or manual setup noted)**  
✅ **Demo directory structure created**  
✅ **Desktop shortcut created**  
✅ **Platform detected as Snapdragon X Elite**  

## 📞 **If Issues Persist**

1. **Check Windows version** (Windows 11 recommended for Snapdragon)
2. **Verify ARM64 architecture** using `systeminfo` command
3. **Try manual package installation** (see section above)
4. **Check antivirus software** (may block installations)
5. **Run Windows Update** (ensure latest ARM64 support)

## 🔄 **Recovery Commands**

If you need to start over completely:

```powershell
# Remove demo directory
Remove-Item "C:\AIDemo" -Recurse -Force -ErrorAction SilentlyContinue

# Remove desktop shortcut
Remove-Item "$env:USERPROFILE\Desktop\AI Demo.lnk" -Force -ErrorAction SilentlyContinue

# Then run the fixed setup script again
.\setup_windows_fixed.ps1 -Force