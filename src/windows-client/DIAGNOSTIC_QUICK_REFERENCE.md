# AI Image Generation Diagnostic Framework - Quick Reference

## Essential Commands (Post-Deployment)

### Basic Validation
```bash
# Quick health check after deployment script
python demo_diagnostic.py --quick

# Detailed analysis for troubleshooting
python demo_diagnostic.py --detailed-report

# Maximum detail for complex issues
python demo_diagnostic.py --detailed-report --log-level DEBUG
```

### Save Results for Support
```bash
# Generate report with logs
python demo_diagnostic.py --detailed-report --log-file issue_report.log --save-logs

# Include verbose system details
python demo_diagnostic.py --detailed-report --log-level VERBOSE --save-logs
```

## Platform-Specific Quick Commands

### Intel DirectML Systems
```bash
# After prepare_intel.ps1 completes
cd src/windows-client
python demo_diagnostic.py --quick

# Check DirectML status specifically
python demo_diagnostic.py --detailed-report | findstr -i "directml\|acceleration"

# Debug DirectML issues
python demo_diagnostic.py --log-level DEBUG | findstr -i "directml\|gpu"
```

### Snapdragon NPU Systems
```bash
# After prepare_snapdragon.ps1 completes
cd src/windows-client
python demo_diagnostic.py --quick

# Check NPU status specifically
python demo_diagnostic.py --detailed-report | findstr -i "npu\|qnn\|acceleration"

# Debug NPU issues
python demo_diagnostic.py --log-level DEBUG | findstr -i "npu\|qnn\|provider"
```

## Common Error Codes and Solutions

### Environment Issues

#### `[FAIL] Python Environment: Not using deployment virtual environment`
**Quick Fix:**
```bash
C:\AIDemo\venv\Scripts\activate.bat
cd C:\AIDemo\client
python ..\windows-client\demo_diagnostic.py --quick
```

#### `[FAIL] Python Environment: Python 3.11 detected, requires Python 3.10`
**Quick Fix:** Re-run deployment script with correct Python 3.10

### Import Failures

#### `[FAIL] AIImagePipeline Import: No module named 'torch_directml'`
**Quick Fix:**
```bash
C:\AIDemo\venv\Scripts\activate.bat
pip install torch-directml
```

#### `[FAIL] AIImagePipeline Import: No module named 'onnxruntime'`
**Quick Fix:**
```bash
C:\AIDemo\venv\Scripts\activate.bat
pip install onnxruntime-directml  # Intel
pip install onnxruntime-qnn       # Snapdragon
```

### Hardware Acceleration Issues

#### `[FAIL] Hardware Acceleration: DirectML device creation failed`
**Causes & Fixes:**
- **Driver Issue**: Update Intel GPU drivers
- **Maintenance Mode**: Restart system, check for GPU conflicts
- **Memory Issue**: Close other applications, check available GPU memory

**Debug Command:**
```bash
python demo_diagnostic.py --log-level DEBUG | findstr -i "directml\|device\|error"
```

#### `[FAIL] Hardware Acceleration: QNN provider not available`
**Causes & Fixes:**
- **Windows Version**: Upgrade to Windows 11 24H2+
- **NPU Drivers**: Install/update Snapdragon NPU drivers
- **Package Issue**: Re-install onnxruntime-qnn

**Debug Command:**
```bash
python -c "import onnxruntime; print(onnxruntime.get_available_providers())"
```

### Model Access Issues

#### `[FAIL] Model Accessibility: Models not found at expected location`
**Quick Fix:**
```bash
# Check if models exist
dir C:\AIDemo\models\ /s

# Re-run deployment script model download
# Intel:
deployment\intel\scripts\prepare_intel.ps1
# Snapdragon:
deployment\snapdragon\scripts\prepare_snapdragon.ps1
```

#### `[FAIL] Model Loading: Pipeline initialization failed`
**Quick Fix:**
```bash
# Check model file integrity
dir C:\AIDemo\models\sdxl-base-1.0\ /s        # Intel
dir C:\AIDemo\models\sdxl_lightning_4step\ /s # Snapdragon

# Compare file sizes with deployment script expectations
```

### Performance Issues

#### `[PASS] Quick Performance Test: 120.3s (target: 35-45s) - SLOW performance`
**Intel Troubleshooting:**
```bash
# Check if using GPU acceleration
python demo_diagnostic.py --detailed-report | findstr -i "acceleration\|directml"

# Check GPU memory usage
python demo_diagnostic.py --log-level DEBUG | findstr -i "memory\|gpu"
```

#### `[PASS] Quick Performance Test: 45.2s (target: 3-5s) - SLOW performance`
**Snapdragon Troubleshooting:**
```bash
# Check if using NPU acceleration
python demo_diagnostic.py --detailed-report | findstr -i "npu\|qnn"

# Check for CPU fallback
python demo_diagnostic.py --log-level DEBUG | findstr -i "fallback\|cpu"
```

## Status Interpretation Guide

