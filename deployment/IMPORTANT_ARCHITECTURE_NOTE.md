# IMPORTANT: Architecture Detection for Snapdragon X Elite

## Key Information
**Snapdragon X Elite devices report as AMD64, not ARM64**

This is by design for compatibility reasons. The PowerShell script `prepare_snapdragon.ps1` has been updated to accept both AMD64 and ARM64 architectures.

## Architecture Mapping
- **Development Machine**: May be any architecture (x64, ARM64, etc.)
- **Target Snapdragon X Elite Devices**: Report as `AMD64` via `$env:PROCESSOR_ARCHITECTURE`
- **Expected Values**: `AMD64` or `ARM64` are both valid for Snapdragon devices

## Script Behavior
The script checks for both architectures:
```powershell
if ($arch -ne "ARM64" -and $arch -ne "AMD64") {
    # Fail - not a supported architecture
}
```

## Testing Note
When testing this script on development machines that are not Snapdragon X Elite:
- The architecture check will pass if you're on AMD64 or ARM64
- Other hardware checks (processor name, NPU detection) may still fail
- Use the `-Force` flag to bypass hardware checks for testing purposes

## References
- Snapdragon X Elite documentation
- Windows on ARM compatibility layer
- PowerShell environment variables

---
*Last Updated: 2024-08-14*
*This is a critical project rule - do not modify architecture checks without understanding the implications*