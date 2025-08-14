#!/usr/bin/env python3
"""
AI Demo Dependency Verification Script

This script verifies that all required dependencies are properly installed
for both Snapdragon (NPU) and Intel (DirectML) AI pipelines.

Usage:
    python verify_dependencies.py [--platform snapdragon|intel|auto]
    python verify_dependencies.py --detailed
    python verify_dependencies.py --fix-suggestions
"""

import sys
import platform
import importlib
import subprocess
from typing import Dict, List, Tuple, Optional
import argparse
from pathlib import Path


class DependencyVerifier:
    def __init__(self):
        self.platform_type = self.detect_platform()
        self.results = {
            'core': [],
            'platform_specific': [],
            'acceleration': [],
            'missing': [],
            'errors': []
        }
        
    def detect_platform(self) -> str:
        """Detect if we're on Snapdragon or Intel platform."""
        machine = platform.machine().upper()
        processor = platform.processor().lower()
        
        if 'ARM' in machine or 'ARM64' in machine or 'snapdragon' in processor or 'qualcomm' in processor:
            return 'snapdragon'
        elif 'AMD64' in machine or 'X86_64' in machine or 'intel' in processor:
            return 'intel'
        else:
            return 'unknown'
    
    def check_python_version(self) -> bool:
        """Check if Python version is compatible."""
        version = sys.version_info
        compatible = (3, 9) <= (version.major, version.minor) < (3, 11)
        
        status = "✅ COMPATIBLE" if compatible else "❌ INCOMPATIBLE"
        self.results['core'].append(f"Python {version.major}.{version.minor}: {status}")
        
        if not compatible:
            self.results['errors'].append(
                f"Python {version.major}.{version.minor} detected. Required: 3.9-3.10"
            )
        
        return compatible
    
    def check_package(self, package_name: str, import_name: Optional[str] = None) -> Tuple[bool, str]:
        """Check if a package is installed and importable."""
        import_name = import_name or package_name
        
        try:
            module = importlib.import_module(import_name)
            version = getattr(module, '__version__', 'unknown')
            return True, version
        except ImportError as e:
            return False, str(e)
    
    def verify_core_dependencies(self) -> int:
        """Verify core dependencies required by all platforms."""
        print("🔍 Checking Core Dependencies...")
        
        core_packages = [
            ('numpy', 'numpy'),
            ('pillow', 'PIL'),
            ('requests', 'requests'),
            ('psutil', 'psutil'),
            ('flask', 'flask'),
            ('flask-socketio', 'flask_socketio'),
            ('torch', 'torch'),
            ('torchvision', 'torchvision'),
            ('diffusers', 'diffusers'),
            ('transformers', 'transformers'),
            ('huggingface_hub', 'huggingface_hub'),
            ('accelerate', 'accelerate'),
            ('safetensors', 'safetensors'),
            ('onnxruntime', 'onnxruntime'),
            ('optimum', 'optimum')
        ]
        
        missing_count = 0
        
        for package_name, import_name in core_packages:
            available, version_or_error = self.check_package(package_name, import_name)
            
            if available:
                self.results['core'].append(f"✅ {package_name}: {version_or_error}")
                print(f"  ✅ {package_name}: {version_or_error}")
            else:
                self.results['missing'].append(f"❌ {package_name}: Missing")
                print(f"  ❌ {package_name}: Missing")
                missing_count += 1
        
        return missing_count
    
    def verify_snapdragon_acceleration(self) -> bool:
        """Verify Snapdragon NPU acceleration capabilities."""
        print("\n🔥 Checking Snapdragon NPU Acceleration...")
        
        # Check ONNX Runtime QNN support
        try:
            import onnxruntime as ort
            providers = ort.get_available_providers()
            
            qnn_available = 'QNNExecutionProvider' in providers
            
            if qnn_available:
                self.results['acceleration'].append("✅ QNN ExecutionProvider: Available")
                print("  ✅ QNN ExecutionProvider: Available")
            else:
                self.results['acceleration'].append("⚠️ QNN ExecutionProvider: Not available (CPU fallback)")
                print("  ⚠️ QNN ExecutionProvider: Not available (CPU fallback)")
            
            # List all available providers
            self.results['platform_specific'].append(f"ONNX Providers: {', '.join(providers)}")
            print(f"  📋 Available ONNX Providers: {', '.join(providers)}")
            
        except ImportError:
            self.results['errors'].append("ONNX Runtime not installed")
            print("  ❌ ONNX Runtime: Not installed")
            return False
        
        # Check optional Snapdragon packages
        optional_packages = [
            ('onnxruntime-qnn', 'onnxruntime'),  # QNN backend
            ('qai-hub', 'qai_hub'),              # Qualcomm AI Hub
            ('winml', 'winml')                   # Windows ML
        ]
        
        for package_name, import_name in optional_packages:
            available, version_or_error = self.check_package(package_name, import_name)
            if available:
                self.results['platform_specific'].append(f"✅ {package_name}: {version_or_error}")
                print(f"  ✅ {package_name}: {version_or_error}")
            else:
                self.results['platform_specific'].append(f"⚠️ {package_name}: Not available")
                print(f"  ⚠️ {package_name}: Not available")
        
        return True
    
    def verify_intel_acceleration(self) -> bool:
        """Verify Intel DirectML acceleration capabilities."""
        print("\n⚡ Checking Intel DirectML Acceleration...")
        
        # Check DirectML availability
        try:
            import torch_directml
            
            directml_available = torch_directml.is_available()
            
            if directml_available:
                device_name = torch_directml.device_name(0)
                self.results['acceleration'].append(f"✅ DirectML: Available ({device_name})")
                print(f"  ✅ DirectML: Available ({device_name})")
            else:
                self.results['acceleration'].append("❌ DirectML: Device not available")
                print("  ❌ DirectML: Device not available")
            
        except ImportError:
            self.results['errors'].append("torch-directml not installed")
            print("  ❌ torch-directml: Not installed")
            return False
        
        # Check ONNX Runtime DirectML
        try:
            import onnxruntime as ort
            providers = ort.get_available_providers()
            
            directml_onnx = 'DmlExecutionProvider' in providers
            
            if directml_onnx:
                self.results['platform_specific'].append("✅ ONNX DirectML: Available")
                print("  ✅ ONNX DirectML: Available")
            else:
                self.results['platform_specific'].append("⚠️ ONNX DirectML: Not available")
                print("  ⚠️ ONNX DirectML: Not available")
            
            # List all available providers
            self.results['platform_specific'].append(f"ONNX Providers: {', '.join(providers)}")
            print(f"  📋 Available ONNX Providers: {', '.join(providers)}")
            
        except ImportError:
            self.results['errors'].append("ONNX Runtime not available")
            print("  ❌ ONNX Runtime: Not available")
        
        # Check Intel-specific optimizations
        optional_packages = [
            ('intel-extension-for-pytorch', 'intel_extension_for_pytorch')
        ]
        
        for package_name, import_name in optional_packages:
            available, version_or_error = self.check_package(package_name, import_name)
            if available:
                self.results['platform_specific'].append(f"✅ {package_name}: {version_or_error}")
                print(f"  ✅ {package_name}: {version_or_error}")
            else:
                self.results['platform_specific'].append(f"⚠️ {package_name}: Not available")
                print(f"  ⚠️ {package_name}: Not available")
        
        return True
    
    def test_basic_functionality(self) -> bool:
        """Test basic AI pipeline functionality."""
        print("\n🧪 Testing Basic AI Pipeline...")
        
        try:
            # Test PyTorch tensor creation
            import torch
            tensor = torch.randn(2, 3)
            self.results['acceleration'].append("✅ PyTorch tensor operations: Working")
            print("  ✅ PyTorch tensor operations: Working")
            
            # Test diffusers import
            from diffusers import DiffusionPipeline
            self.results['acceleration'].append("✅ Diffusers pipeline import: Working")
            print("  ✅ Diffusers pipeline import: Working")
            
            # Test ONNX Runtime
            import onnxruntime as ort
            session_options = ort.SessionOptions()
            self.results['acceleration'].append("✅ ONNX Runtime session: Working")
            print("  ✅ ONNX Runtime session: Working")
            
            return True
            
        except Exception as e:
            self.results['errors'].append(f"Basic functionality test failed: {str(e)}")
            print(f"  ❌ Basic functionality test failed: {str(e)}")
            return False
    
    def generate_fix_suggestions(self) -> List[str]:
        """Generate suggestions for fixing detected issues."""
        suggestions = []
        
        if self.results['missing']:
            suggestions.append("📦 MISSING PACKAGES:")
            suggestions.append("Run one of these commands:")
            
            if self.platform_type == 'snapdragon':
                suggestions.append("  poetry install --extras snapdragon")
                suggestions.append("  pip install -r requirements-snapdragon.txt")
            elif self.platform_type == 'intel':
                suggestions.append("  poetry install --extras intel")
                suggestions.append("  pip install -r requirements-intel.txt")
            else:
                suggestions.append("  poetry install")
                suggestions.append("  pip install -r requirements-core.txt")
            
            suggestions.append("")
        
        if self.results['errors']:
            suggestions.append("🔧 PLATFORM-SPECIFIC ISSUES:")
            
            if 'DirectML' in ' '.join(self.results['errors']):
                suggestions.extend([
                    "DirectML Issues:",
                    "- Ensure Windows 10 1903+ or Windows 11",
                    "- Update GPU drivers to latest version",
                    "- Install Visual C++ 2019 Redistributable",
                    "- Check DirectX 12 support: dxdiag",
                    ""
                ])
            
            if 'QNN' in ' '.join(self.results['errors']):
                suggestions.extend([
                    "Snapdragon NPU Issues:",
                    "- Download Qualcomm AI Engine from developer portal",
                    "- Install Windows 11 ARM64 latest updates",
                    "- Check NPU drivers in Device Manager",
                    ""
                ])
        
        # CPU fallback suggestion
        suggestions.extend([
            "🚀 CPU-ONLY FALLBACK:",
            "If acceleration isn't working, you can still run the demo:",
            "  pip install -r requirements-cpu-fallback.txt",
            "Performance will be slower but functional.",
            ""
        ])
        
        return suggestions
    
    def print_summary(self, detailed: bool = False):
        """Print verification summary."""
        print("\n" + "="*60)
        print(f"🎯 DEPENDENCY VERIFICATION SUMMARY")
        print("="*60)
        print(f"Platform Detected: {self.platform_type.upper()}")
        print(f"Python Version: {sys.version.split()[0]}")
        
        # Core dependencies status
        missing_core = len(self.results['missing'])
        total_core = len(self.results['core']) + missing_core
        
        if missing_core == 0:
            print(f"✅ Core Dependencies: {total_core}/{total_core} installed")
        else:
            print(f"❌ Core Dependencies: {total_core-missing_core}/{total_core} installed")
        
        # Platform-specific status
        if self.results['acceleration']:
            acceleration_working = any('✅' in item and ('DirectML' in item or 'QNN' in item) 
                                    for item in self.results['acceleration'])
            if acceleration_working:
                print(f"✅ AI Acceleration: Working")
            else:
                print(f"⚠️ AI Acceleration: CPU fallback")
        
        if detailed:
            print("\n📋 DETAILED RESULTS:")
            
            if self.results['core']:
                print("\nCore Dependencies:")
                for item in self.results['core']:
                    print(f"  {item}")
            
            if self.results['platform_specific']:
                print(f"\n{self.platform_type.title()} Platform:")
                for item in self.results['platform_specific']:
                    print(f"  {item}")
            
            if self.results['acceleration']:
                print("\nAcceleration Status:")
                for item in self.results['acceleration']:
                    print(f"  {item}")
        
        if self.results['missing'] or self.results['errors']:
            print(f"\n⚠️  ISSUES DETECTED:")
            for item in self.results['missing'] + self.results['errors']:
                print(f"  {item}")
        
        print("="*60)


