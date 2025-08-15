#!/usr/bin/env python3
"""
Error Mitigation and Recovery System for AI Image Generation
Handles common failure scenarios and provides graceful recovery
"""

import os
import sys
import time
import json
import logging
import traceback
import psutil
import threading
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import shutil

logger = logging.getLogger(__name__)

class ErrorMitigationSystem:
    """Comprehensive error handling and recovery for the demo workflow"""
    
    def __init__(self, display_instance=None):
        self.display = display_instance
        self.error_history = []
        self.recovery_strategies = {}
        self.health_status = {
            'model_loaded': False,
            'memory_ok': True,
            'disk_space_ok': True,
            'gpu_available': False,
            'last_check': None
        }
        
        # Common issues and their mitigations
        self.setup_recovery_strategies()
        
        # Start health monitoring
        self.start_health_monitor()
    
    def setup_recovery_strategies(self):
        """Define recovery strategies for common issues"""
        
        self.recovery_strategies = {
            # Model Loading Issues
            'model_not_found': {
                'detection': self.detect_model_missing,
                'recovery': self.recover_model_missing,
                'severity': 'critical'
            },
            
            # Memory Issues
            'out_of_memory': {
                'detection': self.detect_memory_issue,
                'recovery': self.recover_memory_issue,
                'severity': 'high'
            },
            
            # Concurrent Generation
            'concurrent_generation': {
                'detection': self.detect_concurrent_generation,
                'recovery': self.recover_concurrent_generation,
                'severity': 'medium'
            },
            
            # Storage Issues
            'disk_space': {
                'detection': self.detect_disk_space_issue,
                'recovery': self.recover_disk_space_issue,
                'severity': 'high'
            },
            
            # Network/CORS Issues
            'cors_error': {
                'detection': self.detect_cors_issue,
                'recovery': self.recover_cors_issue,
                'severity': 'medium'
            },
            
            # Platform Detection
            'platform_mismatch': {
                'detection': self.detect_platform_mismatch,
                'recovery': self.recover_platform_mismatch,
                'severity': 'high'
            },
            
            # Generation Timeout
            'generation_timeout': {
                'detection': self.detect_generation_timeout,
                'recovery': self.recover_generation_timeout,
                'severity': 'medium'
            },
            
            # GPU/NPU Issues
            'acceleration_failure': {
                'detection': self.detect_acceleration_failure,
                'recovery': self.recover_acceleration_failure,
                'severity': 'medium'
            }
        }
    
    # === Detection Methods ===
    
    def detect_model_missing(self) -> bool:
        """Check if AI models are present"""
        model_paths = [
            Path("C:/AIDemo/models/sdxl-base-1.0"),
            Path("C:/AIDemo/models/sdxl_snapdragon_optimized"),
        ]
        return not any(p.exists() for p in model_paths)
    
    def detect_memory_issue(self) -> bool:
        """Check for memory pressure"""
        memory = psutil.virtual_memory()
        # Issue if less than 2GB available or > 90% used
        return memory.available < 2 * 1024**3 or memory.percent > 90
    
    def detect_concurrent_generation(self) -> bool:
        """Check if multiple generations are running"""
        if self.display and hasattr(self.display, 'jobs') and self.display.jobs:
            active_jobs = sum(1 for job in self.display.jobs.values() 
                            if job.get('status') == 'active')
            return active_jobs > 1
        return False
    
    def detect_disk_space_issue(self) -> bool:
        """Check available disk space"""
        disk = psutil.disk_usage('/')
        # Issue if less than 1GB free
        return disk.free < 1024**3
    
    def detect_cors_issue(self) -> bool:
        """Check if CORS is properly configured"""
        # This would be detected from frontend errors
        return False  # Placeholder - would check logs
    
    def detect_platform_mismatch(self) -> bool:
        """Check if platform detection matches hardware"""
        if not self.display:
            return False
        
        # Check if Snapdragon detection on Intel hardware or vice versa
        import platform
        is_arm = platform.machine().lower() in ['arm64', 'aarch64']
        expects_snapdragon = self.display.is_snapdragon
        
        return is_arm != expects_snapdragon
    
    def detect_generation_timeout(self) -> bool:
        """Check if generation is taking too long"""
        if not self.display or not self.display.demo_active:
            return False
        
        if self.display.start_time:
            elapsed = time.time() - self.display.start_time
            # Timeout after 2 minutes
            return elapsed > 120
        return False
    
    def detect_acceleration_failure(self) -> bool:
        """Check if GPU/NPU acceleration failed to initialize"""
        if not self.display or not self.display.ai_generator:
            return False
        
        # Check if fell back to CPU when acceleration expected
        backend = self.display.ai_generator.optimization_backend
        return backend == "cpu" and not os.environ.get('FORCE_CPU_MODE')
    
    # === Recovery Methods ===
    
    def recover_model_missing(self) -> Dict[str, Any]:
        """Attempt to download or locate models"""
        logger.warning("Models missing - attempting recovery")
        
        suggestions = [
            "1. Run: python deployment/common/scripts/prepare_models.ps1",
            "2. Set MODEL_PATH environment variable to existing models",
            "3. Models will auto-download on first run (requires internet)"
        ]
        
        return {
            'success': False,
            'action': 'manual',
            'suggestions': suggestions,
            'message': 'AI models not found. Please download models first.'
        }
    
    def recover_memory_issue(self) -> Dict[str, Any]:
        """Free up memory"""
        logger.warning("Memory pressure detected - attempting recovery")
        
        actions_taken = []
        
        # Clear Python caches
        import gc
        gc.collect()
        actions_taken.append("Cleared Python garbage collection")
        
        # If display exists, clear old jobs
        if self.display and hasattr(self.display, 'jobs') and len(self.display.jobs) > 10:
            # Keep only last 5 jobs
            job_ids = sorted(self.display.jobs.keys(), 
                           key=lambda x: self.display.jobs[x].get('start_time', 0))
            for job_id in job_ids[:-5]:
                del self.display.jobs[job_id]
            actions_taken.append("Cleared old job history")
        
        # Clear old generated images (keep last 10)
        if self.display:
            image_dir = self.display.generated_images_dir
            if image_dir.exists():
                images = sorted(image_dir.glob("*.png"), key=os.path.getmtime)
                if len(images) > 10:
                    for img in images[:-10]:
                        img.unlink()
                    actions_taken.append("Cleared old generated images")
        
        return {
            'success': True,
            'actions': actions_taken,
            'message': 'Memory cleanup completed'
        }
    
    def recover_concurrent_generation(self) -> Dict[str, Any]:
        """Handle concurrent generation attempts"""
        logger.warning("Concurrent generation detected")
        
        return {
            'success': False,
            'action': 'block',
            'message': 'Generation already in progress. Please wait for completion.'
        }
    
    def recover_disk_space_issue(self) -> Dict[str, Any]:
        """Free up disk space"""
        logger.warning("Low disk space - attempting recovery")
        
        actions_taken = []
        
        # Clear old generated images
        if self.display:
            image_dir = self.display.generated_images_dir
            if image_dir.exists():
                images = list(image_dir.glob("*.png"))
                if len(images) > 5:
                    # Delete all but last 5 images
                    for img in sorted(images, key=os.path.getmtime)[:-5]:
                        img.unlink()
                    actions_taken.append(f"Deleted {len(images)-5} old images")
        
        # Clear temp files
        temp_dirs = [Path("/tmp"), Path(os.environ.get('TEMP', '/tmp'))]
        for temp_dir in temp_dirs:
            if temp_dir.exists():
                # Clear .tmp files older than 1 hour
                cutoff = time.time() - 3600
                for tmp_file in temp_dir.glob("*.tmp"):
                    try:
                        if os.path.getmtime(tmp_file) < cutoff:
                            tmp_file.unlink()
                    except:
                        pass
        
        return {
            'success': True,
            'actions': actions_taken,
            'message': 'Disk cleanup completed'
        }
    
    def recover_cors_issue(self) -> Dict[str, Any]:
        """Provide CORS configuration guidance"""
        return {
            'success': False,
            'action': 'config',
            'message': 'CORS issue detected. Ensure Flask CORS is enabled.',
            'suggestions': [
                'Backend should have: CORS(app)',
                'Try accessing via localhost instead of IP',
                'Check browser console for specific CORS errors'
            ]
        }
    
    def recover_platform_mismatch(self) -> Dict[str, Any]:
        """Handle platform detection mismatch"""
        logger.warning("Platform mismatch detected")
        
        # Force re-detection
        if self.display:
            from platform_detection import PlatformDetector
            detector = PlatformDetector()
            new_info = detector.detect_hardware()
            
            return {
                'success': True,
                'action': 'restart',
                'message': f'Platform re-detected as {new_info["platform_type"]}',
                'platform': new_info
            }
        
        return {
            'success': False,
            'message': 'Platform detection issue - restart recommended'
        }
    
    def recover_generation_timeout(self) -> Dict[str, Any]:
        """Handle generation timeout"""
        logger.warning("Generation timeout - stopping current job")
        
        if self.display:
            self.display.stop_generation()
            
            return {
                'success': True,
                'action': 'stopped',
                'message': 'Generation stopped due to timeout',
                'suggestions': [
                    'Try with fewer steps (10-15)',
                    'Use smaller resolution (512x512)',
                    'Check if models are properly loaded'
                ]
            }
        
        return {
            'success': False,
            'message': 'Unable to stop generation'
        }
    
    def recover_acceleration_failure(self) -> Dict[str, Any]:
        """Handle GPU/NPU acceleration failure"""
        logger.warning("Hardware acceleration not available")
        
        suggestions = []
        
        if self.display and self.display.is_snapdragon:
            suggestions = [
                'Install Qualcomm AI Engine runtime',
                'Check ONNX Runtime with QNN provider',
                'CPU fallback will be slower (~60s)'
            ]
        else:
            suggestions = [
                'Install torch-directml: pip install torch-directml',
                'Update GPU drivers',
                'CPU fallback will be slower (~45s)'
            ]
        
        return {
            'success': False,
            'action': 'fallback',
            'message': 'Using CPU fallback (slower performance)',
            'suggestions': suggestions
        }
    
    # === Health Monitoring ===
    
    def start_health_monitor(self):
        """Start background health monitoring"""
        def monitor():
            while True:
                try:
                    self.check_system_health()
                    time.sleep(30)  # Check every 30 seconds
                except Exception as e:
                    logger.error(f"Health monitor error: {e}")
                    time.sleep(60)
        
        monitor_thread = threading.Thread(target=monitor, daemon=True)
        monitor_thread.start()
    
    def check_system_health(self) -> Dict[str, Any]:
        """Comprehensive system health check"""
        health = {
            'timestamp': datetime.now().isoformat(),
            'issues': [],
            'warnings': []
        }
        
        # Check each detection strategy
        for issue_name, strategy in self.recovery_strategies.items():
            try:
                if strategy['detection']():
                    severity = strategy['severity']
                    
                    if severity == 'critical':
                        health['issues'].append(issue_name)
                        # Attempt automatic recovery
                        recovery_result = strategy['recovery']()
                        logger.info(f"Auto-recovery for {issue_name}: {recovery_result}")
                    elif severity == 'high':
                        health['warnings'].append(issue_name)
                    
            except Exception as e:
                logger.error(f"Error checking {issue_name}: {e}")
        
        self.health_status.update({
            'last_check': health['timestamp'],
            'has_issues': len(health['issues']) > 0,
            'has_warnings': len(health['warnings']) > 0
        })
        
        return health
    
    def get_health_summary(self) -> Dict[str, Any]:
        """Get current health summary for status endpoint"""
        return {
            'healthy': not self.health_status.get('has_issues', False),
            'warnings': self.health_status.get('has_warnings', False),
            'last_check': self.health_status.get('last_check'),
            'memory_ok': not self.detect_memory_issue(),
            'disk_ok': not self.detect_disk_space_issue(),
            'models_ok': not self.detect_model_missing()
        }


