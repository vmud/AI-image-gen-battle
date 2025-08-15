#!/usr/bin/env python3
"""
Diagnostic Configuration Management
AI Image Generation Demo - Enhanced Framework

Provides centralized configuration management for the enhanced diagnostic framework,
supporting advanced logging, metrics collection, reporting, and data persistence.
"""

import os
import json
import argparse
from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from enum import Enum

class LogLevel(Enum):
    """Supported logging levels"""
    ERROR = "ERROR"
    WARN = "WARN"
    INFO = "INFO"
    DEBUG = "DEBUG"
    VERBOSE = "VERBOSE"

class OutputFormat(Enum):
    """Supported output formats"""
    CONSOLE = "console"
    JSON = "json"
    STRUCTURED = "structured"

class ReportFormat(Enum):
    """Supported report formats"""
    JSON = "json"
    HTML = "html"
    MARKDOWN = "markdown"
    ALL = "all"

@dataclass
class LoggingConfig:
    """Logging configuration settings"""
    level: LogLevel = LogLevel.INFO
    output_format: OutputFormat = OutputFormat.CONSOLE
    enable_file_logging: bool = True
    log_file_path: str = "diagnostic.log"
    max_log_size: int = 10 * 1024 * 1024  # 10MB
    backup_count: int = 5
    enable_structured_logging: bool = False
    include_stack_trace: bool = True
    context_lines: int = 3

@dataclass
class MetricsConfig:
    """Metrics collection configuration"""
    enable_performance_metrics: bool = True
    enable_resource_monitoring: bool = True
    collection_interval: float = 0.1  # seconds
    enable_gpu_monitoring: bool = True
    enable_npu_monitoring: bool = True
    enable_memory_profiling: bool = True
    baseline_collection: bool = True
    detailed_timing: bool = True

@dataclass
class StorageConfig:
    """Data persistence configuration"""
    enable_historical_storage: bool = True
    database_path: str = "diagnostic_history.db"
    retention_days: int = 30
    enable_trend_analysis: bool = True
    baseline_threshold_days: int = 7
    enable_alerting: bool = False
    performance_degradation_threshold: float = 0.2  # 20% degradation

@dataclass
class ReportingConfig:
    """Reporting and visualization configuration"""
    enable_detailed_reports: bool = False
    output_formats: List[ReportFormat] = None
    output_directory: str = "diagnostic_reports"
    include_charts: bool = True
    include_trends: bool = True
    include_baselines: bool = True
    enable_comparison: bool = True
    template_directory: str = "report_templates"

    def __post_init__(self):
        if self.output_formats is None:
            self.output_formats = [ReportFormat.JSON]

@dataclass
class PlatformConfig:
    """Platform-specific configuration"""
    intel_directml_timeout: float = 30.0
    snapdragon_qnn_timeout: float = 15.0
    performance_test_steps: Dict[str, int] = None
    performance_test_resolution: tuple = (512, 512)
    enable_fallback_testing: bool = True
    custom_model_paths: List[str] = None

    def __post_init__(self):
        if self.performance_test_steps is None:
            self.performance_test_steps = {"intel": 10, "snapdragon": 4}
        if self.custom_model_paths is None:
            self.custom_model_paths = []

@dataclass
class DiagnosticConfig:
    """Main diagnostic configuration container"""
    logging: LoggingConfig = None
    metrics: MetricsConfig = None
    storage: StorageConfig = None
    reporting: ReportingConfig = None
    platform: PlatformConfig = None
    
    # Global settings
    enable_enhanced_mode: bool = False
    config_file_path: str = "diagnostic_config.json"
    validate_on_load: bool = True

    def __post_init__(self):
        if self.logging is None:
            self.logging = LoggingConfig()
        if self.metrics is None:
            self.metrics = MetricsConfig()
        if self.storage is None:
            self.storage = StorageConfig()
        if self.reporting is None:
            self.reporting = ReportingConfig()
        if self.platform is None:
            self.platform = PlatformConfig()

