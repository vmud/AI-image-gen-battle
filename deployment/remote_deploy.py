#!/usr/bin/env python3
"""
Remote Deployment Script for Windows Machines

This script helps deploy the demo system to Windows machines over the network.
"""

import os
import zipfile
import shutil
import subprocess
import argparse
from pathlib import Path

def create_deployment_package():
    """Create a deployment package with all necessary files."""
    print("📦 Creating deployment package...")
    
    # Create deployment directory
    deploy_dir = Path("deploy_package")
    if deploy_dir.exists():
        shutil.rmtree(deploy_dir)
    deploy_dir.mkdir()
    
    # Copy necessary files
    files_to_copy = [
        ("deployment/setup_windows.ps1", "setup_windows.ps1"),
        ("windows-client/platform_detection.py", "client/platform_detection.py"),
        ("windows-client/demo_client.py", "client/demo_client.py"),
        ("README.md", "README.md"),
        ("docs/SETUP_GUIDE.md", "SETUP_GUIDE.md")
    ]
    
    for src, dst in files_to_copy:
        src_path = Path(src)
        dst_path = deploy_dir / dst
        
        # Create directories if needed
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        
        if src_path.exists():
            shutil.copy2(src_path, dst_path)
            print(f"✅ Copied {src} -> {dst}")
        else:
            print(f"❌ Missing {src}")
    
    # Create a quick start script
    quick_start = """@echo off
title AI Demo Setup
echo ========================================
echo AI Image Generation Demo - Quick Setup
echo ========================================
echo.
echo This will set up your Windows machine for the AI demo.
echo Make sure you are running as Administrator!
echo.
pause
echo.
echo Running setup script...
powershell -ExecutionPolicy Bypass -File setup_windows.ps1
echo.
echo Setup complete! Check above for any errors.
pause
"""
    
    with open(deploy_dir / "QUICK_START.bat", "w") as f:
        f.write(quick_start)
    
    # Create deployment instructions
    instructions = """# Windows Machine Setup Instructions

## Quick Setup (Recommended)

1. **Run as Administrator**: Right-click "QUICK_START.bat" and select "Run as administrator"
2. **Follow prompts**: The script will automatically install everything needed
3. **Wait for completion**: Setup takes 5-10 minutes depending on internet speed

## Manual Setup (Alternative)

1. **Run PowerShell as Administrator**
2. **Execute**: `powershell -ExecutionPolicy Bypass -File setup_windows.ps1`
3. **Copy client files**: Copy `client/` folder to `C:\\AIDemo\\client\\`

## After Setup

1. **Start demo client**: Run `C:\\AIDemo\\start_demo.bat` or use desktop shortcut
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
"""
    
    with open(deploy_dir / "INSTRUCTIONS.md", "w") as f:
        f.write(instructions)
    
    print(f"✅ Deployment package created in: {deploy_dir}")
    return deploy_dir

def create_zip_package(deploy_dir):
    """Create a ZIP file of the deployment package."""
    zip_path = Path("AI_Demo_Windows_Setup.zip")
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for file_path in deploy_dir.rglob('*'):
            if file_path.is_file():
                arcname = file_path.relative_to(deploy_dir)
                zipf.write(file_path, arcname)
                
    print(f"✅ ZIP package created: {zip_path}")
    return zip_path

def generate_deployment_methods():
    """Generate instructions for different deployment methods."""
    methods = """
# 🚀 Deployment Methods (Choose the easiest for your situation)

## Method 1: USB Drive (Simplest - No network needed)
1. Copy `AI_Demo_Windows_Setup.zip` to USB drive
2. Plug into each Windows machine
3. Extract ZIP file to Desktop
4. Right-click `QUICK_START.bat` → "Run as administrator"

## Method 2: Network Share (Best for multiple machines)
```bash
# On your MacOS control hub:
python -m http.server 8000

# On each Windows machine, open browser and go to:
http://[YOUR_MAC_IP]:8000
# Download AI_Demo_Windows_Setup.zip
# Extract and run QUICK_START.bat as administrator
```

## Method 3: Cloud Storage (Convenient)
1. Upload `AI_Demo_Windows_Setup.zip` to Dropbox/OneDrive/Google Drive
2. On each Windows machine, download from cloud
3. Extract and run `QUICK_START.bat` as administrator

## Method 4: Direct Network Copy (If Windows machines are on network)
```bash
# Copy directly via network (requires SMB/CIFS access)
# Replace [WINDOWS_IP] with actual IP address
scp AI_Demo_Windows_Setup.zip administrator@[WINDOWS_IP]:/Users/Public/Desktop/
```

## Method 5: Email Transfer (Simple but manual)
1. Email `AI_Demo_Windows_Setup.zip` to someone with access to Windows machines
2. Download attachment on each machine
3. Extract and run `QUICK_START.bat` as administrator

## Quick Network Discovery (Find Windows machine IPs)
```bash
# On your MacOS machine, scan local network:
nmap -sn 192.168.1.0/24  # Adjust network range as needed
# Or use:
arp -a | grep -E "192\.168\.|10\."
```
"""
    
    with open("DEPLOYMENT_METHODS.md", "w") as f:
        f.write(methods)
    
    print("✅ Deployment methods guide created: DEPLOYMENT_METHODS.md")

def main():
    """Main deployment preparation function."""
    parser = argparse.ArgumentParser(description="Prepare deployment package for Windows machines")
    parser.add_argument("--zip-only", action="store_true", help="Only create ZIP file")
    parser.add_argument("--serve", action="store_true", help="Start HTTP server for network deployment")
    
    args = parser.parse_args()
    
    print("🎯 AI Demo - Windows Deployment Preparation")
    print("=" * 50)
    
    # Create deployment package
    deploy_dir = create_deployment_package()
    
    # Create ZIP package
    zip_path = create_zip_package(deploy_dir)
    
    # Generate deployment methods guide
    generate_deployment_methods()
    
    print("\n🎉 Deployment preparation complete!")
    print("\nFiles created:")
    print(f"  📁 {deploy_dir}/ - Deployment files")
    print(f"  📦 {zip_path} - ZIP package for transfer")
    print(f"  📋 DEPLOYMENT_METHODS.md - Transfer options guide")
    
    if args.serve:
        print(f"\n🌐 Starting HTTP server on port 8000...")
        print(f"Windows machines can download from: http://[YOUR_IP]:8000/{zip_path}")
        subprocess.run(["python", "-m", "http.server", "8000"])
    else:
        print(f"\n📋 Next steps:")
        print(f"1. Choose a deployment method from DEPLOYMENT_METHODS.md")
        print(f"2. Transfer {zip_path} to your Windows machines")
        print(f"3. Extract and run QUICK_START.bat as Administrator on each machine")
        print(f"4. Optional: Start HTTP server with --serve flag for network deployment")

if __name__ == "__main__":
    main()