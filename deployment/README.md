# Deployment Folder Organization

This deployment folder has been reorganized based on architecture (Intel vs Snapdragon) for better maintainability and clarity.

## 📁 Folder Structure

```
deployment/
├── intel/                    # Intel Core Ultra specific deployment
│   ├── scripts/             # PowerShell deployment scripts
│   ├── requirements/        # Python dependencies for Intel
│   ├── tests/              # Intel-specific tests
│   ├── docs/               # Intel documentation
│   └── reports/            # Testing reports
│
├── snapdragon/              # Snapdragon X Elite specific deployment
│   ├── scripts/            # PowerShell deployment scripts
│   ├── requirements/       # Python dependencies for Snapdragon
│   └── docs/              # Snapdragon documentation
│
├── common/                  # Shared resources for both architectures
│   ├── scripts/            # Common deployment scripts
│   ├── requirements/       # Core dependencies
│   ├── validation/         # Testing and validation tools
│   └── docs/              # Common documentation
│
├── fixes/                   # Deployment fixes and patches
│   ├── scripts/            # Fix scripts
│   ├── docs/              # Fix documentation
│   └── backup/            # Backup files
│
└── README.md               # This file
```

## 🚀 Quick Start

### For Intel Deployment:
```powershell
cd intel/scripts
.\prepare_intel.ps1
```

### For Snapdragon Deployment:
```powershell
cd snapdragon/scripts
.\prepare_snapdragon.ps1
```

## 📊 Architecture Comparison

| Feature | Intel Core Ultra | Snapdragon X Elite |
|---------|------------------|-------------------|
| **Acceleration** | DirectML (GPU) | QNN (NPU) |
| **Model Type** | FP16 (6.9GB) | INT8 (1.5GB) |
| **Generation Time** | 35-45 seconds | 3-5 seconds |
| **Memory Required** | 16GB+ | 8GB+ |
| **Power Usage** | 25-35W | 12-15W |

## 📚 Key Documentation

- **Intel Guide**: `intel/docs/README_INTEL.md`
- **Snapdragon Note**: `snapdragon/docs/IMPORTANT_ARCHITECTURE_NOTE.md`
- **Comparison**: `common/docs/INTEL_VS_SNAPDRAGON_COMPARISON.md`
- **Poetry Setup**: `common/docs/README_POETRY.md`

## 🛠️ Common Tools

- **Setup Script**: `common/scripts/setup.ps1`
- **Model Preparation**: `common/scripts/prepare_models.ps1`
- **Dependency Installation**: `common/scripts/install_dependencies.ps1`
- **System Diagnosis**: `common/scripts/diagnose.ps1`
- **Validation**: `common/validation/verify.ps1`

## 🔧 Troubleshooting

If you encounter issues, check the `fixes/` folder for:
- Python path fixes
- Poetry configuration fixes
- Module import fixes
- Syntax validation tools

## 📋 Requirements

### Core Requirements (Both Architectures)
- Windows 10 1903+ or Windows 11
- Python 3.9 or 3.10
- PowerShell 5.1+
- 10GB+ free disk space

### Intel-Specific
- DirectX 12 compatible GPU
- Intel Core i5 11th Gen or newer
- 16GB+ RAM

### Snapdragon-Specific
- Snapdragon X Elite processor
- NPU support
- 8GB+ RAM

## 🔄 Migration from Old Structure

If you have scripts referencing the old flat structure, update paths as follows:
- `deployment/prepare_intel.ps1` → `deployment/intel/scripts/prepare_intel.ps1`
- `deployment/prepare_snapdragon.ps1` → `deployment/snapdragon/scripts/prepare_snapdragon.ps1`
- `deployment/requirements-intel.txt` → `deployment/intel/requirements/requirements-intel.txt`
- `deployment/requirements-snapdragon.txt` → `deployment/snapdragon/requirements/requirements-snapdragon.txt`

---

*Last Updated: 2025-08-14*
*Organization Version: 2.0*