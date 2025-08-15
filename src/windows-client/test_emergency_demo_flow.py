#!/usr/bin/env python3
"""
Test Emergency Demo Flow - End-to-End Validation
Tests the complete flow from generate button to image display
"""

import os
import sys
import time
import json
import logging
import requests
import threading
from pathlib import Path
from typing import Dict, Any

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EmergencyDemoFlowTester:
    """Tests the complete emergency demo flow"""
    
    def __init__(self, base_url: str = "http://localhost:5000"):
        self.base_url = base_url
        self.test_results = {}
        self.server_process = None
        
    def test_server_health(self) -> bool:
        """Test if server is running and healthy"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            logger.info(f"Health check: {response.status_code} - {response.text}")
            self.test_results['server_health'] = {
                'status': response.status_code,
                'healthy': response.status_code == 200
            }
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            self.test_results['server_health'] = {
                'status': 'error',
                'healthy': False,
                'error': str(e)
            }
            return False
    
    def test_emergency_assets_accessibility(self) -> bool:
        """Test if emergency assets are accessible via HTTP"""
        logger.info("Testing emergency asset accessibility...")
        
        # Test different asset types
        test_assets = [
            "emergency_landscape_0_snapdragon.png",
            "emergency_portrait_1_snapdragon.png", 
            "emergency_abstract_2_snapdragon.png",
            "emergency_technology_0_intel.png"
        ]
        
        accessible_count = 0
        total_count = len(test_assets)
        
        for asset in test_assets:
            try:
                response = requests.get(f"{self.base_url}/static/emergency_assets/{asset}", timeout=5)
                if response.status_code == 200:
                    accessible_count += 1
                    logger.info(f"✅ Asset accessible: {asset} ({len(response.content)} bytes)")
                else:
                    logger.warning(f"❌ Asset not accessible: {asset} (HTTP {response.status_code})")
            except Exception as e:
                logger.error(f"❌ Asset request failed: {asset} - {e}")
        
        success_rate = accessible_count / total_count
        self.test_results['emergency_assets'] = {
            'accessible_count': accessible_count,
            'total_count': total_count,
            'success_rate': success_rate,
            'all_accessible': success_rate == 1.0
        }
        
        logger.info(f"Emergency assets accessibility: {accessible_count}/{total_count} ({success_rate*100:.1f}%)")
        return success_rate >= 0.8  # Allow some failures
    
    def test_snapdragon_ui_loading(self) -> bool:
        """Test if Snapdragon UI loads correctly"""
        try:
            response = requests.get(f"{self.base_url}/snapdragon", timeout=5)
            ui_loads = response.status_code == 200 and "Snapdragon X Elite" in response.text
            
            self.test_results['snapdragon_ui'] = {
                'status': response.status_code,
                'loads_correctly': ui_loads,
                'contains_branding': "Snapdragon X Elite" in response.text,
                'contains_generate_button': 'id="generateBtn"' in response.text
            }
            
            logger.info(f"Snapdragon UI loading: {'✅ Success' if ui_loads else '❌ Failed'}")
            return ui_loads
        except Exception as e:
            logger.error(f"Snapdragon UI test failed: {e}")
            self.test_results['snapdragon_ui'] = {
                'status': 'error',
                'loads_correctly': False,
                'error': str(e)
            }
            return False
    
    def test_generation_api_call(self) -> bool:
        """Test the generation API endpoint"""
        logger.info("Testing generation API call...")
        
        try:
            # Test payload
            payload = {
                "command": "start_generation",
                "data": {
                    "prompt": "A beautiful mountain landscape at sunset",
                    "steps": 4,
                    "mode": "local"
                }
            }
            
            response = requests.post(
                f"{self.base_url}/command",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                job_id = result.get('job_id')
                success = result.get('success', False)
                
                self.test_results['generation_api'] = {
                    'status': response.status_code,
                    'success': success,
                    'job_id': job_id,
                    'response': result
                }
                
                logger.info(f"Generation API: {'✅ Success' if success else '❌ Failed'} (Job ID: {job_id})")
                return success and job_id is not None
            else:
                logger.error(f"Generation API failed: HTTP {response.status_code}")
                self.test_results['generation_api'] = {
                    'status': response.status_code,
                    'success': False,
                    'response': response.text
                }
                return False
                
        except Exception as e:
            logger.error(f"Generation API test failed: {e}")
            self.test_results['generation_api'] = {
                'status': 'error',
                'success': False,
                'error': str(e)
            }
            return False
    
    def test_generation_completion(self, timeout: int = 30) -> bool:
        """Test complete generation flow with timeout"""
        logger.info("Testing complete generation flow...")
        
        try:
            # Start generation
            payload = {
                "command": "start_generation",
                "data": {
                    "prompt": "Emergency test - futuristic cityscape",
                    "steps": 4,
                    "mode": "local"
                }
            }
            
            start_time = time.time()
            response = requests.post(f"{self.base_url}/command", json=payload, timeout=10)
            
            if response.status_code != 200:
                logger.error(f"Failed to start generation: HTTP {response.status_code}")
                return False
            
            result = response.json()
            job_id = result.get('job_id')
            
            if not job_id:
                logger.error("No job ID returned from generation start")
                return False
            
            logger.info(f"Generation started with job ID: {job_id}")
            
            # Poll for completion
            completed = False
            image_available = False
            
            while time.time() - start_time < timeout:
                time.sleep(2)  # Poll every 2 seconds
                
                try:
                    status_response = requests.get(f"{self.base_url}/status", timeout=5)
                    if status_response.status_code == 200:
                        status_data = status_response.json()
                        
                        # Check if generation completed
                        if status_data.get('completed', False):
                            completed = True
                            image_url = status_data.get('image_url')
                            
                            # Test if generated image is accessible
                            if image_url:
                                img_response = requests.get(f"{self.base_url}{image_url}", timeout=5)
                                image_available = img_response.status_code == 200
                                logger.info(f"Generated image accessible: {'✅ Yes' if image_available else '❌ No'}")
                            
                            break
                    
                except Exception as e:
                    logger.debug(f"Status polling error: {e}")
                    continue
            
            elapsed = time.time() - start_time
            
            self.test_results['generation_completion'] = {
                'job_id': job_id,
                'completed': completed,
                'image_available': image_available,
                'elapsed_time': elapsed,
                'timeout_reached': elapsed >= timeout
            }
            
            if completed and image_available:
                logger.info(f"✅ Generation completed successfully in {elapsed:.1f}s")
                return True
            elif completed:
                logger.warning(f"⚠️ Generation completed but image not accessible ({elapsed:.1f}s)")
                return False
            else:
                logger.error(f"❌ Generation did not complete within {timeout}s")
                return False
                
        except Exception as e:
            logger.error(f"Generation completion test failed: {e}")
            self.test_results['generation_completion'] = {
                'completed': False,
                'error': str(e)
            }
            return False
    
    def run_complete_test_suite(self) -> Dict[str, Any]:
        """Run all tests and return comprehensive results"""
        logger.info("🧪 Starting Emergency Demo Flow Test Suite")
        logger.info("=" * 60)
        
        # Test sequence
        tests = [
            ("Server Health", self.test_server_health),
            ("Emergency Assets", self.test_emergency_assets_accessibility),
            ("Snapdragon UI", self.test_snapdragon_ui_loading),
            ("Generation API", self.test_generation_api_call),
            ("Complete Flow", self.test_generation_completion)
        ]
        
        passed_tests = 0
        total_tests = len(tests)
        
        for test_name, test_func in tests:
            logger.info(f"\n🔍 Running: {test_name}")
            try:
                success = test_func()
                if success:
                    passed_tests += 1
                    logger.info(f"✅ {test_name}: PASSED")
                else:
                    logger.error(f"❌ {test_name}: FAILED")
            except Exception as e:
                logger.error(f"❌ {test_name}: ERROR - {e}")
        
        # Summary
        success_rate = passed_tests / total_tests
        overall_success = success_rate >= 0.8  # 80% pass rate required
        
        summary = {
            'overall_success': overall_success,
            'passed_tests': passed_tests,
            'total_tests': total_tests,
            'success_rate': success_rate,
            'test_results': self.test_results
        }
        
        logger.info("\n" + "=" * 60)
        logger.info("🏁 TEST SUITE SUMMARY")
        logger.info(f"Tests Passed: {passed_tests}/{total_tests} ({success_rate*100:.1f}%)")
        logger.info(f"Overall Result: {'✅ SUCCESS' if overall_success else '❌ FAILURE'}")
        
        return summary

def main():
    """Main test function"""
    print("🧪 Emergency Demo Flow Tester")
    print("Testing complete flow from generate button to image display")
    print("=" * 60)
    
    # Check if server should be started
    base_url = "http://localhost:5000"
    
    tester = EmergencyDemoFlowTester(base_url)
    results = tester.run_complete_test_suite()
    
    # Exit with appropriate code
    sys.exit(0 if results['overall_success'] else 1)

if __name__ == "__main__":
    main()