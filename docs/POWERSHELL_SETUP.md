# PowerShell Execution Policy Setup

## 🔐 PowerShell Execution Policy Commands

By default, Windows blocks PowerShell scripts for security. You need to allow script execution before running the setup.

## Quick Setup (Recommended)

**Run PowerShell as Administrator** and execute:

```powershell
# Allow scripts for current user only (safest option)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify the policy was set
Get-ExecutionPolicy -List
```

## All Available Options

### Option 1: Current User Only (Recommended)
```powershell
# Safest - only affects current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Option 2: Local Machine (Admin Required)
```powershell
# Affects all users on machine (requires Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### Option 3: Current Session Only (Temporary)
```powershell
# Only for current PowerShell session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Option 4: Force Override (If needed)
```powershell
# Force set if there are conflicts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

## Complete Windows Setup Sequence

**1. Open PowerShell as Administrator**
   - Press `Win + X`
   - Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

**2. Set Execution Policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**3. Navigate to Setup Files**
```powershell
# Navigate to where you extracted AI_Demo_Windows_Setup.zip
cd C:\Users\$env:USERNAME\Desktop\AI_Demo_Windows_Setup
```

**4. Run Setup Script**
```powershell
.\setup_windows.ps1
```

## Alternative: Bypass for Single Script

If you can't change the execution policy permanently:

```powershell
# Run single script with bypass
powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1
```

## Verify Current Policy

Check what policies are currently set:

```powershell
# See all execution policies
Get-ExecutionPolicy -List

# See effective policy
Get-ExecutionPolicy
```

## Reset to Default (If Needed Later)

To restore Windows default security:

```powershell
# Reset to default
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
```

## Execution Policy Explanations

- **Restricted**: No scripts allowed (Windows default)
- **RemoteSigned**: Local scripts run freely, downloaded scripts need digital signature
- **AllSigned**: All scripts must be digitally signed
- **Unrestricted**: All scripts run (not recommended)
- **Bypass**: Nothing is blocked (temporary use only)

## Troubleshooting

**Error: "cannot be loaded because running scripts is disabled"**
```powershell
# Solution:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

**Error: "Access denied"**
- Make sure PowerShell is running as Administrator
- Try using `-Scope CurrentUser` instead of `-Scope LocalMachine`

**Script still won't run:**
```powershell
# Force bypass for this session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

## Security Notes

- **RemoteSigned** is the recommended policy for most users
- **CurrentUser** scope only affects your user account
- **LocalMachine** scope affects all users and requires admin rights
- Always run setup scripts from trusted sources only

## One-Liner for Quick Setup

```powershell
# Complete setup in one command
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; .\setup_windows.ps1