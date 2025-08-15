#!/usr/bin/env python3
"""
Comprehensive Metrics Collection System
AI Image Generation Demo - Enhanced Framework

Provides real-time performance metrics, system resource monitoring,
and platform-specific optimization tracking during diagnostic execution.
"""

import os
import sys
import time
import json
import psutil
import threading
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, List, Optional, Callable, Union
from dataclasses import dataclass, asdict, field
from contextlib import contextmanager
from collections import defaultdict, deque

from diagnostic_config import get_config

@dataclass
class SystemMetrics:
    """System resource metrics snapshot"""
    timestamp: float = field(default_factory=time.time)
    cpu_percent: float = 0.0
    cpu_count: int = 0
    memory_percent: float = 0.0
    memory_available: int = 0
    memory_total: int = 0
    disk_usage: float = 0.0
    network_io: Dict[str, int] = field(default_factory=dict)
    
@dataclass
class GPUMetrics:
    """GPU performance metrics"""
    timestamp: float = field(default_factory=time.time)
    gpu_utilization: float = 0.0
    gpu_memory_used: int = 0
    gpu_memory_total: int = 0
    gpu_temperature: float = 0.0
    gpu_power_draw: float = 0.0
    driver_version: str = ""
    device_name: str = ""

@dataclass
class NPUMetrics:
    """NPU performance metrics for Snapdragon"""
    timestamp: float = field(default_factory=time.time)
    npu_utilization: float = 0.0
    npu_memory_used: int = 0
    npu_power_efficiency: float = 0.0
    qnn_provider_active: bool = False
    inference_ops_per_second: float = 0.0

@dataclass
class TimingMetrics:
    """Detailed timing measurements"""
    operation_name: str = ""
    start_time: float = 0.0
    end_time: float = 0.0
    duration: float = 0.0
    cpu_time: float = 0.0
    wall_time: float = 0.0
    context: Dict[str, Any] = field(default_factory=dict)

@dataclass
class PerformanceBaseline:
    """Performance baseline for comparison"""
    platform_type: str = ""
    cpu_model: str = ""
    total_memory: int = 0
    gpu_model: str = ""
    baseline_metrics: Dict[str, float] = field(default_factory=dict)
    collection_date: str = ""
    sample_count: int = 0

class ResourceMonitor:
    """Real-time system resource monitoring"""
    
    def __init__(self, collection_interval: float = 0.1):
        self.collection_interval = collection_interval
        self.running = False
        self.metrics_history = deque(maxlen=1000)  # Keep last 1000 samples
        self.monitoring_thread = None
        self.callbacks = []
        
    def add_callback(self, callback: Callable[[SystemMetrics], None]):
        """Add callback for real-time metrics"""
        self.callbacks.append(callback)
    
    def start_monitoring(self):
        """Start resource monitoring in background thread"""
        if self.running:
            return
            
        self.running = True
        self.monitoring_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitoring_thread.start()
    
    def stop_monitoring(self):
        """Stop resource monitoring"""
        self.running = False
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=1.0)
    
    def _monitor_loop(self):
        """Main monitoring loop"""
        while self.running:
            try:
                metrics = self._collect_system_metrics()
                self.metrics_history.append(metrics)
                
                # Notify callbacks
                for callback in self.callbacks:
                    try:
                        callback(metrics)
                    except Exception:
                        pass  # Don't let callback errors stop monitoring
                        
                time.sleep(self.collection_interval)
            except Exception:
                time.sleep(self.collection_interval)
    
    def _collect_system_metrics(self) -> SystemMetrics:
        """Collect current system metrics"""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=None)
            cpu_count = psutil.cpu_count()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            
            # Disk usage for current directory
            disk = psutil.disk_usage('.')
            
            # Network I/O
            network = psutil.net_io_counters()
            network_io = {
                'bytes_sent': network.bytes_sent if network else 0,
                'bytes_recv': network.bytes_recv if network else 0,
                'packets_sent': network.packets_sent if network else 0,
                'packets_recv': network.packets_recv if network else 0
            }
            
            return SystemMetrics(
                cpu_percent=cpu_percent,
                cpu_count=cpu_count,
                memory_percent=memory.percent,
                memory_available=memory.available,
                memory_total=memory.total,
                disk_usage=disk.percent,
                network_io=network_io
            )
        except Exception:
            return SystemMetrics()
    
    def get_current_metrics(self) -> Optional[SystemMetrics]:
        """Get most recent metrics"""
        return self.metrics_history[-1] if self.metrics_history else None
    
    def get_metrics_summary(self, duration_seconds: float = 60.0) -> Dict[str, Any]:
        """Get summary statistics for recent metrics"""
        cutoff_time = time.time() - duration_seconds
        recent_metrics = [m for m in self.metrics_history if m.timestamp >= cutoff_time]
        
        if not recent_metrics:
            return {}
        
        cpu_values = [m.cpu_percent for m in recent_metrics]
        memory_values = [m.memory_percent for m in recent_metrics]
        
        return {
            'sample_count': len(recent_metrics),
            'duration_seconds': duration_seconds,
            'cpu': {
                'avg': sum(cpu_values) / len(cpu_values),
                'min': min(cpu_values),
                'max': max(cpu_values)
            },
            'memory': {
                'avg': sum(memory_values) / len(memory_values),
                'min': min(memory_values),
                'max': max(memory_values)
            }
        }

