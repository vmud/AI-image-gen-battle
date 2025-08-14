# Missing Python Modules Fix

## Problem: "No module named 'diffusers'"
When running `prepare_models.ps1`, you get import errors for Python packages like:
- `No module named 'diffusers'`
- `No module named 'transformers'`
- `No module named 'torch'`

## Root Cause
The required Python packages weren't installed properly during the Poetry/pip setup, or the packages were installed in a different Python environment than the one being used.

## Quick Fix Solutions

### Option 1: Automated Installation (Recommended)
```powershell
# Run the dependency installer
.\install_dependencies.ps1

# For Windows users who prefer double-click:
# Double-click: install-dependencies.bat
```

### Option 2: Force Reinstallation
```powershell
# Force reinstall even if some packages are detected
.\install_dependencies.ps1 -Force

# Use specific method
.\install_dependencies.ps1 -Method poetry
.\install_dependencies.ps1 -Method pip
```

### Option 3: Manual Package Installation
```powershell
# Install core packages manually
pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu
pip install diffusers==0.25.1 transformers==4.36.2 huggingface_hub==0.24.6
pip install accelerate==0.25.0 safetensors==0.4.1
pip install optimum[onnxruntime]==1.16.2
```

### Option 4: Poetry Environment Reset
```powershell
# If using Poetry, reset the environment
poetry env remove --all
poetry env use python
poetry install --no-dev
```

## What the Installer Does

The `install_dependencies.ps1` script provides:

### 📦 **Package Management**
- **Auto-detection**: Chooses Poetry or pip based on availability
- **Compatibility Check**: Ensures Python 3.9-3.10 compatibility
- **Version Pinning**: Uses exact versions to prevent conflicts
- **Dependency Resolution**: Handles ML package conflicts automatically

### 🔍 **Verification Process**
- **Current Status**: Checks which packages are already installed
- **Missing Detection**: Identifies exactly what's missing
- **Post-Install Validation**: Verifies all packages work correctly
- **Clear Reporting**: Shows exactly what was installed

### 🚀 **Installation Methods**
- **Poetry First**: Uses Poetry if environment is working
- **Pip Fallback**: Uses pip-tools for enhanced resolution
- **Direct Pip**: Falls back to standard pip if needed

## Expected Output

After running the installer, you should see:
```
============================================
AI Demo Dependency Installation
============================================
[SUCCESS] Python 3.10.11 is compatible
[INFO] Missing packages: diffusers, transformers
[AUTO-DETECT] Using Poetry for installation
[SUCCESS] Poetry installation completed
[INFO] Verifying installation...
   ✓ torch - 2.1.2
   ✓ diffusers - 0.25.1  
   ✓ transformers - 4.36.2
   ✓ optimum - 1.16.2
   ✓ onnxruntime - 1.16.3
============================================
Installation Successful!
============================================
```

## Troubleshooting

### Issue: "Poetry environment broken"
**Solution:** The installer will automatically detect this and use pip instead.

### Issue: "pip installation failed"  
**Solution:** Check Python version and PATH:
```powershell
python --version  # Should be 3.9.x or 3.10.x
.\fix_python_path.ps1  # If Python issues detected
```

### Issue: "Package conflicts detected"
**Solution:** The installer uses pinned versions to prevent conflicts, but if issues persist:
```powershell
# Clean install
pip uninstall torch torchvision diffusers transformers optimum -y
.\install_dependencies.ps1 -Force
```

### Issue: "ImportError: cannot import name DDUFEntry from huggingface_hub"
**Solution:** This occurs when huggingface_hub version is incompatible. Fix with:
```powershell
# Quick fix for DDUFEntry import error
.\fix_huggingface_import.ps1

# Or manual fix:
pip install --upgrade huggingface_hub==0.24.6
```

### Issue: Different Python environment
**Solution:** Verify you're using the same Python:
```powershell
# Check which Python is being used
python -c "import sys; print(sys.executable)"

# If different from expected, run:
.\fix_python_path.ps1
```

## Prevention

To avoid missing module issues in the future:

1. **Use the installer first**: Always run `.\install_dependencies.ps1` before `.\prepare_models.ps1`
2. **Check Python version**: Ensure Python 3.9 or 3.10 before installing packages
3. **Use consistent environment**: Don't mix system Python, Poetry, and conda environments
4. **Validate installation**: The installer automatically verifies all packages work

## Package Details

### Core ML Framework
- **torch** (2.1.2): PyTorch for neural networks
- **torchvision** (0.16.2): Computer vision utilities
- **diffusers** (0.25.1): Stable Diffusion pipelines
- **transformers** (4.36.2): HuggingFace model library

### AI Acceleration  
- **optimum** (1.16.2): Hardware optimization
- **onnxruntime** (1.16+): ONNX model inference
- **accelerate** (0.25.0): Distributed training utilities

### Supporting Libraries
- **huggingface_hub** (0.20.3): Model downloading
- **safetensors** (0.4.1): Safe model serialization
- **pillow**: Image processing
- **numpy**: Numerical computing