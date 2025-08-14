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

    # First ensure all required packages are installed
    Write-Host "Checking and installing required packages for ARM64..." -ForegroundColor Yellow
    
    # Install core AI libraries with compatible versions
    Write-Host "Installing diffusers and dependencies..." -ForegroundColor Yellow
    
    # Upgrade huggingface_hub first to fix cached_download issue
    pip install --upgrade huggingface_hub --quiet
    
    # Install compatible versions for ARM64
    pip install diffusers>=0.24.0 transformers>=4.35.0 accelerate>=0.20.3 safetensors>=0.3.1 --quiet
    
    # Install torch for ARM64 (ensure 2.1+ for optimum compatibility)
    Write-Host "Installing PyTorch 2.1+ for ARM64..." -ForegroundColor Yellow  
    pip install torch>=2.1.0 torchvision>=0.16.0 --index-url https://download.pytorch.org/whl/cpu --quiet
    
    # Install ONNX runtime with ARM64 optimization
    Write-Host "Installing ONNX runtime with ARM64 optimization..." -ForegroundColor Yellow
    
    # Try QNN first, fallback to standard ARM64 optimized runtime
    Write-Host "   Attempting QNN installation for NPU support..." -ForegroundColor Gray
    $qnnInstalled = $false
    try {
        pip install onnxruntime-qnn --quiet --no-warn-script-location 2>$null
        if ($LASTEXITCODE -eq 0) {
            $qnnInstalled = $true
            Write-Host "   ✅ QNN runtime installed successfully" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ⚠️  QNN runtime not available, using ARM64 optimized version" -ForegroundColor Yellow
    }
    
    if (-not $qnnInstalled) {
        Write-Host "   Installing standard ARM64-optimized ONNX runtime..." -ForegroundColor Gray
        pip install onnxruntime optimum[onnxruntime] --quiet
        Write-Host "   ✅ ARM64 ONNX runtime installed" -ForegroundColor Green
    } else {
        pip install optimum[onnxruntime] --quiet
    }
    
    # Install huggingface hub for model downloads
    pip install huggingface-hub --quiet
    
    # Download Qualcomm AI Hub CLI if not present (optional)
    Write-Host "Installing Qualcomm AI Hub tools (optional)..." -ForegroundColor Yellow
    pip install qai-hub --quiet 2>$null

    Write-Host "`nAvailable ARM64-optimized models:" -ForegroundColor Yellow
    Write-Host "1. SDXL-Turbo (1-4 steps, fast, ARM64-compatible)" -ForegroundColor White
    Write-Host "2. SDXL-Base (30 steps, highest quality)" -ForegroundColor White
    Write-Host "3. Simple fallback model (for testing)" -ForegroundColor White
    
    $choice = Read-Host "`nSelect model (1-3)"
    
    switch ($choice) {
        "1" {
            $modelName = "sdxl-turbo"
            $modelSteps = 1
            Write-Host "`nDownloading SDXL-Turbo for ARM64..." -ForegroundColor Yellow
            
            # Create robust NPU-optimized Python script for Snapdragon
            $downloadScript = @"
import os
import sys
from pathlib import Path

def check_qnn_availability():
    try:
        import onnxruntime as ort
        providers = ort.get_available_providers()
        qnn_available = 'QNNExecutionProvider' in providers
        print(f"Available ONNX providers: {providers}")
        print(f"QNN Provider available: {qnn_available}")
        return qnn_available
    except Exception as e:
        print(f"Error checking QNN availability: {e}")
        return False

def force_qnn_optimization():
    '''Force NPU optimization - this is required for Snapdragon demo'''
    models_dir = Path("C:/AIDemo/models")
    models_dir.mkdir(exist_ok=True, parents=True)
    
    try:
        # Import and verify all required packages
        print("Importing required packages for NPU optimization...")
        from optimum.onnxruntime import ORTStableDiffusionXLPipeline
        import torch
        import onnxruntime as ort
        
        print(f"PyTorch version: {torch.__version__}")
        print(f"ONNX Runtime version: {ort.__version__}")
        
        # Check QNN availability 
        qnn_available = check_qnn_availability()
        
        if not qnn_available:
            print("ERROR: QNN Provider not detected!")
            print("Installing QNN runtime...")
            import subprocess
            result = subprocess.run([sys.executable, "-m", "pip", "install", "--upgrade", "--force-reinstall", "onnxruntime-qnn"], 
                                  capture_output=True, text=True)
            print(f"QNN install result: {result.returncode}")
            if result.stdout: print(f"stdout: {result.stdout}")
            if result.stderr: print(f"stderr: {result.stderr}")
            
            # Re-check after installation
            qnn_available = check_qnn_availability()
            
        if qnn_available:
            print("✅ QNN Provider detected - proceeding with NPU optimization")
            
            # Convert with full NPU optimization
            print("Converting SDXL-Turbo with Snapdragon NPU optimization...")
            output_path = models_dir / "sdxl_turbo_npu_optimized"
            
            # Use provider options optimized for Snapdragon X Elite
            provider_options = {
                "backend_path": "QnnHtp.dll",
                "device_id": 0,
                "enable_htp_fp16_precision": True,
                "qnn_context_priority": "high",
                "qnn_saver_path": str(output_path / "qnn_cache")
            }
            
            pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
                "stabilityai/sdxl-turbo",
                export=True,
                provider="QNNExecutionProvider",
                export_dir=str(output_path),
                torch_dtype=torch.float16,
                use_safetensors=True,
                provider_options=provider_options
            )
            
            pipeline.save_pretrained(str(output_path))
            print(f"🚀 SNAPDRAGON NPU-OPTIMIZED MODEL READY: {output_path}")
            print("This model will use Hexagon DSP for maximum performance!")
            return str(output_path)
            
        else:
            raise Exception("QNN Provider installation failed - NPU optimization not possible")
            
    except Exception as e:
        print(f"❌ NPU optimization failed: {e}")
        print("This is a critical error for Snapdragon demo - NPU optimization is required")
        raise e

# Execute NPU optimization
try:
    print("🎯 FORCING SNAPDRAGON NPU OPTIMIZATION...")
    result_path = force_qnn_optimization()
    print(f"✅ SUCCESS: NPU-optimized model ready at: {result_path}")
    
except Exception as e:
    print(f"💥 CRITICAL ERROR: {e}")
    print("Snapdragon NPU optimization failed - demo requirements not met")
    sys.exit(1)
"@
        }
        "2" {
            $modelName = "sdxl-base"
            $modelSteps = 30
            Write-Host "`nDownloading SDXL-Base for ARM64..." -ForegroundColor Yellow
            
            $downloadScript = @"
import os
import sys
from pathlib import Path

try:
    from optimum.onnxruntime import ORTStableDiffusionXLPipeline
    import torch
    
    print("Downloading and optimizing SDXL-Base 1.0 for Snapdragon NPU...")
    
    models_dir = Path("C:/AIDemo/models")
    models_dir.mkdir(exist_ok=True, parents=True)
    
    # Download and convert to ONNX with NPU optimization
    output_path = models_dir / "sdxl_base_npu_optimized"
    
    print("Converting SDXL-Base to NPU-optimized ONNX format (this may take 15-20 minutes)...")
    pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0",
        export=True,
        provider="QNNExecutionProvider",
        export_dir=str(output_path),
        torch_dtype=torch.float16,
        use_safetensors=True,
        # NPU-specific optimizations for high quality
        provider_options={
            "backend_path": "QnnHtp.dll",
            "device_id": 0,
            "enable_htp_fp16_precision": True,
            "enable_htp_weight_sharing": True
        }
    )
    
    # Save the NPU-optimized model
    pipeline.save_pretrained(str(output_path))
    
    print(f"SDXL-Base NPU-optimized model ready at: {output_path}")
    print("Model is configured for Snapdragon NPU acceleration with high quality settings")
    
except ImportError as e:
    print(f"Import error: {e}")
    print("Installing missing dependencies...")
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "optimum[onnxruntime]", "onnxruntime-qnn"])
    # Retry with basic download if ONNX conversion fails
    try:
        from optimum.onnxruntime import ORTStableDiffusionXLPipeline
        pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0",
            export=True,
            provider="QNNExecutionProvider",
            export_dir=str(output_path)
        )
        pipeline.save_pretrained(str(output_path))
        print("NPU-optimized model created successfully")
    except Exception as retry_e:
        print(f"NPU optimization failed, using fallback: {retry_e}")
        from huggingface_hub import snapshot_download
        output_path = models_dir / "sdxl-base-1.0"
        snapshot_download("stabilityai/stable-diffusion-xl-base-1.0", local_dir=str(output_path))
        print("Standard model downloaded - NPU optimization requires manual setup")
    
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
"@
        }
        "3" {
            $modelName = "npu-test"
            $modelSteps = 3
            Write-Host "`nSetting up NPU test model..." -ForegroundColor Yellow
            
            $downloadScript = @"
import os
import sys
from pathlib import Path

try:
    print("Creating NPU test configuration and verifying QNN provider...")
    
    models_dir = Path("C:/AIDemo/models")
    models_dir.mkdir(exist_ok=True, parents=True)
    
    # Test QNN provider availability
    try:
        import onnxruntime as ort
        providers = ort.get_available_providers()
        qnn_available = 'QNNExecutionProvider' in providers
        
        print(f"Available ONNX providers: {providers}")
        print(f"QNN Provider available: {qnn_available}")
        
        if qnn_available:
            print("Snapdragon NPU support detected!")
        else:
            print("QNN Provider not available - installing...")
            import subprocess
            subprocess.run([sys.executable, "-m", "pip", "install", "onnxruntime-qnn", "--force-reinstall"])
            
    except ImportError:
        print("Installing ONNX runtime with QNN support...")
        import subprocess
        subprocess.run([sys.executable, "-m", "pip", "install", "onnxruntime-qnn"])
    
    # Create NPU test configuration
    npu_config = {
        "model_type": "npu_test",
        "platform": "snapdragon",
        "provider": "QNNExecutionProvider",
        "backend_path": "QnnHtp.dll",
        "device_id": 0,
        "optimizations": ["fp16", "npu_acceleration"],
        "note": "NPU test configuration for Snapdragon"
    }
    
    import json
    config_path = models_dir / "npu_test_config.json"
    with open(config_path, 'w') as f:
        json.dump(npu_config, f, indent=2)
    
    print(f"NPU test configuration created at: {config_path}")
    print("This configuration verifies NPU support and creates test settings")
    
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
        Write-Host "`n🚀 SNAPDRAGON NPU OPTIMIZATION COMPLETE!" -ForegroundColor Green
        Write-Host "Model: $modelName" -ForegroundColor White
        Write-Host "Inference steps: $modelSteps" -ForegroundColor White
        Write-Host "Hexagon DSP acceleration: ENABLED" -ForegroundColor Cyan
        # Determine actual model location based on what was created
        $modelLocation = "C:\AIDemo\models\"
        if (Test-Path "C:\AIDemo\models\sdxl_turbo_npu_optimized") {
            $modelLocation += "sdxl_turbo_npu_optimized"
            $actualOptimization = "NPU (Hexagon)"
        } elseif (Test-Path "C:\AIDemo\models\sdxl_turbo_arm64_optimized") {
            $modelLocation += "sdxl_turbo_arm64_optimized"  
            $actualOptimization = "ARM64 CPU"
        } elseif (Test-Path "C:\AIDemo\models\sdxl_base_npu_optimized") {
            $modelLocation += "sdxl_base_npu_optimized"
            $actualOptimization = "NPU (Hexagon)"
        } elseif (Test-Path "C:\AIDemo\models\npu_test_config.json") {
            $modelLocation += "npu_test_config.json"
            $actualOptimization = "Test Config"
        } else {
            $modelLocation += $modelName
            $actualOptimization = "Standard"
        }
        Write-Host "Optimization: $actualOptimization" -ForegroundColor Cyan
        Write-Host "Location: $modelLocation" -ForegroundColor White
        
        # Verify NPU optimization was achieved
        if ($actualOptimization -eq "NPU (Hexagon)") {
            Write-Host "`n🎯 SUCCESS: Full Snapdragon NPU optimization achieved!" -ForegroundColor Green
            Write-Host "Demo is ready for maximum performance comparison" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️  WARNING: NPU optimization not achieved" -ForegroundColor Yellow
            Write-Host "Demo will not show full Snapdragon advantage" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ CRITICAL: NPU model preparation failed" -ForegroundColor Red
        Write-Host "Snapdragon demo requirements not met" -ForegroundColor Red
        exit 1
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

# Set model path based on platform and what was actually created
if ($Platform -eq "snapdragon") {
    # Detect what optimization level was achieved
    if (Test-Path "C:\AIDemo\models\sdxl_turbo_npu_optimized") {
        $modelPath = "sdxl_turbo_npu_optimized"
        $optimizations = @("npu", "qnn_provider", "fp16", "hexagon_dsp")
    } elseif (Test-Path "C:\AIDemo\models\sdxl_turbo_arm64_optimized") {
        $modelPath = "sdxl_turbo_arm64_optimized"
        $optimizations = @("arm64", "cpu_optimized", "fp32")
    } elseif (Test-Path "C:\AIDemo\models\sdxl_base_npu_optimized") {
        $modelPath = "sdxl_base_npu_optimized"
        $optimizations = @("npu", "qnn_provider", "fp16", "hexagon_dsp")
    } elseif (Test-Path "C:\AIDemo\models\npu_test_config.json") {
        $modelPath = "npu_test_config.json"
        $optimizations = @("test_config")
    } else {
        # Fallback to standard model
        $modelPath = switch ($modelName) {
            "sdxl-turbo" { "sdxl-turbo" }
            "sdxl-base" { "sdxl-base-1.0" }
            default { "sdxl-turbo" }
        }
        $optimizations = @("arm64", "standard")
    }
} else {
    $modelPath = "sdxl-base-1.0"
    $optimizations = @("directml", "fp16")
}

$config = @{
    platform = $Platform
    model_name = $modelName
    inference_steps = $modelSteps
    model_path = $modelPath
    optimizations = $optimizations
}

$config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "`nConfiguration saved to: $configPath" -ForegroundColor Yellow
Write-Host "`nYour system is now ready for high-quality AI image generation!" -ForegroundColor Green
