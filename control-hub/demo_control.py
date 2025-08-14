#!/usr/bin/env python3
"""
AI Image Generation Demo Control Hub

This script runs on MacOS and coordinates the synchronized demonstration
between Snapdragon and Intel Windows machines.
"""

import argparse
import asyncio
import json
import socket
import time
import threading
from typing import List, Dict, Any, Optional
import subprocess
import sys

class DemoController:
    def __init__(self):
        self.clients = []
        self.demo_active = False
        self.results = {}
        
    def discover_clients(self, timeout: int = 10) -> List[Dict[str, Any]]:
        """Discover Windows demo clients on the network."""
        print("🔍 Discovering demo clients on network...")
        
        discovered_clients = []
        
        # Get local network range
        try:
            # Get local IP to determine network range
            result = subprocess.run(['ifconfig'], capture_output=True, text=True)
            lines = result.stdout.split('\n')
            
            local_ip = None
            for line in lines:
                if 'inet ' in line and '192.168.' in line:
                    local_ip = line.split('inet ')[1].split(' ')[0]
                    break
                elif 'inet ' in line and '10.' in line:
                    local_ip = line.split('inet ')[1].split(' ')[0]
                    break
            
            if not local_ip:
                print("❌ Could not determine local network range")
                return []
                
            print(f"📡 Scanning network from {local_ip}")
            
            # Simple network scan for demo clients
            network_base = '.'.join(local_ip.split('.')[:-1])
            
            for i in range(1, 255):
                ip = f"{network_base}.{i}"
                if ip == local_ip:
                    continue
                    
                try:
                    # Try to connect to demo client port
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(0.1)
                    result = sock.connect_ex((ip, 5000))
                    sock.close()
                    
                    if result == 0:
                        # Found a potential client, verify it's our demo client
                        client_info = self.get_client_info(ip)
                        if client_info:
                            discovered_clients.append(client_info)
                            print(f"✅ Found demo client: {client_info['platform']} at {ip}")
                            
                except Exception:
                    continue
                    
        except Exception as e:
            print(f"❌ Network discovery error: {e}")
            
        self.clients = discovered_clients
        return discovered_clients
    
    def get_client_info(self, ip: str) -> Optional[Dict[str, Any]]:
        """Get information about a demo client."""
        try:
            import requests
            response = requests.get(f"http://{ip}:5000/info", timeout=2)
            if response.status_code == 200:
                info = response.json()
                info['ip'] = ip
                return info
        except Exception:
            pass
        return None
    
    def send_command(self, command: str, data: Dict[str, Any] = None) -> Dict[str, Any]:
        """Send command to all demo clients."""
        if not self.clients:
            print("❌ No clients available. Run discovery first.")
            return {}
            
        results = {}
        
        for client in self.clients:
            try:
                import requests
                payload = {
                    'command': command,
                    'data': data or {},
                    'timestamp': time.time()
                }
                
                response = requests.post(
                    f"http://{client['ip']}:5000/command",
                    json=payload,
                    timeout=5
                )
                
                if response.status_code == 200:
                    results[client['platform']] = response.json()
                    print(f"✅ Command sent to {client['platform']}: {command}")
                else:
                    print(f"❌ Failed to send command to {client['platform']}")
                    results[client['platform']] = {'error': 'Command failed'}
                    
            except Exception as e:
                print(f"❌ Error sending command to {client['platform']}: {e}")
                results[client['platform']] = {'error': str(e)}
                
        return results
    
    def start_demo(self, prompt: str, steps: int = 20) -> bool:
        """Start synchronized image generation demo."""
        if self.demo_active:
            print("❌ Demo is already running")
            return False
            
        if not self.clients:
            print("❌ No clients available")
            return False
            
        print(f"🚀 Starting demo with prompt: '{prompt}'")
        print(f"📊 Generation steps: {steps}")
        
        # Send start command to all clients
        demo_config = {
            'prompt': prompt,
            'steps': steps,
            'sync_time': time.time() + 3  # Start in 3 seconds
        }
        
        results = self.send_command('start_generation', demo_config)
        
        if all('error' not in result for result in results.values()):
            self.demo_active = True
            print("✅ Demo started successfully on all clients")
            
            # Monitor demo progress
            self.monitor_demo()
            return True
        else:
            print("❌ Failed to start demo on some clients")
            return False
    
    def monitor_demo(self):
        """Monitor demo progress and display results."""
        print("\n" + "="*60)
        print("🎥 DEMO IN PROGRESS")
        print("="*60)
        
        start_time = time.time()
        
        while self.demo_active:
            try:
                # Get status from all clients
                status_results = self.send_command('get_status')
                
                # Display progress
                print("\r" + " "*80, end="")  # Clear line
                progress_info = []
                
                for platform, status in status_results.items():
                    if 'error' not in status:
                        current_step = status.get('current_step', 0)
                        total_steps = status.get('total_steps', 20)
                        progress = int((current_step / total_steps) * 100) if total_steps > 0 else 0
                        elapsed = status.get('elapsed_time', 0)
                        
                        if status.get('completed', False):
                            progress_info.append(f"{platform}: ✅ COMPLETE ({elapsed:.1f}s)")
                        else:
                            progress_info.append(f"{platform}: {progress}% ({current_step}/{total_steps})")
                
                print(f"\r{' | '.join(progress_info)}", end="", flush=True)
                
                # Check if all completed
                all_completed = all(
                    result.get('completed', False) for result in status_results.values()
                    if 'error' not in result
                )
                
                if all_completed:
                    self.demo_active = False
                    self.display_final_results(status_results, time.time() - start_time)
                    break
                    
                time.sleep(0.5)
                
            except KeyboardInterrupt:
                print("\n🛑 Demo interrupted by user")
                self.stop_demo()
                break
            except Exception as e:
                print(f"\n❌ Error monitoring demo: {e}")
                break
    
    def display_final_results(self, results: Dict[str, Any], total_time: float):
        """Display final demo results."""
        print("\n\n" + "="*60)
        print("🏆 DEMO RESULTS")
        print("="*60)
        
        for platform, result in results.items():
            if 'error' not in result:
                elapsed = result.get('elapsed_time', 0)
                steps = result.get('total_steps', 0)
                success = result.get('completed', False)
                
                status_icon = "✅" if success else "❌"
                print(f"{status_icon} {platform.upper()}:")
                print(f"   Generation Time: {elapsed:.2f} seconds")
                print(f"   Steps Completed: {steps}")
                print(f"   Status: {'COMPLETE' if success else 'FAILED'}")
                print()
        
        # Determine winner
        completed_results = {
            platform: result for platform, result in results.items()
            if 'error' not in result and result.get('completed', False)
        }
        
        if completed_results:
            winner = min(completed_results.items(), key=lambda x: x[1].get('elapsed_time', float('inf')))
            print(f"🥇 WINNER: {winner[0].upper()} ({winner[1]['elapsed_time']:.2f}s)")
        
        print("="*60)
    
    def stop_demo(self):
        """Stop the running demo."""
        if not self.demo_active:
            print("❌ No demo is currently running")
            return
            
        print("🛑 Stopping demo...")
        self.send_command('stop_generation')
        self.demo_active = False
        print("✅ Demo stopped")
    
    def get_client_status(self):
        """Get status of all clients."""
        if not self.clients:
            print("❌ No clients available")
            return
            
        print("\n📊 CLIENT STATUS:")
        print("-" * 40)
        
        for client in self.clients:
            try:
                import requests
                response = requests.get(f"http://{client['ip']}:5000/status", timeout=2)
                if response.status_code == 200:
                    status = response.json()
                    print(f"✅ {client['platform'].upper()} ({client['ip']}):")
                    print(f"   Status: {status.get('status', 'Unknown')}")
                    print(f"   Ready: {status.get('ready', False)}")
                    print(f"   Model Loaded: {status.get('model_loaded', False)}")
                else:
                    print(f"❌ {client['platform'].upper()} ({client['ip']}): Connection failed")
            except Exception as e:
                print(f"❌ {client['platform'].upper()} ({client['ip']}): {e}")
    
    def interactive_mode(self):
        """Run interactive demo control mode."""
        print("🎮 Interactive Demo Control Mode")
        print("Commands: discover, status, start <prompt>, stop, quit")
        
        while True:
            try:
                command = input("\n> ").strip().lower()
                
                if command == 'quit' or command == 'exit':
                    break
                elif command == 'discover':
                    self.discover_clients()
                elif command == 'status':
                    self.get_client_status()
                elif command.startswith('start '):
                    prompt = command[6:]  # Remove 'start '
                    if prompt:
                        self.start_demo(prompt)
                    else:
                        print("❌ Please provide a prompt")
                elif command == 'stop':
                    self.stop_demo()
                elif command == 'help':
                    print("Available commands:")
                    print("  discover - Find demo clients on network")
                    print("  status   - Check client status")
                    print("  start <prompt> - Start demo with prompt")
                    print("  stop     - Stop running demo")
                    print("  quit     - Exit control mode")
                else:
                    print(f"❌ Unknown command: {command}")
                    
            except KeyboardInterrupt:
                print("\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"❌ Error: {e}")

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="AI Image Generation Demo Controller")
    parser.add_argument('--prompt', '-p', type=str, help='Image generation prompt')
    parser.add_argument('--steps', '-s', type=int, default=20, help='Number of generation steps')
    parser.add_argument('--discover', '-d', action='store_true', help='Discover clients and exit')
    parser.add_argument('--interactive', '-i', action='store_true', help='Run in interactive mode')
    
    args = parser.parse_args()
    
    controller = DemoController()
    
    print("🎯 AI Image Generation Demo Controller")
    print("=====================================")
    
    # Discover clients
    clients = controller.discover_clients()
    
    if not clients:
        print("❌ No demo clients found on network")
        print("Make sure Windows demo clients are running and connected to the same network")
        return 1
    
    print(f"✅ Found {len(clients)} demo client(s)")
    
    if args.discover:
        return 0
    
    if args.interactive:
        controller.interactive_mode()
    elif args.prompt:
        success = controller.start_demo(args.prompt, args.steps)
        return 0 if success else 1
    else:
        print("\nUsage examples:")
        print("  python demo_control.py --prompt 'a futuristic cityscape'")
        print("  python demo_control.py --interactive")
        print("  python demo_control.py --discover")
        return 1

if __name__ == "__main__":
    # Install required packages if not available
    try:
        import requests
    except ImportError:
        print("Installing required packages...")
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'requests'])
        import requests
    
    sys.exit(main())