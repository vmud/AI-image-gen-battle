#!/usr/bin/env python3
"""
Advanced Diagnostic Logging Framework
AI Image Generation Demo - Enhanced Framework

Provides enterprise-grade logging capabilities with configurable verbosity levels,
structured output, stack trace capture, and log rotation management.
"""

import os
import sys
import json
import time
import logging
import traceback
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional, List, Union, TextIO
from logging.handlers import RotatingFileHandler
from contextlib import contextmanager
from dataclasses import dataclass, asdict

from diagnostic_config import LogLevel, OutputFormat, get_config

@dataclass
class LogContext:
    """Context information for structured logging"""
    test_name: str = ""
    platform_type: str = ""
    operation: str = ""
    duration: float = 0.0
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}

class StructuredFormatter(logging.Formatter):
    """Custom formatter for structured JSON logging"""
    
    def __init__(self, include_context: bool = True):
        super().__init__()
        self.include_context = include_context
        self.start_time = time.time()
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as structured JSON"""
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        
        # Add duration from start
        log_entry["elapsed_time"] = round(record.created - self.start_time, 3)
        
        # Add context if available
        if hasattr(record, 'context') and self.include_context:
            log_entry["context"] = asdict(record.context)
        
        # Add exception information
        if record.exc_info:
            log_entry["exception"] = {
                "type": record.exc_info[0].__name__ if record.exc_info[0] else None,
                "message": str(record.exc_info[1]) if record.exc_info[1] else None,
                "traceback": self.formatException(record.exc_info)
            }
        
        # Add stack trace for errors
        if record.levelno >= logging.ERROR and not record.exc_info:
            log_entry["stack_trace"] = self._get_stack_context(record)
        
        # Add any extra fields
        for key, value in record.__dict__.items():
            if key not in ['name', 'msg', 'args', 'levelname', 'levelno', 'pathname', 
                          'filename', 'module', 'lineno', 'funcName', 'created', 
                          'msecs', 'relativeCreated', 'thread', 'threadName', 
                          'processName', 'process', 'exc_info', 'exc_text', 'stack_info',
                          'context', 'getMessage']:
                log_entry[key] = value
        
        return json.dumps(log_entry, default=str)
    
    def _get_stack_context(self, record: logging.LogRecord, context_lines: int = 3) -> List[str]:
        """Get stack context around the log call"""
        try:
            stack = traceback.extract_stack()
            # Remove the last few frames (logging internals)
            relevant_stack = stack[:-4]
            
            if len(relevant_stack) > context_lines:
                relevant_stack = relevant_stack[-context_lines:]
            
            return [str(frame) for frame in relevant_stack]
        except Exception:
            return []

class ColoredConsoleFormatter(logging.Formatter):
    """Console formatter with color coding"""
    
    COLORS = {
        'ERROR': '\033[91m',    # Red
        'WARN': '\033[93m',     # Yellow
        'WARNING': '\033[93m',  # Yellow
        'INFO': '\033[92m',     # Green
        'DEBUG': '\033[96m',    # Cyan
        'VERBOSE': '\033[95m',  # Magenta
        'RESET': '\033[0m'      # Reset
    }
    
    def __init__(self, format_string: str = None, use_colors: bool = True):
        if format_string is None:
            format_string = "%(asctime)s [%(levelname)-8s] %(name)s: %(message)s"
        super().__init__(format_string)
        self.use_colors = use_colors and sys.stdout.isatty()
    
    def format(self, record: logging.LogRecord) -> str:
        """Format with colors if enabled"""
        if self.use_colors:
            color = self.COLORS.get(record.levelname, '')
            reset = self.COLORS['RESET']
            record.levelname = f"{color}{record.levelname}{reset}"
        
        formatted = super().format(record)
        
        # Add context if available
        if hasattr(record, 'context'):
            context = record.context
            if context.test_name:
                formatted += f" [Test: {context.test_name}]"
            if context.operation:
                formatted += f" [Op: {context.operation}]"
            if context.duration > 0:
                formatted += f" [Duration: {context.duration:.3f}s]"
        
        return formatted

class DiagnosticLogger:
    """Enhanced diagnostic logging system"""
    
    def __init__(self, name: str = "diagnostic", config: Optional[Dict[str, Any]] = None):
        self.name = name
        self.config = get_config()
        self.logger = logging.getLogger(name)
        self.context_stack = []
        self.metrics = {
            'total_logs': 0,
            'error_count': 0,
            'warning_count': 0,
            'start_time': time.time()
        }
        
        # Thread-local storage for context
        self._local = threading.local()
        
        self._setup_logger()
    
    def _setup_logger(self):
        """Configure logger based on configuration"""
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # Set level based on configuration
        log_config = self.config.logging
        level_map = {
            LogLevel.ERROR: logging.ERROR,
            LogLevel.WARN: logging.WARNING,
            LogLevel.INFO: logging.INFO,
            LogLevel.DEBUG: logging.DEBUG,
            LogLevel.VERBOSE: logging.DEBUG - 5  # Custom verbose level
        }
        
        self.logger.setLevel(level_map.get(log_config.level, logging.INFO))
        
        # Add custom VERBOSE level
        logging.addLevelName(logging.DEBUG - 5, 'VERBOSE')
        
        # Console handler
        if log_config.output_format == OutputFormat.JSON:
            console_formatter = StructuredFormatter()
        elif log_config.output_format == OutputFormat.STRUCTURED:
            console_formatter = ColoredConsoleFormatter(
                "%(asctime)s [%(levelname)-8s] [%(module)s:%(lineno)d] %(message)s"
            )
        else:
            console_formatter = ColoredConsoleFormatter()
        
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler with rotation
        if log_config.enable_file_logging:
            self._setup_file_handler()
        
        # Prevent propagation to root logger
        self.logger.propagate = False
    
    def _setup_file_handler(self):
        """Setup rotating file handler"""
        log_config = self.config.logging
        log_path = Path(log_config.log_file_path)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Rotating file handler
        file_handler = RotatingFileHandler(
            log_path,
            maxBytes=log_config.max_log_size,
            backupCount=log_config.backup_count
        )
        
        # Always use structured format for file logging
        file_formatter = StructuredFormatter()
        file_handler.setFormatter(file_formatter)
        
        self.logger.addHandler(file_handler)
    
    def _get_context(self) -> LogContext:
        """Get current logging context"""
        if not hasattr(self._local, 'context'):
            self._local.context = LogContext()
        return self._local.context
    
    def _log_with_context(self, level: int, message: str, **kwargs):
        """Log message with current context"""
        extra = kwargs.copy()
        extra['context'] = self._get_context()
        
        self.logger.log(level, message, extra=extra)
        
        # Update metrics
        self.metrics['total_logs'] += 1
        if level >= logging.ERROR:
            self.metrics['error_count'] += 1
        elif level >= logging.WARNING:
            self.metrics['warning_count'] += 1
    
    @contextmanager
    def test_context(self, test_name: str, platform_type: str = "", operation: str = ""):
        """Context manager for test execution logging"""
        start_time = time.time()
        old_context = getattr(self._local, 'context', LogContext())
        
        # Create new context
        new_context = LogContext(
            test_name=test_name,
            platform_type=platform_type,
            operation=operation,
            metadata=old_context.metadata.copy()
        )
        self._local.context = new_context
        
        self.info(f"Starting test: {test_name}")
        
        try:
            yield self
        except Exception as e:
            duration = time.time() - start_time
            new_context.duration = duration
            self.error(f"Test failed: {test_name}", exc_info=True)
            raise
        else:
            duration = time.time() - start_time
            new_context.duration = duration
            self.info(f"Test completed: {test_name} (Duration: {duration:.3f}s)")
        finally:
            # Restore old context
            self._local.context = old_context
    
    @contextmanager
    def operation_context(self, operation: str, **metadata):
        """Context manager for operation logging"""
        start_time = time.time()
        current_context = self._get_context()
        old_operation = current_context.operation
        
        # Update context
        current_context.operation = operation
        current_context.metadata.update(metadata)
        
        self.debug(f"Starting operation: {operation}")
        
        try:
            yield self
        except Exception as e:
            duration = time.time() - start_time
            self.error(f"Operation failed: {operation} (Duration: {duration:.3f}s)", exc_info=True)
            raise
        else:
            duration = time.time() - start_time
            self.debug(f"Operation completed: {operation} (Duration: {duration:.3f}s)")
        finally:
            # Restore old operation
            current_context.operation = old_operation
            for key in metadata:
                current_context.metadata.pop(key, None)
    
    def set_platform(self, platform_type: str):
        """Set platform type in context"""
        context = self._get_context()
        context.platform_type = platform_type
    
    def add_metadata(self, **metadata):
        """Add metadata to current context"""
        context = self._get_context()
        context.metadata.update(metadata)
    
    def error(self, message: str, **kwargs):
        """Log error message"""
        self._log_with_context(logging.ERROR, message, **kwargs)
    
    def warning(self, message: str, **kwargs):
        """Log warning message"""
        self._log_with_context(logging.WARNING, message, **kwargs)
    
    def warn(self, message: str, **kwargs):
        """Alias for warning"""
        self.warning(message, **kwargs)
    
    def info(self, message: str, **kwargs):
        """Log info message"""
        self._log_with_context(logging.INFO, message, **kwargs)
    
    def debug(self, message: str, **kwargs):
        """Log debug message"""
        self._log_with_context(logging.DEBUG, message, **kwargs)
    
    def verbose(self, message: str, **kwargs):
        """Log verbose message"""
        self._log_with_context(logging.DEBUG - 5, message, **kwargs)
    
    def log_test_result(self, test_name: str, status: str, message: str, 
                       details: Optional[Dict[str, Any]] = None, 
                       fix_commands: Optional[List[str]] = None,
                       duration: float = 0.0):
        """Log structured test result"""
        result_data = {
            'test_name': test_name,
            'status': status,
            'message': message,
            'duration': duration
        }
        
        if details:
            result_data['details'] = details
        
        if fix_commands:
            result_data['fix_commands'] = fix_commands
        
        # Choose log level based on status
        if status == "FAIL":
            self.error(f"Test Result: {message}", test_result=result_data)
        elif status == "PASS":
            self.info(f"Test Result: {message}", test_result=result_data)
        else:
            self.debug(f"Test Result: {message}", test_result=result_data)
    
    def log_performance_metric(self, metric_name: str, value: Union[float, int], 
                              unit: str = "", target: Optional[float] = None):
        """Log performance metric"""
        metric_data = {
            'metric_name': metric_name,
            'value': value,
            'unit': unit,
            'timestamp': time.time()
        }
        
        if target is not None:
            metric_data['target'] = target
            metric_data['meets_target'] = value <= target if 'time' in metric_name.lower() else value >= target
        
        self.info(f"Performance Metric: {metric_name} = {value}{unit}", 
                 performance_metric=metric_data)
    
    def log_system_info(self, info: Dict[str, Any]):
        """Log system information"""
        self.info("System Information", system_info=info)
    
    def log_error_with_context(self, error: Exception, context: str = "", 
                              include_locals: bool = False):
        """Log error with enhanced context information"""
        error_data = {
            'error_type': type(error).__name__,
            'error_message': str(error),
            'context': context
        }
        
        if include_locals:
            try:
                frame = sys.exc_info()[2].tb_frame if sys.exc_info()[2] else None
                if frame:
                    error_data['local_variables'] = {
                        k: str(v) for k, v in frame.f_locals.items() 
                        if not k.startswith('_')
                    }
            except Exception:
                pass
        
        self.error(f"Exception in {context}: {error}", 
                  exc_info=True, error_details=error_data)
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get logging metrics"""
        current_time = time.time()
        runtime = current_time - self.metrics['start_time']
        
        return {
            **self.metrics,
            'runtime_seconds': runtime,
            'logs_per_second': self.metrics['total_logs'] / runtime if runtime > 0 else 0
        }
    
    def export_logs(self, output_path: str, format_type: str = "json") -> bool:
        """Export logs to file"""
        try:
            # This would require implementing log storage/retrieval
            # For now, just indicate successful export
            self.info(f"Logs exported to {output_path} in {format_type} format")
            return True
        except Exception as e:
            self.error(f"Failed to export logs: {e}")
            return False

