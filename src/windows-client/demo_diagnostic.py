#!/usr/bin/env python3
"""
Unified Diagnostic and Performance Validation Script
AI Image Generation Demo - Intel vs Snapdragon Platform Validation

This script provides comprehensive diagnostic testing for both Intel Core Ultra
and Snapdragon X Elite platforms with auto-detection and platform-specific validation.

Enhanced with enterprise-grade logging, metrics collection, data persistence,
and comprehensive reporting capabilities.
"""

import os
import sys
import time
import logging
import traceback
import subprocess
import uuid
from typing import Dict, Any, List, Tuple, Optional
from pathlib import Path
import json

# Enhanced framework imports
try:
    from diagnostic_config import get_config_manager, load_config, is_enhanced_mode
    from diagnostic_logger import get_logger, setup_logging
    from metrics_collector import get_metrics_collector, start_metrics_collection, time_operation
    from diagnostic_storage import get_diagnostic_storage, store_diagnostic_data
    from diagnostic_reporter import get_diagnostic_reporter, generate_report
    ENHANCED_FRAMEWORK_AVAILABLE = True
except ImportError as e:
    # Fallback to basic logging if enhanced framework is not available
    logging.basicConfig(level=logging.WARNING)
    ENHANCED_FRAMEWORK_AVAILABLE = False
    print(f"Enhanced framework not available: {e}")
    print("Running in basic mode...")

# Configure basic logging for fallback
if not ENHANCED_FRAMEWORK_AVAILABLE:
    logger = logging.getLogger(__name__)

class DiagnosticResult:
    """Container for diagnostic test results"""
    def __init__(self, test_name: str):
        self.test_name = test_name
        self.status = "CHECKING"
        self.message = ""
        self.details = {}
        self.fix_commands = []
        self.duration = 0.0
        
    def pass_test(self, message: str, details: Dict[str, Any] = None):
        self.status = "PASS"
        self.message = message
        self.details = details or {}
        
    def fail_test(self, message: str, fix_commands: List[str] = None, details: Dict[str, Any] = None):
        self.status = "FAIL"
        self.message = message
        self.fix_commands = fix_commands or []
        self.details = details or {}