class GPUMonitor:
    """GPU performance monitoring"""
    
    def __init__(self):
        self.nvidia_available = self._check_nvidia_smi()
        self.intel_available = self._check_intel_gpu()
        
    def _check_nvidia_smi(self) -> bool:
        """Check if nvidia-smi is available"""
        try:
            subprocess.run(['nvidia-smi', '--version'], 
                         capture_output=True, check=True, timeout=5)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def _check_intel_gpu(self) -> bool:
        """Check if Intel GPU tools are available"""
        try:
            # Try to import torch_directml as indicator
            import torch_directml
            return torch_directml.is_available()
        except ImportError:
            return False
    
    def collect_gpu_metrics(self) -> Optional[GPUMetrics]:
        """Collect current GPU metrics"""
        if self.nvidia_available:
            return self._collect_nvidia_metrics()
        elif self.intel_available:
            return self._collect_intel_metrics()
        return None
    
    def _collect_nvidia_metrics(self) -> Optional[GPUMetrics]:
        """Collect NVIDIA GPU metrics"""
        try:
            # Query nvidia-smi for metrics
            cmd = [
                'nvidia-smi',
                '--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,driver_version,name',
                '--format=csv,noheader,nounits'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                values = result.stdout.strip().split(', ')
                if len(values) >= 7:
                    return GPUMetrics(
                        gpu_utilization=float(values[0]),
                        gpu_memory_used=int(values[1]) * 1024 * 1024,  # Convert MB to bytes
                        gpu_memory_total=int(values[2]) * 1024 * 1024,
                        gpu_temperature=float(values[3]),
                        gpu_power_draw=float(values[4]) if values[4] != '[Not Supported]' else 0.0,
                        driver_version=values[5],
                        device_name=values[6]
                    )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError):
            pass
        return None
    
    def _collect_intel_metrics(self) -> Optional[GPUMetrics]:
        """Collect Intel GPU metrics"""
        try:
            import torch_directml
            if torch_directml.is_available():
                device_name = torch_directml.device_name(0)
                
                # Basic metrics - Intel GPU monitoring is limited
                return GPUMetrics(
                    gpu_utilization=0.0,  # Not easily available
                    gpu_memory_used=0,
                    gpu_memory_total=0,
                    gpu_temperature=0.0,
                    gpu_power_draw=0.0,
                    driver_version="",
                    device_name=device_name
                )
        except Exception:
            pass
        return None

