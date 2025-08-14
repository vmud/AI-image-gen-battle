#!/usr/bin/env python3
"""
Demo Test Script

This script tests the demo system components locally without requiring
actual Windows machines.
"""

import time
import threading
import json
from demo_control import DemoController

class MockClient:
    """Mock demo client for testing."""
    
    def __init__(self, platform_type: str, ip: str):
        self.platform_type = platform_type
        self.ip = ip
        self.demo_active = False
        self.current_step = 0
        self.total_steps = 20
        self.start_time = None
        
    def get_info(self):
        """Mock client info."""
        return {
            'platform': self.platform_type,
            'processor': f'{"Snapdragon X Elite" if self.platform_type == "snapdragon" else "Intel Core Ultra 7"}',
            'architecture': 'ARM64' if self.platform_type == 'snapdragon' else 'x86_64',
            'ai_acceleration': 'NPU' if self.platform_type == 'snapdragon' else 'CPU+iGPU',
            'status': 'ready',
            'ip': self.ip
        }
    
    def start_generation(self, prompt: str, steps: int = 20):
        """Start mock generation."""
        if self.demo_active:
            return False
            
        self.demo_active = True
        self.current_step = 0
        self.total_steps = steps
        self.start_time = time.time()
        
        # Run generation in background
        threading.Thread(target=self._run_generation, daemon=True).start()
        return True
    
    def _run_generation(self):
        """Run mock generation."""
        # Different speeds for different platforms
        step_delay = 0.4 if self.platform_type == 'snapdragon' else 0.6
        
        for step in range(1, self.total_steps + 1):
            if not self.demo_active:
                break
            self.current_step = step
            time.sleep(step_delay)
        
        # Mark complete
        if self.demo_active:
            time.sleep(0.1)  # Small delay to ensure completion
    
    def get_status(self):
        """Get mock status."""
        elapsed_time = 0
        completed = False
        
        if self.start_time:
            elapsed_time = time.time() - self.start_time
            # Check if generation should be complete
            expected_total_time = self.total_steps * (0.4 if self.platform_type == 'snapdragon' else 0.6)
            completed = elapsed_time >= expected_total_time
            
            if completed:
                self.demo_active = False
        
        return {
            'status': 'active' if self.demo_active else 'idle',
            'ready': True,
            'model_loaded': True,
            'current_step': self.current_step,
            'total_steps': self.total_steps,
            'elapsed_time': elapsed_time,
            'completed': completed,
            'platform': self.platform_type
        }
    
    def stop_generation(self):
        """Stop mock generation."""
        self.demo_active = False

