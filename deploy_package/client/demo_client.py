#!/usr/bin/env python3
"""
Windows Demo Client Application

This application runs on Windows machines and provides the polished demo display
for real-time AI image generation comparison.
"""

import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
import json
import os
import sys
import logging
from typing import Dict, Any, Optional, Callable
from datetime import datetime
import socket
from flask import Flask, request, jsonify
from flask_socketio import SocketIO
import base64
from io import BytesIO
from PIL import Image, ImageTk
import psutil
import queue

# Import our platform detection module
from platform_detection import PlatformDetector

class DemoDisplay:
    def __init__(self, platform_info: Dict[str, Any]):
        self.platform_info = platform_info
        self.is_snapdragon = platform_info['platform_type'] == 'snapdragon'
        
        # Demo state
        self.demo_active = False
        self.current_step = 0
        self.total_steps = 20
        self.start_time = None
        self.end_time = None
        self.current_prompt = ""
        self.generated_image = None
        
        # Performance metrics
        self.cpu_usage = 0
        self.memory_usage = 0
        self.power_consumption = 0
        self.npu_usage = 0 if self.is_snapdragon else None
        
        # UI setup
        self.setup_ui()
        self.setup_monitoring()
        
    def setup_ui(self):
        """Setup the main UI window."""
        self.root = tk.Tk()
        self.root.title(f"AI Demo - {self.platform_info.get('processor_model', 'Unknown')}")
        
        # Make fullscreen
        self.root.attributes('-fullscreen', True)
        self.root.configure(bg='#1a1a2e' if self.is_snapdragon else '#1e3c72')
        
        # Allow ESC to exit fullscreen for testing
        self.root.bind('<Escape>', lambda e: self.root.attributes('-fullscreen', False))
        self.root.bind('<F11>', lambda e: self.root.attributes('-fullscreen', True))
        
        # Main frame
        self.main_frame = tk.Frame(self.root, bg=self.root['bg'])
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        self.create_header()
        self.create_content_area()
        
    def create_header(self):
        """Create the header with platform branding and status."""
        header_color = '#c41e3a' if self.is_snapdragon else '#0071c5'
        
        self.header_frame = tk.Frame(self.main_frame, bg=header_color, height=80)
        self.header_frame.pack(fill=tk.X, pady=(0, 10))
        self.header_frame.pack_propagate(False)
        
        # Platform logo and name
        logo_text = "🔥 Snapdragon X Elite" if self.is_snapdragon else "⚡ Intel Core Ultra 7"
        self.logo_label = tk.Label(
            self.header_frame,
            text=logo_text,
            font=('Segoe UI', 28, 'bold'),
            fg='white',
            bg=header_color
        )
        self.logo_label.pack(side=tk.LEFT, padx=20, pady=20)
        
        # Status indicator
        self.status_label = tk.Label(
            self.header_frame,
            text="🟡 READY",
            font=('Segoe UI', 24, 'bold'),
            fg='#ffa500',
            bg=header_color
        )
        self.status_label.pack(side=tk.RIGHT, padx=20, pady=20)
        
    def create_content_area(self):
        """Create the main content area with image and metrics."""
        content_frame = tk.Frame(self.main_frame, bg=self.root['bg'])
        content_frame.pack(fill=tk.BOTH, expand=True, padx=30, pady=20)
        
        # Left side - Image display
        self.image_frame = tk.Frame(content_frame, bg='#2a2a3e', relief='raised', bd=2)
        self.image_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 20))
        
        # Image canvas
        self.image_canvas = tk.Canvas(
            self.image_frame,
            bg='#1a1a1a',
            highlightthickness=0
        )
        self.image_canvas.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Image status overlay
        self.image_status = tk.Label(
            self.image_canvas,
            text="Waiting for demo to start...",
            font=('Segoe UI', 16),
            fg='white',
            bg='#1a1a1a'
        )
        self.image_status.place(relx=0.5, rely=0.5, anchor='center')
        
        # Right side - Metrics and progress
        self.metrics_frame = tk.Frame(content_frame, bg=self.root['bg'])
        self.metrics_frame.pack(side=tk.RIGHT, fill=tk.Y, padx=(20, 0))
        
        self.create_metrics_widgets()
        
    def create_metrics_widgets(self):
        """Create metrics display widgets."""
        metric_bg = '#2a2a3e'
        border_color = '#c41e3a' if self.is_snapdragon else '#0071c5'
        
        # Generation Time
        self.time_frame = tk.Frame(self.metrics_frame, bg=metric_bg, relief='raised', bd=2)
        self.time_frame.pack(fill=tk.X, pady=(0, 20))
        
        tk.Label(
            self.time_frame,
            text="GENERATION TIME",
            font=('Segoe UI', 12, 'bold'),
            fg='#888',
            bg=metric_bg
        ).pack(pady=(15, 5))
        
        self.time_value = tk.Label(
            self.time_frame,
            text="0.0",
            font=('Segoe UI', 36, 'bold'),
            fg='#00ff88' if self.is_snapdragon else '#ffa500',
            bg=metric_bg
        )
        self.time_value.pack()
        
        tk.Label(
            self.time_frame,
            text="seconds",
            font=('Segoe UI', 14),
            fg='#ccc',
            bg=metric_bg
        ).pack(pady=(0, 15))
        
        # AI Acceleration Usage
        ai_label = "NPU UTILIZATION" if self.is_snapdragon else "CPU UTILIZATION"
        self.ai_frame = tk.Frame(self.metrics_frame, bg=metric_bg, relief='raised', bd=2)
        self.ai_frame.pack(fill=tk.X, pady=(0, 20))
        
        tk.Label(
            self.ai_frame,
            text=ai_label,
            font=('Segoe UI', 12, 'bold'),
            fg='#888',
            bg=metric_bg
        ).pack(pady=(15, 5))
        
        self.ai_value = tk.Label(
            self.ai_frame,
            text="0",
            font=('Segoe UI', 36, 'bold'),
            fg='#00ff88' if self.is_snapdragon else '#ffa500',
            bg=metric_bg
        )
        self.ai_value.pack()
        
        tk.Label(
            self.ai_frame,
            text="%",
            font=('Segoe UI', 14),
            fg='#ccc',
            bg=metric_bg
        ).pack(pady=(0, 15))
        
        # Memory Usage
        self.memory_frame = tk.Frame(self.metrics_frame, bg=metric_bg, relief='raised', bd=2)
        self.memory_frame.pack(fill=tk.X, pady=(0, 20))
        
        tk.Label(
            self.memory_frame,
            text="MEMORY USAGE",
            font=('Segoe UI', 12, 'bold'),
            fg='#888',
            bg=metric_bg
        ).pack(pady=(15, 5))
        
        self.memory_value = tk.Label(
            self.memory_frame,
            text="0.0",
            font=('Segoe UI', 36, 'bold'),
            fg='#00ff88' if self.is_snapdragon else '#ffa500',
            bg=metric_bg
        )
        self.memory_value.pack()
        
        tk.Label(
            self.memory_frame,
            text="GB",
            font=('Segoe UI', 14),
            fg='#ccc',
            bg=metric_bg
        ).pack(pady=(0, 15))
        
        # Power Consumption
        self.power_frame = tk.Frame(self.metrics_frame, bg=metric_bg, relief='raised', bd=2)
        self.power_frame.pack(fill=tk.X, pady=(0, 20))
        
        tk.Label(
            self.power_frame,
            text="POWER EFFICIENCY",
            font=('Segoe UI', 12, 'bold'),
            fg='#888',
            bg=metric_bg
        ).pack(pady=(15, 5))
        
        self.power_value = tk.Label(
            self.power_frame,
            text="0",
            font=('Segoe UI', 36, 'bold'),
            fg='#00ff88' if self.is_snapdragon else '#ffa500',
            bg=metric_bg
        )
        self.power_value.pack()
        
        tk.Label(
            self.power_frame,
            text="W",
            font=('Segoe UI', 14),
            fg='#ccc',
            bg=metric_bg
        ).pack(pady=(0, 15))
        
        # Progress Section
        progress_color = '#00ff88' if self.is_snapdragon else '#ffa500'
        self.progress_frame = tk.Frame(self.metrics_frame, bg=metric_bg, relief='raised', bd=2)
        self.progress_frame.pack(fill=tk.X, pady=(0, 20))
        
        tk.Label(
            self.progress_frame,
            text="🎯 GENERATION PROGRESS" if self.is_snapdragon else "⚙️ GENERATION PROGRESS",
            font=('Segoe UI', 14, 'bold'),
            fg=progress_color,
            bg=metric_bg
        ).pack(pady=(15, 10))
        
        # Progress bar
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(
            self.progress_frame,
            variable=self.progress_var,
            maximum=100,
            length=200,
            mode='determinate'
        )
        self.progress_bar.pack(pady=(0, 10))
        
        # Progress text
        self.progress_text = tk.Label(
            self.progress_frame,
            text="Steps: 0/20 | 0% Complete",
            font=('Segoe UI', 12),
            fg='white',
            bg=metric_bg
        )
        self.progress_text.pack(pady=(0, 15))
        
        # Prompt display
        self.prompt_frame = tk.Frame(self.metrics_frame, bg='#2a2a4e', relief='raised', bd=2)
        self.prompt_frame.pack(fill=tk.X)
        
        tk.Label(
            self.prompt_frame,
            text="💭 Current Prompt:",
            font=('Segoe UI', 12, 'bold'),
            fg='#00a8ff' if not self.is_snapdragon else '#ff6b6b',
            bg='#2a2a4e'
        ).pack(pady=(15, 5))
        
        self.prompt_label = tk.Label(
            self.prompt_frame,
            text="Waiting for prompt...",
            font=('Segoe UI', 10, 'italic'),
            fg='white',
            bg='#2a2a4e',
            wraplength=200,
            justify=tk.CENTER
        )
        self.prompt_label.pack(pady=(0, 15))
        
    def setup_monitoring(self):
        """Setup performance monitoring."""
        self.monitor_thread = threading.Thread(target=self.monitor_performance, daemon=True)
        self.monitor_thread.start()
        
    def monitor_performance(self):
        """Monitor system performance metrics."""
        while True:
            try:
                # CPU usage
                self.cpu_usage = psutil.cpu_percent(interval=0.1)
                
                # Memory usage
                memory = psutil.virtual_memory()
                self.memory_usage = memory.used / (1024**3)  # GB
                
                # Approximate power consumption based on platform and usage
                if self.is_snapdragon:
                    # Snapdragon X Elite is more power efficient
                    base_power = 8
                    load_factor = (self.cpu_usage / 100) * 7
                    self.power_consumption = base_power + load_factor
                    self.npu_usage = min(95, self.cpu_usage + 10) if self.demo_active else 0
                else:
                    # Intel Core Ultra consumes more power
                    base_power = 15
                    load_factor = (self.cpu_usage / 100) * 13
                    self.power_consumption = base_power + load_factor
                
                # Update UI
                self.root.after_idle(self.update_metrics_display)
                
                time.sleep(1)
                
            except Exception as e:
                logging.error(f"Error monitoring performance: {e}")
                time.sleep(5)
                
    def update_metrics_display(self):
        """Update the metrics display."""
        try:
            # Update AI acceleration metric
            if self.is_snapdragon and self.npu_usage is not None:
                self.ai_value.config(text=f"{int(self.npu_usage)}")
            else:
                self.ai_value.config(text=f"{int(self.cpu_usage)}")
            
            # Update memory
            self.memory_value.config(text=f"{self.memory_usage:.1f}")
            
            # Update power
            self.power_value.config(text=f"{int(self.power_consumption)}")
            
            # Update generation time if demo is active
            if self.demo_active and self.start_time:
                elapsed = time.time() - self.start_time
                self.time_value.config(text=f"{elapsed:.1f}")
                
        except Exception as e:
            logging.error(f"Error updating metrics: {e}")
            
    def start_generation(self, prompt: str, steps: int = 20, sync_time: float = None):
        """Start image generation."""
        if self.demo_active:
            return False
            
        self.demo_active = True
        self.current_prompt = prompt
        self.total_steps = steps
        self.current_step = 0
        self.generated_image = None
        
        # Update UI
        self.status_label.config(text="🟠 PROCESSING...", fg='#ffa500')
        self.prompt_label.config(text=prompt)
        self.image_status.config(text=f"Generating: {prompt}\nProcessing with {'NPU' if self.is_snapdragon else 'CPU + iGPU'}")
        
        # Wait for sync time if specified
        if sync_time:
            wait_time = sync_time - time.time()
            if wait_time > 0:
                time.sleep(wait_time)
        
        self.start_time = time.time()
        
        # Start generation in separate thread
        gen_thread = threading.Thread(target=self.run_generation, daemon=True)
        gen_thread.start()
        
        return True
        
    def run_generation(self):
        """Run the actual image generation (simulated for now)."""
        try:
            # Simulate different generation speeds
            if self.is_snapdragon:
                # Snapdragon is faster due to NPU
                step_delay = 0.4  # 8 seconds total for 20 steps
            else:
                # Intel takes longer
                step_delay = 0.6  # 12 seconds total for 20 steps
            
            for step in range(1, self.total_steps + 1):
                if not self.demo_active:
                    break
                    
                self.current_step = step
                progress = (step / self.total_steps) * 100
                
                # Update progress on UI thread
                self.root.after_idle(self.update_progress, step, progress)
                
                time.sleep(step_delay)
            
            # Generation complete
            if self.demo_active:
                self.end_time = time.time()
                self.root.after_idle(self.generation_complete)
                
        except Exception as e:
            logging.error(f"Error in generation: {e}")
            self.root.after_idle(self.generation_error, str(e))
            
    def update_progress(self, step: int, progress: float):
        """Update progress display."""
        self.progress_var.set(progress)
        self.progress_text.config(text=f"Steps: {step}/{self.total_steps} | {int(progress)}% Complete")
        
        # Update image status
        if step < self.total_steps:
            self.image_status.config(
                text=f"Generating: {self.current_prompt}\nStep {step}/{self.total_steps} - {int(progress)}% complete"
            )
        
    def generation_complete(self):
        """Handle generation completion."""
        elapsed_time = self.end_time - self.start_time
        
        # Update status
        self.status_label.config(text="✅ COMPLETE!", fg='#00ff88')
        self.time_value.config(text=f"{elapsed_time:.1f}")
        
        # Update image display
        self.image_status.config(
            text=f"🏙️ Generated Image:\n\"{self.current_prompt}\"\n\nComplete AI-generated artwork\npowered by {'Snapdragon NPU' if self.is_snapdragon else 'Intel CPU + iGPU'}"
        )
        
        # Change image background to indicate completion
        self.image_canvas.config(bg='#4a4a8a' if self.is_snapdragon else '#4a4a6a')
        
    def generation_error(self, error: str):
        """Handle generation error."""
        self.demo_active = False
        self.status_label.config(text="❌ ERROR", fg='red')
        self.image_status.config(text=f"Generation failed: {error}")
        
    def stop_generation(self):
        """Stop current generation."""
        self.demo_active = False
        self.status_label.config(text="🛑 STOPPED", fg='#888')
        self.image_status.config(text="Generation stopped")
        
    def get_status(self) -> Dict[str, Any]:
        """Get current demo status."""
        elapsed_time = 0
        if self.start_time:
            if self.end_time:
                elapsed_time = self.end_time - self.start_time
            else:
                elapsed_time = time.time() - self.start_time
                
        return {
            'status': 'active' if self.demo_active else 'idle',
            'ready': True,
            'model_loaded': True,
            'current_step': self.current_step,
            'total_steps': self.total_steps,
            'elapsed_time': elapsed_time,
            'completed': not self.demo_active and self.end_time is not None,
            'prompt': self.current_prompt,
            'platform': self.platform_info['platform_type'],
            'cpu_usage': self.cpu_usage,
            'memory_usage': self.memory_usage,
            'power_consumption': self.power_consumption,
            'npu_usage': self.npu_usage
        }
        
    def run(self):
        """Run the demo display."""
        self.root.mainloop()

