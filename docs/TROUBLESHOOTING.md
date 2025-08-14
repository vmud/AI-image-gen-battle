# 🔧 Troubleshooting Guide - Snapdragon Setup Issues

## 📋 **Issues Found in Your Snapdragon Setup**

Based on the error output, here are the specific issues and their fixes:

### ❌ **Issue 1: Permission Errors During Python Cleanup**
```
Remove-Item $pythonInstaller -Force
+ FullyQualifiedErrorId : UnauthorizedAccess
```

**Fix:** Use safer file cleanup with error handling
```powershell
# Use the fixed script: setup_windows_fixed.ps1
# It includes Safe-RemoveItem function with proper error handling
```

### ❌ **Issue 2: DirectML Package Not Found (ARM64)**
```
ERROR: Could not find a version that satisfies the requirement directml>=1.12.0
ERROR: No matching distribution found for directml>=1.12.0
```

**Fix:** DirectML is not available for ARM64 architecture
- **Root Cause:** DirectML only supports x86_64, not ARM64 (Snapdragon)
- **Solution:** Use CPU-based inference for Snapdragon (still faster due to NPU)

### ❌ **Issue 3: Firewall Configuration Error**
```
Failed to configure firewall: A parameter cannot be found that matches parameter name 'Force'
```

**Fix:** Use correct PowerShell firewall syntax
```powershell
# Old (broken):
New-NetFirewallRule -Force

# New (fixed):
New-NetFirewallRule -ErrorAction SilentlyContinue
```

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