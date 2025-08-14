
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
