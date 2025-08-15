# AI Image Generation Diagnostic Framework - Client User Guide

## Overview

The Enhanced Diagnostic Framework provides **post-deployment troubleshooting** for AI image generation systems on Intel and Snapdragon platforms. This tool helps diagnose issues when the deployment scripts complete successfully but the **final performance tests fail**.

## When to Use This Tool

✅ **Use the diagnostic framework when:**
- [`prepare_intel.ps1`](../../deployment/intel/scripts/prepare_intel.ps1) or [`prepare_snapdragon.ps1`](../../deployment/snapdragon/scripts/prepare_snapdragon.ps1) complete successfully
- **BUT** the final performance test fails or shows poor performance
- You need to validate client machine readiness
- You're troubleshooting AI model execution issues

❌ **Don't use this tool for:**
- Initial system setup (use deployment scripts instead)
- Installing dependencies (deployment scripts handle this)
- Model downloads (deployment scripts handle this)

## Diagnostic Workflow Diagram

```
Client Machine AI Setup Workflow
================================

Step 1: Initial Deployment
┌─────────────────────────────────────────────────────────────┐
│ Run Platform Deployment Script                             │
│ ┌─────────────────────┐  ┌─────────────────────────────────┐ │
│ │ Intel Systems       │  │ Snapdragon Systems              │ │
│ │ prepare_intel.ps1   │  │ prepare_snapdragon.ps1          │ │
│ └─────────────────────┘  └─────────────────────────────────┘ │
│                                                             │
│ Installs: Python 3.10, Dependencies, Models, Config       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
Step 2: Performance Test (Built into Deployment Scripts)
┌─────────────────────────────────────────────────────────────┐
│ Deployment Script Performance Test                         │
│ ┌─────────────────────┐  ┌─────────────────────────────────┐ │
│ │ Intel Target:       │  │ Snapdragon Target:              │ │
│ │ 35-45s per image    │  │ 3-5s per image                  │ │
│ │ DirectML GPU        │  │ Hexagon NPU                     │ │
│ └─────────────────────┘  └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
         ┌─────────────┐              ┌─────────────┐
         │ Test PASSED │              │ Test FAILED │
         │    Done!    │              │     or      │
         └─────────────┘              │ Poor Performance │
                                      └─────────────┘
                                              │
                                              ▼
Step 3: Diagnostic Troubleshooting (Only when needed)
┌─────────────────────────────────────────────────────────────┐
│ cd src/windows-client                                       │
│ python demo_diagnostic.py --quick                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Diagnostic Results Analysis                                 │
│ ┌─────────────────────┐  ┌─────────────────────────────────┐ │
│ │ All Tests PASS      │  │ Some Tests FAIL                 │ │
│ │ Issue Identified    │  │ Need Deeper Analysis            │ │
│ └─────────────────────┘  └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
    ┌─────────────────────┐        ┌─────────────────────┐
    │ Apply Specific Fix  │        │ Detailed Debugging  │
    │ (see Quick Reference│        │ --detailed-report   │
    │  for common fixes)  │        │ --log-level DEBUG   │
    └─────────────────────┘        └─────────────────────┘
                │                           │
                └─────────────┬─────────────┘
                              ▼
Step 4: Validation and Resolution
┌─────────────────────────────────────────────────────────────┐
│ Re-test with python demo_diagnostic.py --quick             │
│                                                             │
│ If still failing: Collect support data                     │
│ python demo_diagnostic.py --detailed-report --save-logs    │
└─────────────────────────────────────────────────────────────┘

Key Principle: Deployment Scripts do the SETUP
               Diagnostic Framework does the TROUBLESHOOTING
```

## Quick Start (Post-Deployment Validation)

### 1. After Deployment Script Completion
```bash
# FIRST: Run the appropriate deployment script
# Intel systems:
deployment/intel/scripts/prepare_intel.ps1

# Snapdragon systems:
deployment/snapdragon/scripts/prepare_snapdragon.ps1

# THEN: Use diagnostics if performance test fails
cd src/windows-client
python demo_diagnostic.py --quick
```

### 2. Troubleshoot Performance Issues
```bash
# Detailed analysis when performance test fails
python demo_diagnostic.py --detailed-report --log-level DEBUG

# Save results for technical support
python demo_diagnostic.py --detailed-report --log-file performance_issue.log
```

## Prerequisites

