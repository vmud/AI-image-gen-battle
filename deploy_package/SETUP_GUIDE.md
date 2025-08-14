# AI Image Generation Battle - Setup Guide

## Overview

This guide walks you through setting up the AI Image Generation Battle demonstration system that showcases Snapdragon X Elite's superiority over Intel Core Ultra processors.

## System Requirements

### Hardware
- **Snapdragon Machine**: Samsung Galaxy Book4 Edge (Snapdragon X Elite)
- **Intel Machine**: Lenovo Yoga 7 2-in-1 16IML9 (Intel Core Ultra 7 155U)
- **Control Hub**: MacOS laptop for coordination
- **Network**: All machines on same WiFi network

### Software
- Windows 11 on both test machines
- macOS on control hub
- Python 3.11+ on all machines

## Quick Start (5 Minutes)

### 1. Prepare Control Hub (MacOS)
```bash
# Navigate to project directory
cd AI-image-gen-battle

# Install Python dependencies
pip install requests

# Test the system
python control-hub/test_demo.py
```

### 2. Setup Windows Machines

**On each Windows machine (as Administrator):**

```powershell
# Download and run setup script
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deployment\setup_windows.ps1
```

### 3. Deploy Client Files

Copy the following files to `C:\AIDemo\client\` on each Windows machine:
- `windows-client/platform_detection.py`
- `windows-client/demo_client.py`

### 4. Start Demo Clients

On each Windows machine, run:
```cmd
C:\AIDemo\start_demo.bat
```

### 5. Run the Demo

From your MacOS control hub:

```bash
# Basic demo
python control-hub/demo_control.py --prompt "a futuristic cityscape"

# Interactive mode
python control-hub/demo_control.py --interactive
```

## Demo Commands

### Control Hub Commands

```bash
# Discover clients on network
python control-hub/demo_control.py --discover

# Run demo with custom prompt
python control-hub/demo_control.py --prompt "a beautiful sunset over mountains"

# Run demo with custom steps
python control-hub/demo_control.py --prompt "a robot in a garden" --steps 25

# Interactive mode for live control
python control-hub/demo_control.py --interactive
```

### Interactive Mode Commands
- `discover` - Find demo clients on network
- `status` - Check client status
- `start <prompt>` - Start demo with prompt
- `stop` - Stop running demo
- `quit` - Exit control mode

## Expected Demo Results

**Snapdragon X Elite Performance:**
- Generation Time: ~8-10 seconds
- NPU Utilization: 90-95%
- Power Consumption: 15-18W
- Memory Usage: 4-5GB

**Intel Core Ultra Performance:**
- Generation Time: ~12-15 seconds
- CPU Utilization: 85-90%
- Power Consumption: 25-30W
- Memory Usage: 6-8GB

## Troubleshooting

### Common Issues

**1. Clients Not Discovered**
```bash
# Check network connectivity
ping <client-ip>

# Verify client is running
# Look for "Network server running on port 5000" message
```

**2. Demo Fails to Start**
```bash
# Check client logs
tail -f C:\AIDemo\logs\demo_client.log

# Restart client application
C:\AIDemo\start_demo.bat
```

**3. Platform Detection Issues**
```python
# Test platform detection manually
cd C:\AIDemo
venv\Scripts\activate
python client\platform_detection.py
```

### Network Configuration

**Firewall Settings:**
- Port 5000 must be open on Windows machines
- Same WiFi network required for all devices

**IP Address Discovery:**
```bash
# Find Windows machine IPs
arp -a | grep -E "192\.168\.|10\."
```

## Advanced Configuration

### Custom Optimization Settings

Edit `windows-client/platform_detection.py` to adjust:
- Generation steps (default: 20)
- Memory optimization settings
- CPU thread allocation
- Power management profiles

### Performance Monitoring

The system automatically monitors:
- CPU/NPU utilization
- Memory usage
- Power consumption estimates
- Generation timing
- Step-by-step progress

## Demo Script Example

For presentations, use this sequence:

1. **Setup Phase** (2 minutes)
   - Show both machines with demo ready screens
   - Explain hardware differences

2. **Demo Execution** (30 seconds)
   ```bash
   python control-hub/demo_control.py --prompt "a futuristic AI datacenter"
   ```

3. **Results Analysis** (1 minute)
   - Point out speed difference
   - Highlight power efficiency
   - Emphasize NPU advantage

## File Structure Reference

```
AI-image-gen-battle/
├── README.md                          # Project overview
├── control-hub/                       # MacOS control scripts
│   ├── demo_control.py               # Main control application
│   └── test_demo.py                  # System validation tests
├── windows-client/                   # Windows client applications
│   ├── platform_detection.py        # Hardware detection
│   └── demo_client.py               # Demo display application
├── deployment/                       # Deployment scripts
│   └── setup_windows.ps1           # Windows setup automation
├── mockups/                          # UI design mockups
│   ├── snapdragon-display.html     # Snapdragon UI mockup
│   ├── intel-display.html          # Intel UI mockup
│   └── side-by-side-comparison.html # Demo comparison view
└── docs/                             # Documentation
    └── SETUP_GUIDE.md               # This guide
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Run the test suite: `python control-hub/test_demo.py`
3. Review client logs in `C:\AIDemo\logs\`
4. Verify network connectivity between all machines