class NPUMonitor:
    """NPU performance monitoring for Snapdragon"""
    
    def __init__(self):
        self.qnn_available = self._check_qnn_provider()
    
    def _check_qnn_provider(self) -> bool:
        """Check if QNN provider is available"""
        try:
            import onnxruntime as ort
            return 'QNNExecutionProvider' in ort.get_available_providers()
        except ImportError:
            return False
    
    def collect_npu_metrics(self) -> Optional[NPUMetrics]:
        """Collect current NPU metrics"""
        if not self.qnn_available:
            return None
            
        try:
            # NPU metrics are limited in availability
            # This is a placeholder for when more detailed NPU monitoring becomes available
            return NPUMetrics(
                npu_utilization=0.0,  # Not easily available
                npu_memory_used=0,
                npu_power_efficiency=0.0,
                qnn_provider_active=self.qnn_available,
                inference_ops_per_second=0.0
            )
        except Exception:
            return None

class TimingCollector:
    """Detailed timing measurements for operations"""
    
    def __init__(self):
        self.active_timers = {}
        self.completed_timings = []
        self.nested_operations = []
    
    @contextmanager
    def time_operation(self, operation_name: str, **context):
        """Context manager for timing operations"""
        timing = TimingMetrics(
            operation_name=operation_name,
            start_time=time.time(),
            context=context
        )
        
        # Track nested operations
        self.nested_operations.append(operation_name)
        
        try:
            yield timing
        finally:
            timing.end_time = time.time()
            timing.duration = timing.end_time - timing.start_time
            timing.wall_time = timing.duration
            
            self.completed_timings.append(timing)
            self.nested_operations.pop()
    
    def get_timing_summary(self) -> Dict[str, Any]:
        """Get summary of all timing measurements"""
        if not self.completed_timings:
            return {}
        
        # Group by operation name
        operation_groups = defaultdict(list)
        for timing in self.completed_timings:
            operation_groups[timing.operation_name].append(timing.duration)
        
        summary = {}
        for op_name, durations in operation_groups.items():
            summary[op_name] = {
                'count': len(durations),
                'total_time': sum(durations),
                'avg_time': sum(durations) / len(durations),
                'min_time': min(durations),
                'max_time': max(durations)
            }
        
        return summary