### Test Result Status Codes
- `[PASS]` - Test successful (green)
- `[FAIL]` - Test failed, requires attention (red)
- `[FIX]` - Recommended fix command provided (cyan)
- `[CHECKING]` - Test in progress (yellow)

### Performance Ratings
- `EXCELLENT` - Optimal hardware acceleration active
- `GOOD` - Hardware acceleration working well  
- `ACCEPTABLE` - Using optimized CPU fallback
- `SLOW` - Performance below expectations, check setup

## Emergency Troubleshooting Workflow

### When Everything Fails
```bash
# 1. Verify deployment environment
C:\AIDemo\venv\Scripts\activate.bat
cd C:\AIDemo\client

# 2. Check basic Python functionality
python -c "print('Python OK')"

# 3. Test minimal imports
python -c "import torch; print('PyTorch OK')"

# 4. Platform-specific acceleration test
# Intel:
python -c "import torch_directml; print('DirectML OK')"
# Snapdragon:
python -c "import onnxruntime; print('ONNX Runtime OK')"

# 5. Full diagnostic with maximum detail
python ..\windows-client\demo_diagnostic.py --detailed-report --log-level DEBUG --save-logs
```

### When Performance is Unexpectedly Slow

#### Intel Systems (Expected: 35-45s, Getting: >60s)
```bash
# Check DirectML device status
python demo_diagnostic.py --log-level DEBUG | findstr -i "directml.*device"

# Check for CPU fallback indicators
python demo_diagnostic.py --detailed-report | findstr -i "cpu.*fallback"

# Verify GPU is being used
python -c "import torch_directml; device = torch_directml.device(); print(f'Using device: {device}')"
```

#### Snapdragon Systems (Expected: 3-5s, Getting: >30s)
```bash
# Check NPU provider availability
python -c "import onnxruntime as ort; providers = ort.get_available_providers(); print('QNN available:', 'QNNExecutionProvider' in providers)"

# Check for CPU fallback
python demo_diagnostic.py --log-level DEBUG | findstr -i "cpu.*execution"

# Verify NPU environment variables
echo %SNAPDRAGON_NPU%
echo %ONNX_PROVIDERS%
```

## Integration with Deployment Scripts

### Recommended Post-Deployment Workflow
```bash
# 1. Run deployment script first
deployment\intel\scripts\prepare_intel.ps1      # Intel
deployment\snapdragon\scripts\prepare_snapdragon.ps1  # Snapdragon

# 2. If final performance test fails, diagnose
cd src\windows-client
python demo_diagnostic.py --quick

# 3. Address any [FAIL] results
# Follow error-specific fixes above

# 4. Re-validate
python demo_diagnostic.py --detailed-report

# 5. If still failing, get support data
python demo_diagnostic.py --detailed-report --log-level DEBUG --save-logs
```

### When to Re-run Deployment Scripts
- Python environment issues persist
- Multiple dependency failures
- Model files missing or corrupted
- Hardware acceleration completely unavailable

### When to Use Diagnostics Only
- Deployment completed successfully but performance is poor
- Intermittent hardware acceleration issues
- Need to validate client readiness
- Troubleshooting specific error messages

## Support Data Collection

### Generate Complete Support Package
```bash
# Activate environment
C:\AIDemo\venv\Scripts\activate.bat
cd C:\AIDemo\client

# Generate comprehensive diagnostics
python ..\windows-client\demo_diagnostic.py --detailed-report --log-level VERBOSE --save-logs --log-file support_package.log

# Include system information
systeminfo > system_info.txt
dxdiag /t dxdiag_report.txt

# Package all logs
# Files to include in support request:
# - support_package.log
# - system_info.txt  
# - dxdiag_report.txt
# - Any error screenshots
```

## Quick Command Reference Card

| Purpose | Command |
|---------|---------|
| **Post-deployment validation** | `python demo_diagnostic.py --quick` |
| **Performance troubleshooting** | `python demo_diagnostic.py --detailed-report` |
| **Deep debugging** | `python demo_diagnostic.py --log-level DEBUG` |
| **Intel DirectML check** | `python demo_diagnostic.py --detailed-report \| findstr -i directml` |
| **Snapdragon NPU check** | `python demo_diagnostic.py --detailed-report \| findstr -i npu` |
| **Performance analysis** | `python demo_diagnostic.py --detailed-report \| findstr -i "generation time"` |
| **Support data collection** | `python demo_diagnostic.py --detailed-report --log-level VERBOSE --save-logs` |

## File Locations Reference

| Platform | Deployment Script | Models Location | Client Files | Virtual Environment |
|----------|-------------------|----------------|--------------|-------------------|
| **Intel** | `deployment\intel\scripts\prepare_intel.ps1` | `C:\AIDemo\models\sdxl-base-1.0\` | `C:\AIDemo\client\` | `C:\AIDemo\venv\` |
| **Snapdragon** | `deployment\snapdragon\scripts\prepare_snapdragon.ps1` | `C:\AIDemo\models\` | `C:\AIDemo\client\` | `C:\AIDemo\venv\` |

---

⚠️ **Remember**: Always run diagnostics ON the client machine where deployment occurred. Remote diagnostics will not accurately reflect client performance.