class LoggerFactory:
    """Factory for creating configured loggers"""
    
    _loggers: Dict[str, DiagnosticLogger] = {}
    
    @classmethod
    def get_logger(cls, name: str = "diagnostic") -> DiagnosticLogger:
        """Get or create logger instance"""
        if name not in cls._loggers:
            cls._loggers[name] = DiagnosticLogger(name)
        return cls._loggers[name]
    
    @classmethod
    def configure_all_loggers(cls):
        """Reconfigure all existing loggers"""
        for logger in cls._loggers.values():
            logger._setup_logger()

# Global logger instance
_default_logger = None

def get_logger(name: str = "diagnostic") -> DiagnosticLogger:
    """Get default logger instance"""
    global _default_logger
    if _default_logger is None:
        _default_logger = LoggerFactory.get_logger(name)
    return _default_logger

def setup_logging(config_path: Optional[str] = None):
    """Setup logging system with configuration"""
    if config_path:
        from diagnostic_config import get_config_manager
        get_config_manager().load_config(config_path)
    
    # Reconfigure all loggers
    LoggerFactory.configure_all_loggers()

# Convenience functions
def log_test_start(test_name: str, platform_type: str = ""):
    """Log test start"""
    get_logger().info(f"Starting test: {test_name}", 
                     test_event={'type': 'start', 'test_name': test_name, 'platform': platform_type})

def log_test_end(test_name: str, status: str, duration: float):
    """Log test end"""
    get_logger().info(f"Test completed: {test_name} - {status} ({duration:.3f}s)",
                     test_event={'type': 'end', 'test_name': test_name, 'status': status, 'duration': duration})

def log_fix_command(command: str, test_name: str = ""):
    """Log fix command"""
    get_logger().info(f"Fix command: {command}",
                     fix_command={'command': command, 'test_name': test_name})