⚠️ **Important:** Run deployment scripts FIRST. This diagnostic tool requires:
- Deployment script completed successfully  
- Python 3.10 virtual environment created at `C:\AIDemo\venv` (Intel) or `C:\AIDemo\venv` (Snapdragon)
- AI models downloaded to `C:\AIDemo\models\`
- Client files deployed to `C:\AIDemo\client\`

## Command-Line Options for Client Troubleshooting

### Essential Options

#### `--quick` (Post-Deployment Validation)
```bash
python demo_diagnostic.py --quick
```
- **Purpose**: Validate deployment script success
- **Runtime**: 10-30 seconds
- **Use Case**: Quick check after deployment script completes
- **Output**: PASS/FAIL status for each component

#### `--detailed-report` (Performance Troubleshooting)
```bash
python demo_diagnostic.py --detailed-report
```
- **Purpose**: Diagnose why performance tests fail
- **Runtime**: 2-5 minutes
- **Use Case**: When deployment script performance test shows poor results
- **Output**: Comprehensive analysis with performance metrics

#### `--log-level DEBUG` (Deep Troubleshooting)
```bash
python demo_diagnostic.py --detailed-report --log-level DEBUG
```
- **Purpose**: Maximum detail for complex issues
- **Use Case**: When initial diagnosis doesn't reveal the problem
- **Output**: Verbose logging for technical analysis

## Platform-Specific Troubleshooting

### Intel DirectML Validation

#### Expected Deployment Results
After [`prepare_intel.ps1`](../../deployment/intel/scripts/prepare_intel.ps1) completes:
- **Models**: SDXL Base 1.0 FP16 (~6.9GB) in `C:\AIDemo\models\sdxl-base-1.0\`
- **Performance Target**: 35-45 seconds per 768x768 image
- **Acceleration**: DirectML GPU acceleration

#### Common Post-Deployment Issues
```bash
# Validate DirectML after deployment
python demo_diagnostic.py --quick

# Check specific DirectML issues
python demo_diagnostic.py --detailed-report --log-level DEBUG
```

**Issue**: DirectML reports "maintenance mode"
```bash
# Diagnostic approach
python demo_diagnostic.py --log-level DEBUG | findstr DirectML
```
**Resolution**: Usually indicates driver issues or GPU conflicts

**Issue**: Performance much slower than 35-45 seconds
```bash
# Check hardware acceleration status
python demo_diagnostic.py --detailed-report | findstr -i "acceleration"
```
**Resolution**: May be falling back to CPU processing

### Snapdragon NPU Validation

#### Expected Deployment Results  
After [`prepare_snapdragon.ps1`](../../deployment/snapdragon/scripts/prepare_snapdragon.ps1) completes:
- **Models**: SDXL-Lightning and SDXL-Turbo (~400-500MB each) in `C:\AIDemo\models\`
- **Performance Target**: 3-5 seconds per image
- **Acceleration**: Hexagon NPU with QNN provider

#### Common Post-Deployment Issues
```bash
# Validate NPU after deployment
python demo_diagnostic.py --quick

# Check NPU-specific issues
python demo_diagnostic.py --detailed-report --log-level DEBUG
```

**Issue**: NPU not detected or QNN provider unavailable
```bash
# Check provider status
python demo_diagnostic.py --detailed-report | findstr -i "provider"
```
**Resolution**: Verify Windows 11 24H2 and NPU drivers

**Issue**: Performance much slower than 3-5 seconds
```bash
# Check for CPU fallback
python demo_diagnostic.py --log-level DEBUG | findstr -i "fallback"
```
**Resolution**: Likely using CPU instead of NPU

## Troubleshooting Common Client Issues

### Python Environment Issues

#### Wrong Virtual Environment
```
[FAIL] Python Environment: Not using C:\AIDemo\venv
```
**Cause**: Diagnostic running outside deployment environment  
**Solution**: 
```bash
# Activate correct environment first
C:\AIDemo\venv\Scripts\activate.bat
cd C:\AIDemo\client
python ..\windows-client\demo_diagnostic.py --quick
```

#### Python Version Mismatch  
```
[FAIL] Python Environment: Python 3.11 detected, requires Python 3.10
```
**Cause**: Deployment script used wrong Python version  
**Solution**: Re-run deployment script with correct Python 3.10

### Dependency Issues After Deployment

#### Missing Critical Packages
```
[FAIL] AIImagePipeline Import: ModuleNotFoundError: No module named 'torch_directml'
```
**Cause**: Deployment script dependency installation incomplete  
**Solution**: 
```bash
# Check what deployment script installed
C:\AIDemo\venv\Scripts\activate.bat
pip list | findstr torch
```

#### Package Version Conflicts
```
[FAIL] Package Compatibility: torch-directml conflicts with torch version
```
**Cause**: Deployment script installed incompatible versions  
**Solution**: Re-run deployment script with `--Force` parameter

### Hardware Acceleration Failures

#### Intel DirectML Not Working
```
[FAIL] Hardware Acceleration: DirectML device creation failed
```
**Common Causes**:
1. Intel GPU drivers outdated
2. DirectML in maintenance mode  
3. GPU memory insufficient
4. Windows 10 version too old

**Diagnostic Steps**:
```bash
# Check DirectML status
python demo_diagnostic.py --log-level DEBUG | findstr -i directml