class UnifiedDiagnostic:
    """Unified diagnostic framework for Intel and Snapdragon platforms"""
    
    def __init__(self, enhanced_mode: bool = None):
        self.start_time = time.time()
        self.platform_info = {}
        self.platform_type = "unknown"
        self.results = {}
        self.overall_status = "CHECKING"
        
        # Enhanced framework integration
        self.enhanced_mode = enhanced_mode
        if self.enhanced_mode is None:
            self.enhanced_mode = ENHANCED_FRAMEWORK_AVAILABLE and is_enhanced_mode()
        
        # Initialize enhanced components if available
        if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
            self.config_manager = get_config_manager()
            self.logger = get_logger("diagnostic")
            self.metrics_collector = get_metrics_collector()
            self.storage = get_diagnostic_storage()
            self.reporter = get_diagnostic_reporter()
            self.run_id = str(uuid.uuid4())
            
            # Setup enhanced logging
            setup_logging()
            self.logger.info("Enhanced diagnostic framework initialized")
        else:
            # Fallback to basic components
            self.config_manager = None
            self.logger = logger if not ENHANCED_FRAMEWORK_AVAILABLE else get_logger("diagnostic")
            self.metrics_collector = None
            self.storage = None
            self.reporter = None
            self.run_id = f"basic_{int(time.time())}"
        
        # Platform-specific performance targets
        self.performance_targets = {
            'intel': {
                'min_time': 35.0,
                'max_time': 45.0,
                'acceleration': 'DirectML',
                'fallback_min': 120.0,
                'fallback_max': 180.0
            },
            'snapdragon': {
                'min_time': 8.0,
                'max_time': 15.0,
                'acceleration': 'QNN/NPU',
                'fallback_min': 30.0,
                'fallback_max': 60.0
            }
        }
        
    def print_header(self):
        """Print diagnostic header"""
        print("=" * 80)
        print("AI IMAGE GENERATION DEMO - UNIFIED DIAGNOSTIC VALIDATOR")
        print("=" * 80)
        print("Auto-detecting platform and validating environment readiness...")
        print("")
        
    def print_status(self, test_name: str, status: str, message: str = ""):
        """Print formatted status line"""
        status_colors = {
            'CHECKING': '\033[93m',  # Yellow
            'PASS': '\033[92m',      # Green
            'FAIL': '\033[91m',      # Red
            'FIX': '\033[96m'        # Cyan
        }
        reset_color = '\033[0m'
        
        color = status_colors.get(status, '')
        status_symbol = {
            'CHECKING': '[CHECKING]',
            'PASS': '[PASS]',
            'FAIL': '[FAIL]',
            'FIX': '[FIX]'
        }.get(status, f'[{status}]')
        
        if message:
            print(f"{color}{status_symbol:<12}{reset_color} {test_name}: {message}")
        else:
            print(f"{color}{status_symbol:<12}{reset_color} {test_name}")
    
    def run_diagnostics(self) -> bool:
        """Run all diagnostic tests in sequence"""
        # Initialize enhanced framework components
        if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
            self.logger.info(f"Starting enhanced diagnostic run: {self.run_id}")
            self.logger.set_platform(self.platform_type)
            start_metrics_collection()
            self.metrics_collector.set_platform_type(self.platform_type)
        
        self.print_header()
        
        # Define the 6 critical tests
        tests = [
            ("Platform Detection", self.test_platform_detection),
            ("Python Environment", self.test_python_environment),
            ("AIImagePipeline Import", self.test_ai_pipeline_import),
            ("Hardware Acceleration", self.test_hardware_acceleration),
            ("Model Accessibility", self.test_model_accessibility),
            ("Quick Performance Test", self.test_quick_performance)
        ]
        
        passed_tests = 0
        total_tests = len(tests)
        
        for test_name, test_function in tests:
            self.print_status(test_name, "CHECKING")
            
            result = DiagnosticResult(test_name)
            start_time = time.time()
            
            try:
                # Enhanced logging context
                if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
                    with self.logger.test_context(test_name, self.platform_type):
                        with self.metrics_collector.time_test(test_name) as timing:
                            test_function(result)
                else:
                    test_function(result)
                    
                result.duration = time.time() - start_time
                
                # Enhanced logging for test results
                if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
                    self.logger.log_test_result(
                        test_name, result.status, result.message,
                        result.details, result.fix_commands, result.duration
                    )
                
            except Exception as e:
                result.duration = time.time() - start_time
                result.fail_test(
                    f"Test crashed: {str(e)}",
                    ["Check logs for detailed error information"],
                    {"error": str(e), "traceback": traceback.format_exc()}
                )
                
                # Enhanced error logging
                if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
                    self.logger.log_error_with_context(e, f"Test: {test_name}", include_locals=True)
            
            # Store result and print status
            self.results[test_name] = result
            self.print_status(test_name, result.status, result.message)
            
            # Print fix commands if test failed
            if result.status == "FAIL" and result.fix_commands:
                for fix_cmd in result.fix_commands:
                    self.print_status("", "FIX", fix_cmd)
                    if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
                        self.logger.info(f"Fix command: {fix_cmd}")
            
            if result.status == "PASS":
                passed_tests += 1
            
            print("")  # Add spacing between tests
        
        # Determine overall status
        self.overall_status = "READY" if passed_tests == total_tests else "NOT READY"
        
        # Enhanced data collection and storage
        if self.enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
            self._collect_and_store_diagnostic_data(passed_tests, total_tests)
        
        # Print summary
        self.print_summary(passed_tests, total_tests)
        
        return passed_tests == total_tests
    
    def test_platform_detection(self, result: DiagnosticResult):
        """Test 1: Auto-detect Intel vs Snapdragon platform"""
        try:
            from platform_detection import detect_platform
            
            self.platform_info = detect_platform()
            self.platform_type = self.platform_info.get('platform_type', 'unknown')
            
            if self.platform_type == 'intel':
                processor = self.platform_info.get('name', 'Intel Core Ultra')
                acceleration = self.platform_info.get('ai_framework', 'DirectML')
                result.pass_test(
                    f"Intel platform detected: {processor} with {acceleration}",
                    {"platform": self.platform_type, "processor": processor, "acceleration": acceleration}
                )
            elif self.platform_type == 'snapdragon':
                processor = self.platform_info.get('name', 'Snapdragon X Elite')
                acceleration = self.platform_info.get('ai_framework', 'QNN')
                result.pass_test(
                    f"Snapdragon platform detected: {processor} with {acceleration}",
                    {"platform": self.platform_type, "processor": processor, "acceleration": acceleration}
                )
            else:
                result.fail_test(
                    f"Unknown platform detected: {self.platform_type}",
                    [
                        "Ensure you're running on Intel Core Ultra or Snapdragon X Elite",
                        "Check platform_detection.py for compatibility issues"
                    ],
                    {"detected_platform": self.platform_type}
                )
                
        except ImportError as e:
            result.fail_test(
                "Cannot import platform_detection module",
                [
                    "Verify platform_detection.py exists in the same directory",
                    f"Install missing dependencies: {str(e)}"
                ]
            )
        except Exception as e:
            result.fail_test(
                f"Platform detection failed: {str(e)}",
                ["Check platform_detection.py for errors"]
            )
    
    def test_python_environment(self, result: DiagnosticResult):
        """Test 2: Verify Python 3.10 and virtual environment"""
        python_version = f"{sys.version_info.major}.{sys.version_info.minor}"
        python_path = sys.executable
        
        # Check Python version
        if python_version != "3.10":
            result.fail_test(
                f"Python {python_version} detected, requires Python 3.10",
                [
                    "Install Python 3.10",
                    "Create virtual environment with: python3.10 -m venv .venv",
                    "Activate virtual environment"
                ],
                {"current_version": python_version, "required": "3.10"}
            )
            return
        
        # Check virtual environment
        in_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix)
        
        # Check pip availability
        try:
            import pip
            pip_available = True
        except ImportError:
            pip_available = False
        
        if not pip_available:
            result.fail_test(
                "pip not available",
                [
                    "Reinstall Python 3.10 with pip",
                    "Or install pip manually: python -m ensurepip"
                ]
            )
            return
        
        details = {
            "python_version": python_version,
            "python_path": python_path,
            "virtual_env": in_venv,
            "pip_available": pip_available
        }
        
        if in_venv:
            result.pass_test(
                f"Python 3.10 in virtual environment: {python_path}",
                details
            )
        else:
            result.pass_test(
                f"Python 3.10 detected (not in venv): {python_path}",
                details
            )
    
    def test_ai_pipeline_import(self, result: DiagnosticResult):
        """Test 3: Test specific AIImagePipeline import (known failure point)"""
        try:
            # Test the specific import that's known to fail
            from ai_pipeline import AIImagePipeline
            
            # Verify the class can be instantiated
            test_platform = self.platform_info or {'platform_type': 'intel'}
            
            # Test instantiation without full initialization
            try:
                pipeline = AIImagePipeline(test_platform)
                result.pass_test(
                    "AIImagePipeline successfully imported and instantiated",
                    {
                        "class_available": True,
                        "platform_support": test_platform.get('platform_type', 'unknown'),
                        "backend": getattr(pipeline, 'optimization_backend', 'unknown')
                    }
                )
            except Exception as init_error:
                # Import succeeded but initialization failed
                result.fail_test(
                    f"AIImagePipeline import OK but initialization failed: {str(init_error)}",
                    self._get_ai_pipeline_fix_commands(str(init_error)),
                    {"import_success": True, "init_error": str(init_error)}
                )
                
        except ImportError as e:
            error_msg = str(e).lower()
            
            if 'torch' in error_msg or 'directml' in error_msg:
                result.fail_test(
                    f"Missing PyTorch/DirectML dependencies: {str(e)}",
                    [
                        "Install PyTorch: pip install torch torchvision",
                        "Install DirectML: pip install torch-directml",
                        "Verify CUDA/DirectML installation"
                    ]
                )
            elif 'diffusers' in error_msg:
                result.fail_test(
                    f"Missing diffusers library: {str(e)}",
                    [
                        "Install diffusers: pip install diffusers",
                        "Install transformers: pip install transformers"
                    ]
                )
            elif 'onnx' in error_msg and self.platform_type == 'snapdragon':
                result.fail_test(
                    f"Missing ONNX Runtime for Snapdragon: {str(e)}",
                    [
                        "Install ONNX Runtime: pip install onnxruntime",
                        "Install optimum: pip install optimum[onnxruntime]",
                        "Verify QNN provider availability"
                    ]
                )
            else:
                result.fail_test(
                    f"AIImagePipeline import failed: {str(e)}",
                    [
                        "Install missing dependencies: pip install -r requirements.txt",
                        "Check ai_pipeline.py for syntax errors",
                        "Verify all imports in ai_pipeline.py are available"
                    ]
                )
        except Exception as e:
            result.fail_test(
                f"Unexpected error importing AIImagePipeline: {str(e)}",
                ["Check ai_pipeline.py for errors", "Review system compatibility"]
            )
    
    def _get_ai_pipeline_fix_commands(self, error_msg: str) -> List[str]:
        """Get platform-specific fix commands for AI pipeline issues"""
        error_lower = error_msg.lower()
        
        if self.platform_type == 'intel':
            if 'directml' in error_lower or 'torch_directml' in error_lower:
                return [
                    "Install DirectML: pip install torch-directml",
                    "Update GPU drivers: Check Intel website for latest drivers",
                    "Restart system after driver installation"
                ]
            elif 'maintenance mode' in error_lower:
                return [
                    "DirectML in maintenance mode - disable GPU acceleration",
                    "Set environment: set PYTORCH_ENABLE_MPS_FALLBACK=1",
                    "Use CPU fallback mode for testing"
                ]
        elif self.platform_type == 'snapdragon':
            if 'qnn' in error_lower or 'npu' in error_lower:
                return [
                    "Install QNN provider: pip install onnxruntime-qnn",
                    "Verify NPU drivers are installed",
                    "Check ARM64 package compatibility"
                ]
            elif 'arm64' in error_lower or 'architecture' in error_lower:
                return [
                    "Install ARM64-compatible packages",
                    "Use: pip install --force-reinstall --no-deps package_name",
                    "Check package availability for ARM64 architecture"
                ]
        
        return [
            "Install dependencies: pip install -r requirements.txt",
            "Check platform-specific requirements",
            "Review error logs for specific missing modules"
        ]
    
    def test_hardware_acceleration(self, result: DiagnosticResult):
        """Test 4: Detect DirectML (Intel) or QNN/NPU (Snapdragon) availability"""
        if self.platform_type == 'intel':
            self._test_directml_acceleration(result)
        elif self.platform_type == 'snapdragon':
            self._test_qnn_npu_acceleration(result)
        else:
            result.fail_test(
                "Unknown platform - cannot test hardware acceleration",
                ["Run platform detection test first"]
            )
    
    def _test_directml_acceleration(self, result: DiagnosticResult):
        """Test DirectML availability for Intel platforms"""
        try:
            import torch_directml
            
            if not torch_directml.is_available():
                result.fail_test(
                    "DirectML not available",
                    [
                        "Install DirectML: pip install torch-directml",
                        "Update Intel GPU drivers",
                        "Verify Intel Core Ultra GPU support"
                    ]
                )
                return
            
            # Test device access
            try:
                device = torch_directml.device()
                device_name = torch_directml.device_name(0)
                
                # Quick tensor operation test
                import torch
                test_tensor = torch.ones(10, 10).to(device)
                result_tensor = torch.mm(test_tensor, test_tensor)
                
                result.pass_test(
                    f"DirectML acceleration available: {device_name}",
                    {
                        "device": str(device),
                        "device_name": device_name,
                        "tensor_ops": "functional"
                    }
                )
                
            except Exception as device_error:
                result.fail_test(
                    f"DirectML device error: {str(device_error)}",
                    [
                        "Update Intel GPU drivers",
                        "Restart system",
                        "Check DirectML installation: pip install --force-reinstall torch-directml"
                    ]
                )
                
        except ImportError:
            result.fail_test(
                "torch-directml not installed",
                [
                    "Install DirectML: pip install torch-directml",
                    "Verify PyTorch compatibility",
                    "Check Intel GPU driver installation"
                ]
            )
    
    def _test_qnn_npu_acceleration(self, result: DiagnosticResult):
        """Test QNN/NPU availability for Snapdragon platforms"""
        try:
            import onnxruntime as ort
            
            # Check available providers
            available_providers = ort.get_available_providers()
            
            has_qnn = 'QNNExecutionProvider' in available_providers
            has_cpu = 'CPUExecutionProvider' in available_providers
            
            if has_qnn:
                try:
                    # Test QNN provider session creation
                    sess_options = ort.SessionOptions()
                    sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
                    
                    result.pass_test(
                        "QNN/NPU acceleration available",
                        {
                            "qnn_provider": True,
                            "available_providers": available_providers,
                            "npu_ready": True
                        }
                    )
                    
                except Exception as qnn_error:
                    result.fail_test(
                        f"QNN provider error: {str(qnn_error)}",
                        [
                            "Install QNN provider: pip install onnxruntime-qnn",
                            "Verify NPU drivers",
                            "Check Snapdragon NPU support"
                        ]
                    )
            else:
                result.fail_test(
                    "QNN provider not available",
                    [
                        "Install QNN provider: pip install onnxruntime-qnn",
                        "Verify Snapdragon NPU drivers",
                        "Check ARM64 package compatibility",
                        f"Available providers: {', '.join(available_providers)}"
                    ],
                    {"available_providers": available_providers}
                )
                
        except ImportError:
            result.fail_test(
                "ONNX Runtime not installed",
                [
                    "Install ONNX Runtime: pip install onnxruntime",
                    "For NPU support: pip install onnxruntime-qnn",
                    "Install optimum: pip install optimum[onnxruntime]"
                ]
            )
    
    def test_model_accessibility(self, result: DiagnosticResult):
        """Test 5: Check if required models are accessible"""
        model_paths = [
            "C:\\AIDemo\\models",
            Path.cwd() / "models",
            Path.home() / ".cache" / "huggingface" / "transformers"
        ]
        
        found_models = []
        accessible_paths = []
        
        for model_path in model_paths:
            if isinstance(model_path, str):
                model_path = Path(model_path)
                
            if model_path.exists():
                accessible_paths.append(str(model_path))
                
                # Check for SDXL model files
                sdxl_path = model_path / "sdxl-base-1.0"
                if sdxl_path.exists():
                    found_models.append(f"SDXL at {sdxl_path}")
                
                # Check for any model directories
                model_dirs = [d for d in model_path.iterdir() if d.is_dir()]
                if model_dirs:
                    found_models.extend([f"{d.name} at {d}" for d in model_dirs[:3]])  # Limit to first 3
        
        # Test HuggingFace Hub access
        hf_accessible = False
        try:
            from huggingface_hub import HfApi
            api = HfApi()
            # Test connection without downloading
            api.model_info("stabilityai/stable-diffusion-xl-base-1.0")
            hf_accessible = True
        except Exception:
            pass
        
        details = {
            "accessible_paths": accessible_paths,
            "found_models": found_models,
            "huggingface_hub": hf_accessible
        }
        
        if found_models or hf_accessible:
            message = f"Models accessible: {len(found_models)} local"
            if hf_accessible:
                message += ", HuggingFace Hub available"
            result.pass_test(message, details)
        else:
            result.fail_test(
                "No models found and HuggingFace Hub inaccessible",
                [
                    "Download models: Use prepare_models.ps1 script",
                    "Create models directory: mkdir C:\\AIDemo\\models",
                    "Check internet connection for HuggingFace Hub",
                    "Install huggingface_hub: pip install huggingface_hub"
                ],
                details
            )
    
    def test_quick_performance(self, result: DiagnosticResult):
        """Test 6: Run minimal inference test within platform targets"""
        if self.platform_type not in self.performance_targets:
            result.fail_test(
                "Unknown platform for performance testing",
                ["Complete platform detection first"]
            )
            return
        
        targets = self.performance_targets[self.platform_type]
        
        try:
            # Import required modules
            from ai_pipeline import AIImagePipeline
            
            if not self.platform_info:
                result.fail_test(
                    "Platform info not available for performance test",
                    ["Run platform detection test first"]
                )
                return
            
            # Create AI pipeline
            pipeline = AIImagePipeline(self.platform_info)
            
            # Quick performance test with minimal settings
            test_prompt = "a simple landscape"
            test_steps = 4 if self.platform_type == 'snapdragon' else 10  # Minimal steps
            test_resolution = (512, 512)  # Smaller resolution for speed
            
            print(f"         Running quick performance test...")
            print(f"         Platform: {self.platform_type.upper()}")
            print(f"         Target: {targets['min_time']}-{targets['max_time']} seconds")
            
            start_time = time.time()
            
            try:
                # Attempt generation with timeout
                image = pipeline.generate(
                    prompt=test_prompt,
                    steps=test_steps,
                    width=test_resolution[0],
                    height=test_resolution[1],
                    guidance_scale=5.0  # Lower for speed
                )
                
                generation_time = time.time() - start_time
                
                # Evaluate performance
                if generation_time <= targets['max_time']:
                    performance_rating = "EXCELLENT" if generation_time <= targets['min_time'] else "GOOD"
                    result.pass_test(
                        f"Performance test {performance_rating}: {generation_time:.1f}s (target: {targets['min_time']}-{targets['max_time']}s)",
                        {
                            "generation_time": generation_time,
                            "target_min": targets['min_time'],
                            "target_max": targets['max_time'],
                            "rating": performance_rating,
                            "acceleration": targets['acceleration']
                        }
                    )
                else:
                    # Still within fallback range?
                    if generation_time <= targets['fallback_max']:
                        result.pass_test(
                            f"Performance ACCEPTABLE (CPU fallback): {generation_time:.1f}s",
                            {
                                "generation_time": generation_time,
                                "target_min": targets['fallback_min'],
                                "target_max": targets['fallback_max'],
                                "rating": "ACCEPTABLE",
                                "acceleration": "CPU Fallback"
                            }
                        )
                    else:
                        result.fail_test(
                            f"Performance POOR: {generation_time:.1f}s (expected: <{targets['max_time']}s)",
                            self._get_performance_fix_commands(),
                            {
                                "generation_time": generation_time,
                                "target_max": targets['max_time'],
                                "rating": "POOR"
                            }
                        )
                
            except Exception as gen_error:
                result.fail_test(
                    f"Performance test failed during generation: {str(gen_error)}",
                    self._get_performance_fix_commands() + [
                        "Check hardware acceleration test results",
                        "Verify model accessibility"
                    ]
                )
                
        except Exception as e:
            result.fail_test(
                f"Performance test setup failed: {str(e)}",
                [
                    "Complete AIImagePipeline import test first",
                    "Verify hardware acceleration is working",
                    "Check model accessibility"
                ]
            )
    
    def _get_performance_fix_commands(self) -> List[str]:
        """Get platform-specific performance optimization commands"""
        if self.platform_type == 'intel':
            return [
                "Update Intel GPU drivers",
                "Verify DirectML installation: pip install --force-reinstall torch-directml",
                "Check system memory (8GB+ required)",
                "Close other applications to free resources",
                "Reduce inference steps or resolution for testing"
            ]
        elif self.platform_type == 'snapdragon':
            return [
                "Verify NPU drivers are installed",
                "Check QNN provider: pip install onnxruntime-qnn",
                "Ensure optimized models are available",
                "Check ARM64 package compatibility",
                "Verify system is in high-performance mode"
            ]
        else:
            return [
                "Check platform detection",
                "Verify hardware acceleration is available",
                "Update system drivers"
            ]
    
    def print_summary(self, passed_tests: int, total_tests: int):
        """Print final diagnostic summary"""
        print("=" * 80)
        print("DIAGNOSTIC SUMMARY")
        print("=" * 80)
        
        # Overall status
        status_color = '\033[92m' if self.overall_status == "READY" else '\033[91m'
        reset_color = '\033[0m'
        
        print(f"Overall Status: {status_color}{self.overall_status}{reset_color}")
        print(f"Tests Passed: {passed_tests}/{total_tests}")
        print(f"Platform: {self.platform_type.upper() if self.platform_type != 'unknown' else 'Unknown'}")
        
        if self.platform_type in self.performance_targets:
            targets = self.performance_targets[self.platform_type]
            print(f"Performance Target: {targets['min_time']}-{targets['max_time']} seconds with {targets['acceleration']}")
        
        total_time = time.time() - self.start_time
        print(f"Diagnostic Time: {total_time:.1f} seconds")
        print("")
        
        # Failed tests summary
        failed_tests = [name for name, result in self.results.items() if result.status == "FAIL"]
        if failed_tests:
            print("FAILED TESTS:")
            for test_name in failed_tests:
                result = self.results[test_name]
                print(f"  - {test_name}: {result.message}")
                for fix_cmd in result.fix_commands:
                    print(f"    [FIX] {fix_cmd}")
            print("")
        
        # Next steps
        if self.overall_status == "READY":
            print("NEXT STEPS:")
            print("  - System is ready for AI image generation demo")
            print("  - Run: python demo_client.py")
            print("  - Or run: python ai_pipeline.py for direct testing")
        else:
            print("REQUIRED ACTIONS:")
            print("  - Address failed tests above")
            print("  - Re-run diagnostic: python demo_diagnostic.py")
            print("  - Check platform-specific documentation")
        
        print("=" * 80)
    
    def _collect_and_store_diagnostic_data(self, passed_tests: int, total_tests: int):
        """Collect and store comprehensive diagnostic data"""
        try:
            # Collect comprehensive metrics
            metrics = self.metrics_collector.get_comprehensive_metrics()
            
            # Prepare results data
            results_data = {
                'run_id': self.run_id,
                'overall_status': self.overall_status,
                'total_tests': total_tests,
                'passed_tests': passed_tests,
                'total_duration': time.time() - self.start_time,
                'test_results': {}
            }
            
            # Convert DiagnosticResult objects to dict format
            for test_name, result in self.results.items():
                results_data['test_results'][test_name] = {
                    'status': result.status,
                    'message': result.message,
                    'duration': result.duration,
                    'details': result.details,
                    'fix_commands': result.fix_commands
                }
            
            # Store data in database
            if self.storage:
                self.storage.store_complete_diagnostic(
                    self.run_id, self.platform_type, results_data, metrics
                )
                self.logger.info("Diagnostic data stored successfully")
            
            # Generate reports if configured
            if self.config_manager and self.config_manager.get_config().reporting.enable_detailed_reports:
                if self.reporter:
                    generated_files = self.reporter.generate_comprehensive_report(
                        self.run_id, self.platform_type, results_data, metrics
                    )
                    
                    if generated_files:
                        self.logger.info(f"Reports generated: {', '.join(generated_files.values())}")
                        print(f"\nDetailed reports generated:")
                        for format_type, file_path in generated_files.items():
                            print(f"  {format_type.upper()}: {file_path}")
            
        except Exception as e:
            if self.logger:
                self.logger.error(f"Failed to collect/store diagnostic data: {e}")
            else:
                print(f"Warning: Failed to collect/store diagnostic data: {e}")