class JobRecoveryManager:
    """Manages job recovery and cleanup"""
    
    def __init__(self, jobs_dict: Dict[str, Any], max_jobs: int = 20):
        self.jobs = jobs_dict
        self.max_jobs = max_jobs
        self.orphan_timeout = 300  # 5 minutes
    
    def cleanup_old_jobs(self):
        """Remove old completed jobs to prevent memory buildup"""
        if len(self.jobs) <= self.max_jobs:
            return
        
        # Sort by start time and keep only recent jobs
        sorted_jobs = sorted(
            self.jobs.items(),
            key=lambda x: x[1].get('start_time', 0)
        )
        
        # Remove oldest completed jobs
        removed = 0
        for job_id, job in sorted_jobs:
            if job.get('status') in ['completed', 'error', 'stopped']:
                del self.jobs[job_id]
                removed += 1
                if len(self.jobs) <= self.max_jobs // 2:
                    break
        
        if removed > 0:
            logger.info(f"Cleaned up {removed} old jobs")
    
    def detect_orphaned_jobs(self) -> List[str]:
        """Find jobs that are stuck in active state"""
        orphaned = []
        current_time = time.time()
        
        for job_id, job in self.jobs.items():
            if job.get('status') == 'active':
                start_time = job.get('start_time', current_time)
                if current_time - start_time > self.orphan_timeout:
                    orphaned.append(job_id)
        
        return orphaned
    
    def recover_orphaned_jobs(self):
        """Mark orphaned jobs as failed"""
        orphaned = self.detect_orphaned_jobs()
        
        for job_id in orphaned:
            self.jobs[job_id]['status'] = 'error'
            self.jobs[job_id]['error'] = 'Job timeout - marked as failed'
            self.jobs[job_id]['end_time'] = time.time()
            logger.warning(f"Recovered orphaned job: {job_id}")
        
        return len(orphaned)


def create_error_handler(display_instance=None):
    """Factory function to create error mitigation system"""
    return ErrorMitigationSystem(display_instance)


# Decorator for automatic error recovery
def with_error_recovery(recovery_strategy='default'):
    """Decorator to add automatic error recovery to functions"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                logger.error(f"Error in {func.__name__}: {e}")
                logger.error(traceback.format_exc())
                
                # Attempt recovery based on exception type
                if "out of memory" in str(e).lower():
                    mitigation = ErrorMitigationSystem()
                    mitigation.recover_memory_issue()
                elif "model" in str(e).lower() and "not found" in str(e).lower():
                    mitigation = ErrorMitigationSystem()
                    mitigation.recover_model_missing()
                
                # Re-raise if recovery doesn't help
                raise
        return wrapper
    return decorator
