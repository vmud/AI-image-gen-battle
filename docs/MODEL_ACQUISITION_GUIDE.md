# Model Acquisition Guide

This guide provides detailed instructions for obtaining and preparing AI models for both Snapdragon and Intel platforms.

## Quick Start

Run the automated model preparation script:
```powershell
# Automatically detects platform and downloads appropriate models
.\deployment\prepare_models.ps1
```

## Snapdragon Models (Qualcomm AI Hub)

### Option 1: Qualcomm AI Hub (Recommended)

**Prerequisites:**
- Qualcomm AI Hub account (free)
- Python 3.9 with pip
- 10-15 GB free disk space

**Steps:**

1. **Create Qualcomm AI Hub Account**
   - Visit: https://aihub.qualcomm.com/
   - Sign up for free developer account
   - Verify email and complete registration

2. **Install QAI Hub Tools**
   ```bash
   pip install qai-hub
   qai-hub configure  # Enter your API credentials
   ```

3. **Browse Available Models**
   - Go to: https://aihub.qualcomm.com/models
   - Search for "Stable Diffusion XL"
   - Available optimized models:
     - `stable-diffusion-xl-lightning-quantized`
     - `stable-diffusion-xl-turbo-quantized`
     - `stable-diffusion-xl-base-quantized`

4. **Download via CLI**
   ```bash
   # Download SDXL-Lightning (fastest, 4-step)
   qai-hub models download stable-diffusion-xl-lightning-quantized \
     --target-device "Snapdragon 8 Gen 3" \
     --output-dir "C:\AIDemo\models\sdxl_snapdragon_optimized"
   ```

5. **Model Details**
   - **Size**: ~1.5 GB (INT8 quantized)
   - **Format**: ONNX with QNN optimizations
   - **Performance**: 3-5 seconds @ 768x768

### Option 2: AIMET Optimization Tool

For custom model optimization:

1. **Install AIMET**
   ```bash
   pip install aimet-torch
   ```

2. **Download Base Model**
   ```python
   from diffusers import StableDiffusionXLPipeline
   
   pipeline = StableDiffusionXLPipeline.from_pretrained(
       "stabilityai/stable-diffusion-xl-base-1.0",
       torch_dtype=torch.float16
   )
   pipeline.save_pretrained("./sdxl-base")
   ```

3. **Apply Quantization**
   ```python
   from aimet_torch.quantsim import QuantizationSimModel
   
   # Quantize for Snapdragon NPU
   quant_sim = QuantizationSimModel(
       model=pipeline.unet,
       quant_scheme='tf_enhanced',
       default_param_bw=8,  # INT8
       default_output_bw=8
   )
   ```

4. **Export to ONNX**
   ```python
   torch.onnx.export(
       quant_sim.model,
       dummy_input,
       "unet_quantized.onnx",
       opset_version=17,
       do_constant_folding=True
   )
   ```

### Option 3: Pre-converted Models

**Community Resources:**
- Hugging Face Snapdragon Collection: https://huggingface.co/collections/Qualcomm/snapdragon-models
- Direct downloads (no account required):

```powershell
# Download pre-converted SDXL-Lightning for Snapdragon
Invoke-WebRequest -Uri "https://huggingface.co/Qualcomm/sdxl-lightning-snapdragon/resolve/main/model.onnx" `
  -OutFile "C:\AIDemo\models\sdxl_snapdragon_optimized\unet\model.onnx"

# Download configuration files
Invoke-WebRequest -Uri "https://huggingface.co/Qualcomm/sdxl-lightning-snapdragon/resolve/main/config.json" `
  -OutFile "C:\AIDemo\models\sdxl_snapdragon_optimized\config.json"
```

## Intel Models (Standard SDXL)

### Option 1: Hugging Face Direct Download (Recommended)

**Using Python:**
```python
from huggingface_hub import snapshot_download

# Download SDXL Base 1.0
snapshot_download(
    repo_id="stabilityai/stable-diffusion-xl-base-1.0",
    local_dir="C:\\AIDemo\\models\\sdxl-base-1.0",
    local_dir_use_symlinks=False,
    resume_download=True,
    ignore_patterns=["*.ckpt"]  # Skip checkpoint files
)

# Download optimized VAE (optional, better quality)
snapshot_download(
    repo_id="madebyollin/sdxl-vae-fp16-fix",
    local_dir="C:\\AIDemo\\models\\sdxl-vae",
    local_dir_use_symlinks=False
)
```

**Using Git LFS:**
```bash
# Install Git LFS if not already installed
git lfs install

# Clone SDXL repository
git clone https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 \
  C:\AIDemo\models\sdxl-base-1.0
```

### Option 2: Direct Web Download

