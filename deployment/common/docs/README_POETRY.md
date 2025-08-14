# Poetry-Based Dependency Management

This directory now includes Poetry configuration for robust dependency management, solving the pip dependency resolution issues.

## Quick Start

### Option 1: Automatic Setup (Recommended)
```powershell
# Run the Poetry setup script
.\poetry_setup.ps1

# Then run the model preparation
.\prepare_models.ps1
```

### Option 2: Manual Poetry Setup
```powershell
# Install Poetry (if not already installed)
pip install poetry

# Install dependencies
poetry install

# For Snapdragon systems, install NPU extras
poetry install --extras snapdragon

# Run model preparation with Poetry environment
poetry shell
.\prepare_models.ps1
```

## Why Poetry?

### Problems with pip
- **Dependency Conflicts**: ML packages have complex, conflicting requirements
- **Version Resolution**: pip's resolver struggles with the ML ecosystem
- **Reproducibility**: No guaranteed consistent installs across machines
- **Environment Isolation**: Manual virtual environment management

### Poetry Solutions
- **Advanced Dependency Resolution**: SAT solver handles complex conflicts
- **Lock Files**: Guarantees identical installs across all machines  
- **Virtual Environment Management**: Automatic creation and activation
- **Extras System**: Optional dependencies for platform-specific features
- **Source Management**: Custom indexes (PyTorch CPU, etc.)

## Configuration Details

### pyproject.toml Structure
```toml
[tool.poetry.dependencies]
python = "^3.9,<3.11"  # Compatible with DirectML and ONNX
torch = {version = "2.1.2", source = "pytorch-cpu"}
# ... other dependencies with exact versions

[tool.poetry.extras]
snapdragon = ["qai-hub", "onnxruntime-qnn"]  # NPU-specific packages

[[tool.poetry.source]]
name = "pytorch-cpu"
url = "https://download.pytorch.org/whl/cpu"
```

### Dependency Resolution Strategy
1. **Core ML Packages**: Fixed versions for stability
2. **Platform-Specific**: Optional extras for Snapdragon NPU
3. **Fallback Strategy**: pip-tools if Poetry unavailable
4. **Source Priority**: PyTorch CPU index for ARM64 compatibility

## Troubleshooting

### Poetry Installation Issues
```powershell
# If Poetry installation fails, manual fallback
pip install pip-tools
# Script automatically falls back to pip-sync
```

### Dependency Conflicts
```powershell
# Clear Poetry cache
poetry cache clear pypi --all

# Force lock file regeneration
poetry lock --no-update
```

### NPU Package Issues
```powershell
# Check QNN provider availability
poetry run python -c "import onnxruntime; print(onnxruntime.get_available_providers())"

# Install NPU packages manually if needed
poetry add onnxruntime-qnn --optional
```

## Benefits for AI Demo

1. **Consistent Environments**: Same packages on all demo machines
2. **Faster Setup**: Cached dependency resolution
3. **Platform Flexibility**: Automatic handling of Snapdragon vs Intel
4. **Error Reduction**: Eliminates "pip's dependency resolver" errors
5. **Maintainability**: Clear dependency specifications
6. **CI/CD Ready**: Lock file enables reproducible builds

## Integration with Existing Scripts

The `prepare_models.ps1` script now:
1. **Detects Poetry**: Automatically uses if available
2. **Fallback Strategy**: Uses pip-tools if Poetry fails
3. **Environment Awareness**: Runs Python scripts in correct environment
4. **Verification**: Tests all packages in managed environment

This ensures backward compatibility while providing improved dependency management.