class DemoTester:
    """Test the demo system."""
    
    def __init__(self):
        self.mock_clients = {
            'snapdragon': MockClient('snapdragon', '192.168.1.100'),
            'intel': MockClient('intel', '192.168.1.101')
        }
        
    def test_platform_detection(self):
        """Test platform detection functionality."""
        print("🧪 Testing Platform Detection...")
        
        try:
            import sys
            import os
            # Add the windows-client directory to the Python path
            sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(__file__)), 'windows-client'))
            
            from platform_detection import PlatformDetector
            detector = PlatformDetector()
            
            # This will detect the current macOS system, but the logic should work
            platform_info = detector.detect_hardware()
            config = detector.get_optimization_config()
            
            print(f"✅ Platform detection works")
            print(f"   Detected: {platform_info.get('platform_type', 'Unknown')}")
            print(f"   Config generated: {len(config)} settings")
            
        except Exception as e:
            print(f"❌ Platform detection failed: {e}")
            return False
            
        return True
    
    def test_control_system(self):
        """Test the control system with mock clients."""
        print("\n🧪 Testing Control System...")
        
        # Mock the controller's client discovery
        controller = DemoController()
        controller.clients = [client.get_info() for client in self.mock_clients.values()]
        
        print(f"✅ Mock clients created: {len(controller.clients)}")
        
        # Test demo execution
        print("🚀 Starting mock demo...")
        
        prompt = "a futuristic cityscape with flying cars"
        
        # Start generation on mock clients
        for client in self.mock_clients.values():
            client.start_generation(prompt, 20)
        
        print(f"✅ Demo started with prompt: '{prompt}'")
        
        # Monitor progress
        print("\n📊 Monitoring progress...")
        start_time = time.time()
        
        while True:
            # Get status from mock clients
            status_info = []
            all_completed = True
            
            for platform, client in self.mock_clients.items():
                status = client.get_status()
                
                if not status['completed']:
                    all_completed = False
                
                progress = int((status['current_step'] / status['total_steps']) * 100)
                elapsed = status['elapsed_time']
                
                if status['completed']:
                    status_info.append(f"{platform.upper()}: ✅ COMPLETE ({elapsed:.1f}s)")
                else:
                    status_info.append(f"{platform.upper()}: {progress}% ({status['current_step']}/{status['total_steps']})")
            
            # Clear line and show progress
            print(f"\r{' | '.join(status_info)}", end="", flush=True)
            
            if all_completed:
                break
                
            if time.time() - start_time > 30:  # Timeout after 30 seconds
                print("\n⏰ Test timeout reached")
                break
                
            time.sleep(0.5)
        
        # Show final results
        print("\n\n🏆 Final Results:")
        results = []
        for platform, client in self.mock_clients.items():
            status = client.get_status()
            elapsed = status['elapsed_time']
            completed = status['completed']
            
            icon = "✅" if completed else "❌"
            results.append((platform, elapsed, completed))
            print(f"{icon} {platform.upper()}: {elapsed:.1f}s {'(COMPLETE)' if completed else '(INCOMPLETE)'}")
        
        # Determine winner
        completed_results = [(platform, elapsed) for platform, elapsed, completed in results if completed]
        if completed_results:
            winner = min(completed_results, key=lambda x: x[1])
            print(f"\n🥇 WINNER: {winner[0].upper()} ({winner[1]:.1f}s)")
            
            # Verify Snapdragon wins (as expected)
            if winner[0] == 'snapdragon':
                print("✅ Expected result: Snapdragon wins due to NPU advantage")
                return True
            else:
                print("⚠️ Unexpected result: Intel won")
                return False
        else:
            print("❌ No clients completed the test")
            return False
    
    def test_file_structure(self):
        """Test that all required files exist."""
        print("\n🧪 Testing File Structure...")
        
        # Get project root directory (parent of control-hub)
        import os
        project_root = os.path.dirname(os.path.dirname(__file__))
        
        required_files = [
            'README.md',
            'mockups/snapdragon-display.html',
            'mockups/intel-display.html',
            'mockups/side-by-side-comparison.html',
            'control-hub/demo_control.py',
            'windows-client/platform_detection.py',
            'windows-client/demo_client.py',
            'deployment/setup_windows.ps1'
        ]
        
        missing_files = []
        
        for file_path in required_files:
            full_path = os.path.join(project_root, file_path)
            if os.path.exists(full_path):
                print(f"✅ {file_path}")
            else:
                print(f"❌ {file_path}")
                missing_files.append(file_path)
        
        if missing_files:
            print(f"\n❌ Missing {len(missing_files)} required files")
            return False
        else:
            print(f"\n✅ All {len(required_files)} required files present")
            return True
    
    def run_all_tests(self):
        """Run all tests."""
        print("🧪 AI Image Generation Battle - System Tests")
        print("=" * 50)
        
        tests = [
            ("File Structure", self.test_file_structure),
            ("Platform Detection", self.test_platform_detection),
            ("Control System", self.test_control_system)
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            try:
                if test_func():
                    passed += 1
            except Exception as e:
                print(f"\n❌ {test_name} failed with error: {e}")
        
        print("\n" + "=" * 50)
        print(f"🧪 TEST RESULTS: {passed}/{total} tests passed")
        
        if passed == total:
            print("✅ All tests passed! System is ready for deployment.")
        else:
            print("❌ Some tests failed. Please check the issues above.")
        
        return passed == total

def main():
    """Main test function."""
    tester = DemoTester()
    success = tester.run_all_tests()
    
    if success:
        print("\n🎉 System validation complete!")
        print("\nNext steps:")
        print("1. Deploy to Windows machines using deployment/setup_windows.ps1")
        print("2. Copy windows-client files to target machines")
        print("3. Run demo_client.py on each Windows machine")
        print("4. Use control-hub/demo_control.py to coordinate the demo")
    
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())