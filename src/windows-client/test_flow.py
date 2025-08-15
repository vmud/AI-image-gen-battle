#!/usr/bin/env python3
"""
Test script for the prompt-to-image flow
"""

import requests
import time
import sys

def test_flow():
    """Test the complete prompt-to-image flow."""
    base_url = "http://localhost:5000"
    
    print("🧪 Testing Prompt-to-Image Flow")
    print("=" * 40)
    
    # 1. Check status
    print("\n1. Checking system status...")
    try:
        response = requests.get(f"{base_url}/status")
        status = response.json()
        print(f"   ✅ System status: {status['status']}")
        print(f"   ✅ LLM Ready: {status.get('llm_ready', False)}")
        print(f"   ✅ Control Reachable: {status.get('control_reachable', False)}")
    except Exception as e:
        print(f"   ❌ Failed to get status: {e}")
        return False
    
    # 2. Start generation
    print("\n2. Starting image generation...")
    prompt = "A beautiful sunset over mountains"
    try:
        response = requests.post(f"{base_url}/command", json={
            "command": "start_generation",
            "data": {
                "prompt": prompt,
                "steps": 20,
                "mode": "local"
            }
        })
        result = response.json()
        if result.get('success'):
            job_id = result.get('job_id')
            print(f"   ✅ Generation started with job ID: {job_id}")
        else:
            print(f"   ❌ Failed to start: {result.get('message')}")
            return False
    except Exception as e:
        print(f"   ❌ Failed to start generation: {e}")
        return False
    
    # 3. Poll for progress
    print("\n3. Monitoring progress...")
    start_time = time.time()
    last_step = 0
    
    while True:
        try:
            response = requests.get(f"{base_url}/status?job_id={job_id}")
            status = response.json()
            
            # Print progress
            if status.get('current_step', 0) > last_step:
                last_step = status['current_step']
                total_steps = status.get('total_steps', 20)
                percent = (last_step / total_steps) * 100
                print(f"   Step {last_step}/{total_steps} - {percent:.0f}% complete")
            
            # Check if completed
            if status.get('status') == 'completed':
                elapsed = time.time() - start_time
                print(f"\n   ✅ Generation complete in {elapsed:.1f}s!")
                
                # Check for image URL
                image_url = status.get('image_url')
                if image_url:
                    print(f"   ✅ Image available at: {base_url}{image_url}")
                    
                    # Try to fetch the image
                    try:
                        img_response = requests.get(f"{base_url}{image_url}")
                        if img_response.status_code == 200:
                            print(f"   ✅ Image successfully accessible ({len(img_response.content)} bytes)")
                        else:
                            print(f"   ⚠️  Image URL returned {img_response.status_code}")
                    except:
                        print(f"   ⚠️  Could not fetch image")
                
                return True
            
            # Check for error
            if status.get('status') == 'error':
                print(f"   ❌ Generation failed: {status.get('error')}")
                return False
            
            time.sleep(0.5)
            
        except KeyboardInterrupt:
            print("\n   ⚠️  Test interrupted by user")
            return False
        except Exception as e:
            print(f"   ❌ Error polling status: {e}")
            return False

def main():
    """Main test function."""
    print("\n🚀 AI Image Generation Flow Test")
    print("This test verifies the complete prompt-to-image pipeline")
    print("-" * 50)
    
    # Check if server is running
    try:
        response = requests.get("http://localhost:5000/info")
        info = response.json()
        print(f"\n✅ Server is running")
        print(f"   Platform: {info.get('platform', 'unknown')}")
        print(f"   Processor: {info.get('processor', 'unknown')}")
    except:
        print("\n❌ Server is not running!")
        print("   Please start the demo client first:")
        print("   python src/windows-client/demo_client.py")
        sys.exit(1)
    
    # Run the test
    success = test_flow()
    
    if success:
        print("\n✅ All tests passed! The flow is working correctly.")
        print("\nYou can now:")
        print("1. Open http://localhost:5000 in your browser")
        print("2. Choose Intel or Snapdragon demo")
        print("3. Enter a prompt and generate images!")
    else:
        print("\n❌ Test failed. Please check the errors above.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