# Check GPU detection
python demo_diagnostic.py --detailed-report | findstr -i gpu
```

#### Snapdragon NPU Not Working
```
[FAIL] Hardware Acceleration: QNN provider not available
```
**Common Causes**:
1. Windows 11 version not 24H2+
2. NPU drivers missing
3. QNN execution provider not installed
4. ARM64 package compatibility issues

**Diagnostic Steps**:
```bash
# Check NPU detection
python demo_diagnostic.py --log-level DEBUG | findstr -i npu

# Check QNN provider
python -c "import onnxruntime; print(onnxruntime.get_available_providers())"
```

### Model Access Issues After Deployment

#### Models Not Found
```
[FAIL] Model Accessibility: Models not found at C:\AIDemo\models
```
**Cause**: Deployment script model download failed  
**Solution**: Re-run deployment script without `--SkipModelDownload`

#### Model Loading Failures
```
[FAIL] Model Loading: SDXL pipeline initialization failed
```
**Cause**: Model files corrupted or incomplete  
**Solution**: 
```bash
# Check model file sizes
dir C:\AIDemo\models\sdxl-base-1.0\ /s
# Compare with expected sizes in deployment script comments
```

## Integration with Deployment Scripts

### Recommended Workflow

```bash
# Step 1: Run deployment script
deployment/intel/scripts/prepare_intel.ps1
# OR
deployment/snapdragon/scripts/prepare_snapdragon.ps1

# Step 2: If performance test fails, diagnose
cd src/windows-client
python demo_diagnostic.py --quick

# Step 3: For detailed troubleshooting
python demo_diagnostic.py --detailed-report --log-level DEBUG

# Step 4: Fix issues and re-test
# (Re-run deployment script if needed)

# Step 5: Validate resolution
python demo_diagnostic.py --quick
```

### When Deployment Scripts Succeed but Performance Is Poor

The deployment scripts include these performance expectations:
- **Intel**: 35-45 seconds per 768x768 image via [`Test-IntelPerformance`](../../deployment/intel/scripts/prepare_intel.ps1#L2048)
- **Snapdragon**: 3-5 seconds per image via [`Test-Performance`](../../deployment/snapdragon/scripts/prepare_snapdragon.ps1#L814) and [`Invoke-QuickBenchmark`](../../deployment/snapdragon/scripts/prepare_snapdragon.ps1#L938)

If these built-in tests show poor performance:

```bash
# Use diagnostics to identify the cause
python demo_diagnostic.py --detailed-report | findstr -i "performance\|acceleration\|time"
```

## Key Differences from Deployment Scripts

| Deployment Scripts | Diagnostic Framework |
|-------------------|---------------------|
| **Install** dependencies | **Validate** dependencies |
| **Download** models | **Check** model accessibility |
| **Configure** acceleration | **Test** acceleration functionality |
| **Set up** environment | **Troubleshoot** environment issues |
| **Create** virtual environment | **Use existing** virtual environment |

## Quick Reference Commands

### After Intel Deployment
```bash
# Quick validation
python demo_diagnostic.py --quick

# If DirectML issues found
python demo_diagnostic.py --detailed-report --log-level DEBUG | findstr -i directml

# Performance analysis
python demo_diagnostic.py --detailed-report | findstr -i "generation time\|performance"
```

### After Snapdragon Deployment  
```bash
# Quick validation
python demo_diagnostic.py --quick

# If NPU issues found
python demo_diagnostic.py --detailed-report --log-level DEBUG | findstr -i "npu\|qnn"

# Performance analysis  
python demo_diagnostic.py --detailed-report | findstr -i "generation time\|acceleration"
```

### Save Diagnostics for Support
```bash
# Generate comprehensive report
python demo_diagnostic.py --detailed-report --log-file support_diagnostics.log --save-logs

# Include system information
python demo_diagnostic.py --detailed-report --log-level VERBOSE --save-logs
```

## Important Notes

⚠️ **Client Machine Requirement**: The diagnostic framework must run **ON** the client machine where the deployment script was executed. Running diagnostics remotely will not accurately reflect client machine performance.

⚠️ **Post-Deployment Only**: This tool assumes the deployment scripts have completed successfully. It's designed for troubleshooting, not initial setup.

⚠️ **Platform-Specific**: Use Intel-specific commands for Intel systems and Snapdragon-specific commands for Snapdragon systems. The diagnostic framework auto-detects platform but provides platform-specific guidance.

## Next Steps

1. Always run deployment scripts first
2. Use diagnostics only when performance tests fail
3. Follow platform-specific troubleshooting guides
4. Re-run deployment scripts after resolving issues
5. Validate resolution with final diagnostic check

For additional reference, see:
- [DIAGNOSTIC_QUICK_REFERENCE.md](DIAGNOSTIC_QUICK_REFERENCE.md) - Essential commands and error codes
- [Intel Deployment Script](../../deployment/intel/scripts/prepare_intel.ps1) - Primary setup for Intel systems
- [Snapdragon Deployment Script](../../deployment/snapdragon/scripts/prepare_snapdragon.ps1) - Primary setup for Snapdragon systems