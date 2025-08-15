#!/usr/bin/env python3
"""
Environment Validation for Intel AI Demo
Comprehensive checks for DirectML, models, and system readiness
"""

import os
import sys
import logging
import json
import time
from typing import Dict, Any, List, Tuple
from pathlib import Path
import psutil

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class IntelEnvironmentValidator:
    """Validates Intel demo environment readiness"""
    
    def __init__(self, model_path: str = "C:\\AIDemo\\models", client_path: str = "C:\\AIDemo\\client"):
        self.model_path = Path(model_path)
        self.client_path = Path(client_path)
        self.validation_results = {}
        self.overall_status = False
        self.error_count = 0
        self.warning_count = 0
        
        # Intel-specific requirements
        self.requirements = {
            "python_version": "3.10",
            "min_memory_gb": 12,
            "min_disk_space_gb": 8,
            "required_packages": [
                "torch", "torch_directml", "diffusers", "transformers",
                "huggingface_hub", "PIL", "flask", "psutil", "numpy"
            ],
            "model_files": [
                "sdxl-base-1.0/unet/diffusion_pytorch_model.fp16.safetensors",
                "sdxl-base-1.0/vae/diffusion_pytorch_model.fp16.safetensors",
                "sdxl-base-1.0/text_encoder/model.safetensors",
                "sdxl-base-1.0/text_encoder_2/model.safetensors"
            ],
            "config_files": [
                "sdxl-base-1.0/model_index.json",
                "sdxl-base-1.0/scheduler/scheduler_config.json"
            ]
        }
    
    def validate_all(self) -> Dict[str, Any]:
        """Run comprehensive environment validation"""
        logger.info("Starting comprehensive Intel environment validation...")
        
        start_time = time.time()
        
        # Run all validation checks
        checks = [
            ("Python Environment", self._check_python_environment),
            ("System Resources", self._check_system_resources),
            ("DirectML Availability", self._check_directml),
            ("Required Packages", self._check_packages),
            ("Model Files", self._check_model_files),
            ("Intel Configuration", self._check_intel_config),
            ("Performance Baseline", self._check_performance_baseline)
        ]
        
        for check_name, check_function in checks:
            try:
                logger.info(f"Running check: {check_name}")
                result = check_function()
                self.validation_results[check_name] = result
                
                if not result["status"]:
                    self.error_count += 1
                elif result.get("warnings"):
                    self.warning_count += 1
                    
            except Exception as e:
                logger.error(f"Check failed: {check_name} - {e}")
                self.validation_results[check_name] = {
                    "status": False,
                    "error": str(e),
                    "critical": True
                }
                self.error_count += 1
        
        # Determine overall status
        self.overall_status = self.error_count == 0
        
        validation_time = time.time() - start_time
        
        # Generate summary
        summary = {
            "overall_ready": self.overall_status,
            "validation_time": round(validation_time, 2),
            "checks_passed": len(checks) - self.error_count,
            "total_checks": len(checks),
            "error_count": self.error_count,
            "warning_count": self.warning_count,
            "platform": "intel",
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "details": self.validation_results
        }
        
        logger.info(f"Validation complete: {summary['checks_passed']}/{summary['total_checks']} checks passed")
        return summary
    
    def _check_python_environment(self) -> Dict[str, Any]:
        """Check Python version and virtual environment"""
        result = {"status": False, "details": {}}
        
        try:
            # Check Python version
            python_version = f"{sys.version_info.major}.{sys.version_info.minor}"
            result["details"]["python_version"] = python_version
            result["details"]["python_executable"] = sys.executable
            
            if python_version == self.requirements["python_version"]:
                result["details"]["version_check"] = "✅ Python 3.10 detected"
            else:
                result["details"]["version_check"] = f"❌ Python {python_version} (requires 3.10)"
                result["error"] = f"Wrong Python version: {python_version}"
                return result
            
            # Check virtual environment
            in_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix)
            result["details"]["virtual_env"] = "✅ Virtual environment active" if in_venv else "⚠️ Not in virtual environment"
            
            # Check pip availability
            try:
                import pip
                result["details"]["pip_available"] = "✅ pip available"
            except ImportError:
                result["details"]["pip_available"] = "❌ pip not available"
                result["error"] = "pip not available"
                return result
            
            result["status"] = True
            
        except Exception as e:
            result["error"] = f"Python environment check failed: {e}"
            
        return result
    
    def _check_system_resources(self) -> Dict[str, Any]:
        """Check system memory, disk space, and CPU"""
        result = {"status": False, "details": {}, "warnings": []}
        
        try:
            # Memory check
            memory = psutil.virtual_memory()
            memory_gb = memory.total / (1024**3)
            result["details"]["total_memory_gb"] = round(memory_gb, 1)
            result["details"]["available_memory_gb"] = round(memory.available / (1024**3), 1)
            
            if memory_gb >= self.requirements["min_memory_gb"]:
                result["details"]["memory_check"] = f"✅ {memory_gb:.1f}GB RAM (sufficient)"
            else:
                result["details"]["memory_check"] = f"❌ {memory_gb:.1f}GB RAM (requires {self.requirements['min_memory_gb']}GB)"
                result["error"] = f"Insufficient memory: {memory_gb:.1f}GB"
                return result
            
            # Disk space check
            disk = psutil.disk_usage('C:')
            free_space_gb = disk.free / (1024**3)
            result["details"]["free_disk_space_gb"] = round(free_space_gb, 1)
            
            if free_space_gb >= self.requirements["min_disk_space_gb"]:
                result["details"]["disk_check"] = f"✅ {free_space_gb:.1f}GB free space"
            else:
                result["details"]["disk_check"] = f"❌ {free_space_gb:.1f}GB free (requires {self.requirements['min_disk_space_gb']}GB)"
                result["error"] = f"Insufficient disk space: {free_space_gb:.1f}GB"
                return result
            
            # CPU check
            cpu_count = psutil.cpu_count()
            cpu_freq = psutil.cpu_freq()
            result["details"]["cpu_cores"] = cpu_count
            result["details"]["cpu_freq_mhz"] = round(cpu_freq.max) if cpu_freq else "Unknown"
            
            if cpu_count >= 4:
                result["details"]["cpu_check"] = f"✅ {cpu_count} CPU cores"
            else:
                result["details"]["cpu_check"] = f"⚠️ {cpu_count} CPU cores (4+ recommended)"
                result["warnings"].append(f"Low CPU core count: {cpu_count}")
            
            result["status"] = True
            
        except Exception as e:
            result["error"] = f"System resources check failed: {e}"
            
        return result
    
    def _check_directml(self) -> Dict[str, Any]:
        """Check DirectML availability and functionality"""
        result = {"status": False, "details": {}}
        
        try:
            # Check DirectML import
            try:
                import torch_directml
                result["details"]["directml_import"] = "✅ torch-directml imported"
                
                if hasattr(torch_directml, '__version__'):
                    result["details"]["directml_version"] = torch_directml.__version__
                
            except ImportError as e:
                result["details"]["directml_import"] = f"❌ torch-directml not available: {e}"
                result["error"] = "DirectML not installed"
                return result
            
            # Check DirectML device availability
            try:
                if torch_directml.is_available():
                    device = torch_directml.device()
                    device_name = torch_directml.device_name(0)
                    result["details"]["directml_device"] = f"✅ Device: {device_name}"
                    result["details"]["device_object"] = str(device)
                else:
                    result["details"]["directml_device"] = "❌ DirectML device not available"
                    result["error"] = "DirectML device not accessible"
                    return result
                    
            except Exception as e:
                result["details"]["directml_device"] = f"❌ Device check failed: {e}"
                result["error"] = f"DirectML device error: {e}"
                return result
            
            # Test basic tensor operations
            try:
                import torch
                test_tensor = torch.ones(10, 10)
                dml_device = torch_directml.device()
                gpu_tensor = test_tensor.to(dml_device)
                
                # Simple operation test
                result_tensor = torch.mm(gpu_tensor, gpu_tensor)
                
                result["details"]["tensor_operations"] = "✅ DirectML tensor operations working"
                result["status"] = True
                
            except Exception as e:
                result["details"]["tensor_operations"] = f"❌ Tensor operations failed: {e}"
                result["error"] = f"DirectML functionality error: {e}"
                return result
            
        except Exception as e:
            result["error"] = f"DirectML check failed: {e}"
            
        return result
    
    def _check_packages(self) -> Dict[str, Any]:
        """Check required Python packages"""
        result = {"status": True, "details": {}, "warnings": []}
        
        missing_packages = []
        
        for package in self.requirements["required_packages"]:
            try:
                if package == "PIL":
                    import PIL
                    result["details"][package] = f"✅ {PIL.__version__}"
                elif package == "torch_directml":
                    import torch_directml
                    version = getattr(torch_directml, '__version__', 'Unknown')
                    result["details"][package] = f"✅ {version}"
                else:
                    imported_module = __import__(package)
                    version = getattr(imported_module, '__version__', 'Unknown')
                    result["details"][package] = f"✅ {version}"
                    
            except ImportError:
                missing_packages.append(package)
                result["details"][package] = "❌ Not installed"
        
        if missing_packages:
            result["status"] = False
            result["error"] = f"Missing packages: {', '.join(missing_packages)}"
        
        return result
    
    def _check_model_files(self) -> Dict[str, Any]:
        """Check SDXL model files"""
        result = {"status": True, "details": {}, "warnings": []}
        
        missing_files = []
        total_size = 0
        
        # Check main model files
        for model_file in self.requirements["model_files"]:
            file_path = self.model_path / model_file
            
            if file_path.exists():
                file_size = file_path.stat().st_size
                size_mb = file_size / (1024 * 1024)
                total_size += size_mb
                result["details"][model_file] = f"✅ {size_mb:.1f}MB"
            else:
                missing_files.append(model_file)
                result["details"][model_file] = "❌ Missing"
        
        # Check config files
        for config_file in self.requirements["config_files"]:
            file_path = self.model_path / config_file
            
            if file_path.exists():
                result["details"][config_file] = "✅ Available"
            else:
                result["warnings"].append(f"Missing config: {config_file}")
                result["details"][config_file] = "⚠️ Missing (non-critical)"
        
        result["details"]["total_model_size_mb"] = round(total_size, 1)
        result["details"]["total_model_size_gb"] = round(total_size / 1024, 2)
        
        if missing_files:
            result["status"] = False
            result["error"] = f"Missing model files: {', '.join(missing_files)}"
        elif total_size < 6000:  # Less than 6GB suggests incomplete download
            result["status"] = False
            result["error"] = f"Models appear incomplete: {total_size:.1f}MB (expected ~6900MB)"
        
        return result
    
    def _check_intel_config(self) -> Dict[str, Any]:
        """Check Intel-specific configuration"""
        result = {"status": True, "details": {}, "warnings": []}
        
        # Check environment variables
        intel_env_vars = {
            "ORT_DIRECTML_DEVICE_ID": "0",
            "MKL_ENABLE_INSTRUCTIONS": "AVX512",
            "INTEL_OPTIMIZED": "1"
        }
        
        for var, expected in intel_env_vars.items():
            actual = os.environ.get(var)
            if actual == expected:
                result["details"][var] = f"✅ {actual}"
            elif actual:
                result["details"][var] = f"⚠️ {actual} (expected: {expected})"
                result["warnings"].append(f"Environment variable {var} not optimized")
            else:
                result["details"][var] = f"❌ Not set (should be: {expected})"
                result["warnings"].append(f"Missing environment variable: {var}")
        
        # Check Intel config file
        config_path = self.client_path / "intel_config.json"
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    config = json.load(f)
                
                result["details"]["config_file"] = "✅ Intel configuration loaded"
                result["details"]["optimization_profile"] = config.get("optimization_profile", "Unknown")
                result["details"]["directml_enabled"] = "✅" if config.get("directml_enabled") else "❌"
                
            except Exception as e:
                result["details"]["config_file"] = f"⚠️ Config file error: {e}"
                result["warnings"].append("Intel configuration file has issues")
        else:
            result["details"]["config_file"] = "⚠️ Intel config not found"
            result["warnings"].append("Intel configuration file missing")
        
        return result
    
    def _check_performance_baseline(self) -> Dict[str, Any]:
        """Run a quick performance baseline test"""
        result = {"status": False, "details": {}}
        
        try:
            # Test basic DirectML functionality
            import torch
            import torch_directml
            
            if not torch_directml.is_available():
                result["error"] = "DirectML not available for performance test"
                return result
            
            device = torch_directml.device()
            
            # Quick tensor operation benchmark
            logger.info("Running DirectML performance baseline...")
            start_time = time.time()
            
            # Create test tensors
            test_size = 512
            tensor_a = torch.randn(test_size, test_size).to(device)
            tensor_b = torch.randn(test_size, test_size).to(device)
            
            # Perform matrix multiplication (common AI operation)
            for _ in range(10):
                result_tensor = torch.mm(tensor_a, tensor_b)
            
            torch_directml.synchronize()  # Ensure GPU operations complete
            
            baseline_time = time.time() - start_time
            operations_per_second = 10 / baseline_time
            
            result["details"]["baseline_time_ms"] = round(baseline_time * 1000, 1)
            result["details"]["operations_per_second"] = round(operations_per_second, 1)
            
            # Performance assessment
            if operations_per_second > 50:
                result["details"]["performance_assessment"] = "✅ Excellent DirectML performance"
                result["status"] = True
            elif operations_per_second > 20:
                result["details"]["performance_assessment"] = "✅ Good DirectML performance"
                result["status"] = True
            else:
                result["details"]["performance_assessment"] = "⚠️ DirectML performance below optimal"
                result["warnings"] = ["DirectML performance may be suboptimal"]
                result["status"] = True  # Still functional
            
        except Exception as e:
            result["error"] = f"Performance baseline failed: {e}"
            result["details"]["performance_assessment"] = "❌ Could not test DirectML performance"
        
        return result
    
    def get_readiness_status(self) -> Tuple[str, str, str]:
        """Get simple readiness status for UI display"""
        if not hasattr(self, 'validation_results') or not self.validation_results:
            return "🟡", "CHECKING", "Validating environment..."
        
        if self.overall_status:
            return "🟢", "READY", "All systems operational"
        elif self.error_count == 0 and self.warning_count > 0:
            return "🟡", "READY*", f"Ready with {self.warning_count} warnings"
        else:
            return "🔴", "NOT READY", f"{self.error_count} critical issues"
    
    def get_performance_expectations(self) -> Dict[str, Any]:
        """Get Intel-specific performance expectations"""
        
        # Check if DirectML is functional
        directml_status = self.validation_results.get("DirectML Availability", {})
        has_directml = directml_status.get("status", False)
        
        if has_directml:
            return {
                "expected_time_range": "35-45 seconds",
                "expected_time_min": 35,
                "expected_time_max": 45,
                "acceleration": "DirectML GPU",
                "performance_tier": "High Performance",
                "power_usage": "25-35W",
                "memory_usage": "8-10GB"
            }
        else:
            return {
                "expected_time_range": "120-180 seconds",
                "expected_time_min": 120,
                "expected_time_max": 180,
                "acceleration": "CPU Only",
                "performance_tier": "CPU Fallback",
                "power_usage": "45-65W",
                "memory_usage": "6-8GB"
            }
    
    def save_validation_report(self, filepath: str = None):
        """Save validation report to file"""
        if not filepath:
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filepath = self.client_path / f"intel_validation_report_{timestamp}.json"
        
        report = {
            "validation_summary": {
                "overall_ready": self.overall_status,
                "error_count": self.error_count,
                "warning_count": self.warning_count,
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
            },
            "system_info": {
                "platform": "intel",
                "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
                "python_executable": sys.executable
            },
            "validation_results": self.validation_results,
            "performance_expectations": self.get_performance_expectations()
        }
        
        try:
            with open(filepath, 'w') as f:
                json.dump(report, f, indent=2)
            logger.info(f"Validation report saved: {filepath}")
        except Exception as e:
            logger.error(f"Could not save validation report: {e}")

def validate_intel_environment() -> Dict[str, Any]:
    """Standalone function to validate Intel environment"""
    validator = IntelEnvironmentValidator()
    return validator.validate_all()

def get_environment_status() -> Tuple[str, str, str]:
    """Quick environment status check for UI"""
    try:
        validator = IntelEnvironmentValidator()
        validator.validate_all()
        return validator.get_readiness_status()
    except Exception as e:
        logger.error(f"Environment status check failed: {e}")
        return "🔴", "ERROR", f"Validation failed: {str(e)[:30]}..."

def main():
    """Main function for standalone execution"""
    print("Intel Environment Validator")
    print("=" * 50)
    
    validator = IntelEnvironmentValidator()
    results = validator.validate_all()
    
    # Print summary
    icon, status, message = validator.get_readiness_status()
    print(f"\nStatus: {icon} {status}")
    print(f"Message: {message}")
    print(f"Checks: {results['checks_passed']}/{results['total_checks']} passed")
    
    if results['error_count'] > 0:
        print(f"Errors: {results['error_count']}")
    
    if results['warning_count'] > 0:
        print(f"Warnings: {results['warning_count']}")
    
    # Save report
    validator.save_validation_report()
    
    return validator.overall_status

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