class ConfigManager:
    """Centralized configuration management"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config_path = config_path or "diagnostic_config.json"
        self._config = DiagnosticConfig()
        self._command_line_args = None
        
    def load_config(self, config_path: Optional[str] = None) -> DiagnosticConfig:
        """Load configuration from file or create default"""
        if config_path:
            self.config_path = config_path
            
        config_file = Path(self.config_path)
        
        if config_file.exists():
            try:
                with open(config_file, 'r') as f:
                    config_data = json.load(f)
                    self._config = self._deserialize_config(config_data)
            except Exception as e:
                print(f"Warning: Failed to load config from {config_file}: {e}")
                print("Using default configuration")
                self._config = DiagnosticConfig()
        else:
            # Create default config file
            self.save_config()
            
        return self._config
    
    def save_config(self, config_path: Optional[str] = None) -> None:
        """Save current configuration to file"""
        if config_path:
            self.config_path = config_path
            
        config_file = Path(self.config_path)
        config_file.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            config_data = self._serialize_config(self._config)
            with open(config_file, 'w') as f:
                json.dump(config_data, f, indent=2)
        except Exception as e:
            print(f"Warning: Failed to save config to {config_file}: {e}")
    
    def _serialize_config(self, config: DiagnosticConfig) -> Dict[str, Any]:
        """Convert config to JSON-serializable format"""
        def convert_enum(obj):
            if isinstance(obj, Enum):
                return obj.value
            elif isinstance(obj, list):
                return [convert_enum(item) for item in obj]
            elif isinstance(obj, dict):
                return {k: convert_enum(v) for k, v in obj.items()}
            return obj
        
        config_dict = asdict(config)
        return convert_enum(config_dict)
    
    def _deserialize_config(self, config_data: Dict[str, Any]) -> DiagnosticConfig:
        """Convert JSON data back to config objects"""
        # Convert enum strings back to enums
        if 'logging' in config_data:
            logging_data = config_data['logging']
            if 'level' in logging_data:
                logging_data['level'] = LogLevel(logging_data['level'])
            if 'output_format' in logging_data:
                logging_data['output_format'] = OutputFormat(logging_data['output_format'])
        
        if 'reporting' in config_data:
            reporting_data = config_data['reporting']
            if 'output_formats' in reporting_data:
                reporting_data['output_formats'] = [
                    ReportFormat(fmt) for fmt in reporting_data['output_formats']
                ]
        
        # Create config objects
        config = DiagnosticConfig()
        
        if 'logging' in config_data:
            config.logging = LoggingConfig(**config_data['logging'])
        if 'metrics' in config_data:
            config.metrics = MetricsConfig(**config_data['metrics'])
        if 'storage' in config_data:
            config.storage = StorageConfig(**config_data['storage'])
        if 'reporting' in config_data:
            config.reporting = ReportingConfig(**config_data['reporting'])
        if 'platform' in config_data:
            config.platform = PlatformConfig(**config_data['platform'])
        
        # Set global settings
        for key in ['enable_enhanced_mode', 'config_file_path', 'validate_on_load']:
            if key in config_data:
                setattr(config, key, config_data[key])
        
        return config
    
    def parse_command_line(self, args: Optional[List[str]] = None) -> argparse.Namespace:
        """Parse command line arguments and update configuration"""
        parser = argparse.ArgumentParser(
            description="Enhanced AI Image Generation Diagnostic Tool",
            formatter_class=argparse.RawDescriptionHelpFormatter
        )
        
        # Enhanced mode flags
        parser.add_argument(
            '--detailed-report', 
            action='store_true',
            help='Generate detailed diagnostic report'
        )
        
        parser.add_argument(
            '--enhanced-logging',
            action='store_true',
            help='Enable enhanced logging with detailed output'
        )
        
        # Logging options
        parser.add_argument(
            '--log-level',
            choices=[level.value for level in LogLevel],
            help='Set logging verbosity level'
        )
        
        parser.add_argument(
            '--log-format',
            choices=[fmt.value for fmt in OutputFormat],
            help='Set output format (console, json, structured)'
        )
        
        parser.add_argument(
            '--log-file',
            help='Path to log file'
        )
        
        # Reporting options
        parser.add_argument(
            '--report-format',
            choices=[fmt.value for fmt in ReportFormat],
            help='Report output format (json, html, markdown, all)'
        )
        
        parser.add_argument(
            '--report-dir',
            help='Directory for report output'
        )
        
        # Metrics options
        parser.add_argument(
            '--disable-metrics',
            action='store_true',
            help='Disable performance metrics collection'
        )
        
        parser.add_argument(
            '--disable-storage',
            action='store_true',
            help='Disable historical data storage'
        )
        
        # Configuration file
        parser.add_argument(
            '--config',
            help='Path to configuration file'
        )
        
        # Quick mode (backward compatibility)
        parser.add_argument(
            '--quick',
            action='store_true',
            help='Run in quick mode (original behavior)'
        )
        
        self._command_line_args = parser.parse_args(args)
        self._apply_command_line_overrides()
        
        return self._command_line_args
    
    def _apply_command_line_overrides(self) -> None:
        """Apply command line arguments to configuration"""
        if not self._command_line_args:
            return
            
        args = self._command_line_args
        
        # Enhanced mode detection
        if args.detailed_report or args.enhanced_logging:
            self._config.enable_enhanced_mode = True
        
        if args.quick:
            self._config.enable_enhanced_mode = False
        
        # Logging overrides
        if args.log_level:
            self._config.logging.level = LogLevel(args.log_level)
        
        if args.log_format:
            self._config.logging.output_format = OutputFormat(args.log_format)
        
        if args.log_file:
            self._config.logging.log_file_path = args.log_file
        
        if args.enhanced_logging:
            self._config.logging.enable_structured_logging = True
            self._config.logging.include_stack_trace = True
        
        # Reporting overrides
        if args.detailed_report:
            self._config.reporting.enable_detailed_reports = True
        
        if args.report_format:
            if args.report_format == 'all':
                self._config.reporting.output_formats = [
                    ReportFormat.JSON, ReportFormat.HTML, ReportFormat.MARKDOWN
                ]
            else:
                self._config.reporting.output_formats = [ReportFormat(args.report_format)]
        
        if args.report_dir:
            self._config.reporting.output_directory = args.report_dir
        
        # Metrics overrides
        if args.disable_metrics:
            self._config.metrics.enable_performance_metrics = False
            self._config.metrics.enable_resource_monitoring = False
        
        # Storage overrides
        if args.disable_storage:
            self._config.storage.enable_historical_storage = False
    
    def get_config(self) -> DiagnosticConfig:
        """Get current configuration"""
        return self._config
    
    def update_config(self, **kwargs) -> None:
        """Update configuration with provided values"""
        for key, value in kwargs.items():
            if hasattr(self._config, key):
                setattr(self._config, key, value)
    
    def is_enhanced_mode(self) -> bool:
        """Check if enhanced mode is enabled"""
        return self._config.enable_enhanced_mode
    
    def get_platform_config(self, platform_type: str) -> Dict[str, Any]:
        """Get platform-specific configuration"""
        config = {
            'timeout': 30.0,
            'performance_steps': 10,
            'resolution': self._config.platform.performance_test_resolution,
            'enable_fallback': self._config.platform.enable_fallback_testing
        }
        
        if platform_type == 'intel':
            config['timeout'] = self._config.platform.intel_directml_timeout
            config['performance_steps'] = self._config.platform.performance_test_steps.get('intel', 10)
        elif platform_type == 'snapdragon':
            config['timeout'] = self._config.platform.snapdragon_qnn_timeout
            config['performance_steps'] = self._config.platform.performance_test_steps.get('snapdragon', 4)
        
        return config
    
    def validate_config(self) -> List[str]:
        """Validate configuration and return any errors"""
        errors = []
        
        # Validate paths
        if self._config.reporting.enable_detailed_reports:
            report_dir = Path(self._config.reporting.output_directory)
            try:
                report_dir.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errors.append(f"Cannot create report directory: {e}")
        
        if self._config.logging.enable_file_logging:
            log_path = Path(self._config.logging.log_file_path)
            try:
                log_path.parent.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errors.append(f"Cannot create log directory: {e}")
        
        # Validate storage settings
        if self._config.storage.enable_historical_storage:
            if self._config.storage.retention_days < 1:
                errors.append("Storage retention_days must be at least 1")
        
        # Validate metrics settings
        if self._config.metrics.collection_interval <= 0:
            errors.append("Metrics collection_interval must be positive")
        
        return errors

# Global configuration instance
_config_manager = None

def get_config_manager() -> ConfigManager:
    """Get global configuration manager instance"""
    global _config_manager
    if _config_manager is None:
        _config_manager = ConfigManager()
    return _config_manager

def load_config(config_path: Optional[str] = None) -> DiagnosticConfig:
    """Load configuration from file"""
    return get_config_manager().load_config(config_path)

def get_config() -> DiagnosticConfig:
    """Get current configuration"""
    return get_config_manager().get_config()

def is_enhanced_mode() -> bool:
    """Check if enhanced mode is enabled"""
    return get_config_manager().is_enhanced_mode()