1. Visit: https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0
2. Click "Files and versions" tab
3. Download required files:
   - `unet/diffusion_pytorch_model.fp16.safetensors` (5.14 GB)
   - `vae/diffusion_pytorch_model.fp16.safetensors` (335 MB)
   - `text_encoder/model.safetensors` (246 MB)
   - `text_encoder_2/model.safetensors` (1.39 GB)
   - All JSON configuration files

### Option 3: Optimized Variants

**SDXL-Turbo (Faster, 1-4 steps):**
```python
snapshot_download(
    repo_id="stabilityai/sdxl-turbo",
    local_dir="C:\\AIDemo\\models\\sdxl-turbo"
)
```

**SDXL-Lightning (Fast, 4 steps):**
```python
snapshot_download(
    repo_id="ByteDance/SDXL-Lightning",
    local_dir="C:\\AIDemo\\models\\sdxl-lightning"
)
```

## Model Specifications

### Snapdragon Optimized Models

| Model | Size | Format | Steps | Speed | Quality |
|-------|------|--------|-------|-------|---------|
| SDXL-Lightning-Q8 | 1.5 GB | ONNX INT8 | 4 | 3-5s | High |
| SDXL-Turbo-Q8 | 1.5 GB | ONNX INT8 | 1-4 | 2-4s | Good |
| SDXL-Base-Q8 | 1.5 GB | ONNX INT8 | 30 | 15-20s | Excellent |

### Intel Standard Models

| Model | Size | Format | Steps | Speed | Quality |
|-------|------|--------|-------|-------|---------|
| SDXL-Base-1.0 | 6.9 GB | SafeTensors FP16 | 25 | 35-45s | Excellent |
| SDXL-Turbo | 6.9 GB | SafeTensors FP16 | 4 | 10-15s | Good |
| SDXL-Lightning | 6.9 GB | SafeTensors FP16 | 4 | 12-18s | High |

## Storage Requirements

### Minimum Requirements
- **Snapdragon**: 2 GB (single INT8 model)
- **Intel**: 7 GB (single FP16 model)

### Recommended Setup
- **Snapdragon**: 5 GB (multiple model variants)
- **Intel**: 15 GB (base + variants + VAE)

## Model Verification

### Verify Download Integrity

**Check file sizes:**
```powershell
Get-ChildItem -Path "C:\AIDemo\models" -Recurse | 
  Where-Object {$_.Extension -in ".onnx", ".safetensors"} | 
  Select-Object Name, @{N="Size(MB)";E={[math]::Round($_.Length/1MB, 2)}}
```

**Verify model loading:**
```python
# Test Snapdragon model
from optimum.onnxruntime import ORTStableDiffusionXLPipeline
pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
    "C:/AIDemo/models/sdxl_snapdragon_optimized"
)
print("✓ Snapdragon model loaded successfully")

# Test Intel model
from diffusers import StableDiffusionXLPipeline
pipeline = StableDiffusionXLPipeline.from_pretrained(
    "C:/AIDemo/models/sdxl-base-1.0"
)
print("✓ Intel model loaded successfully")
```

## Licensing and Usage Rights

### Open Source Models
- **SDXL-Base**: Apache 2.0 License (commercial use allowed)
- **SDXL-Turbo**: Non-commercial research only
- **SDXL-Lightning**: Apache 2.0 License

### Qualcomm AI Hub Models
- Free for development and testing
- Production use requires agreement
- NPU optimizations are Qualcomm proprietary

## Troubleshooting

### Download Issues

**"Connection timeout":**
- Use VPN if in restricted region
- Try alternative CDN: `export HF_ENDPOINT=https://hf-mirror.com`

**"Insufficient space":**
- Clear Windows temp files: `cleanmgr`
- Use external drive for models
- Download directly to target location

**"Access denied":**
- Some models require Hugging Face login:
```bash
huggingface-cli login
# Enter your access token
```

### Model Loading Errors

**"Model not found":**
- Verify all required files downloaded
- Check `model_index.json` exists
- Ensure correct directory structure

**"Unsupported format":**
- Snapdragon: Requires ONNX format
- Intel: Requires PyTorch SafeTensors
- Don't mix model formats

**"Out of memory":**
- Use FP16 models instead of FP32
- Enable CPU offloading
- Reduce batch size to 1

## Performance Tips

### For Snapdragon
1. Use INT8 quantized models only
2. Ensure QNN runtime is installed
3. Keep models on fast SSD
4. Disable Windows Defender scanning for model directory

### For Intel
1. Use FP16 variants when available
2. Ensure DirectML is properly installed
3. Close unnecessary applications
4. Set Windows to High Performance mode

## Additional Resources

- Qualcomm AI Hub Documentation: https://docs.aihub.qualcomm.com/
- Hugging Face Model Hub: https://huggingface.co/models
- ONNX Model Zoo: https://github.com/onnx/models
- DirectML Samples: https://github.com/microsoft/DirectML
- Stable Diffusion Wiki: https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki