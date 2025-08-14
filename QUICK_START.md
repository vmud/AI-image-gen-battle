# Quick Start Guide

## 🚀 5-Minute Setup

### On Windows Machines (Both Intel and Snapdragon)

1. **Run setup with monitoring** (open 2 PowerShell windows as Admin):
   
   **Window 1 - Run Setup:**
   ```powershell
   .\deployment\setup.ps1
   ```
   
   **Window 2 - Monitor Progress:**
   ```powershell
   .\deployment\monitor.ps1
   ```

2. **Download AI Models** (after setup completes):
   ```powershell
   .\deployment\prepare_models.ps1
   # Choose appropriate model when prompted
   ```

3. **Verify Installation:**
   ```powershell
   .\deployment\verify.ps1
   ```

4. **Copy Client Files:**
   ```powershell
   Copy-Item src\windows-client\*.py C:\AIDemo\client\
   ```

### On MacOS Control Hub

```bash
# Install dependencies
pip install requests flask flask-socketio

# Test the system
python src/control-hub/test_demo.py

# Run synchronized demo
python src/control-hub/demo_control.py --discover
python src/control-hub/demo_control.py --prompt "a futuristic robot"
```

## 📁 Clean Project Structure

```
AI-image-gen-battle/
├── src/                   # All source code
│   ├── control-hub/       # MacOS control (demo_control.py, test_demo.py)
│   └── windows-client/    # Windows client (demo_client.py, ai_pipeline.py)
├── deployment/            # All setup scripts
│   ├── setup.ps1          # Main setup with real-time logging
│   ├── monitor.ps1        # Watch setup progress
│   ├── diagnose.ps1       # Fix DirectML issues
│   ├── prepare_models.ps1 # Download AI models
│   └── verify.ps1         # Check installation
└── docs/                  # All documentation
```

## ⚡ Performance Expectations

- **Snapdragon X Elite**: 3-5 seconds per image (768x768)
- **Intel Core Ultra**: 35-45 seconds per image (768x768)
- **Advantage**: Snapdragon is 7-10x faster!

## 🔧 Troubleshooting

### DirectML Issues on Intel?
```powershell
.\deployment\diagnose.ps1
```

### Want to see what's happening during setup?
```powershell
Get-Content "C:\AIDemo\setup.log" -Wait -Tail 10
```

### Need to reinstall?
```powershell
.\deployment\setup.ps1 -Force
```

## 📚 Key Documentation

- **AI Implementation**: `docs/AI_IMPLEMENTATION.md`
- **Model Download Guide**: `docs/MODEL_ACQUISITION_GUIDE.md`
- **Performance Benchmarks**: `docs/PERFORMANCE_BENCHMARKS.md`
- **Full Setup Guide**: `docs/SETUP_GUIDE.md`