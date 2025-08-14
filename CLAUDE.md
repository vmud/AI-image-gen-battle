# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a demonstration system showcasing Snapdragon X Elite's AI processing superiority over Intel Core Ultra processors using real-time Stable Diffusion image generation. The system consists of:

- **MacOS Control Hub**: Coordinates synchronized demonstrations between Windows machines
- **Windows Clients**: Full-screen displays showing real-time image generation with platform-specific optimizations
- **Deployment Scripts**: PowerShell scripts for automated Windows machine setup

## Key Commands

### Testing and Validation
```bash
# Run full system test from control hub
python src/control-hub/test_demo.py

# Discover Windows clients on network
python src/control-hub/demo_control.py --discover

# Execute synchronized demo
python src/control-hub/demo_control.py --prompt "your prompt here"
```

### Windows Setup (PowerShell)
```powershell
# Main setup with real-time logging (requires admin)
.\deployment\setup.ps1

# Monitor setup progress in another window
.\deployment\monitor.ps1

# Troubleshoot DirectML issues
.\deployment\diagnose.ps1

# Download and prepare AI models
.\deployment\prepare_models.ps1

# Verify installation
.\deployment\verify.ps1
```

### Development Server
```bash
# Serve deployment package over HTTP
python -m http.server 8000
```

## Architecture

### Control Flow
1. **demo_control.py** (MacOS) discovers Windows clients via network scan on port 5000
2. Sends synchronized demo commands to both Windows machines
3. **demo_client.py** (Windows) receives commands, executes AI image generation
4. Real-time progress and metrics are displayed on full-screen UIs
5. Control hub monitors completion and announces winner

### Platform Detection
- **platform_detection.py** identifies Snapdragon vs Intel hardware
- Snapdragon uses NPU acceleration via ONNX Runtime
- Intel uses DirectML (when available) or CPU/CUDA fallback
- Detection based on processor name, WMI queries, and architecture

### Key Components

**Control Hub (src/control-hub/)**:
- `demo_control.py`: Network discovery, synchronization, command dispatch
- `test_demo.py`: Validates entire system setup before demos

**Windows Client (src/windows-client/)**:
- `demo_client.py`: Flask server (port 5000), WebSocket communication, Tkinter fullscreen UI
- `platform_detection.py`: Hardware detection, optimization path selection
- `ai_pipeline.py`: Stable Diffusion XL pipeline with platform-specific optimizations

**Deployment (deployment/)**:
- `setup.ps1`: Main setup with real-time logging, installs Python 3.9, Git, dependencies
- `monitor.ps1`: Real-time progress monitoring for setup script
- `diagnose.ps1`: Automated DirectML troubleshooting and fixes
- `prepare_models.ps1`: Downloads platform-optimized AI models (Qualcomm AI Hub for Snapdragon)
- `verify.ps1`: Validates complete installation and readiness

### Network Communication
- Discovery: UDP broadcast or TCP scan on port 5000
- Commands: HTTP POST to `/demo/start`, `/demo/stop`, `/demo/status`
- Real-time updates: WebSocket on port 5001
- Image transfer: Base64 encoded in JSON responses

## Important Notes

### DirectML Compatibility
DirectML requires Python 3.8-3.10 and x86_64 architecture. The setup script handles this automatically with fallback to ONNX Runtime if DirectML is unavailable.

### Demo Directory Structure
All demo files are deployed to `C:\AIDemo\` on Windows machines:
```
C:\AIDemo\
├── client\         # Demo client application
├── models\         # Stable Diffusion models
├── cache\          # Model cache
├── logs\           # Application logs
└── venv\           # Python virtual environment
```

### Error Handling
- Windows setup continues even if DirectML fails to install
- Network discovery has 0.1s timeout per IP to speed up scanning
- Platform detection falls back to CPU if specific accelerators unavailable

## Deployment Process

1. Run `setup_windows.ps1` on both Windows machines as administrator
2. Copy client files to `C:\AIDemo\client\`
3. Start demo clients on Windows machines
4. Run `test_demo.py` from MacOS to validate setup
5. Execute demos with `demo_control.py --prompt "..."`