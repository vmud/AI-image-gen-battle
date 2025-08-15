#!/usr/bin/env python3
"""
Intel AI Demo Launcher
Comprehensive launcher with environment validation and error handling
"""

import sys
import os
import time
import logging
from pathlib import Path

def setup_logging():
    """Setup logging for the launcher"""
    log_path = Path("C:/AIDemo/logs")
    log_path.mkdir(exist_ok=True)
    
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    log_file = log_path / f"intel_demo_launch_{timestamp}.log"
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    
    return logging.getLogger(__name__)

def validate_environment():
    """Quick environment validation before launch"""
    logger = logging.getLogger(__name__)
    
    print("🔍 Validating Intel demo environment...")
    
    # Check Python version
    if sys.version_info[:2] != (3, 10):
        print(f"❌ Wrong Python version: {sys.version_info[:2]} (requires 3.10)")
        return False
    
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor} detected")
    
    # Check current directory
    current_dir = Path.cwd()
    expected_files = ["demo_client.py", "ai_pipeline.py", "platform_detection.py", "environment_validator.py"]
    
    missing_files = []
    for file in expected_files:
        if not (current_dir / file).exists():
            missing_files.append(file)
    
    if missing_files:
        print(f"❌ Missing demo files: {', '.join(missing_files)}")
        print(f"Current directory: {current_dir}")
        return False
    
    print("✅ All demo files present")
    
    # Check for models
    models_path = Path("C:/AIDemo/models/sdxl-base-1.0")
    if not models_path.exists():
        print("⚠️  Models directory not found - demo may run slowly without pre-downloaded models")
    else:
        print("✅ Models directory found")
    
    # Quick DirectML check
    try:
        import torch_directml
        if torch_directml.is_available():
            print("✅ DirectML acceleration available")
        else:
            print("⚠️  DirectML available but no device detected")
    except ImportError:
        print("⚠️  DirectML not installed - will use CPU fallback")
    
    return True

def set_intel_environment():
    """Set Intel-specific environment variables"""
    logger = logging.getLogger(__name__)
    
    intel_env = {
        'PYTHONPATH': str(Path.cwd()),
        'INTEL_OPTIMIZED': '1',
        'ORT_DIRECTML_DEVICE_ID': '0',
        'ORT_DIRECTML_MEMORY_ARENA': '1',
        'ORT_DIRECTML_GRAPH_OPTIMIZATION': 'ALL',
        'MKL_ENABLE_INSTRUCTIONS': 'AVX512',
        'MKL_DYNAMIC': 'FALSE',
        'MKL_NUM_THREADS': str(max(4, os.cpu_count() // 2)),
        'OMP_NUM_THREADS': str(os.cpu_count())
    }
    
    print("⚙️  Setting Intel optimization environment...")
    
    for var, value in intel_env.items():
        os.environ[var] = value
        logger.info(f"Set {var}={value}")
    
    print("✅ Intel environment optimized")

def launch_demo():
    """Launch the Intel AI demo"""
    logger = logging.getLogger(__name__)
    
    print("\n" + "="*60)
    print("🚀 LAUNCHING INTEL AI DEMO")
    print("="*60)
    
    try:
        # Import and run the demo
        print("Loading demo modules...")
        
        # Set up the path
        sys.path.insert(0, str(Path.cwd()))
        
        # Import modules
        from platform_detection import PlatformDetector
        from demo_client import DemoDisplay, NetworkServer
        import threading
        
        print("✅ Demo modules loaded successfully")
        
        # Detect platform
        print("Detecting platform...")
        detector = PlatformDetector()
        platform_info = detector.detect_hardware()
        optimization_config = detector.get_optimization_config()
        detector.apply_optimizations()
        
        print(f"✅ Platform: {platform_info['platform_type'].upper()}")
        print(f"   Processor: {platform_info.get('processor_model', 'Unknown')}")
        print(f"   Acceleration: {platform_info.get('ai_acceleration', 'Unknown')}")
        
        # Create and launch demo
        print("Starting demo display...")
        display = DemoDisplay(platform_info)
        
        # Start network server
        print("Starting network server...")
        server = NetworkServer(display)
        server_thread = threading.Thread(
            target=server.run,
            kwargs={'host': '0.0.0.0', 'port': 5000},
            daemon=True
        )
        server_thread.start()
        
        print("\n" + "="*60)
        print("✅ INTEL AI DEMO READY!")
        print("="*60)
        print("🎮 Controls:")
        print("   • F11: Toggle fullscreen")
        print("   • ESC: Exit fullscreen")
        print("   • Local Test button: Test image generation")
        print("🌐 Network:")
        print("   • Server running on port 5000")
        print("   • Remote control enabled")
        print("🔥 Expected Performance:")
        print("   • DirectML: 35-45 seconds per image")
        print("   • CPU Fallback: 120-180 seconds per image")
        print("="*60)
        
        # Run the demo
        display.run()
        
    except ImportError as e:
        logger.error(f"Failed to import demo modules: {e}")
        print(f"❌ Import error: {e}")
        print("\n🔧 Troubleshooting steps:")
        print("1. Ensure prepare_intel.ps1 completed successfully")
        print("2. Check that all Python packages are installed")
        print("3. Verify virtual environment is activated")
        return False
        
    except Exception as e:
        logger.error(f"Demo launch failed: {e}")
        print(f"❌ Launch error: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

def main():
    """Main launcher function"""
    
    # Setup logging
    logger = setup_logging()
    
    print("🎯 Intel AI Image Generation Demo Launcher")
    print("🔧 DirectML GPU-Accelerated • Intel Core Ultra Optimized")
    print("-" * 60)
    
    # Validate environment
    if not validate_environment():
        print("\n❌ Environment validation failed!")
        print("\n🔧 Please run the following to fix issues:")
        print("   deployment/intel/scripts/prepare_intel.ps1")
        input("\nPress Enter to exit...")
        sys.exit(1)
    
    print("✅ Environment validation passed")
    
    # Set Intel optimizations
    set_intel_environment()
    
    # Launch demo
    print("\n🚀 Starting Intel AI demo...")
    
    try:
        success = launch_demo()
        if not success:
            input("\nPress Enter to exit...")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n\n👋 Demo terminated by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        print(f"\n❌ Unexpected error: {e}")
        input("\nPress Enter to exit...")
        sys.exit(1)

if __name__ == "__main__":
    main()