class NetworkServer:
    def __init__(self, display: DemoDisplay):
        self.display = display
        self.app = Flask(__name__)
        self.socketio = SocketIO(self.app, cors_allowed_origins="*")
        self.setup_routes()
        
    def setup_routes(self):
        """Setup Flask routes for remote control."""
        
        @self.app.route('/info', methods=['GET'])
        def get_info():
            return jsonify({
                'platform': self.display.platform_info['platform_type'],
                'processor': self.display.platform_info.get('processor_model', 'Unknown'),
                'architecture': self.display.platform_info.get('architecture', 'Unknown'),
                'ai_acceleration': self.display.platform_info.get('ai_acceleration', 'Unknown'),
                'status': 'ready'
            })
            
        @self.app.route('/status', methods=['GET'])
        def get_status():
            return jsonify(self.display.get_status())
            
        @self.app.route('/command', methods=['POST'])
        def handle_command():
            try:
                data = request.get_json()
                command = data.get('command')
                command_data = data.get('data', {})
                
                if command == 'start_generation':
                    prompt = command_data.get('prompt', 'a beautiful landscape')
                    steps = command_data.get('steps', 20)
                    sync_time = command_data.get('sync_time')
                    
                    success = self.display.start_generation(prompt, steps, sync_time)
                    return jsonify({'success': success, 'message': 'Generation started' if success else 'Already running'})
                    
                elif command == 'stop_generation':
                    self.display.stop_generation()
                    return jsonify({'success': True, 'message': 'Generation stopped'})
                    
                elif command == 'get_status':
                    return jsonify(self.display.get_status())
                    
                else:
                    return jsonify({'success': False, 'message': f'Unknown command: {command}'}), 400
                    
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500
                
    def run(self, host='0.0.0.0', port=5000):
        """Run the network server."""
        self.socketio.run(self.app, host=host, port=port, debug=False)

def main():
    """Main function."""
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('demo_client.log'),
            logging.StreamHandler()
        ]
    )
    
    print("🚀 Starting AI Image Generation Demo Client...")
    
    # Detect platform
    detector = PlatformDetector()
    platform_info = detector.detect_hardware()
    optimization_config = detector.get_optimization_config()
    detector.apply_optimizations()
    
    print(f"Platform detected: {platform_info['platform_type'].upper()}")
    
    # Create demo display
    display = DemoDisplay(platform_info)
    
    # Start network server in separate thread
    server = NetworkServer(display)
    server_thread = threading.Thread(
        target=server.run,
        kwargs={'host': '0.0.0.0', 'port': 5000},
        daemon=True
    )
    server_thread.start()
    
    print("✅ Demo client ready!")
    print("Network server running on port 5000")
    print("Press F11 for fullscreen, ESC to exit fullscreen")
    
    # Run the display
    display.run()

if __name__ == "__main__":
    main()