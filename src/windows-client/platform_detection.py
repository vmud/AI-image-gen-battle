#!/usr/bin/env python3
"""
Platform Detection and Hardware Optimization for AI Image Generation Demo

This script detects whether the system is running on Snapdragon X Elite or Intel Core Ultra
and configures the appropriate AI acceleration settings.
"""

import platform
import subprocess
import json
import sys
import os
from typing import Dict, Any, Optional

class PlatformDetector:
    def __init__(self):
        self.platform_info = {}
        self.optimization_config = {}
        
    def detect_hardware(self) -> Dict[str, Any]:
        """Detect hardware platform and AI acceleration capabilities."""
        
        # Get basic system info
        self.platform_info['os'] = platform.system()
        self.platform_info['machine'] = platform.machine()
        self.platform_info['processor'] = platform.processor()
        
        # Detect CPU architecture (allow environment override for Snapdragon)
        force_snap = os.getenv('SNAPDRAGON_NPU', '').lower() in ('1', 'true', 'yes', 'y')
        if force_snap:
            self.platform_info['architecture'] = 'ARM64'
            self.platform_info['platform_type'] = 'snapdragon'
        elif 'ARM' in platform.machine().upper() or 'ARM64' in platform.machine().upper():
            self.platform_info['architecture'] = 'ARM64'
            self.platform_info['platform_type'] = 'snapdragon'
        else:
            self.platform_info['architecture'] = 'x86_64'
            self.platform_info['platform_type'] = 'intel'
            
        # Get detailed CPU information
        self._get_cpu_details()
        
        # Detect AI acceleration capabilities
        self._detect_ai_acceleration()
        
        return self.platform_info
    
    def _get_cpu_details(self):
        """Get detailed CPU information using WMI."""
        try:
            if self.platform_info['os'] == 'Windows':
                # Use wmic to get CPU information
                cmd = 'wmic cpu get Name,Description,Manufacturer,MaxClockSpeed /format:csv'
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    if len(lines) > 1:
                        # Parse CSV output (skip header)
                        for line in lines[1:]:
                            if line.strip():
                                parts = line.split(',')
                                if len(parts) >= 4:
                                    self.platform_info['cpu_name'] = parts[3].strip()
                                    self.platform_info['cpu_manufacturer'] = parts[2].strip()
                                    self.platform_info['max_clock_speed'] = parts[1].strip()
                                    break
                                    
                # Detect specific processor models
                cpu_name = self.platform_info.get('cpu_name', '').lower()
                if 'snapdragon' in cpu_name or 'qualcomm' in cpu_name:
                    self.platform_info['platform_type'] = 'snapdragon'
                    if 'x elite' in cpu_name:
                        self.platform_info['processor_model'] = 'Snapdragon X Elite'
                elif 'intel' in cpu_name:
                    self.platform_info['platform_type'] = 'intel'
                    if 'core ultra' in cpu_name:
                        self.platform_info['processor_model'] = 'Intel Core Ultra'
                        
        except Exception as e:
            print(f"Error getting CPU details: {e}")
            
    def _detect_ai_acceleration(self):
        """Detect available AI acceleration capabilities."""
        
        if self.platform_info['platform_type'] == 'snapdragon':
            # Snapdragon X Elite has dedicated NPU
            self.platform_info['ai_acceleration'] = 'NPU'
            self.platform_info['npu_available'] = True
            # Use ONNX Runtime with QNN provider on Snapdragon
            self.platform_info['ai_framework'] = 'ONNX Runtime (QNN)'
            
        elif self.platform_info['platform_type'] == 'intel':
            # Intel Core Ultra uses integrated graphics + CPU
            self.platform_info['ai_acceleration'] = 'CPU+iGPU'
            self.platform_info['npu_available'] = False
            self.platform_info['ai_framework'] = 'OpenVINO'
            
        # Check for GPU acceleration
        self._check_gpu_availability()
        
    def _check_gpu_availability(self):
        """Check for dedicated GPU availability."""
        try:
            # Try to detect GPU using wmic
            cmd = 'wmic path win32_VideoController get name'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                gpu_info = result.stdout.lower()
                self.platform_info['dedicated_gpu'] = 'nvidia' in gpu_info or 'amd' in gpu_info
                self.platform_info['gpu_info'] = result.stdout.strip()
            else:
                self.platform_info['dedicated_gpu'] = False
                
        except Exception as e:
            print(f"Error checking GPU: {e}")
            self.platform_info['dedicated_gpu'] = False
            
    def get_optimization_config(self) -> Dict[str, Any]:
        """Get optimization configuration based on detected platform."""
        
        if self.platform_info['platform_type'] == 'snapdragon':
            self.optimization_config = {
                'device': 'QNN',
                'precision': 'fp16',
                'batch_size': 1,
                'use_npu': True,
                'memory_optimization': True,
                'cpu_threads': 4,
                'scheduler': 'DPMSolverMultistepScheduler',
                'steps': 20,
                'guidance_scale': 7.5,
                'optimizations': [
                    'enable_attention_slicing',
                    'enable_memory_efficient_attention',
                    'enable_cpu_offload'
                ]
            }
            
        elif self.platform_info['platform_type'] == 'intel':
            self.optimization_config = {
                'device': 'cpu',
                'precision': 'fp32',
                'batch_size': 1,
                'use_npu': False,
                'memory_optimization': True,
                'cpu_threads': 8,
                'scheduler': 'PNDMScheduler',
                'steps': 20,
                'guidance_scale': 7.5,
                'optimizations': [
                    'enable_attention_slicing',
                    'enable_memory_efficient_attention'
                ]
            }
            
        return self.optimization_config
        
    def apply_optimizations(self):
        """Apply platform-specific optimizations."""
        
        if self.platform_info['platform_type'] == 'snapdragon':
            print("Applying Snapdragon NPU optimizations...")
            # Set environment variables for NPU optimization
            os.environ['OMP_NUM_THREADS'] = '4'
            os.environ['MKL_NUM_THREADS'] = '4'
            os.environ['NUMEXPR_NUM_THREADS'] = '4'
            
        elif self.platform_info['platform_type'] == 'intel':
            print("Applying Intel CPU+iGPU optimizations...")
            # Set environment variables for CPU optimization
            os.environ['OMP_NUM_THREADS'] = '8'
            os.environ['MKL_NUM_THREADS'] = '8'
            os.environ['NUMEXPR_NUM_THREADS'] = '8'
            
    def save_config(self, filepath: str):
        """Save detection results and configuration to file."""
        config = {
            'platform_info': self.platform_info,
            'optimization_config': self.optimization_config
        }
        
        with open(filepath, 'w') as f:
            json.dump(config, f, indent=2)
            
    def print_summary(self):
        """Print a summary of detected platform and configuration."""
        print("\n" + "="*60)
        print("PLATFORM DETECTION SUMMARY")
        print("="*60)
        print(f"Platform Type: {self.platform_info.get('platform_type', 'Unknown').upper()}")
        print(f"Processor: {self.platform_info.get('processor_model', 'Unknown')}")
        print(f"Architecture: {self.platform_info.get('architecture', 'Unknown')}")
        print(f"AI Acceleration: {self.platform_info.get('ai_acceleration', 'Unknown')}")
        print(f"NPU Available: {self.platform_info.get('npu_available', False)}")
        print(f"AI Framework: {self.platform_info.get('ai_framework', 'Unknown')}")
        print(f"Dedicated GPU: {self.platform_info.get('dedicated_gpu', False)}")
        print("-"*60)
        print("OPTIMIZATION CONFIGURATION:")
        for key, value in self.optimization_config.items():
            print(f"  {key}: {value}")
        print("="*60)