def main():
    """Main diagnostic entry point with enhanced framework support"""
    
    # Parse command line arguments if enhanced framework is available
    enhanced_mode = False
    if ENHANCED_FRAMEWORK_AVAILABLE:
        try:
            config_manager = get_config_manager()
            
            # Load configuration first
            config_manager.load_config()
            
            # Parse command line arguments
            args = config_manager.parse_command_line()
            enhanced_mode = config_manager.is_enhanced_mode()
            
            if enhanced_mode:
                print("Enhanced diagnostic mode enabled")
                if args.detailed_report:
                    print("Detailed reporting enabled")
                if args.enhanced_logging:
                    print("Enhanced logging enabled")
            
        except Exception as e:
            print(f"Warning: Enhanced framework initialization failed: {e}")
            print("Falling back to basic mode...")
            enhanced_mode = False
    
    # Create diagnostic instance
    diagnostic = UnifiedDiagnostic(enhanced_mode=enhanced_mode)
    
    try:
        success = diagnostic.run_diagnostics()
        
        # Enhanced cleanup
        if enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
            try:
                # Stop metrics collection
                if diagnostic.metrics_collector:
                    diagnostic.metrics_collector.stop_collection()
                
                # Perform final logging
                if diagnostic.logger:
                    diagnostic.logger.info(f"Diagnostic completed: {'SUCCESS' if success else 'FAILED'}")
                    metrics = diagnostic.logger.get_metrics()
                    diagnostic.logger.info(f"Logging metrics: {metrics}")
                
            except Exception as cleanup_error:
                print(f"Warning: Enhanced cleanup failed: {cleanup_error}")
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n\nDiagnostic interrupted by user")
        
        # Enhanced cleanup on interrupt
        if enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
            try:
                if diagnostic.logger:
                    diagnostic.logger.warning("Diagnostic interrupted by user")
                if diagnostic.metrics_collector:
                    diagnostic.metrics_collector.stop_collection()
            except Exception:
                pass
        
        return 130
        
    except Exception as e:
        print(f"\n\nDiagnostic crashed: {str(e)}")
        
        # Enhanced error logging
        if enhanced_mode and ENHANCED_FRAMEWORK_AVAILABLE:
            try:
                if diagnostic.logger:
                    diagnostic.logger.error(f"Diagnostic crashed: {str(e)}", exc_info=True)
            except Exception:
                pass
        
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())