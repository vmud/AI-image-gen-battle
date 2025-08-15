
# 🚀 Deployment Methods (Choose the easiest for your situation)

## Method 1: GitHub Clone (Recommended for Production)
```powershell
# One-line deployment - Open PowerShell as Administrator and run:
irm https://raw.githubusercontent.com/vmud/AI-image-gen-battle/main/deploy_from_github.ps1 | iex

# Or clone manually:
git clone https://github.com/vmud/AI-image-gen-battle.git C:\AI-Demo
cd C:\AI-Demo
powershell -ExecutionPolicy Bypass -File deployment\common\scripts\setup.ps1
```

## Method 2: USB Drive (No network needed)
1. Copy `AI_Demo_Windows_Setup.zip` to USB drive
2. Plug into each Windows machine
3. Extract ZIP file to Desktop
4. Right-click `QUICK_START.bat` → "Run as administrator"

## Method 3: Network Share (Best for multiple machines on same network)
```bash
# On your MacOS control hub:
python -m http.server 8000

# On each Windows machine, open browser and go to:
http://[YOUR_MAC_IP]:8000
# Download AI_Demo_Windows_Setup.zip
# Extract and run QUICK_START.bat as administrator
```

## Method 4: Cloud Storage (Alternative for remote deployment)
1. Upload `AI_Demo_Windows_Setup.zip` to Dropbox/OneDrive/Google Drive
2. On each Windows machine, download from cloud
3. Extract and run `QUICK_START.bat` as administrator

## Method 5: Direct Network Copy (If Windows machines are on network)
```bash
# Copy directly via network (requires SMB/CIFS access)
# Replace [WINDOWS_IP] with actual IP address
scp AI_Demo_Windows_Setup.zip administrator@[WINDOWS_IP]:/Users/Public/Desktop/
```

## Method 6: Email Transfer (Simple but manual)
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
