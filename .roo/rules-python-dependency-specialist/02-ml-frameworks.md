# ML/AI Framework Guidelines

## PyTorch Installation
- Check CUDA compatibility matrix first
- Use conda for CUDA-enabled installations when possible
- For DirectML: use torch-directml package
- Always verify with `torch.cuda.is_available()` or `torch_directml.is_available()`

## DirectML Setup (Windows/WSL)
- Requires Windows 10 build 1709+ or Windows 11
- Install latest GPU drivers
- Use specific torch-directml versions for compatibility
- Test with simple tensor operations first

## TensorFlow Considerations
- Match TensorFlow and CUDA versions carefully
- Use tensorflow-gpu for older versions (<2.0)
- Consider using Docker images for complex setups
- Verify with `tf.config.list_physical_devices('GPU')`

## Data Science Stack
- Install NumPy before other scientific packages
- Use conda for complex scientific computing stacks
- Pin NumPy version when using multiple frameworks
- Consider using mamba for faster conda resolves