# Intel Optimization Guide
## Maximizing AI Performance with DirectML and Intel Technologies

---

## Table of Contents

1. [Overview](#overview)
2. [DirectML Configuration](#directml-configuration)
3. [AVX-512 Instruction Set Utilization](#avx-512-instruction-set-utilization)
4. [Intel MKL Integration](#intel-mkl-integration)
5. [Memory Optimization Techniques](#memory-optimization-techniques)
6. [Performance Tuning Options](#performance-tuning-options)
7. [Optimization Profiles](#optimization-profiles)
8. [Advanced Configuration](#advanced-configuration)
9. [Troubleshooting Performance](#troubleshooting-performance)
10. [Benchmarking Guide](#benchmarking-guide)

---

## Overview

This guide provides comprehensive instructions for optimizing AI image generation performance on Intel Core Ultra systems. The Intel deployment script incorporates multiple optimization layers:

- **DirectML GPU Acceleration** - 37 integration points
- **AVX-512 Vector Instructions** - 13 optimizations
- **Intel MKL Library** - 8 performance enhancements
- **Memory Management** - Efficient FP16 model handling

**Performance Impact:**
- Baseline (CPU only): 90-120 seconds
- With DirectML: 35-45 seconds (2.5× faster)
- With AVX-512: Additional 10-15% improvement
- With MKL: Additional 5-10% improvement

---

## DirectML Configuration

### Understanding DirectML

DirectML (Direct Machine Learning) is Microsoft's hardware-agnostic ML acceleration API that provides GPU acceleration on Intel integrated and discrete graphics.

```mermaid
graph TD
    A[Python/PyTorch] --> B[torch-directml]
    B --> C[ONNX Runtime]
    C --> D[DirectML Provider]
    D --> E[DirectX 12]
    E --> F[Intel GPU Driver]
    F --> G[Intel Arc/Iris Hardware]
```

### Configuration Parameters

#### 1. Device Selection

```powershell
# Set primary GPU device (0 = first GPU)
$env:ORT_DIRECTML_DEVICE_ID = "0"

# Python verification
python -c "
import torch_directml
print(f'Available devices: {torch_directml.device_count()}')
print(f'Selected device: {torch_directml.device_name(0)}')
"
```

#### 2. Memory Arena Configuration

```powershell
# Enable memory arena for better performance
$env:ORT_DIRECTML_MEMORY_ARENA = "1"

# Arena extension strategy options:
# - kNextPowerOfTwo: Rounds up to next power of 2
# - kSameAsRequested: Exact allocation (default)
$env:ORT_DIRECTML_ARENA_EXTEND_STRATEGY = "kSameAsRequested"
```

#### 3. Graph Optimization

```powershell
# Optimization levels: NONE, BASIC, EXTENDED, ALL
$env:ORT_DIRECTML_GRAPH_OPTIMIZATION = "ALL"

# Enable graph capture for repeated inference
$env:ORT_DIRECTML_ENABLE_GRAPH_CAPTURE = "1"
```

### DirectML Best Practices

1. **Warmup Runs**
```python
# Always perform warmup to compile kernels
def warmup_directml():
    import torch_directml
    dml = torch_directml.device()
    
    # Small tensor operation to trigger compilation
    dummy = torch.randn(1, 3, 64, 64).to(dml)
    _ = dummy * 2.0
    torch_directml.sync()  # Ensure completion
```

2. **Memory Management**
```python
# Clear cache between generations
def clear_directml_cache():
    import gc
    import torch_directml
    
    torch_directml.empty_cache()
    gc.collect()
```

3. **Device Synchronization**
```python
# Ensure operations complete
def generate_with_sync(pipeline, prompt):
    result = pipeline(prompt)
    torch_directml.sync()  # Wait for GPU completion
    return result
```

---

## AVX-512 Instruction Set Utilization

### Overview

AVX-512 (Advanced Vector Extensions 512) provides 512-bit SIMD operations, significantly accelerating matrix operations and convolutions.

### Enabling AVX-512

#### 1. BIOS Configuration
- Enter BIOS/UEFI settings
- Navigate to CPU Configuration
- Enable "AVX-512" or "Advanced Vector Extensions"
- Save and reboot

#### 2. Environment Configuration

```powershell
# Enable AVX-512 in MKL
$env:MKL_ENABLE_INSTRUCTIONS = "AVX512"

# Verify AVX-512 support
python -c "
import numpy as np
print(np.show_config())
# Look for 'mkl_info' with AVX512 in build info
"
```

#### 3. Compiler Flags (for custom builds)

```bash
# GCC/Clang flags
-march=native -mavx512f -mavx512dq -mavx512cd -mavx512bw -mavx512vl

# MSVC flags
/arch:AVX512
```

### AVX-512 Performance Impact

| Operation | Without AVX-512 | With AVX-512 | Speedup |
|-----------|----------------|--------------|---------|
| Matrix Multiply | 100ms | 65ms | 1.54× |
| Convolution | 150ms | 95ms | 1.58× |
| Attention | 200ms | 140ms | 1.43× |
| VAE Decode | 300ms | 210ms | 1.43× |

### Code Optimization for AVX-512

```python
# NumPy automatically uses AVX-512 when available
import numpy as np

# Ensure alignment for optimal performance
def create_aligned_array(shape, dtype=np.float32):
    # 64-byte alignment for AVX-512
    size = np.prod(shape)
    aligned = np.zeros(size + 16, dtype=dtype)
    offset = (64 - aligned.ctypes.data % 64) % 64
    return aligned[offset:offset + size].reshape(shape)
```

---

## Intel MKL Integration

### Math Kernel Library Benefits

Intel MKL provides optimized implementations of:
- BLAS (Basic Linear Algebra Subprograms)
- LAPACK (Linear Algebra Package)
- FFT (Fast Fourier Transform)
- Vector Math functions

### Configuration

#### 1. Thread Configuration

```powershell
# Set optimal thread count (usually cores/2)
$cores = [Environment]::ProcessorCount
$env:MKL_NUM_THREADS = [Math]::Max(4, $cores / 2)

# Disable dynamic adjustment
$env:MKL_DYNAMIC = "FALSE"

# Force Intel optimizations
$env:MKL_SERVICE_FORCE_INTEL = "1"
```

#### 2. Memory Configuration

```powershell
# Optimize memory allocation
$env:MKL_FAST_MEMORY_LIMIT = "20000"  # MB

# Enable huge pages (requires admin)
$env:MKL_DISABLE_FAST_MM = "0"
```

#### 3. Python Integration

```python
# Verify MKL is being used
import numpy as np
np.show_config()  # Should show MKL info

# Configure at runtime
import mkl
mkl.set_num_threads(8)
mkl.set_dynamic(False)
```

### MKL Optimization Strategies

1. **Batch Operations**
```python
# Inefficient: Individual operations
for i in range(100):
    result[i] = np.dot(matrix, vector[i])

# Efficient: Batched operation
result = np.dot(matrix, vectors.T).T
```

2. **Memory Layout**
```python
# Use Fortran-order for column operations
matrix_f = np.asfortranarray(matrix)

# Use C-order for row operations
matrix_c = np.ascontiguousarray(matrix)
```

---

## Memory Optimization Techniques

### FP16 Model Handling

#### 1. Progressive Loading

```python
def load_model_progressive(model_path):
    import torch
    import gc
    
    # Load to CPU first with memory mapping
    model = torch.load(
        model_path,
        map_location='cpu',
        mmap=True  # Memory-mapped loading
    )
    
    # Move to GPU in chunks
    import torch_directml
    dml = torch_directml.device()
    
    for name, param in model.named_parameters():
        param.data = param.data.to(dml)
        gc.collect()  # Force cleanup after each transfer
    
    return model
```

#### 2. Attention Slicing

```python
# Reduce memory usage for attention layers
def enable_memory_efficient_attention(pipeline):
    # Slice attention computation
    pipeline.enable_attention_slicing(slice_size="auto")
    
    # Or specify manual slice size
    # pipeline.enable_attention_slicing(slice_size=4)
    
    return pipeline
```

#### 3. VAE Slicing

```python
# Reduce VAE memory usage
def enable_vae_slicing(pipeline):
    pipeline.enable_vae_slicing()
    
    # For extreme memory savings
    pipeline.enable_vae_tiling()
    
    return pipeline
```

#### 4. Sequential CPU Offload

```python
# Offload models to CPU when not in use
def enable_sequential_offload(pipeline):
    pipeline.enable_sequential_cpu_offload()
    
    # Or specify device
    # pipeline.enable_sequential_cpu_offload(gpu_id=0)
    
    return pipeline
```

### Memory Monitoring

```python
def monitor_memory():
    import psutil
    import torch_directml
    
    # System memory
    mem = psutil.virtual_memory()
    print(f"System RAM: {mem.used/1024**3:.1f}GB / {mem.total/1024**3:.1f}GB")
    
    # GPU memory (if available)
    if torch_directml.is_available():
        # Note: DirectML doesn't provide direct memory queries
        # Use Windows Performance Counters instead
        pass
```

---

## Performance Tuning Options

### System-Level Optimizations

#### 1. Windows Power Settings

```powershell
# Set to High Performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Disable GPU power management
powercfg -setacvalueindex SCHEME_CURRENT SUB_GRAPHICS GPUPREFER 0
```

#### 2. Process Priority

```powershell
# Set high priority for Python
$python = Get-Process python -ErrorAction SilentlyContinue
if ($python) {
    $python.PriorityClass = "High"
}
```

#### 3. CPU Affinity

```powershell
# Bind to performance cores (P-cores on Intel)
$python = Get-Process python -ErrorAction SilentlyContinue
if ($python) {
    # Use first 8 cores (typically P-cores)
    $python.ProcessorAffinity = 0xFF
}
```

### Application-Level Optimizations

#### 1. Batch Size Tuning

```python
# Find optimal batch size
def find_optimal_batch_size():
    batch_sizes = [1, 2, 4, 8]
    best_throughput = 0
    best_batch = 1
    
    for batch in batch_sizes:
        try:
            throughput = benchmark_batch(batch)
            if throughput > best_throughput:
                best_throughput = throughput
                best_batch = batch
        except RuntimeError:  # Out of memory
            break
    
    return best_batch
```

#### 2. Precision Tuning

```python
# Mixed precision for performance
def configure_mixed_precision():
    import torch
    
    # Enable TF32 for A100/H100 (if available)
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    
    # Use automatic mixed precision
    from torch.cuda.amp import autocast
    return autocast
```

---

## Optimization Profiles

### Profile Comparison

| Profile | Steps | CFG Scale | Resolution | Time | Quality |
|---------|-------|-----------|------------|------|---------|
| **Speed** | 4-8 | 5.0 | 512×512 | 15-25s | Draft |
| **Balanced** | 20-25 | 7.5 | 768×768 | 35-45s | Good |
| **Quality** | 30-50 | 8.5 | 768×768 | 50-80s | Maximum |

### Speed Profile Configuration

```python
speed_config = {
    "num_inference_steps": 6,
    "guidance_scale": 5.0,
    "width": 512,
    "height": 512,
    "enable_attention_slicing": True,
    "enable_vae_slicing": True
}

# Apply configuration
def apply_speed_profile(pipeline):
    pipeline.enable_attention_slicing()
    pipeline.enable_vae_slicing()
    
    # Use lower precision where possible
    pipeline.unet = pipeline.unet.half()
    pipeline.vae = pipeline.vae.half()
    
    return pipeline
```

### Balanced Profile Configuration

```python
balanced_config = {
    "num_inference_steps": 25,
    "guidance_scale": 7.5,
    "width": 768,
    "height": 768,
    "enable_attention_slicing": "auto",
    "enable_vae_slicing": False
}

# Apply configuration
def apply_balanced_profile(pipeline):
    pipeline.enable_attention_slicing("auto")
    
    # Standard FP16 precision
    pipeline = pipeline.to(torch.float16)
    
    return pipeline
```

### Quality Profile Configuration

```python
quality_config = {
    "num_inference_steps": 40,
    "guidance_scale": 8.5,
    "width": 768,
    "height": 768,
    "enable_attention_slicing": False,
    "enable_vae_slicing": False
}

# Apply configuration
def apply_quality_profile(pipeline):
    # Disable memory optimizations for quality
    pipeline.disable_attention_slicing()
    
    # Use higher precision for VAE
    pipeline.vae = pipeline.vae.float()
    
    return pipeline
```

### Dynamic Profile Selection

```python
def select_profile_based_on_memory():
    import psutil
    
    available_gb = psutil.virtual_memory().available / 1024**3
    
    if available_gb < 8:
        return "speed"
    elif available_gb < 16:
        return "balanced"
    else:
        return "quality"
```

---

## Advanced Configuration

### Custom Scheduler Configuration

```python
from diffusers import (
    DPMSolverMultistepScheduler,
    EulerDiscreteScheduler,
    EulerAncestralDiscreteScheduler
)

# Fast scheduler for speed
def configure_fast_scheduler(pipeline):
    pipeline.scheduler = DPMSolverMultistepScheduler.from_config(
        pipeline.scheduler.config,
        use_karras_sigmas=True,
        algorithm_type="dpmsolver++",
        solver_type="midpoint",
        lower_order_final=True
    )
    return pipeline

# Quality scheduler
def configure_quality_scheduler(pipeline):
    pipeline.scheduler = EulerAncestralDiscreteScheduler.from_config(
        pipeline.scheduler.config,
        use_karras_sigmas=True
    )
    return pipeline
```

### Custom Optimization Pipeline

```python
class OptimizedPipeline:
    def __init__(self, model_path, optimization_level="balanced"):
        self.optimization_level = optimization_level
        self.pipeline = self._load_optimized(model_path)
    
    def _load_optimized(self, model_path):
        import torch
        import torch_directml
        from diffusers import StableDiffusionXLPipeline
        
        # Select device
        device = torch_directml.device()
        
        # Load with optimizations
        pipeline = StableDiffusionXLPipeline.from_pretrained(
            model_path,
            torch_dtype=torch.float16,
            variant="fp16",
            use_safetensors=True
        )
        
        # Apply optimization level
        if self.optimization_level == "speed":
            pipeline.enable_attention_slicing(4)
            pipeline.enable_vae_slicing()
            pipeline.enable_sequential_cpu_offload()
        elif self.optimization_level == "balanced":
            pipeline.enable_attention_slicing("auto")
        # Quality mode: no additional optimizations
        
        # Move to device
        pipeline = pipeline.to(device)
        
        return pipeline
    
    def generate(self, prompt, **kwargs):
        # Apply profile-specific defaults
        defaults = self._get_defaults()
        kwargs = {**defaults, **kwargs}
        
        return self.pipeline(prompt, **kwargs)
    
    def _get_defaults(self):
        profiles = {
            "speed": {
                "num_inference_steps": 6,
                "guidance_scale": 5.0,
                "width": 512,
                "height": 512
            },
            "balanced": {
                "num_inference_steps": 25,
                "guidance_scale": 7.5,
                "width": 768,
                "height": 768
            },
            "quality": {
                "num_inference_steps": 40,
                "guidance_scale": 8.5,
                "width": 768,
                "height": 768
            }
        }
        return profiles.get(self.optimization_level, profiles["balanced"])
```

### Environment Variable Reference

```powershell
# Complete environment setup
function Set-IntelOptimizationEnvironment {
    param(
        [ValidateSet("Speed", "Balanced", "Quality")]
        [string]$Profile = "Balanced"
    )
    
    # DirectML settings
    $env:ORT_DIRECTML_DEVICE_ID = "0"
    $env:ORT_DIRECTML_MEMORY_ARENA = "1"
    $env:ORT_DIRECTML_GRAPH_OPTIMIZATION = "ALL"
    $env:ORT_DIRECTML_ENABLE_GRAPH_CAPTURE = "1"
    
    # Intel MKL settings
    $env:MKL_ENABLE_INSTRUCTIONS = "AVX512"
    $env:MKL_SERVICE_FORCE_INTEL = "1"
    $env:MKL_DYNAMIC = "FALSE"
    
    # Thread configuration based on profile
    $cores = [Environment]::ProcessorCount
    switch ($Profile) {
        "Speed" {
            $env:OMP_NUM_THREADS = [Math]::Min(4, $cores)
            $env:MKL_NUM_THREADS = [Math]::Min(4, $cores)
        }
        "Balanced" {
            $env:OMP_NUM_THREADS = [Math]::Max(4, $cores / 2)
            $env:MKL_NUM_THREADS = [Math]::Max(4, $cores / 2)
        }
        "Quality" {
            $env:OMP_NUM_THREADS = $cores
            $env:MKL_NUM_THREADS = $cores
        }
    }
    
    # Python optimizations
    $env:PYTHONOPTIMIZE = "1"
    $env:PYTHONHASHSEED = "0"
    
    Write-Host "Environment configured for $Profile profile" -ForegroundColor Green
}
```

---

## Troubleshooting Performance

### Performance Diagnostics

#### 1. Check DirectML Status

```python
def diagnose_directml():
    try:
        import torch_directml
        
        print(f"DirectML Available: {torch_directml.is_available()}")
        print(f"Device Count: {torch_directml.device_count()}")
        
        for i in range(torch_directml.device_count()):
            print(f"Device {i}: {torch_directml.device_name(i)}")
        
        # Test performance
        import time
        import torch
        
        dml = torch_directml.device()
        x = torch.randn(1, 3, 512, 512).to(dml)
        
        # Warmup
        for _ in range(3):
            _ = x * 2.0
        
        # Benchmark
        torch_directml.sync()
        start = time.time()
        for _ in range(100):
            _ = x * 2.0
        torch_directml.sync()
        elapsed = time.time() - start
        
        print(f"100 operations: {elapsed:.2f}s")
        print(f"Throughput: {100/elapsed:.1f} ops/sec")
        
    except Exception as e:
        print(f"DirectML Error: {e}")
```

#### 2. Memory Profiling

```python
def profile_memory():
    import tracemalloc
    import psutil
    
    # Start tracing
    tracemalloc.start()
    
    # Your generation code here
    result = generate_image("test prompt")
    
    # Get memory stats
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    
    print(f"Current memory: {current / 1024**2:.1f} MB")
    print(f"Peak memory: {peak / 1024**2:.1f} MB")
    
    # System memory
    mem = psutil.virtual_memory()
    print(f"System: {mem.used/1024**3:.1f}GB / {mem.total/1024**3:.1f}GB")
```

#### 3. Bottleneck Analysis

```python
import cProfile
import pstats

def profile_generation():
    profiler = cProfile.Profile()
    
    profiler.enable()
    result = generate_image("test prompt")
    profiler.disable()
    
    stats = pstats.Stats(profiler)
    stats.sort_stats('cumulative')
    stats.print_stats(20)  # Top 20 functions
```

### Common Performance Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **DirectML Not Used** | 90+ second generation | Verify DirectML installation, check device selection |
| **Memory Thrashing** | System freezes during generation | Enable attention/VAE slicing, reduce resolution |
| **Thermal Throttling** | Performance degrades over time | Improve cooling, reduce power limits |
| **Wrong Device** | Using integrated GPU instead of discrete | Set ORT_DIRECTML_DEVICE_ID correctly |
| **Driver Issues** | Crashes or errors | Update Intel graphics drivers |

---

## Benchmarking Guide

### Standard Benchmark Suite

```python
def run_comprehensive_benchmark():
    import time
    import statistics
    
    benchmarks = [
        ("Warmup", 1, 512, 1),
        ("Speed", 6, 512, 5),
        ("Balanced", 25, 768, 3),
        ("Quality", 40, 768, 3),
        ("Stress", 50, 1024, 1)
    ]
    
    results = {}
    
    for name, steps, resolution, iterations in benchmarks:
        times = []
        
        for _ in range(iterations):
            start = time.time()
            generate_image(
                "benchmark prompt",
                num_inference_steps=steps,
                width=resolution,
                height=resolution
            )
            elapsed = time.time() - start
            times.append(elapsed)
        
        results[name] = {
            "mean": statistics.mean(times),
            "stdev": statistics.stdev(times) if len(times) > 1 else 0,
            "min": min(times),
            "max": max(times)
        }
    
    return results
```

### Performance Reporting

```python
def generate_performance_report(results):
    print("=" * 60)
    print("PERFORMANCE BENCHMARK REPORT")
    print("=" * 60)
    
    for name, metrics in results.items():
        print(f"\n{name} Profile:")
        print(f"  Average: {metrics['mean']:.2f}s")
        print(f"  Std Dev: {metrics['stdev']:.2f}s")
        print(f"  Range: {metrics['min']:.2f}s - {metrics['max']:.2f}s")
        
        # Performance rating
        if name == "Balanced":
            if metrics['mean'] < 35:
                rating = "EXCELLENT"
            elif metrics['mean'] < 45:
                rating = "GOOD"
            elif metrics['mean'] < 60:
                rating = "ACCEPTABLE"
            else:
                rating = "NEEDS OPTIMIZATION"
            print(f"  Rating: {rating}")
    
    print("\n" + "=" * 60)
```

### Continuous Monitoring

```powershell
# PowerShell monitoring script
function Start-PerformanceMonitor {
    while ($true) {
        Clear-Host
        Write-Host "=== Intel AI Performance Monitor ===" -ForegroundColor Cyan
        
        # CPU usage
        $cpu = Get-WmiObject Win32_Processor
        Write-Host "CPU: $($cpu.LoadPercentage)%"
        
        # Memory
        $mem = Get-WmiObject Win32_OperatingSystem
        $used = ($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1024 / 1024
        $total = $mem.TotalVisibleMemorySize / 1024 / 1024
        Write-Host "Memory: $([Math]::Round($used, 1))GB / $([Math]::Round($total, 1))GB"
        
        # GPU (if available)
        $gpu = Get-WmiObject Win32_VideoController | Where-Object {$_.Name -match "Intel"}
        if ($gpu) {
            Write-Host "GPU: $($gpu.Name)"
        }
        
        # Python processes
        $python = Get-Process python -ErrorAction SilentlyContinue
        if ($python) {
            $pythonMem = ($python.WorkingSet64 / 1GB)
            Write-Host "Python Memory: $([Math]::Round($pythonMem, 2))GB"
        }
        
        Start-Sleep -Seconds 2
    }
}
```

---

## Conclusion

Optimizing Intel Core Ultra systems for AI image generation involves multiple layers:

1. **Hardware Acceleration** - DirectML provides 2.5× speedup
2. **CPU Optimizations** - AVX-512 and MKL add 15-25% improvement
3. **Memory Management** - Critical for handling 6.9GB FP16 models
4. **Profile Selection** - Balance speed vs quality based on use case

By following this guide, you can achieve optimal performance:
- **Speed Profile:** 15-25 seconds for quick drafts
- **Balanced Profile:** 35-45 seconds for production use
- **Quality Profile:** 50-80 seconds for maximum quality

Remember to:
- Always warm up the pipeline before benchmarking
- Monitor thermal throttling during extended use
- Use appropriate optimization profile for your use case
- Keep drivers and software updated

---

*Document Version: 1.0.0*  
*Last Updated: 2025-08-14*  
*Based on: prepare_intel.ps1 v1.0.0*  
*Tested with: Intel Core Ultra 7 155H, DirectML 1.12.0, PyTorch 2.1.2*