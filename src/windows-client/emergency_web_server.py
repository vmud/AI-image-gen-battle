#!/usr/bin/env python3
"""
Emergency Web-Only Server for Snapdragon Demo
Runs Flask server without Tkinter for emergency mode
"""

import os
import sys
import time
import json
import logging
import threading
from typing import Dict, Any, Optional
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory, render_template_string
from flask_socketio import SocketIO, emit
from flask_cors import CORS
from pathlib import Path
import psutil
import uuid

# Import our modules
from platform_detection import PlatformDetector
from ai_pipeline import AIImageGenerator
from error_mitigation import ErrorMitigationSystem

# Emergency mode integration
try:
    from emergency_simulator import get_emergency_activator
    EMERGENCY_MODE_AVAILABLE = True
except ImportError:
    EMERGENCY_MODE_AVAILABLE = False
    print("Warning: Emergency mode not available - emergency_simulator module not found")

class EmergencyWebServer:
    """Web-only server for emergency demo mode"""
    
    def __init__(self, platform_info: Dict[str, Any]):
        self.platform_info = platform_info
        self.is_snapdragon = platform_info['platform_type'] == 'snapdragon'
        
        # Demo state
        self.demo_active = False
        self.current_step = 0
        self.total_steps = 30
        self.start_time = None
        self.end_time = None
        self.current_prompt = ""
        self.generated_image = None
        self.generation_metrics = None
        self.ai_generator = None
        
        # Job management
        self.current_job_id = None
        self.jobs = {}
        self.generated_images_dir = Path("static/generated")
        self.generated_images_dir.mkdir(parents=True, exist_ok=True)
        
        # Error mitigation system
        self.error_mitigation = ErrorMitigationSystem(self)
        
        # Performance metrics
        self.cpu_usage = 0
        self.memory_usage = 0
        self.power_consumption = 0
        self.npu_usage = 0 if self.is_snapdragon else None
        
        # Setup logging
        self.logger = logging.getLogger(__name__)
        
        # Start monitoring
        self.start_monitoring()
        
        # Initialize Flask app
        self.app = Flask(__name__, static_folder='static')
        CORS(self.app)
        self.socketio = SocketIO(self.app, cors_allowed_origins="*", async_mode='eventlet')
        self.setup_routes()
        self.setup_socket_handlers()
        
    def start_monitoring(self):
        """Start performance monitoring."""
        def monitor():
            while True:
                try:
                    # CPU usage
                    self.cpu_usage = psutil.cpu_percent(interval=0.1)
                    
                    # Memory usage
                    memory = psutil.virtual_memory()
                    self.memory_usage = memory.used / (1024**3)  # GB
                    
                    # Approximate power consumption
                    if self.is_snapdragon:
                        base_power = 8
                        load_factor = (self.cpu_usage / 100) * 7
                        self.power_consumption = base_power + load_factor
                        self.npu_usage = min(95, self.cpu_usage + 10) if self.demo_active else 0
                    else:
                        base_power = 15
                        load_factor = (self.cpu_usage / 100) * 13
                        self.power_consumption = base_power + load_factor
                    
                    # Emit telemetry via WebSocket
                    try:
                        self.socketio.emit('telemetry', {
                            'telemetry': {
                                'cpu': self.cpu_usage,
                                'memory_gb': self.memory_usage,
                                'power_w': self.power_consumption,
                                'npu': self.npu_usage
                            }
                        }, broadcast=True)
                        
                        # Emit status snapshot
                        status_payload = self.get_status()
                        self.socketio.emit('status', status_payload, broadcast=True)
                    except Exception as emit_error:
                        self.logger.debug(f"Socket emit error: {emit_error}")
                    
                    time.sleep(1)
                    
                except Exception as e:
                    logging.error(f"Error monitoring performance: {e}")
                    time.sleep(5)
        
        monitor_thread = threading.Thread(target=monitor, daemon=True)
        monitor_thread.start()
    
    def get_status(self, job_id: Optional[str] = None) -> Dict[str, Any]:
        """Get current demo status."""
        elapsed_time = 0
        if self.start_time:
            if self.end_time:
                elapsed_time = self.end_time - self.start_time
            else:
                elapsed_time = time.time() - self.start_time
        
        # Get current job image URL if available
        image_url = None
        if self.current_job_id and self.current_job_id in self.jobs:
            image_url = self.jobs[self.current_job_id].get('image_url')
        
        # Get health status
        health_summary = self.error_mitigation.get_health_summary()
        
        return {
            'status': 'active' if self.demo_active else 'idle',
            'ready': True,  # Always ready in emergency mode
            'model_loaded': self.ai_generator is not None,
            'llm_ready': self.ai_generator is not None,
            'control_reachable': True,
            'current_step': self.current_step,
            'total_steps': self.total_steps,
            'elapsed_time': elapsed_time,
            'completed': not self.demo_active and self.end_time is not None,
            'prompt': self.current_prompt,
            'platform': self.platform_info['platform_type'],
            'telemetry': {
                'cpu': self.cpu_usage,
                'memory_gb': self.memory_usage,
                'power_w': self.power_consumption,
                'npu': self.npu_usage
            },
            'image_url': image_url,
            'current_job_id': self.current_job_id,
            'health': health_summary,
            'emergency_mode': {
                'emergency_mode_available': EMERGENCY_MODE_AVAILABLE,
                'emergency_mode_active': True
            }
        }
    
    def start_generation(self, prompt: str, steps: int = 20, sync_time: Optional[float] = None, 
                        mode: str = 'local', job_id: Optional[str] = None) -> Optional[str]:
        """Start image generation."""
        if self.demo_active:
            self.logger.warning("Generation already in progress")
            return None
        
        # Generate job ID if not provided
        if job_id is None:
            job_id = str(uuid.uuid4())
        
        self.current_job_id = job_id
        self.demo_active = True
        self.current_prompt = prompt
        self.total_steps = steps
        self.current_step = 0
        self.generated_image = None
        self.start_time = time.time()
        self.end_time = None
        
        # Initialize job record
        self.jobs[job_id] = {
            'id': job_id,
            'prompt': prompt,
            'steps': steps,
            'mode': mode,
            'status': 'active',
            'start_time': self.start_time,
            'end_time': None,
            'image_url': None,
            'metrics': {},
            'current_step': 0,
            'total_steps': steps
        }
        
        # Wait for sync time if specified
        if sync_time is not None:
            wait_time = sync_time - time.time()
            if wait_time > 0:
                time.sleep(wait_time)
        
        # Start generation in separate thread
        gen_thread = threading.Thread(target=self.run_generation, daemon=True)
        gen_thread.start()
        
        return job_id
    
    def run_generation(self):
        """Run the actual image generation using AI pipeline."""
        try:
            # Initialize AI pipeline if not already done
            if not hasattr(self, 'ai_generator') or self.ai_generator is None:
                self.ai_generator = AIImageGenerator(self.platform_info)
            
            # Progress callback for real-time updates
            def progress_callback(progress, current_step, total_steps):
                if not self.demo_active:
                    return
                self.current_step = current_step
                progress_percent = progress * 100
                
                # Update job record
                if self.current_job_id and self.current_job_id in self.jobs:
                    self.jobs[self.current_job_id]['current_step'] = current_step
                
                # Emit progress via WebSocket
                try:
                    elapsed_time = time.time() - self.start_time if self.start_time else 0
                    self.socketio.emit('progress', {
                        'job_id': self.current_job_id,
                        'current_step': current_step,
                        'total_steps': total_steps,
                        'progress': progress_percent,
                        'elapsed_time': elapsed_time
                    }, broadcast=True)
                except Exception as emit_error:
                    self.logger.debug(f"Socket emit error: {emit_error}")
            
            # Quality-focused settings based on platform
            if self.is_snapdragon:
                steps = 4  # Fast generation in emergency mode
                resolution = (768, 768)
            else:
                steps = 10  # Faster Intel generation
                resolution = (768, 768)
            
            self.total_steps = steps
            
            # Generate the image
            if self.ai_generator:
                image, metrics = self.ai_generator.generate_image(
                    prompt=self.current_prompt,
                    steps=steps,
                    resolution=resolution,
                    guidance_scale=7.5,
                    seed=42,
                    progress_callback=progress_callback
                )
            else:
                raise RuntimeError("AI generator not initialized")
            
            # Store the generated image and metrics
            self.generated_image = image
            self.generation_metrics = metrics
            
            # Save image to disk
            if image and self.current_job_id:
                image_filename = f"{self.current_job_id}.png"
                image_path = self.generated_images_dir / image_filename
                image.save(image_path, "PNG")
                
                # Update job record with image URL
                self.jobs[self.current_job_id]['image_url'] = f"/static/generated/{image_filename}"
                self.jobs[self.current_job_id]['metrics'] = metrics
            
            # Generation complete
            if self.demo_active:
                self.end_time = time.time()
                self.generation_complete()
                
        except Exception as e:
            logging.error(f"Error in generation: {e}")
            if self.current_job_id and self.current_job_id in self.jobs:
                self.jobs[self.current_job_id]['status'] = 'error'
                self.jobs[self.current_job_id]['error'] = str(e)
            self.generation_error(str(e))
    
    def generation_complete(self):
        """Handle generation completion."""
        if self.end_time is not None and self.start_time is not None:
            elapsed_time = self.end_time - self.start_time
        else:
            elapsed_time = 0.0
        
        # Update job record
        if self.current_job_id and self.current_job_id in self.jobs:
            self.jobs[self.current_job_id]['status'] = 'completed'
            self.jobs[self.current_job_id]['end_time'] = self.end_time
            self.jobs[self.current_job_id]['elapsed_time'] = elapsed_time
        
        # Mark demo as inactive
        self.demo_active = False
        
        # Emit completed event via WebSocket
        try:
            self.socketio.emit('completed', {
                'job_id': self.current_job_id,
                'prompt': self.current_prompt,
                'elapsed_time': elapsed_time,
                'image_url': self.jobs[self.current_job_id].get('image_url') if self.current_job_id in self.jobs else None,
                'total_steps': self.total_steps
            }, broadcast=True)
        except Exception as emit_error:
            self.logger.debug(f"Socket emit error: {emit_error}")
    
    def generation_error(self, error: str):
        """Handle generation error."""
        self.demo_active = False
        
        # Update job record
        if self.current_job_id and self.current_job_id in self.jobs:
            self.jobs[self.current_job_id]['status'] = 'error'
            self.jobs[self.current_job_id]['error'] = error
        
        # Emit error event via WebSocket
        try:
            self.socketio.emit('error', {
                'job_id': self.current_job_id,
                'error': error
            }, broadcast=True)
        except Exception as emit_error:
            self.logger.debug(f"Socket emit error: {emit_error}")
    
    def setup_routes(self):
        """Setup Flask routes."""
        
        @self.app.route('/')
        def index():
            """Redirect to Snapdragon demo."""
            return '''
            <script>
                window.location.href = '/snapdragon';
            </script>
            '''
        
        @self.app.route('/snapdragon')
        def snapdragon_demo():
            """Serve Snapdragon demo page."""
            return send_from_directory('static', 'snapdragon-demo.html')
        
        @self.app.route('/static/<path:path>')
        def serve_static(path):
            """Serve static files."""
            return send_from_directory('static', path)
        
        @self.app.route('/info', methods=['GET'])
        def get_info():
            return jsonify({
                'platform': self.platform_info['platform_type'],
                'processor': self.platform_info.get('processor_model', 'Unknown'),
                'architecture': self.platform_info.get('architecture', 'Unknown'),
                'ai_acceleration': self.platform_info.get('ai_acceleration', 'Unknown'),
                'status': 'ready'
            })
        
        @self.app.route('/status', methods=['GET'])
        def get_status():
            """Get status."""
            job_id = request.args.get('job_id')
            return jsonify(self.get_status(job_id))
        
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
                    mode = command_data.get('mode', 'local')
                    
                    job_id = self.start_generation(prompt, steps, sync_time, mode)
                    
                    if job_id:
                        return jsonify({'success': True, 'job_id': job_id, 'message': 'Generation started'})
                    else:
                        return jsonify({'success': False, 'message': 'Already running'}), 400
                
                else:
                    return jsonify({'success': False, 'message': f'Unknown command: {command}'}), 400
                    
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500
        
        @self.app.route('/static/generated/<path:filename>')
        def serve_generated_image(filename):
            """Serve generated images."""
            return send_from_directory(str(self.generated_images_dir), filename)
        
        @self.app.route('/health', methods=['GET'])
        def health_check():
            """Health check endpoint."""
            health = self.error_mitigation.get_health_summary()
            return jsonify(health), 200  # Always return 200 in emergency mode
    
    def setup_socket_handlers(self):
        """Setup Socket.IO event handlers."""
        
        @self.socketio.on('connect')
        def handle_connect():
            """Handle client connection."""
            self.logger.info("Client connected via WebSocket")
            emit('status', self.get_status())
            
        @self.socketio.on('disconnect')
        def handle_disconnect():
            """Handle client disconnection."""
            self.logger.info("Client disconnected from WebSocket")
            
        @self.socketio.on('request_status')
        def handle_status_request():
            """Handle status request from client."""
            emit('status', self.get_status())
    
    def run(self, host='0.0.0.0', port=5000):
        """Run the server."""
        self.socketio.run(self.app, host=host, port=port, debug=False)

def main():
    """Main function for emergency web server."""
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('emergency_demo.log'),
            logging.StreamHandler()
        ]
    )
    
    print("🚨 Starting Emergency Snapdragon Demo Server...")
    
    # Detect platform
    detector = PlatformDetector()
    platform_info = detector.detect_hardware()
    optimization_config = detector.get_optimization_config()
    detector.apply_optimizations()
    
    print(f"Platform detected: {platform_info['platform_type'].upper()}")
    print("Emergency Mode: ACTIVE")
    
    # Create emergency server
    server = EmergencyWebServer(platform_info)
    
    print("✅ Emergency demo server ready!")
    print("Server running on port 5000")
    print("Press Ctrl+C to stop")
    
    # Run server
    server.run(host='0.0.0.0', port=5000)

if __name__ == "__main__":
    main()