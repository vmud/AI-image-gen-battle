# Windows Machine Setup Instructions

## Quick Setup (Recommended)

1. **Run as Administrator**: Right-click "QUICK_START.bat" and select "Run as administrator"
2. **Follow prompts**: The script will automatically install everything needed
3. **Wait for completion**: Setup takes 5-10 minutes depending on internet speed

## Manual Setup (Alternative)

1. **Run PowerShell as Administrator**
2. **Execute**: `powershell -ExecutionPolicy Bypass -File setup_windows.ps1`
3. **Copy client files**: Copy `client/` folder to `C:\AIDemo\client\`

## After Setup

1. **Start demo client**: Run `C:\AIDemo\start_demo.bat` or use desktop shortcut
2. **Verify ready status**: Look for "READY" status on the demo screen
3. **Test from control hub**: Your MacOS control hub should discover this machine

## Troubleshooting

- **Permission errors**: Make sure you're running as Administrator
- **Network issues**: Check Windows Firewall allows Python on port 5000
- **Python errors**: Restart and try again, setup script installs all dependencies

## Files Included

- `setup_windows.ps1` - Main setup script
- `client/platform_detection.py` - Hardware detection
- `client/demo_client.py` - Demo display application
- `SETUP_GUIDE.md` - Detailed documentation