class MetricsCollector:
    """Main metrics collection coordinator"""
    
    def __init__(self):
        self.config = get_config()
        self.resource_monitor = ResourceMonitor(self.config.metrics.collection_interval)
        self.gpu_monitor = GPUMonitor()
        self.npu_monitor = NPUMonitor()
        self.timing_collector = TimingCollector()
        
        self.platform_type = "unknown"
        self.collection_active = False
        self.baseline_data = None
        self.metrics_callbacks = []
        
        # Performance thresholds
        self.performance_thresholds = {
            'cpu_high': 80.0,
            'memory_high': 85.0,
            'gpu_high': 90.0,
            'disk_high': 90.0
        }
    
    def set_platform_type(self, platform_type: str):
        """Set the detected platform type"""
        self.platform_type = platform_type
    
    def start_collection(self):
        """Start metrics collection"""
        if not self.config.metrics.enable_performance_metrics:
            return
            
        self.collection_active = True
        
        if self.config.metrics.enable_resource_monitoring:
            self.resource_monitor.start_monitoring()
            
        # Add real-time monitoring callback
        self.resource_monitor.add_callback(self._check_performance_thresholds)
    
    def stop_collection(self):
        """Stop metrics collection"""
        self.collection_active = False
        self.resource_monitor.stop_monitoring()
    
    def _check_performance_thresholds(self, metrics: SystemMetrics):
        """Check if performance thresholds are exceeded"""
        alerts = []
        
        if metrics.cpu_percent > self.performance_thresholds['cpu_high']:
            alerts.append(f"High CPU usage: {metrics.cpu_percent:.1f}%")
            
        if metrics.memory_percent > self.performance_thresholds['memory_high']:
            alerts.append(f"High memory usage: {metrics.memory_percent:.1f}%")
            
        if metrics.disk_usage > self.performance_thresholds['disk_high']:
            alerts.append(f"High disk usage: {metrics.disk_usage:.1f}%")
        
        if alerts:
            # Notify callbacks about performance issues
            for callback in self.metrics_callbacks:
                try:
                    callback('performance_alert', {'alerts': alerts, 'metrics': metrics})
                except Exception:
                    pass
    
    def add_metrics_callback(self, callback: Callable[[str, Dict[str, Any]], None]):
        """Add callback for metrics events"""
        self.metrics_callbacks.append(callback)
    
    @contextmanager
    def time_test(self, test_name: str, **context):
        """Time a test execution with full metrics collection"""
        if not self.collection_active:
            self.start_collection()
        
        # Collect baseline metrics
        baseline_system = self.resource_monitor.get_current_metrics()
        baseline_gpu = self.gpu_monitor.collect_gpu_metrics()
        baseline_npu = self.npu_monitor.collect_npu_metrics()
        
        with self.timing_collector.time_operation(test_name, **context) as timing:
            yield timing
        
        # Collect final metrics
        final_system = self.resource_monitor.get_current_metrics()
        final_gpu = self.gpu_monitor.collect_gpu_metrics()
        final_npu = self.npu_monitor.collect_npu_metrics()
        
        # Calculate resource delta
        if baseline_system and final_system:
            self._calculate_resource_delta(test_name, baseline_system, final_system)
    
    def _calculate_resource_delta(self, test_name: str, baseline: SystemMetrics, final: SystemMetrics):
        """Calculate resource usage delta during test"""
        delta = {
            'test_name': test_name,
            'cpu_delta': final.cpu_percent - baseline.cpu_percent,
            'memory_delta': final.memory_percent - baseline.memory_percent,
            'network_sent_delta': (final.network_io.get('bytes_sent', 0) - 
                                 baseline.network_io.get('bytes_sent', 0)),
            'network_recv_delta': (final.network_io.get('bytes_recv', 0) - 
                                 baseline.network_io.get('bytes_recv', 0))
        }
        
        # Notify callbacks
        for callback in self.metrics_callbacks:
            try:
                callback('resource_delta', delta)
            except Exception:
                pass
    
    def collect_performance_baseline(self) -> PerformanceBaseline:
        """Collect performance baseline for the current system"""
        if not self.config.metrics.baseline_collection:
            return None
        
        # Collect system info
        cpu_info = self._get_cpu_info()
        memory_info = psutil.virtual_memory()
        gpu_info = self.gpu_monitor.collect_gpu_metrics()
        
        # Collect performance samples
        baseline_metrics = {}
        
        # CPU benchmark
        baseline_metrics['cpu_benchmark'] = self._run_cpu_benchmark()
        
        # Memory bandwidth test
        baseline_metrics['memory_bandwidth'] = self._run_memory_test()
        
        # Platform-specific tests
        if self.platform_type == 'intel' and gpu_info:
            baseline_metrics['directml_ops_per_second'] = self._run_directml_benchmark()
        elif self.platform_type == 'snapdragon':
            baseline_metrics['npu_ops_per_second'] = self._run_npu_benchmark()
        
        return PerformanceBaseline(
            platform_type=self.platform_type,
            cpu_model=cpu_info.get('brand', 'Unknown'),
            total_memory=memory_info.total,
            gpu_model=gpu_info.device_name if gpu_info else 'Unknown',
            baseline_metrics=baseline_metrics,
            collection_date=datetime.now(timezone.utc).isoformat(),
            sample_count=1
        )
    
    def _get_cpu_info(self) -> Dict[str, Any]:
        """Get CPU information"""
        try:
            import cpuinfo
            return cpuinfo.get_cpu_info()
        except ImportError:
            return {'brand': 'Unknown'}
    
    def _run_cpu_benchmark(self) -> float:
        """Run simple CPU benchmark"""
        try:
            start_time = time.time()
            # Simple calculation benchmark
            result = sum(i * i for i in range(100000))
            end_time = time.time()
            return 1.0 / (end_time - start_time)  # Operations per second
        except Exception:
            return 0.0
    
    def _run_memory_test(self) -> float:
        """Run memory bandwidth test"""
        try:
            import array
            start_time = time.time()
            # Create and manipulate large array
            data = array.array('i', range(1000000))
            data.reverse()
            end_time = time.time()
            return len(data) / (end_time - start_time)  # Elements per second
        except Exception:
            return 0.0
    
    def _run_directml_benchmark(self) -> float:
        """Run DirectML benchmark"""
        try:
            import torch
            import torch_directml
            
            if not torch_directml.is_available():
                return 0.0
            
            device = torch_directml.device()
            start_time = time.time()
            
            # Simple tensor operations
            a = torch.randn(1000, 1000).to(device)
            b = torch.randn(1000, 1000).to(device)
            c = torch.mm(a, b)
            torch_directml.synchronize()
            
            end_time = time.time()
            return 1.0 / (end_time - start_time)  # Operations per second
        except Exception:
            return 0.0
    
    def _run_npu_benchmark(self) -> float:
        """Run NPU benchmark"""
        try:
            # NPU benchmarking would require specific models and setup
            # This is a placeholder for when NPU benchmarking becomes available
            return 0.0
        except Exception:
            return 0.0
    
    def get_comprehensive_metrics(self) -> Dict[str, Any]:
        """Get comprehensive metrics summary"""
        summary = {
            'collection_time': datetime.now(timezone.utc).isoformat(),
            'platform_type': self.platform_type,
            'collection_active': self.collection_active
        }
        
        # System metrics
        current_system = self.resource_monitor.get_current_metrics()
        if current_system:
            summary['system'] = asdict(current_system)
        
        # GPU metrics
        gpu_metrics = self.gpu_monitor.collect_gpu_metrics()
        if gpu_metrics:
            summary['gpu'] = asdict(gpu_metrics)
        
        # NPU metrics
        npu_metrics = self.npu_monitor.collect_npu_metrics()
        if npu_metrics:
            summary['npu'] = asdict(npu_metrics)
        
        # Timing summary
        timing_summary = self.timing_collector.get_timing_summary()
        if timing_summary:
            summary['timing'] = timing_summary
        
        # Resource monitoring summary
        resource_summary = self.resource_monitor.get_metrics_summary(60.0)
        if resource_summary:
            summary['resource_trend'] = resource_summary
        
        # Performance baseline
        if self.baseline_data:
            summary['baseline'] = asdict(self.baseline_data)
        
        return summary
    
    def export_metrics(self, output_path: str) -> bool:
        """Export collected metrics to JSON file"""
        try:
            metrics = self.get_comprehensive_metrics()
            with open(output_path, 'w') as f:
                json.dump(metrics, f, indent=2, default=str)
            return True
        except Exception:
            return False

# Global metrics collector instance
_metrics_collector = None

def get_metrics_collector() -> MetricsCollector:
    """Get global metrics collector instance"""
    global _metrics_collector
    if _metrics_collector is None:
        _metrics_collector = MetricsCollector()
    return _metrics_collector

def start_metrics_collection():
    """Start global metrics collection"""
    get_metrics_collector().start_collection()

def stop_metrics_collection():
    """Stop global metrics collection"""
    get_metrics_collector().stop_collection()

@contextmanager
def time_operation(operation_name: str, **context):
    """Context manager for timing operations"""
    with get_metrics_collector().time_test(operation_name, **context) as timing:
        yield timing