def main():
    """Main function for standalone execution."""
    detector = PlatformDetector()
    
    print("Detecting hardware platform...")
    platform_info = detector.detect_hardware()
    
    print("Generating optimization configuration...")
    optimization_config = detector.get_optimization_config()
    
    print("Applying platform-specific optimizations...")
    detector.apply_optimizations()
    
    # Print summary
    detector.print_summary()
    
    # Save configuration
    config_path = os.path.join(os.path.dirname(__file__), 'platform_config.json')
    detector.save_config(config_path)
    print(f"\nConfiguration saved to: {config_path}")
    
    return detector

def detect_platform() -> Dict[str, Any]:
    """
    Standalone function to detect platform - wrapper around PlatformDetector class.
    This function provides a simple interface for other modules to detect the platform
    and returns a dictionary with platform information.
    
    Returns:
        Dict containing platform information with keys:
        - name: Platform name
        - platform_type: 'intel' or 'snapdragon'
        - architecture: 'x86_64' or 'ARM64'
        - acceleration: Available acceleration type
        - cpu_name: Processor name
        - npu_available: Boolean for NPU availability
    """
    detector = PlatformDetector()
    platform_info = detector.detect_hardware()
    optimization_config = detector.get_optimization_config()
    detector.apply_optimizations()
    
    # Return a simplified structure for compatibility
    return {
        'name': platform_info.get('processor_model', platform_info.get('platform_type', 'Unknown')),
        'platform_type': platform_info.get('platform_type', 'unknown'),
        'architecture': platform_info.get('architecture', 'unknown'),
        'acceleration': platform_info.get('ai_acceleration', 'CPU'),
        'cpu_name': platform_info.get('cpu_name', platform_info.get('processor', 'Unknown')),
        'npu_available': platform_info.get('npu_available', False),
        'ai_framework': platform_info.get('ai_framework', 'Unknown'),
        'dedicated_gpu': platform_info.get('dedicated_gpu', False),
        'optimization_config': optimization_config,
        'full_platform_info': platform_info
    }

if __name__ == "__main__":
    main()
