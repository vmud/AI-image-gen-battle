"""
AI Image Generation Pipeline
Optimized for quality with platform-specific acceleration
"""

import os
import sys
import time
import logging
from typing import Optional, Dict, Any, Callable, Tuple
from pathlib import Path
try:
    import numpy as np  # type: ignore
except Exception:
    np = None  # type: ignore
try:
    from PIL import Image  # type: ignore
except Exception:
    Image = None  # type: ignore
import platform

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AIImageGenerator:
    """Platform-optimized image generation pipeline with Intel performance benchmarking"""
    
    def __init__(self, platform_info: Dict[str, Any], model_path: str = "C:\\AIDemo\\models"):
        self.platform_info = platform_info
        self.model_path = Path(model_path)
        # Allow environment override to force Snapdragon behavior on Windows-on-ARM systems
        snapdragon_env = os.getenv('SNAPDRAGON_NPU', '').lower() in ('1', 'true', 'yes', 'y')
        self.is_snapdragon = platform_info.get('platform_type') == 'snapdragon' or snapdragon_env
        self.pipeline = None
        self.device = None
        self.optimization_backend = None
        self.model_loaded = False
        
        # Intel-specific performance targets
        self.intel_performance_targets = {
            'excellent_threshold': 35.0,  # seconds
            'good_threshold': 45.0,       # seconds
            'expected_directml_utilization': 85.0,  # percentage
            'expected_memory_usage': 8.5,  # GB
            'target_steps_per_second': 0.8  # steps/second
        }
        
        # Quality-focused settings
        self.default_steps = 25 if not self.is_snapdragon else 30  # Intel optimized
        self.default_guidance = 7.5
        self.default_resolution = (768, 768)  # Higher resolution for quality
        
        self._setup_platform_optimization()
        
    def _setup_platform_optimization(self):
        """Configure platform-specific optimizations"""
        
        if self.is_snapdragon:
            logger.info("Configuring Snapdragon NPU optimization...")
            self._setup_snapdragon_npu()
        else:
            logger.info("Configuring Intel DirectML optimization...")
            self._setup_intel_directml()
    
    def _setup_snapdragon_npu(self):
        """Setup Snapdragon-specific optimizations using Qualcomm AI Engine"""
        try:
            # Check for Qualcomm AI Hub optimized models first
            optimized_model = self.model_path / "sdxl_snapdragon_optimized"

            if optimized_model.exists():
                # Resolve providers from environment if available
                providers_env = os.getenv("ONNX_PROVIDERS")
                if providers_env:
                    providers = [p.strip() for p in providers_env.split(",") if p.strip()]
                else:
                    providers = ['QNNExecutionProvider', 'CPUExecutionProvider']

                # Import ONNX Runtime only when needed
                import onnxruntime as ort  # type: ignore

                # Create session options for optimal NPU performance
                sess_options = ort.SessionOptions()
                sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

                self.optimization_backend = "qualcomm_npu"

                # Load the optimized ONNX model using QNN
                self._load_snapdragon_optimized_model(optimized_model, providers, sess_options)
            else:
                logger.info("Snapdragon optimized model not found; using standard pipeline")
                self._setup_standard_pipeline()
        except Exception as e:
            logger.warning(f"Snapdragon NPU setup unavailable ({e}); using standard pipeline")
            self._setup_standard_pipeline()
    
    def _load_snapdragon_optimized_model(self, model_path, providers, sess_options):
        """Load Qualcomm-optimized SDXL model for Snapdragon"""
        try:
            import onnxruntime as ort  # type: ignore
            from optimum.onnxruntime import ORTStableDiffusionXLPipeline  # type: ignore
            
            # Load the Qualcomm AI Hub optimized SDXL pipeline
            # These models are specifically quantized and optimized for Snapdragon NPU
            self.pipeline = ORTStableDiffusionXLPipeline.from_pretrained(
                model_path,
                provider=providers[0],
                session_options=sess_options,
                provider_options=[{
                    'backend_path': 'QnnHtp.dll',  # Use HTP (Hexagon Tensor Processor)
                    'enable_htp_fp16_precision': '1',
                    'htp_performance_mode': 'high_performance',
                    'rpc_control_latency': '100'
                }]
            )
            
            # Optimize for quality over speed
            self.pipeline.scheduler.config.num_train_timesteps = 1000
            self.pipeline.vae_scale_factor = 8
            
            # Enable memory efficient attention for larger images
            self.pipeline.enable_attention_slicing()
            
            logger.info("Successfully loaded Snapdragon NPU-optimized SDXL model")
            
        except Exception as e:
            logger.warning(f"Error loading Snapdragon optimized model ({e}); falling back to standard pipeline")
            # Reset backend so metrics reflect the actual backend used
            self.optimization_backend = None
            self._setup_standard_pipeline()
    
    def _setup_intel_directml(self):
        """Setup Intel-specific optimizations using DirectML with performance monitoring"""
        try:
            import torch_directml  # type: ignore
            
            # Check if DirectML is available
            if torch_directml.is_available():
                self.device = torch_directml.device()
                self.optimization_backend = "directml"
                device_name = torch_directml.device_name(0)
                logger.info(f"DirectML device available: {device_name}")
                
                # Set Intel-specific environment optimizations
                os.environ['ORT_DIRECTML_DEVICE_ID'] = '0'
                os.environ['ORT_DIRECTML_MEMORY_ARENA'] = '1'
                os.environ['ORT_DIRECTML_GRAPH_OPTIMIZATION'] = 'ALL'
                
                # Intel MKL optimizations for Core Ultra
                os.environ['MKL_ENABLE_INSTRUCTIONS'] = 'AVX512'
                os.environ['MKL_DYNAMIC'] = 'FALSE'
                os.environ['MKL_NUM_THREADS'] = str(max(4, int(((os.cpu_count() or 8) / 2))))
                
                logger.info("Intel DirectML environment optimized for Core Ultra")
                
                # Load SDXL with DirectML optimization
                self._load_intel_optimized_model()
            else:
                logger.warning("DirectML not available, falling back to CPU")
                self._setup_standard_pipeline()
                
        except ImportError:
            logger.error("DirectML not installed, using CPU fallback")
            self._setup_standard_pipeline()
    
    def _load_intel_optimized_model(self):
        """Load SDXL model optimized for Intel with DirectML and performance monitoring"""
        try:
            from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler  # type: ignore
            import torch_directml  # type: ignore
            import torch  # type: ignore
            
            model_id = "stabilityai/stable-diffusion-xl-base-1.0"
            
            # Check for local model first
            local_model = self.model_path / "sdxl-base-1.0"
            if local_model.exists():
                model_id = str(local_model)
                logger.info(f"Using local Intel-optimized model: {local_model}")
            
            logger.info("Loading SDXL model for Intel DirectML...")
            load_start = time.time()
            
            # Load with DirectML device and Intel optimizations
            self.pipeline = StableDiffusionXLPipeline.from_pretrained(
                model_id,
                torch_dtype=torch.float16,
                variant="fp16",
                use_safetensors=True,
                low_cpu_mem_usage=True
            )
            
            # Move to DirectML device
            self.pipeline = self.pipeline.to(torch_directml.device())
            
            # Use DPM-Solver++ optimized for Intel hardware
            self.pipeline.scheduler = DPMSolverMultistepScheduler.from_config(
                self.pipeline.scheduler.config,
                use_karras_sigmas=True,
                algorithm_type="dpmsolver++",
                solver_order=2
            )
            
            # Intel-specific optimizations
            self.pipeline.enable_attention_slicing("auto")
            self.pipeline.enable_vae_slicing()
            
            # Try to enable model CPU offloading for memory efficiency
            try:
                self.pipeline.enable_model_cpu_offload()
                logger.info("Model CPU offloading enabled for memory efficiency")
            except Exception as e:
                logger.warning(f"Could not enable CPU offloading: {e}")
            
            load_time = time.time() - load_start
            self.model_loaded = True
            
            logger.info(f"Successfully loaded SDXL with DirectML acceleration ({load_time:.1f}s)")
            logger.info(f"Model device: {self.device}")
            logger.info(f"Scheduler: {self.pipeline.scheduler.__class__.__name__}")
            
        except Exception as e:
            logger.error(f"Error loading Intel optimized model: {e}")
            raise
    
    def _setup_standard_pipeline(self):
        """Fallback to standard Stable Diffusion pipeline"""
        try:
            from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler  # type: ignore
            import torch  # type: ignore
            
            model_id = "stabilityai/stable-diffusion-xl-base-1.0"
            
            # Check for local model
            local_model = self.model_path / "sdxl-base-1.0"
            if local_model.exists():
                model_id = str(local_model)
            
            # Load with CPU as fallback
            self.pipeline = StableDiffusionXLPipeline.from_pretrained(
                model_id,
                torch_dtype=torch.float32,
                use_safetensors=True,
                low_cpu_mem_usage=True
            )
            
            # Use efficient scheduler
            self.pipeline.scheduler = DPMSolverMultistepScheduler.from_config(
                self.pipeline.scheduler.config,
                use_karras_sigmas=True
            )
            
            self.device = "cpu"
            self.optimization_backend = "cpu"
            
            logger.info("Using CPU-based pipeline (will be slower)")
            
        except Exception as e:
            logger.error(f"Failed to setup standard pipeline: {e}")
            raise
    
    def generate_image(
        self,
        prompt: str,
        negative_prompt: Optional[str] = None,
        steps: Optional[int] = None,
        guidance_scale: Optional[float] = None,
        resolution: Optional[Tuple[int, int]] = None,
        seed: Optional[int] = None,
        progress_callback: Optional[Callable] = None
    ) -> Tuple[Any, Dict[str, Any]]:
        """
        Generate high-quality image with Intel-optimized performance benchmarking
        
        Returns:
            Tuple of (PIL Image, comprehensive metrics dict)
        """
        
        if self.pipeline is None:
            raise RuntimeError("Pipeline not initialized - run model loading first")
        assert self.pipeline is not None
        
        # Use Intel-optimized defaults
        steps = steps or self.default_steps
        guidance_scale = guidance_scale or self.default_guidance
        resolution = resolution or self.default_resolution
        
        # Intel-optimized negative prompt for quality
        if not negative_prompt:
            negative_prompt = (
                "low quality, blurry, pixelated, noisy, oversaturated, "
                "undersaturated, overexposed, underexposed, grainy, jpeg artifacts, "
                "distorted, deformed, ugly, bad anatomy"
            )
        
        # Set seed for reproducible Intel demos
        import torch  # type: ignore
        if seed is not None:
            if self.device and "directml" in str(self.device):
                # DirectML-compatible generator
                generator = torch.Generator().manual_seed(seed)
            else:
                generator = torch.Generator().manual_seed(seed)
        else:
            generator = None
        
        # Initialize comprehensive metrics tracking
        metrics = {
            "platform": "snapdragon" if self.is_snapdragon else "intel",
            "backend": self.optimization_backend,
            "device": str(self.device),
            "resolution": f"{resolution[0]}x{resolution[1]}",
            "steps": steps,
            "guidance_scale": guidance_scale,
            "model_loaded": self.model_loaded
        }
        
        # Performance monitoring setup
        import psutil  # type: ignore
        process = psutil.Process()
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        logger.info(f"Starting {'Snapdragon (QNN)' if self.is_snapdragon else 'Intel DirectML'} generation: {steps} steps, {resolution[0]}x{resolution[1]}")
        start_time = time.time()
        step_times = []
        
        try:
            # Enhanced progress tracking with Intel performance data
            
            def intel_callback_wrapper(step, timestep, latents):
                step_time = time.time()
                if len(step_times) > 0:
                    step_duration = step_time - step_times[-1]
                    avg_step_time = sum(step_times[1:]) / max(1, len(step_times) - 1) if len(step_times) > 1 else step_duration
                    
                    # Log performance every 5 steps
                    if step % 5 == 0:
                        logger.info(f"Intel Step {step}/{steps}: {step_duration:.2f}s (avg: {avg_step_time:.2f}s/step)")
                
                step_times.append(step_time)
                
                if progress_callback:
                    progress = (step + 1) / steps
                    progress_callback(progress, step + 1, steps)
                
                return latents
            
            # Generate image with platform-optimized path
            if self.optimization_backend == "directml":
                result = self.pipeline(
                    prompt=prompt,
                    negative_prompt=negative_prompt,
                    num_inference_steps=steps,
                    guidance_scale=guidance_scale,
                    height=resolution[1],
                    width=resolution[0],
                    generator=generator,
                    callback=intel_callback_wrapper,
                    callback_steps=1,
                    output_type="pil"
                )
            elif self.optimization_backend == "qualcomm_npu":
                # Use Snapdragon-optimized generation path
                result = self._generate_snapdragon_optimized(
                    prompt, negative_prompt, steps, guidance_scale,
                    resolution, generator, intel_callback_wrapper
                )
            else:
                # CPU fallback: ensure PIL output for consistency
                result = self.pipeline(
                    prompt=prompt,
                    negative_prompt=negative_prompt,
                    num_inference_steps=steps,
                    guidance_scale=guidance_scale,
                    height=resolution[1],
                    width=resolution[0],
                    generator=generator,
                    callback=intel_callback_wrapper,
                    callback_steps=1,
                    output_type="pil",
                    return_dict=True
                )
            
            # Get the generated image
            image = result.images[0]
            generation_time = time.time() - start_time
            
            # Comprehensive Intel performance metrics
            final_memory = process.memory_info().rss / 1024 / 1024  # MB
            memory_used = final_memory - initial_memory
            
            metrics.update({
                "generation_time": round(generation_time, 2),
                "ms_per_step": round((generation_time * 1000) / steps, 1),
                "steps_per_second": round(steps / generation_time, 2),
                "memory_used_mb": round(memory_used, 1),
                "initial_memory_mb": round(initial_memory, 1),
                "final_memory_mb": round(final_memory, 1)
            })
            
            # Intel-specific performance analysis
            performance_analysis = self._analyze_intel_performance(generation_time, steps, memory_used)
            metrics.update(performance_analysis)
            
            # Platform-specific utilization metrics
            if not self.is_snapdragon:
                intel_metrics = self._get_intel_performance_metrics()
                metrics.update(intel_metrics)
            
            # Log comprehensive results
            logger.info(f"{'Snapdragon (QNN)' if self.is_snapdragon else 'Intel DirectML'} generation complete:")
            logger.info(f"  Time: {generation_time:.2f}s ({metrics['ms_per_step']}ms/step)")
            logger.info(f"  Performance: {performance_analysis['performance_rating']}")
            logger.info(f"  Memory: {memory_used:.1f}MB used")
            logger.info(f"  Efficiency: {performance_analysis['efficiency_score']:.1f}%")
            
            return image, metrics
            
        except Exception as e:
            error_metrics = {
                "error": str(e),
                "generation_time": time.time() - start_time,
                "error_step": len(step_times) if 'step_times' in locals() else 0
            }
            metrics.update(error_metrics)
            logger.error(f"Image generation failed: {e}")
            raise
    
    def _analyze_intel_performance(self, generation_time: float, steps: int, memory_used: float) -> Dict[str, Any]:
        """Analyze Intel DirectML performance against targets"""
        
        analysis = {
            "performance_rating": "Unknown",
            "efficiency_score": 0.0,
            "meets_target": False,
            "optimization_suggestions": []
        }
        
        # Performance rating based on Intel targets
        if generation_time <= self.intel_performance_targets['excellent_threshold']:
            analysis["performance_rating"] = "Excellent"
            analysis["efficiency_score"] = 95.0
            analysis["meets_target"] = True
        elif generation_time <= self.intel_performance_targets['good_threshold']:
            analysis["performance_rating"] = "Good"
            analysis["efficiency_score"] = 80.0
            analysis["meets_target"] = True
        else:
            analysis["performance_rating"] = "Needs Optimization"
            analysis["efficiency_score"] = max(50.0, 100 * (60 / generation_time))
            analysis["meets_target"] = False
            
            # Add optimization suggestions
            if generation_time > 60:
                analysis["optimization_suggestions"].append("Consider reducing steps to 20-25")
            if memory_used > 10000:  # 10GB
                analysis["optimization_suggestions"].append("Enable model CPU offloading")
            if self.optimization_backend != "directml":
                analysis["optimization_suggestions"].append("Install torch-directml for GPU acceleration")
        
        # Steps per second analysis
        steps_per_second = steps / generation_time
        analysis["steps_per_second"] = round(steps_per_second, 2)
        
        if steps_per_second >= self.intel_performance_targets['target_steps_per_second']:
            analysis["step_efficiency"] = "Good"
        else:
            analysis["step_efficiency"] = "Below Target"
            analysis["optimization_suggestions"].append("Check DirectML installation and GPU drivers")
        
        # Memory efficiency analysis
        expected_memory = self.intel_performance_targets['expected_memory_usage'] * 1024  # Convert to MB
        memory_efficiency = min(100, (expected_memory / max(memory_used, expected_memory)) * 100)
        analysis["memory_efficiency"] = round(memory_efficiency, 1)
        
        return analysis
    
    def _get_intel_performance_metrics(self) -> Dict[str, Any]:
        """Get Intel-specific performance metrics"""
        metrics = {
            "gpu_utilization": 0.0,
            "directml_active": False,
            "intel_optimization_level": "unknown"
        }
        
        try:
            import psutil  # type: ignore
            
            # CPU utilization as proxy for Intel iGPU
            cpu_percent = psutil.cpu_percent(interval=0.1)
            metrics["gpu_utilization"] = min(95.0, cpu_percent * 1.2)  # Approximate iGPU usage
            
            # Check DirectML status
            if self.optimization_backend == "directml":
                metrics["directml_active"] = True
                metrics["intel_optimization_level"] = "high"
            else:
                metrics["intel_optimization_level"] = "cpu_only"
            
            # Memory pressure
            memory = psutil.virtual_memory()
            metrics["memory_pressure"] = memory.percent
            
            # Intel-specific environment checks
            intel_env_vars = ['MKL_ENABLE_INSTRUCTIONS', 'ORT_DIRECTML_DEVICE_ID']
            metrics["intel_env_optimized"] = all(var in os.environ for var in intel_env_vars)
            
        except Exception as e:
            logger.warning(f"Could not get Intel performance metrics: {e}")
        
        return metrics
    
    def _generate_snapdragon_optimized(
        self, prompt, negative_prompt, steps, guidance_scale,
        resolution, generator, callback
    ):
        """Snapdragon-specific generation with NPU optimizations"""
        
        # The Qualcomm AI Hub models use optimized inference
        # with INT8 quantization and NPU-specific graph optimizations
        assert self.pipeline is not None
        return self.pipeline(
            prompt=prompt,
            negative_prompt=negative_prompt,
            num_inference_steps=steps,
            guidance_scale=guidance_scale,
            height=resolution[1],
            width=resolution[0],
            generator=generator,
            callback=callback,
            callback_steps=1,
            # Snapdragon-specific optimizations
            num_images_per_prompt=1,
            output_type="pil",
            return_dict=True
        )
    
    def _get_snapdragon_npu_usage(self) -> float:
        """Get Snapdragon NPU utilization percentage"""
        try:
            # This would interface with Qualcomm's performance monitoring
            # For demo purposes, return estimated value based on workload
            return 85.0  # NPU typically runs at high utilization during inference
        except:
            return 0.0
    
    def _get_intel_gpu_usage(self) -> float:
        """Get Intel GPU/NPU utilization percentage"""
        try:
            import psutil  # type: ignore
            # Simplified - real implementation would use Intel metrics APIs
            return psutil.cpu_percent()
        except:
            return 0.0
    
    def download_models(self, progress_callback: Optional[Callable] = None):
        """Download and prepare models for the platform"""
        
        if self.is_snapdragon:
            self._download_snapdragon_models(progress_callback)
        else:
            self._download_intel_models(progress_callback)
    
    def _download_snapdragon_models(self, progress_callback):
        """Download Qualcomm AI Hub optimized models"""
        logger.info("Downloading Snapdragon-optimized SDXL models...")
        
        # Models from Qualcomm AI Hub are pre-optimized for NPU
        # They include:
        # - INT8 quantized weights
        # - Graph optimizations for Hexagon DSP
        # - Optimized attention mechanisms
        
        model_url = "https://aihub.qualcomm.com/models/sdxl_snapdragon"
        # Implementation would download the optimized ONNX models
        
    def _download_intel_models(self, progress_callback):
        """Download standard SDXL models for Intel"""
        logger.info("Downloading SDXL models for Intel...")
        
        from huggingface_hub import snapshot_download  # type: ignore
        
        # Download SDXL base model
        snapshot_download(
            repo_id="stabilityai/stable-diffusion-xl-base-1.0",
            local_dir=self.model_path / "sdxl-base-1.0",
            ignore_patterns=["*.ckpt", "*.safetensors.index.json"]
        )

# Backwards-compatibility wrapper for existing demo code
class AIImagePipeline(AIImageGenerator):
    """
    Compatibility layer exposing a simpler .generate(...) API expected by the
    Snapdragon performance test scripts. Internally delegates to AIImageGenerator.
    """
    def __init__(self, platform_info: Dict[str, Any], model_path: str = "C:\\AIDemo\\models"):
        super().__init__(platform_info, model_path)

    def generate(
        self,
        prompt: str,
        steps: int = 4,
        width: int = 768,
        height: int = 768,
        negative_prompt: Optional[str] = None,
        guidance_scale: Optional[float] = None,
        seed: Optional[int] = None,
        progress_callback: Optional[Callable] = None
    ):
        image, _metrics = self.generate_image(
            prompt=prompt,
            negative_prompt=negative_prompt,
            steps=steps,
            guidance_scale=guidance_scale,
            resolution=(width, height),
            seed=seed,
            progress_callback=progress_callback,
        )
        return image
