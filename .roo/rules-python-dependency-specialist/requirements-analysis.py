#!/usr/bin/env python3
"""
Dependency Analysis Tool for Python Projects
"""

import subprocess
import json
import sys
from pathlib import Path

def check_conflicts():
    """Check for dependency conflicts"""
    result = subprocess.run([sys.executable, "-m", "pip", "check"], 
                          capture_output=True, text=True)
    return result.stdout

def get_dependency_tree():
    """Get full dependency tree"""
    try:
        result = subprocess.run([sys.executable, "-m", "pipdeptree", "--json"], 
                              capture_output=True, text=True)
        return json.loads(result.stdout)
    except:
        return "pipdeptree not installed"

def check_gpu_availability():
    """Check GPU acceleration availability"""
    gpu_info = {}
    
    # Check PyTorch
    try:
        import torch
        gpu_info['pytorch_cuda'] = torch.cuda.is_available()
        gpu_info['pytorch_devices'] = torch.cuda.device_count()
    except ImportError:
        gpu_info['pytorch'] = "Not installed"
    
    # Check DirectML
    try:
        import torch_directml
        gpu_info['directml'] = torch_directml.is_available()
    except ImportError:
        gpu_info['directml'] = "Not installed"
    
    # Check TensorFlow
    try:
        import tensorflow as tf
        gpu_info['tensorflow_gpus'] = len(tf.config.list_physical_devices('GPU'))
    except ImportError:
        gpu_info['tensorflow'] = "Not installed"
    
    return gpu_info

def analyze_requirements():
    """Analyze requirements files"""
    req_files = ['requirements.txt', 'requirements-dev.txt', 
                 'environment.yml', 'Pipfile', 'pyproject.toml']
    
    found_files = {}
    for req_file in req_files:
        if Path(req_file).exists():
            found_files[req_file] = True
    
    return found_files

if __name__ == "__main__":
    print("=== Python Dependency Analysis ===\n")
    
    print("1. Checking for conflicts...")
    print(check_conflicts())
    
    print("\n2. Requirements files found:")
    print(json.dumps(analyze_requirements(), indent=2))
    
    print("\n3. GPU Acceleration Status:")
    print(json.dumps(check_gpu_availability(), indent=2))
    
    print("\n4. Dependency Tree:")
    tree = get_dependency_tree()
    if isinstance(tree, str):
        print(tree)
    else:
        print(f"Found {len(tree)} top-level packages")