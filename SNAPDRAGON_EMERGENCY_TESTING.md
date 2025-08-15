# Snapdragon Emergency Mode Testing Guide

## Testing the snapdragon_launch.bat Script

### Prerequisites
- Windows system with Python 3.10+ installed
- Project dependencies installed in virtual environment
- Run from project root directory
- Emergency assets directory will be auto-created at `src/windows-client/static/emergency_assets/`

### Test Scenarios

#### 1. Basic Launch Test
```bash
# Run from project root
snapdragon_launch.bat
```

**Expected Behavior:**
- Script shows 6-phase startup process
- Sets emergency mode environment variables
- Launches demo server on port 5000
- Waits for health check endpoint to respond
- Opens browser to `http://localhost:5000/snapdragon`
- Shows monitoring loop with server status

#### 2. Emergency Mode Verification
Once launched, verify emergency mode is active:

1. **Check Web Interface:**
   - Navigate to `http://localhost:5000/snapdragon`
   - Interface should show "Snapdragon X Elite" branding
   - Status should show "READY" 

2. **Test Image Generation:**
   - Enter a prompt (e.g., "A beautiful mountain landscape")
   - Click "Generate" 
   - **Expected:** Generation completes in 3-5 seconds (not 30-45s)
   - Image should be a placeholder/simulated image
   - Telemetry should show NPU utilization ~90%

3. **Check Emergency Status API:**
   ```bash
   curl http://localhost:5000/emergency
   ```
   Should return:
   ```json
   {
     "emergency_mode_available": true,
     "emergency_mode_active": true,
     "activation_reasons": ["Manual override via EMERGENCY_MODE environment variable"]
   }
   ```

#### 3. Error Recovery Tests

**Test Port Conflict:**
1. Start another service on port 5000
2. Run `snapdragon_launch.bat`
3. Should detect conflict and prompt user

**Test Missing Dependencies:**
1. Rename demo_client.py temporarily
2. Run script
3. Should show error about missing files

**Test Server Startup Timeout:**
1. Modify script to reduce MAX_WAIT_TIME to 5 seconds
2. If server takes longer to start, should timeout gracefully

#### 4. Cleanup Testing

**Test Ctrl+C Cleanup:**
1. Launch script successfully
2. Press Ctrl+C in console
3. Should kill Python processes and clean up port 5000

**Test Process Monitoring:**
1. Launch script
2. Manually kill the Python demo process
3. Monitor loop should detect server stopped responding

### Verification Checklist

- [ ] Script runs without syntax errors
- [ ] Emergency mode environment variables are set
- [ ] Server starts and responds to health checks
- [ ] Browser opens to Snapdragon demo page
- [ ] Image generation completes in 3-5 seconds
- [ ] Emergency mode status API confirms activation
- [ ] Cleanup works properly on exit
- [ ] Log file is created with timestamps

### Common Issues and Solutions

**Issue:** "Python not found in PATH"
**Solution:** Install Python 3.10+ or add to system PATH

**Issue:** "demo_client.py not found"
**Solution:** Run script from project root directory

**Issue:** "Port 5000 in use"
**Solution:** Stop other services using port 5000 or choose different port

**Issue:** Browser doesn't open automatically
**Solution:** Manually navigate to http://localhost:5000/snapdragon

### Performance Expectations

In emergency mode:
- **Generation Time:** 3-5 seconds (simulated)
- **NPU Utilization:** 88-95% (simulated)
- **Memory Usage:** Gradual increase during generation
- **Power Consumption:** 8-15W (simulated Snapdragon efficiency)

### Log Analysis

Check `snapdragon_emergency_launch.log` for:
- Timestamp of each major operation
- Error messages and their context
- Server startup confirmation
- Browser launch success/failure
- Cleanup operations

The log helps diagnose issues if the demo doesn't work as expected.