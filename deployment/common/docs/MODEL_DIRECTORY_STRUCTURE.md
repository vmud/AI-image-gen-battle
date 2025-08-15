# Model Directory Structure for Pre-Downloaded Models

## Expected Source Directory Structure

The deployment script expects pre-downloaded models to be organized in the source directory (`C:\Users\Mosai\ai-demo-working`) as follows:

```
C:\Users\Mosai\ai-demo-working\
├── models\
│   ├── intel\                           # Intel-optimized models
│   │   ├── stable-diffusion-v1-5\       # Standard PyTorch model
│   │   │   ├── model_index.json
│   │   │   ├── scheduler\
│   │   │   ├── text_encoder\
│   │   │   ├── tokenizer\
│   │   │   ├── unet\
│   │   │   └── vae\
│   │   └── directml-optimized\          # DirectML-specific optimizations
│   │       ├── optimized_unet.bin
│   │       └── directml_config.json
│   │
│   ├── snapdragon\                      # Snapdragon/ARM-optimized models
│   │   ├── stable-diffusion-v1-5-onnx\  # ONNX converted model
│   │   │   ├── model_index.json
│   │   │   ├── scheduler\
│   │   │   ├── text_encoder\
│   │   │   │   ├── model.onnx
│   │   │   │   └── config.json
│   │   │   ├── tokenizer\
│   │   │   ├── unet\
│   │   │   │   ├── model.onnx
│   │   │   │   └── config.json
│   │   │   └── vae_decoder\
│   │   │       ├── model.onnx
│   │   │       └── config.json
│   │   └── arm-optimized\               # ARM-specific optimizations
│   │       ├── optimized_providers.json
│   │       └── quantized_models\
│   │
│   ├── onnx\                            # Additional ONNX models/components
│   │   ├── vae_encoder\
│   │   │   ├── model.onnx
│   │   │   └── config.json
│   │   └── safety_checker\
│   │       ├── model.onnx
│   │       └── config.json
│   │
│   └── common\                          # Shared model components
│       ├── tokenizer\
│       │   ├── tokenizer.json
│       │   ├── tokenizer_config.json
│       │   ├── vocab.json
│       │   └── merges.txt
│       ├── scheduler\
│       │   └── scheduler_config.json
│       └── feature_extractor\
│           └── preprocessor_config.json
```

## Production Directory Destinations

### Intel System - Models copied to:
```
C:\AIDemo\models\stable-diffusion\intel-optimized\
├── stable-diffusion-v1-5\       # From models\intel\stable-diffusion-v1-5\
├── directml-optimized\           # From models\intel\directml-optimized\
├── tokenizer\                    # From models\common\tokenizer\
├── scheduler\                    # From models\common\scheduler\
└── feature_extractor\            # From models\common\feature_extractor\
```

### Snapdragon System - Models copied to:
```
C:\AIDemo\models\stable-diffusion\snapdragon-optimized\
├── stable-diffusion-v1-5-onnx\  # From models\snapdragon\stable-diffusion-v1-5-onnx\
├── arm-optimized\                # From models\snapdragon\arm-optimized\
├── vae_encoder\                  # From models\onnx\vae_encoder\
├── safety_checker\               # From models\onnx\safety_checker\
├── tokenizer\                    # From models\common\tokenizer\
├── scheduler\                    # From models\common\scheduler\
└── feature_extractor\            # From models\common\feature_extractor\
```

## Deployment Script Model Copying

The batch script performs the following model copy operations:

### For Intel Systems:
```batch
call :copy_with_progress "%SourceDir%\models\intel" "%TargetDir%\models\stable-diffusion\intel-optimized\" "Intel-optimized models"
call :copy_with_progress "%SourceDir%\models\common" "%TargetDir%\models\stable-diffusion\intel-optimized\" "Common model files"
```

### For Snapdragon Systems:
```batch
call :copy_with_progress "%SourceDir%\models\snapdragon" "%TargetDir%\models\stable-diffusion\snapdragon-optimized\" "Snapdragon-optimized models"
call :copy_with_progress "%SourceDir%\models\onnx" "%TargetDir%\models\stable-diffusion\snapdragon-optimized\" "ONNX model files"
call :copy_with_progress "%SourceDir%\models\common" "%TargetDir%\models\stable-diffusion\snapdragon-optimized\" "Common model files"
```

## Model Types and Formats

### Intel Models:
- **Format**: PyTorch (.bin, .safetensors)
- **Optimization**: DirectML acceleration for Intel integrated graphics
- **Components**: Standard Stable Diffusion pipeline components
- **Special Files**: DirectML-optimized U-Net, configuration files for multi-threading

### Snapdragon Models:
- **Format**: ONNX (.onnx)
- **Optimization**: ARM CPU optimization, quantization
- **Components**: All pipeline components converted to ONNX format
- **Special Files**: ARM-specific execution providers, quantized model variants

### Common Components:
- **Tokenizer**: Text processing components (shared between platforms)
- **Scheduler**: Diffusion scheduler configurations
- **Feature Extractor**: Image preprocessing configurations

## Model Sizes (Approximate)

| Component | Intel (PyTorch) | Snapdragon (ONNX) |
|-----------|-----------------|-------------------|
| Text Encoder | ~500MB | ~250MB (quantized) |
| U-Net | ~3.5GB | ~1.8GB (quantized) |
| VAE Decoder | ~350MB | ~175MB (quantized) |
| VAE Encoder | ~350MB | ~175MB (quantized) |
| Tokenizer | ~2MB | ~2MB |
| **Total** | **~4.7GB** | **~2.4GB** |

## Validation

After deployment, verify models are correctly placed:

### Intel System Check:
```batch
dir "C:\AIDemo\models\stable-diffusion\intel-optimized"
```

### Snapdragon System Check:
```batch
dir "C:\AIDemo\models\stable-diffusion\snapdragon-optimized"
```

## Configuration References

The production configuration files reference these model paths:

### Intel Configuration:
```json
{
    "model_path": "C:\\AIDemo\\models\\stable-diffusion\\intel-optimized",
    "use_directml": true,
    "use_onnx": false
}
```

### Snapdragon Configuration:
```json
{
    "model_path": "C:\\AIDemo\\models\\stable-diffusion\\snapdragon-optimized", 
    "use_onnx": true,
    "onnx_providers": ["CPUExecutionProvider"]
}
```

## Pre-Deployment Setup

Before running the deployment script, ensure:

1. **Models are downloaded** to the expected source directories
2. **Intel models** include DirectML optimizations if available
3. **Snapdragon models** are properly converted to ONNX format
4. **Common components** are present and compatible with both platforms
5. **Directory structure** matches the expected layout above

The deployment script will automatically detect the platform and copy the appropriate model set to the production location.
