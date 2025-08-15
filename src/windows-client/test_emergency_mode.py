#!/usr/bin/env python3
"""
Test script for Emergency Simulation Mode
Validates that emergency mode works correctly when AI generation fails
"""

import os
import sys
import time
import json
import logging
from pathlib import Path

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_emergency_mode():
    """Test emergency mode functionality"""
    
    print("🚨 Testing Emergency Simulation Mode")
    print("=" * 50)
    
    try:
        # Import modules
        from platform_detection import PlatformDetector
        from ai_pipeline import AIImageGenerator
        from emergency_simulator import EmergencyImageGenerator, get_emergency_activator
        
        print("✅ All modules imported successfully")
        
        # Detect platform
        detector = PlatformDetector()
        platform_info = detector.detect_hardware()
        print(f"✅ Platform detected: {platform_info['platform_type']}")
        
        # Test 1: Direct emergency generator
        print("\n📋 Test 1: Direct Emergency Generator")
        emergency_gen = EmergencyImageGenerator(platform_info)
        
        test_prompts = [
            "A beautiful sunset over mountains",
            "A futuristic robot in a garden",
            "Abstract colorful pattern",
            "A majestic dragon flying over a castle"
        ]
        
        for i, prompt in enumerate(test_prompts):
            print(f"  Testing prompt {i+1}: {prompt}")
            start_time = time.time()
            
            def progress_callback(progress, step, total):
                if step % 5 == 0 or step == total:
                    print(f"    Step {step}/{total} - {progress*100:.1f}%")
            
            try:
                image, metrics = emergency_gen.generate_image(
                    prompt=prompt,
                    steps=20,
                    progress_callback=progress_callback
                )
                
                elapsed = time.time() - start_time
                print(f"    ✅ Generated in {elapsed:.1f}s")
                print(f"    📊 Metrics: {metrics.get('prompt_category')} category, {metrics.get('backend')} backend")
                
                # Verify image
                if image and hasattr(image, 'size'):
                    print(f"    🖼️  Image size: {image.size}")
                else:
                    print("    ❌ Invalid image returned")
                
            except Exception as e:
                print(f"    ❌ Error: {e}")
        
        # Test 2: AI Generator with emergency fallback
        print("\n📋 Test 2: AI Generator Emergency Fallback")
        
        # Force emergency mode via environment variable
        os.environ['EMERGENCY_MODE'] = 'true'
        
        try:
            ai_gen = AIImageGenerator(platform_info)
            
            # Check emergency status
            emergency_status = ai_gen.get_emergency_status()
            print(f"  Emergency mode available: {emergency_status['emergency_mode_available']}")
            
            # Test generation with emergency mode
            print("  Testing generation with emergency mode enabled...")
            start_time = time.time()
            
            image, metrics = ai_gen.generate_image(
                prompt="A technological cityscape at night",
                steps=15
            )
            
            elapsed = time.time() - start_time
            print(f"  ✅ Generated in {elapsed:.1f}s")
            print(f"  📊 Emergency mode: {metrics.get('emergency_mode', False)}")
            print(f"  📊 Backend: {metrics.get('backend')}")
            
        except Exception as e:
            print(f"  ❌ Error testing AI generator: {e}")
        finally:
            # Clean up environment variable
            if 'EMERGENCY_MODE' in os.environ:
                del os.environ['EMERGENCY_MODE']
        
        # Test 3: Manual emergency activation
        print("\n📋 Test 3: Manual Emergency Activation")
        
        try:
            ai_gen = AIImageGenerator(platform_info)
            
            # Check initial status
            status = ai_gen.get_emergency_status()
            print(f"  Initial emergency mode: {status['emergency_mode_active']}")
            
            # Manually activate emergency mode
            success = ai_gen.force_emergency_mode()
            print(f"  Manual activation: {'✅ Success' if success else '❌ Failed'}")
            
            # Check status after activation
            status = ai_gen.get_emergency_status()
            print(f"  Emergency mode after activation: {status['emergency_mode_active']}")
            
            # Test generation
            if status['emergency_mode_active']:
                image, metrics = ai_gen.generate_image(
                    prompt="A peaceful lake surrounded by forests",
                    steps=10
                )
                print(f"  ✅ Emergency generation completed")
                print(f"  📊 Backend: {metrics.get('backend')}")
            
            # Deactivate emergency mode
            deactivated = ai_gen.deactivate_emergency_mode()
            print(f"  Deactivation: {'✅ Success' if deactivated else '❌ Failed'}")
            
        except Exception as e:
            print(f"  ❌ Error testing manual activation: {e}")
        
        # Test 4: Emergency assets verification
        print("\n📋 Test 4: Emergency Assets Verification")
        
        emergency_gen = EmergencyImageGenerator(platform_info)
        assets_dir = emergency_gen.emergency_assets_dir
        
        print(f"  Assets directory: {assets_dir}")
        
        if assets_dir.exists():
            asset_files = list(assets_dir.glob("*.png"))
            print(f"  ✅ Found {len(asset_files)} emergency assets")
            
            # List categories
            categories = set()
            for asset in asset_files:
                parts = asset.stem.split('_')
                if len(parts) >= 3:
                    categories.add(parts[1])  # category is second part
            
            print(f"  📂 Categories: {', '.join(sorted(categories))}")
        else:
            print(f"  ❌ Assets directory not found")
        
        # Test 5: Platform-specific behavior
        print("\n📋 Test 5: Platform-Specific Behavior")
        
        emergency_gen = EmergencyImageGenerator(platform_info)
        
        print(f"  Platform: {platform_info['platform_type']}")
        print(f"  Is Snapdragon: {emergency_gen.is_snapdragon}")
        print(f"  Default steps: {emergency_gen.default_steps}")
        print(f"  Base generation time: {emergency_gen.base_generation_time}s")
        print(f"  Steps per second: {emergency_gen.steps_per_second}")
        
        # Test telemetry generation
        telemetry = emergency_gen.generate_realistic_telemetry(10, 20, 15.0)
        print(f"  📊 Sample telemetry: {telemetry}")
        
        print("\n🎉 All tests completed successfully!")
        return True
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("Make sure all required modules are available")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_rest_api():
    """Test emergency mode REST API endpoints"""
    
    print("\n🌐 Testing REST API Endpoints")
    print("=" * 40)
    
    try:
        import requests
        base_url = "http://localhost:5000"
        
        # Test emergency status endpoint
        print("Testing GET /emergency...")
        try:
            response = requests.get(f"{base_url}/emergency", timeout=5)
            if response.status_code == 200:
                status = response.json()
                print(f"  ✅ Emergency status: {status}")
            else:
                print(f"  ❌ Status code: {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"  ⚠️  Server not running or unreachable: {e}")
            return False
        
        # Test emergency activation
        print("Testing POST /emergency/activate...")
        try:
            response = requests.post(f"{base_url}/emergency/activate", timeout=5)
            result = response.json()
            print(f"  📋 Activation result: {result}")
        except requests.exceptions.RequestException as e:
            print(f"  ❌ Activation failed: {e}")
        
        # Test emergency deactivation
        print("Testing POST /emergency/deactivate...")
        try:
            response = requests.post(f"{base_url}/emergency/deactivate", timeout=5)
            result = response.json()
            print(f"  📋 Deactivation result: {result}")
        except requests.exceptions.RequestException as e:
            print(f"  ❌ Deactivation failed: {e}")
        
        return True
        
    except ImportError:
        print("  ⚠️  requests module not available, skipping API tests")
        return True

if __name__ == "__main__":
    print("🚀 Emergency Mode Test Suite")
    print("Testing emergency simulation functionality\n")
    
    # Run tests
    success = test_emergency_mode()
    
    if success:
        # Test API if possible
        test_rest_api()
        
        print("\n✅ Emergency mode testing completed successfully!")
        print("\nTo manually test:")
        print("1. Set EMERGENCY_MODE=true environment variable")
        print("2. Start demo client: python demo_client.py")
        print("3. Generate images to see emergency mode in action")
        
        sys.exit(0)
    else:
        print("\n❌ Emergency mode testing failed!")
        sys.exit(1)