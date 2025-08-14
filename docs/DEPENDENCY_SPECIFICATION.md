# Comprehensive Python Package Dependency Specification

## Executive Summary

This document provides a complete dependency specification resolving all identified gaps between the current [`pyproject.toml`](../deployment/pyproject.toml) and actual code requirements. The specification addresses platform-specific AI pipeline architectures for Snapdragon (ONNX+QNN+NPU) and Intel (DirectML+PyTorch+GPU) platforms.

## Critical Dependency Gaps Identified

### Missing Core Dependencies
- **`numpy>=1.21.0`** - Required by [`ai_pipeline.py`](../src/windows-client/ai_pipeline.py:12)
- **`pillow>=8.0.0`** - Required by [`ai_pipeline.py`](../src/windows-client/ai_pipeline.py:13) and [`demo_client.py`](../src/windows-client/demo_client.py:24)
- **`requests>=2.25.0`** - Required by [`demo_control.py`](../src/control-hub/demo_control.py:86)
- **`flask`** - Required by [`demo_client.py`](../src/windows-client/demo_client.py:20)
- **`flask-socketio`** - Required by [`demo_client.py`](../src/windows-client/demo_client.py:21)
- **`psutil`** - Required by [`demo_client.py`](../src/windows-client/demo_client.py:25)

### Missing Platform-Specific Dependencies
- **Snapdragon**: `torch-directml` incorrectly included (ARM64 incompatible)
- **Intel**: `torch-directml`, `onnxruntime-directml` not specified in pyproject.toml

## Core Dependency Specification

### Base Requirements (All Platforms)
```toml
python = "^3.9,<3.11"  # DirectML compatibility constraint

# Core Python packages
numpy = ">=1.21.0,<2.0.0"
pillow = ">=8.0.0,<11.0.0"
requests = ">=2.25.0,<3.0.0"
psutil = ">=5.8.0"

# Web framework
flask = ">=2.0.0,<3.0.0"
flask-socketio = ">=5.0.0,<6.0.0"

# Core ML Framework (CPU-compatible base)
torch = "2.1.2"
torchvision = "0.16.2"

# HuggingFace Ecosystem (verified compatible versions)
huggingface_hub = "0.24.6"
transformers = "4.36.2"
diffusers = "0.25.1"
accelerate = "0.25.0"
safetensors = "0.4.1"

# Base ONNX Runtime
onnxruntime = ">=1.16.0,<1.17.0"
optimum = {version = "1.16.2", extras = ["onnxruntime"]}
```

## Platform-Specific Dependency Matrices

### Snapdragon X Elite (ARM64) - NPU Pipeline

**AI Acceleration Strategy**: ONNX Runtime + QNN Backend + NPU
**Model Type**: INT8 quantized (~1.5GB)
**Performance Target**: 3-5 seconds for 768x768 images

```toml
[tool.poetry.extras]
snapdragon = [
    "onnxruntime-qnn",
    "qai-hub", 
    "winml"
]

# Platform-specific packages
onnxruntime-qnn = {version = "*", optional = true, markers = "platform_machine == 'ARM64'"}
qai-hub = {version = "*", optional = true, markers = "platform_machine == 'ARM64'"}
winml = {version = ">=1.0.0", optional = true, markers = "sys_platform == 'win32' and platform_machine == 'ARM64'"}
```

**Key Dependencies:**
- **Primary**: `onnxruntime` (1.16.0+) + `optimum[onnxruntime]`
- **NPU Acceleration**: `onnxruntime-qnn` (Qualcomm Neural Network backend)
- **Model Optimization**: `qai-hub` (Qualcomm AI Hub tools)
- **Windows ML**: `winml` (Windows Machine Learning)
- **Fallback**: CPU-only ONNX Runtime

### Intel Core Ultra (x86_64) - DirectML Pipeline

**AI Acceleration Strategy**: PyTorch + DirectML + GPU/iGPU
**Model Type**: FP16 precision (~6.9GB)
**Performance Target**: 35-45 seconds for 768x768 images

```toml
[tool.poetry.extras]
intel = [
    "torch-directml",
    "onnxruntime-directml",
    "intel-extension-for-pytorch"
]

# Platform-specific packages
torch-directml = {version = ">=1.12.0", optional = true, markers = "sys_platform == 'win32' and platform_machine == 'AMD64'"}
onnxruntime-directml = {version = ">=1.16.0", optional = true, markers = "sys_platform == 'win32' and platform_machine == 'AMD64'"}
intel-extension-for-pytorch = {version = ">=2.0.0", optional = true, markers = "platform_machine == 'AMD64'"}
```

