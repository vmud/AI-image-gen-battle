# Platform-Specific Rules

## Windows
- Use Miniconda/Anaconda for scientific packages
- Handle path length limitations (enable long paths)
- Install Visual C++ Build Tools for compiled packages
- Use torch-directml for non-NVIDIA GPUs

## Linux
- Prefer system package manager for system libraries
- Use --user flag for pip in system Python
- Handle libstdc++ version requirements
- Consider using pyenv for Python version management

## macOS (Apple Silicon)
- Check for ARM64 compatibility
- Use conda-forge channel for M1/M2 support
- Some packages may need Rosetta 2
- Verify Metal Performance Shaders availability

## Docker/Containers
- Use official Python images as base
- Implement multi-stage builds
- Cache pip downloads in CI/CD
- Document all system dependencies