def main():
    parser = argparse.ArgumentParser(description="Verify AI Demo dependencies")
    parser.add_argument('--platform', choices=['snapdragon', 'intel', 'auto'], 
                       default='auto', help='Target platform')
    parser.add_argument('--detailed', action='store_true', 
                       help='Show detailed dependency information')
    parser.add_argument('--fix-suggestions', action='store_true',
                       help='Show suggestions for fixing issues')
    
    args = parser.parse_args()
    
    verifier = DependencyVerifier()
    
    print("🔍 AI Demo Dependency Verification")
    print(f"Platform: {verifier.platform_type.upper()}")
    print("-" * 40)
    
    # Check Python version first
    if not verifier.check_python_version():
        print("\n❌ Python version incompatible. Please install Python 3.9 or 3.10")
        return 1
    
    # Check core dependencies
    missing_core = verifier.verify_core_dependencies()
    
    # Check platform-specific acceleration
    if args.platform == 'auto':
        target_platform = verifier.platform_type
    else:
        target_platform = args.platform
    
    if target_platform == 'snapdragon':
        verifier.verify_snapdragon_acceleration()
    elif target_platform == 'intel':
        verifier.verify_intel_acceleration()
    
    # Test basic functionality
    verifier.test_basic_functionality()
    
    # Print summary
    verifier.print_summary(detailed=args.detailed)
    
    # Show fix suggestions if requested or if there are issues
    if args.fix_suggestions or verifier.results['missing'] or verifier.results['errors']:
        print("\n🛠️  FIX SUGGESTIONS:")
        suggestions = verifier.generate_fix_suggestions()
        for suggestion in suggestions:
            print(suggestion)
    
    # Return appropriate exit code
    if missing_core > 0 or verifier.results['errors']:
        return 1
    else:
        return 0


if __name__ == "__main__":
    sys.exit(main())