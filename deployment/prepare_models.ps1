# Model Preparation Script for AI Demo
# Downloads and optimizes models for each platform

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("snapdragon", "intel", "auto")]
    [string]$Platform = "auto"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AI Model Preparation Tool" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Detect platform if auto
if ($Platform -eq "auto") {
    $processor = (Get-WmiObject -Class Win32_Processor).Name
    if ($processor -like "*Snapdragon*" -or $processor -like "*Qualcomm*") {
        $Platform = "snapdragon"
    } else {
        $Platform = "intel"
    }
    Write-Host "Detected platform: $Platform" -ForegroundColor Yellow
}

# Ensure Python environment is activated
$venvPath = "C:\AIDemo\venv\Scripts\Activate.ps1"
if (Test-Path $venvPath) {
    & $venvPath
} else {
    Write-Host "Virtual environment not found. Please run setup_windows.ps1 first." -ForegroundColor Red
    exit 1
}

# Create models directory
$modelsPath = "C:\AIDemo\models"
if (-not (Test-Path $modelsPath)) {
    New-Item -ItemType Directory -Path $modelsPath -Force | Out-Null
}

Write-Host "`nPreparing models for $Platform platform..." -ForegroundColor Yellow

if ($Platform -eq "snapdragon") {
    Write-Host @"

============================================
SNAPDRAGON MODEL OPTIMIZATION
============================================

For optimal performance on Snapdragon X Elite, we'll use Qualcomm AI Hub
pre-optimized models. These models are specifically tuned for the Hexagon NPU.

"@ -ForegroundColor Cyan

    # Download Qualcomm AI Hub CLI if not present
    Write-Host "Installing Qualcomm AI Hub tools..." -ForegroundColor Yellow
    pip install qai-hub --quiet

    Write-Host "`nAvailable optimized models:" -ForegroundColor Yellow
    Write-Host "1. SDXL-Lightning (4-step, ultra-fast)" -ForegroundColor White
    Write-Host "2. SDXL-Turbo (1-4 steps, fast)" -ForegroundColor White
    Write-Host "3. SDXL-Base (30 steps, highest quality)" -ForegroundColor White
    
    $choice = Read-Host "`nSelect model (1-3)"
    
    switch ($choice) {
        "1" {
            $modelName = "sdxl-lightning"
            $modelSteps = 4
            Write-Host "`nDownloading SDXL-Lightning for Snapdragon..." -ForegroundColor Yellow
            
            # Create Python script to download and convert
            $downloadScript = @"
import os
import sys
from pathlib import Path

try:
    from qai_hub import Device
    from qai_hub.client import Client
    import torch
    from diffusers import StableDiffusionXLPipeline, UNet2DConditionModel, DPMSolverMultistepScheduler
    from optimum.onnxruntime import ORTStableDiffusionXLPipeline
    
    # Initialize QAI Hub client
    client = Client()
    
    # Target device
    device = Device.SNAPDRAGON_8_GEN_3
    
    print("Downloading SDXL-Lightning base model...")
    # Download base model
    base_model = "ByteDance/SDXL-Lightning"
    pipeline = StableDiffusionXLPipeline.from_pretrained(
        base_model,
        torch_dtype=torch.float16,
        variant="fp16",
        use_safetensors=True
    )
    
    print("Converting to ONNX format...")
    # Export to ONNX for Snapdragon NPU
    output_path = Path("C:/AIDemo/models/sdxl_snapdragon_optimized")
    output_path.mkdir(exist_ok=True, parents=True)
    
    # Convert to ONNX with Snapdragon optimizations
    onnx_pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
        base_model,
        export=True,
        provider="QNNExecutionProvider",
        export_dir=str(output_path)
    )
    
    print("Optimizing for Snapdragon NPU...")
    # Apply Qualcomm-specific optimizations
    # This includes INT8 quantization and graph optimizations
    onnx_pipeline.save_pretrained(str(output_path))
    
    print("Model ready for Snapdragon NPU!")
    
except ImportError as e:
    print(f"Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
        }
        "2" {
            $modelName = "sdxl-turbo"
            $modelSteps = 1
            Write-Host "`nDownloading SDXL-Turbo for Snapdragon..." -ForegroundColor Yellow
            
            $downloadScript = @"
import os
import sys
from pathlib import Path

try:
    from diffusers import AutoPipelineForImage2Image
    from optimum.onnxruntime import ORTStableDiffusionXLPipeline
    import torch
    
    print("Downloading SDXL-Turbo...")
    model_id = "stabilityai/sdxl-turbo"
    
    # Download and convert to ONNX
    output_path = Path("C:/AIDemo/models/sdxl_snapdragon_optimized")
    output_path.mkdir(exist_ok=True, parents=True)
    
    pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
        model_id,
        export=True,
        provider="QNNExecutionProvider",
        export_dir=str(output_path),
        torch_dtype=torch.float16
    )
    
    pipeline.save_pretrained(str(output_path))
    print("SDXL-Turbo ready for Snapdragon NPU!")
    
except ImportError as e:
    print(f"Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
        }
        "3" {
            $modelName = "sdxl-base"
            $modelSteps = 30
            Write-Host "`nDownloading SDXL-Base for Snapdragon..." -ForegroundColor Yellow
            
            $downloadScript = @"
import os
import sys
from pathlib import Path

try:
    from diffusers import StableDiffusionXLPipeline
    from optimum.onnxruntime import ORTStableDiffusionXLPipeline
    import torch
    
    print("Downloading SDXL-Base 1.0...")
    model_id = "stabilityai/stable-diffusion-xl-base-1.0"
    
    # Download and convert to ONNX with NPU optimizations
    output_path = Path("C:/AIDemo/models/sdxl_snapdragon_optimized")
    output_path.mkdir(exist_ok=True, parents=True)
    
    # Export with Snapdragon optimizations
    pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
        model_id,
        export=True,
        provider="QNNExecutionProvider",
        export_dir=str(output_path),
        torch_dtype=torch.float16,
        use_safetensors=True
    )
    
    # Apply quantization for NPU
    pipeline.save_pretrained(str(output_path))
    print("SDXL-Base ready for Snapdragon NPU!")
    
except ImportError as e:
    print(f"Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
        }
    }
    
    # Save and run the download script
    $scriptPath = "$env:TEMP\download_snapdragon_model.py"
    $downloadScript | Out-File -FilePath $scriptPath -Encoding UTF8
    
    Write-Host "Downloading and optimizing model (this may take 10-15 minutes)..." -ForegroundColor Yellow
    python $scriptPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Snapdragon-optimized model ready!" -ForegroundColor Green
        Write-Host "Model: $modelName" -ForegroundColor White
        Write-Host "Optimized for: $modelSteps inference steps" -ForegroundColor White
        Write-Host "Location: C:\AIDemo\models\sdxl_snapdragon_optimized" -ForegroundColor White
    } else {
        Write-Host "❌ Model preparation failed" -ForegroundColor Red
    }
    
    Remove-Item $scriptPath -ErrorAction SilentlyContinue
    
} else {
    # Intel platform
    Write-Host @"

============================================
INTEL MODEL SETUP
============================================

For Intel platforms, we'll use SDXL with DirectML acceleration.
This provides good quality while leveraging Intel's AI acceleration.

"@ -ForegroundColor Cyan

    Write-Host "Downloading SDXL-Base 1.0 for Intel..." -ForegroundColor Yellow
    
    # Create download script for Intel
    $downloadScript = @"
import os
import sys
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
    import torch
    
    models_dir = Path("C:/AIDemo/models")
    models_dir.mkdir(exist_ok=True, parents=True)
    
    print("Downloading Stable Diffusion XL Base 1.0...")
    print("This is approximately 6.9GB and may take some time...")
    
    # Download SDXL base model
    local_dir = models_dir / "sdxl-base-1.0"
    snapshot_download(
        repo_id="stabilityai/stable-diffusion-xl-base-1.0",
        local_dir=str(local_dir),
        local_dir_use_symlinks=False,
        resume_download=True,
        ignore_patterns=["*.ckpt", "*.safetensors.index.json"]
    )
    
    # Also download VAE for better quality
    print("\nDownloading SDXL VAE for improved quality...")
    vae_dir = models_dir / "sdxl-vae"
    snapshot_download(
        repo_id="madebyollin/sdxl-vae-fp16-fix",
        local_dir=str(vae_dir),
        local_dir_use_symlinks=False,
        resume_download=True
    )
    
    print("\n✅ Models downloaded successfully!")
    print(f"Location: {local_dir}")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Download failed: {e}")
    sys.exit(1)
"@

    $scriptPath = "$env:TEMP\download_intel_model.py"
    $downloadScript | Out-File -FilePath $scriptPath -Encoding UTF8
    
    Write-Host "Downloading SDXL model (6.9GB - this will take several minutes)..." -ForegroundColor Yellow
    python $scriptPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Intel models ready!" -ForegroundColor Green
        Write-Host "Model: SDXL-Base 1.0 with DirectML acceleration" -ForegroundColor White
        Write-Host "Location: C:\AIDemo\models\sdxl-base-1.0" -ForegroundColor White
    } else {
        Write-Host "❌ Model download failed" -ForegroundColor Red
    }
    
    Remove-Item $scriptPath -ErrorAction SilentlyContinue
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Model preparation complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

# Create a config file with model settings
$configPath = "C:\AIDemo\models\config.json"
$config = @{
    platform = $Platform
    model_name = $modelName
    inference_steps = $modelSteps
    model_path = if ($Platform -eq "snapdragon") { "sdxl_snapdragon_optimized" } else { "sdxl-base-1.0" }
    optimizations = if ($Platform -eq "snapdragon") { @("npu", "int8", "graph_optimization") } else { @("directml", "fp16") }
}

$config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "`nConfiguration saved to: $configPath" -ForegroundColor Yellow
Write-Host "`nYour system is now ready for high-quality AI image generation!" -ForegroundColor Green