**Key Dependencies:**
- **Primary**: `torch` (2.1.2) + `diffusers` + `torch-directml`
- **GPU Acceleration**: `torch-directml` (>=1.12.0)
- **ONNX Support**: `onnxruntime-directml` (>=1.16.0)
- **Intel Optimizations**: `intel-extension-for-pytorch`
- **Fallback**: CPU-only PyTorch

## Fallback Strategies

### 3-Tier Fallback Architecture

1. **Platform-Specific Acceleration** (Primary)
   - Snapdragon: NPU via QNN backend
   - Intel: GPU via DirectML

2. **CPU Acceleration** (Secondary)
   - Both platforms: Optimized CPU inference
   - Uses base `torch` + `onnxruntime`

3. **Minimal Fallback** (Emergency)
   - Basic CPU-only operation
   - Reduced quality/resolution settings

### Graceful Degradation Matrix

| Platform | Primary | Secondary | Emergency |
|----------|---------|-----------|-----------|
| **Snapdragon** | NPU (QNN) | CPU (ONNX) | CPU (Basic) |
| **Intel** | GPU (DirectML) | CPU (PyTorch) | CPU (Basic) |
| **Generic** | N/A | CPU (PyTorch) | CPU (Basic) |

## Updated pyproject.toml Structure

```toml
[tool.poetry]
name = "ai-demo-snapdragon"
version = "1.0.0"
description = "AI Image Generation Demo - Snapdragon vs Intel Performance Comparison"
authors = ["AI Demo Team <demo@example.com>"]

[tool.poetry.dependencies]
python = "^3.9,<3.11"

# === CORE DEPENDENCIES (MISSING FROM CURRENT) ===
numpy = ">=1.21.0,<2.0.0"
pillow = ">=8.0.0,<11.0.0"
requests = ">=2.25.0,<3.0.0"
psutil = ">=5.8.0"

# === WEB FRAMEWORK (MISSING FROM CURRENT) ===
flask = ">=2.0.0,<3.0.0"
flask-socketio = ">=5.0.0,<6.0.0"

# === ML FRAMEWORK (CPU-COMPATIBLE BASE) ===
torch = {version = "2.1.2", source = "pytorch-cpu"}
torchvision = {version = "0.16.2", source = "pytorch-cpu"}

# === HUGGINGFACE ECOSYSTEM (EXISTING - VALIDATED) ===
huggingface_hub = "0.24.6"
transformers = "4.36.2"
diffusers = "0.25.1"
accelerate = "0.25.0"
safetensors = "0.4.1"

# === ONNX RUNTIME (BASE FOR BOTH PLATFORMS) ===
onnxruntime = ">=1.16.0,<1.17.0"
optimum = {version = "1.16.2", extras = ["onnxruntime"]}

# === PLATFORM-SPECIFIC (OPTIONAL) ===
# Snapdragon NPU packages
onnxruntime-qnn = {version = "*", optional = true}
qai-hub = {version = "*", optional = true}
winml = {version = ">=1.0.0", optional = true}

# Intel DirectML packages  
torch-directml = {version = ">=1.12.0", optional = true}
onnxruntime-directml = {version = ">=1.16.0", optional = true}
intel-extension-for-pytorch = {version = ">=2.0.0", optional = true}

[tool.poetry.extras]
# Platform-specific extras
snapdragon = ["onnxruntime-qnn", "qai-hub", "winml"]
intel = ["torch-directml", "onnxruntime-directml", "intel-extension-for-pytorch"]
full = ["onnxruntime-qnn", "qai-hub", "winml", "torch-directml", "onnxruntime-directml", "intel-extension-for-pytorch"]

[tool.poetry.group.dev.dependencies]
pytest = "^7.0.0"
black = "^23.0.0"
isort = "^5.0.0"
pip-tools = "^7.0.0"  # For requirements.txt generation

[[tool.poetry.source]]
name = "pytorch-cpu"
url = "https://download.pytorch.org/whl/cpu"
priority = "supplemental"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

## Version Compatibility Matrix

### Python Version Constraints
- **Minimum**: Python 3.9 (ARM64 ML package support)
- **Maximum**: Python <3.11 (DirectML compatibility limit)
- **Recommended**: Python 3.9 or 3.10

### Hardware Compatibility Requirements

#### Snapdragon X Elite
- **OS**: Windows 11 ARM64
- **NPU**: Hexagon NPU (built-in)
- **Memory**: 16GB+ recommended for models
- **Storage**: 3GB (1.5GB models + dependencies)

#### Intel Core Ultra
- **OS**: Windows 10 1903+ or Windows 11
- **GPU**: DirectX 12 compatible iGPU/dGPU
- **Memory**: 16GB+ recommended
- **Storage**: 8GB (6.9GB models + dependencies)

### Critical Version Dependencies

| Package | Snapdragon | Intel | Reason |
|---------|------------|-------|---------|
| `python` | 3.9-3.10 | 3.9-3.10 | DirectML compatibility |
| `torch` | 2.1.2 | 2.1.2 | Stable diffusion compatibility |
| `torch-directml` | N/A | >=1.12.0 | DirectML acceleration |
| `onnxruntime` | >=1.16.0 | >=1.16.0 | QNN/DirectML support |
| `diffusers` | 0.25.1 | 0.25.1 | SDXL pipeline compatibility |

## Platform-Specific Installation Recommendations

### Snapdragon Installation Sequence
```bash
# 1. Install core dependencies
poetry install

# 2. Install Snapdragon-specific packages
poetry install --extras snapdragon

# 3. Verify NPU availability
python -c "import onnxruntime as ort; print('QNN available:', 'QNNExecutionProvider' in ort.get_available_providers())"

# 4. Download optimized models
python deployment/prepare_models.ps1  # Downloads INT8 models
```

### Intel Installation Sequence  
```bash
# 1. Install core dependencies
poetry install

# 2. Install Intel-specific packages
poetry install --extras intel

# 3. Verify DirectML availability
python -c "import torch_directml; print('DirectML available:', torch_directml.is_available())"

# 4. Download standard models
python deployment/prepare_models.ps1  # Downloads FP16 models
```

### Fallback Installation (Both Platforms)
```bash
# 1. Install only core dependencies (no platform extras)
poetry install

# 2. Verify CPU-only operation
python -c "import torch; import onnxruntime; print('CPU fallback ready')"
```

## Dependency Management Improvements

### Current Issues with Deployment Scripts

1. **Inconsistent Dependency Sources**
   - [`pyproject.toml`](../deployment/pyproject.toml) vs [`install_dependencies.ps1`](../deployment/install_dependencies.ps1) have different packages
   - Three-tier fallback (Poetry → pip-tools → pip) creates confusion

2. **Platform Detection Timing**
   - Dependencies should be resolved at install time, not runtime
   - Current approach installs wrong packages then fails

### Recommended Improvements

1. **Unified Dependency Source**
   ```bash
   # Use pyproject.toml as single source of truth
   poetry install --extras $(detect_platform)
   ```

2. **Pre-Install Platform Detection**
   ```bash
   # Detect platform before dependency resolution
   platform=$(python -c "from platform_detection import PlatformDetector; print(PlatformDetector().detect_hardware()['platform_type'])")
   poetry install --extras $platform
   ```

3. **Graceful Degradation**
   ```bash
   # Try platform-specific first, fallback to core
   poetry install --extras snapdragon || poetry install --extras intel || poetry install
   ```

## Model Requirements by Platform

### Snapdragon Models (Qualcomm AI Hub Optimized)
- **SDXL-Lightning**: 4-step INT8 (~400MB)
- **SDXL-Turbo**: 1-4 step INT8 (~500MB)  
- **SDXL-Base**: 30-step INT8 (~600MB)
- **Total**: ~1.5GB

### Intel Models (Hugging Face Standard)
- **SDXL-Base-1.0**: FP16 precision (~6.9GB)
- **VAE Improvements**: Optional quality enhancement (~200MB)
- **Total**: ~7.1GB

## Installation Verification Commands

### Core Dependencies Check
```python
# Verify all core packages are available
import numpy, PIL, requests, psutil, flask, torch, diffusers, transformers
print("Core dependencies: OK")
```

### Platform-Specific Verification
```python
# Snapdragon verification
try:
    import onnxruntime as ort
    providers = ort.get_available_providers()
    npu_available = 'QNNExecutionProvider' in providers
    print(f"Snapdragon NPU: {'Available' if npu_available else 'CPU fallback'}")
except ImportError:
    print("Snapdragon packages: Not installed")

# Intel verification  
try:
    import torch_directml
    directml_available = torch_directml.is_available()
    print(f"Intel DirectML: {'Available' if directml_available else 'CPU fallback'}")
except ImportError:
    print("Intel packages: Not installed")
```

## Next Steps

1. **Update pyproject.toml** with complete specification
2. **Modify deployment scripts** to use unified dependency source
3. **Test installation** on both target platforms
4. **Validate performance** meets target specifications
5. **Document troubleshooting** for common installation issues

This specification resolves all identified dependency gaps and provides a robust foundation for platform-specific AI acceleration while maintaining graceful fallback capabilities.