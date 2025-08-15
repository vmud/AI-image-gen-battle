#!/usr/bin/env python3
"""
Diagnostic Data Persistence and Analysis
AI Image Generation Demo - Enhanced Framework

Provides SQLite database storage for historical diagnostic data, trend analysis,
baseline establishment, and performance threshold monitoring.
"""

import os
import sqlite3
import json
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple, Union
from dataclasses import dataclass, asdict
import threading
from contextlib import contextmanager

from diagnostic_config import get_config

@dataclass
class DiagnosticRun:
    """Represents a complete diagnostic run"""
    run_id: str
    timestamp: float
    platform_type: str
    overall_status: str
    total_tests: int
    passed_tests: int
    total_duration: float
    system_info: Dict[str, Any]
    configuration: Dict[str, Any]

@dataclass
class TestResult:
    """Individual test result record"""
    run_id: str
    test_name: str
    status: str
    message: str
    duration: float
    details: Dict[str, Any]
    fix_commands: List[str]
    error_info: Optional[Dict[str, Any]] = None

@dataclass
class PerformanceMetric:
    """Performance metric record"""
    run_id: str
    metric_name: str
    metric_value: float
    metric_unit: str
    target_value: Optional[float]
    timestamp: float
    context: Dict[str, Any]

@dataclass
class SystemSnapshot:
    """System resource snapshot"""
    run_id: str
    timestamp: float
    cpu_percent: float
    memory_percent: float
    gpu_utilization: float
    gpu_memory_used: int
    disk_usage: float
    network_io: Dict[str, Any]

@dataclass
class PerformanceBaseline:
    """Performance baseline record"""
    baseline_id: str
    platform_type: str
    cpu_model: str
    gpu_model: str
    total_memory: int
    baseline_metrics: Dict[str, float]
    collection_date: float
    sample_count: int
    is_active: bool

class DatabaseManager:
    """SQLite database management for diagnostic data"""
    
    def __init__(self, db_path: Optional[str] = None):
        self.config = get_config()
        self.db_path = db_path or self.config.storage.database_path
        self.connection_lock = threading.Lock()
        
        # Ensure database directory exists
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize database
        self._initialize_database()
    
    def _initialize_database(self):
        """Create database tables if they don't exist"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Diagnostic runs table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS diagnostic_runs (
                    run_id TEXT PRIMARY KEY,
                    timestamp REAL NOT NULL,
                    platform_type TEXT NOT NULL,
                    overall_status TEXT NOT NULL,
                    total_tests INTEGER NOT NULL,
                    passed_tests INTEGER NOT NULL,
                    total_duration REAL NOT NULL,
                    system_info TEXT NOT NULL,
                    configuration TEXT NOT NULL,
                    created_at REAL DEFAULT (strftime('%s', 'now'))
                )
            ''')
            
            # Test results table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS test_results (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id TEXT NOT NULL,
                    test_name TEXT NOT NULL,
                    status TEXT NOT NULL,
                    message TEXT NOT NULL,
                    duration REAL NOT NULL,
                    details TEXT NOT NULL,
                    fix_commands TEXT NOT NULL,
                    error_info TEXT,
                    FOREIGN KEY (run_id) REFERENCES diagnostic_runs (run_id)
                )
            ''')
            
            # Performance metrics table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS performance_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id TEXT NOT NULL,
                    metric_name TEXT NOT NULL,
                    metric_value REAL NOT NULL,
                    metric_unit TEXT,
                    target_value REAL,
                    timestamp REAL NOT NULL,
                    context TEXT NOT NULL,
                    FOREIGN KEY (run_id) REFERENCES diagnostic_runs (run_id)
                )
            ''')
            
            # System snapshots table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS system_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id TEXT NOT NULL,
                    timestamp REAL NOT NULL,
                    cpu_percent REAL NOT NULL,
                    memory_percent REAL NOT NULL,
                    gpu_utilization REAL,
                    gpu_memory_used INTEGER,
                    disk_usage REAL,
                    network_io TEXT,
                    FOREIGN KEY (run_id) REFERENCES diagnostic_runs (run_id)
                )
            ''')
            
            # Performance baselines table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS performance_baselines (
                    baseline_id TEXT PRIMARY KEY,
                    platform_type TEXT NOT NULL,
                    cpu_model TEXT NOT NULL,
                    gpu_model TEXT NOT NULL,
                    total_memory INTEGER NOT NULL,
                    baseline_metrics TEXT NOT NULL,
                    collection_date REAL NOT NULL,
                    sample_count INTEGER NOT NULL,
                    is_active BOOLEAN DEFAULT 1
                )
            ''')
            
            # Performance alerts table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS performance_alerts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id TEXT NOT NULL,
                    alert_type TEXT NOT NULL,
                    metric_name TEXT NOT NULL,
                    current_value REAL NOT NULL,
                    threshold_value REAL NOT NULL,
                    severity TEXT NOT NULL,
                    timestamp REAL NOT NULL,
                    resolved BOOLEAN DEFAULT 0,
                    FOREIGN KEY (run_id) REFERENCES diagnostic_runs (run_id)
                )
            ''')
            
            # Create indexes for better query performance
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON diagnostic_runs (timestamp)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_runs_platform ON diagnostic_runs (platform_type)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_tests_run_id ON test_results (run_id)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_tests_name ON test_results (test_name)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_metrics_run_id ON performance_metrics (run_id)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_metrics_name ON performance_metrics (metric_name)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_snapshots_run_id ON system_snapshots (run_id)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_baselines_platform ON performance_baselines (platform_type)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_alerts_run_id ON performance_alerts (run_id)')
            
            conn.commit()
    
    @contextmanager
    def _get_connection(self):
        """Get database connection with proper cleanup"""
        with self.connection_lock:
            conn = sqlite3.connect(self.db_path, timeout=30.0)
            conn.row_factory = sqlite3.Row  # Enable dict-like access
            try:
                yield conn
            finally:
                conn.close()
    
    def store_diagnostic_run(self, diagnostic_run: DiagnosticRun) -> bool:
        """Store complete diagnostic run data"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT INTO diagnostic_runs 
                    (run_id, timestamp, platform_type, overall_status, total_tests, 
                     passed_tests, total_duration, system_info, configuration)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    diagnostic_run.run_id,
                    diagnostic_run.timestamp,
                    diagnostic_run.platform_type,
                    diagnostic_run.overall_status,
                    diagnostic_run.total_tests,
                    diagnostic_run.passed_tests,
                    diagnostic_run.total_duration,
                    json.dumps(diagnostic_run.system_info),
                    json.dumps(diagnostic_run.configuration)
                ))
                conn.commit()
                return True
        except Exception as e:
            print(f"Error storing diagnostic run: {e}")
            return False
    
    def store_test_results(self, test_results: List[TestResult]) -> bool:
        """Store test results for a diagnostic run"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                for result in test_results:
                    cursor.execute('''
                        INSERT INTO test_results 
                        (run_id, test_name, status, message, duration, details, fix_commands, error_info)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        result.run_id,
                        result.test_name,
                        result.status,
                        result.message,
                        result.duration,
                        json.dumps(result.details),
                        json.dumps(result.fix_commands),
                        json.dumps(result.error_info) if result.error_info else None
                    ))
                conn.commit()
                return True
        except Exception as e:
            print(f"Error storing test results: {e}")
            return False
    
    def store_performance_metrics(self, metrics: List[PerformanceMetric]) -> bool:
        """Store performance metrics"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                for metric in metrics:
                    cursor.execute('''
                        INSERT INTO performance_metrics 
                        (run_id, metric_name, metric_value, metric_unit, target_value, timestamp, context)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        metric.run_id,
                        metric.metric_name,
                        metric.metric_value,
                        metric.metric_unit,
                        metric.target_value,
                        metric.timestamp,
                        json.dumps(metric.context)
                    ))
                conn.commit()
                return True
        except Exception as e:
            print(f"Error storing performance metrics: {e}")
            return False
    
    def store_system_snapshots(self, snapshots: List[SystemSnapshot]) -> bool:
        """Store system resource snapshots"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                for snapshot in snapshots:
                    cursor.execute('''
                        INSERT INTO system_snapshots 
                        (run_id, timestamp, cpu_percent, memory_percent, gpu_utilization, 
                         gpu_memory_used, disk_usage, network_io)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        snapshot.run_id,
                        snapshot.timestamp,
                        snapshot.cpu_percent,
                        snapshot.memory_percent,
                        snapshot.gpu_utilization,
                        snapshot.gpu_memory_used,
                        snapshot.disk_usage,
                        json.dumps(snapshot.network_io)
                    ))
                conn.commit()
                return True
        except Exception as e:
            print(f"Error storing system snapshots: {e}")
            return False
    
    def store_performance_baseline(self, baseline: PerformanceBaseline) -> bool:
        """Store performance baseline"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                # Deactivate previous baselines for the same platform
                cursor.execute('''
                    UPDATE performance_baselines 
                    SET is_active = 0 
                    WHERE platform_type = ? AND is_active = 1
                ''', (baseline.platform_type,))
                
                # Insert new baseline
                cursor.execute('''
                    INSERT INTO performance_baselines 
                    (baseline_id, platform_type, cpu_model, gpu_model, total_memory, 
                     baseline_metrics, collection_date, sample_count, is_active)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    baseline.baseline_id,
                    baseline.platform_type,
                    baseline.cpu_model,
                    baseline.gpu_model,
                    baseline.total_memory,
                    json.dumps(baseline.baseline_metrics),
                    baseline.collection_date,
                    baseline.sample_count,
                    baseline.is_active
                ))
                conn.commit()
                return True
        except Exception as e:
            print(f"Error storing performance baseline: {e}")
            return False
    
    def get_recent_runs(self, limit: int = 10, platform_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get recent diagnostic runs"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                if platform_type:
                    cursor.execute('''
                        SELECT * FROM diagnostic_runs 
                        WHERE platform_type = ? 
                        ORDER BY timestamp DESC 
                        LIMIT ?
                    ''', (platform_type, limit))
                else:
                    cursor.execute('''
                        SELECT * FROM diagnostic_runs 
                        ORDER BY timestamp DESC 
                        LIMIT ?
                    ''', (limit,))
                
                runs = []
                for row in cursor.fetchall():
                    run_data = dict(row)
                    run_data['system_info'] = json.loads(run_data['system_info'])
                    run_data['configuration'] = json.loads(run_data['configuration'])
                    runs.append(run_data)
                return runs
        except Exception as e:
            print(f"Error getting recent runs: {e}")
            return []
    
    def get_test_trend(self, test_name: str, days: int = 30) -> List[Dict[str, Any]]:
        """Get trend data for a specific test"""
        try:
            cutoff_time = time.time() - (days * 24 * 3600)
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    SELECT tr.*, dr.timestamp as run_timestamp, dr.platform_type
                    FROM test_results tr
                    JOIN diagnostic_runs dr ON tr.run_id = dr.run_id
                    WHERE tr.test_name = ? AND dr.timestamp >= ?
                    ORDER BY dr.timestamp ASC
                ''', (test_name, cutoff_time))
                
                results = []
                for row in cursor.fetchall():
                    result_data = dict(row)
                    result_data['details'] = json.loads(result_data['details'])
                    result_data['fix_commands'] = json.loads(result_data['fix_commands'])
                    if result_data['error_info']:
                        result_data['error_info'] = json.loads(result_data['error_info'])
                    results.append(result_data)
                return results
        except Exception as e:
            print(f"Error getting test trend: {e}")
            return []
    
    def get_performance_trend(self, metric_name: str, days: int = 30) -> List[Dict[str, Any]]:
        """Get performance trend for a specific metric"""
        try:
            cutoff_time = time.time() - (days * 24 * 3600)
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    SELECT pm.*, dr.platform_type
                    FROM performance_metrics pm
                    JOIN diagnostic_runs dr ON pm.run_id = dr.run_id
                    WHERE pm.metric_name = ? AND pm.timestamp >= ?
                    ORDER BY pm.timestamp ASC
                ''', (metric_name, cutoff_time))
                
                metrics = []
                for row in cursor.fetchall():
                    metric_data = dict(row)
                    metric_data['context'] = json.loads(metric_data['context'])
                    metrics.append(metric_data)
                return metrics
        except Exception as e:
            print(f"Error getting performance trend: {e}")
            return []
    
    def get_active_baseline(self, platform_type: str) -> Optional[Dict[str, Any]]:
        """Get active performance baseline for platform"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    SELECT * FROM performance_baselines 
                    WHERE platform_type = ? AND is_active = 1
                    ORDER BY collection_date DESC
                    LIMIT 1
                ''', (platform_type,))
                
                row = cursor.fetchone()
                if row:
                    baseline_data = dict(row)
                    baseline_data['baseline_metrics'] = json.loads(baseline_data['baseline_metrics'])
                    return baseline_data
                return None
        except Exception as e:
            print(f"Error getting active baseline: {e}")
            return None
    
    def detect_performance_regression(self, current_metrics: Dict[str, float], 
                                    platform_type: str, threshold: float = 0.2) -> List[Dict[str, Any]]:
        """Detect performance regressions compared to baseline"""
        baseline = self.get_active_baseline(platform_type)
        if not baseline:
            return []
        
        regressions = []
        baseline_metrics = baseline['baseline_metrics']
        
        for metric_name, current_value in current_metrics.items():
            if metric_name in baseline_metrics:
                baseline_value = baseline_metrics[metric_name]
                
                # Calculate percentage change (negative for performance metrics like time)
                if baseline_value > 0:
                    change = (current_value - baseline_value) / baseline_value
                    
                    # For time-based metrics, higher is worse
                    is_regression = False
                    if 'time' in metric_name.lower() or 'duration' in metric_name.lower():
                        is_regression = change > threshold
                    else:
                        # For rate-based metrics, lower is worse
                        is_regression = change < -threshold
                    
                    if is_regression:
                        regressions.append({
                            'metric_name': metric_name,
                            'current_value': current_value,
                            'baseline_value': baseline_value,
                            'change_percent': change * 100,
                            'severity': 'high' if abs(change) > threshold * 2 else 'medium'
                        })
        
        return regressions
    
    def store_performance_alert(self, run_id: str, alert_type: str, metric_name: str,
                              current_value: float, threshold_value: float, severity: str) -> bool:
        """Store performance alert"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT INTO performance_alerts 
                    (run_id, alert_type, metric_name, current_value, threshold_value, severity, timestamp)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    run_id, alert_type, metric_name, current_value, threshold_value, severity, time.time()
                ))
                conn.commit()
                return True
        except Exception as e:
            print(f"Error storing performance alert: {e}")
            return False
    
    def get_test_success_rate(self, days: int = 30) -> Dict[str, Dict[str, Any]]:
        """Get success rate statistics for all tests"""
        try:
            cutoff_time = time.time() - (days * 24 * 3600)
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    SELECT tr.test_name, tr.status, COUNT(*) as count
                    FROM test_results tr
                    JOIN diagnostic_runs dr ON tr.run_id = dr.run_id
                    WHERE dr.timestamp >= ?
                    GROUP BY tr.test_name, tr.status
                ''', (cutoff_time,))
                
                # Organize results by test name
                test_stats = {}
                for row in cursor.fetchall():
                    test_name = row['test_name']
                    status = row['status']
                    count = row['count']
                    
                    if test_name not in test_stats:
                        test_stats[test_name] = {'PASS': 0, 'FAIL': 0}
                    
                    test_stats[test_name][status] = count
                
                # Calculate success rates
                for test_name, stats in test_stats.items():
                    total = stats['PASS'] + stats['FAIL']
                    stats['success_rate'] = (stats['PASS'] / total * 100) if total > 0 else 0
                    stats['total_runs'] = total
                
                return test_stats
        except Exception as e:
            print(f"Error getting test success rates: {e}")
            return {}
    
    def cleanup_old_data(self, retention_days: Optional[int] = None) -> bool:
        """Clean up old diagnostic data based on retention policy"""
        if retention_days is None:
            retention_days = self.config.storage.retention_days
        
        cutoff_time = time.time() - (retention_days * 24 * 3600)
        
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                # Get run IDs to be deleted
                cursor.execute('SELECT run_id FROM diagnostic_runs WHERE timestamp < ?', (cutoff_time,))
                old_run_ids = [row[0] for row in cursor.fetchall()]
                
                if old_run_ids:
                    # Delete related data
                    placeholders = ','.join('?' * len(old_run_ids))
                    
                    cursor.execute(f'DELETE FROM test_results WHERE run_id IN ({placeholders})', old_run_ids)
                    cursor.execute(f'DELETE FROM performance_metrics WHERE run_id IN ({placeholders})', old_run_ids)
                    cursor.execute(f'DELETE FROM system_snapshots WHERE run_id IN ({placeholders})', old_run_ids)
                    cursor.execute(f'DELETE FROM performance_alerts WHERE run_id IN ({placeholders})', old_run_ids)
                    cursor.execute(f'DELETE FROM diagnostic_runs WHERE run_id IN ({placeholders})', old_run_ids)
                
                # Clean up old baselines (keep only the last 5 per platform)
                cursor.execute('''
                    DELETE FROM performance_baselines 
                    WHERE baseline_id NOT IN (
                        SELECT baseline_id FROM performance_baselines 
                        WHERE platform_type = performance_baselines.platform_type
                        ORDER BY collection_date DESC 
                        LIMIT 5
                    )
                ''')
                
                conn.commit()
                return True
        except Exception as e:
            print(f"Error cleaning up old data: {e}")
            return False
    
    def get_database_stats(self) -> Dict[str, Any]:
        """Get database statistics"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                stats = {}
                
                # Count records in each table
                tables = ['diagnostic_runs', 'test_results', 'performance_metrics', 
                         'system_snapshots', 'performance_baselines', 'performance_alerts']
                
                for table in tables:
                    cursor.execute(f'SELECT COUNT(*) FROM {table}')
                    stats[f'{table}_count'] = cursor.fetchone()[0]
                
                # Database file size
                db_path = Path(self.db_path)
                if db_path.exists():
                    stats['database_size_bytes'] = db_path.stat().st_size
                    stats['database_size_mb'] = stats['database_size_bytes'] / (1024 * 1024)
                
                # Date range of data
                cursor.execute('SELECT MIN(timestamp), MAX(timestamp) FROM diagnostic_runs')
                date_range = cursor.fetchone()
                if date_range[0] and date_range[1]:
                    stats['oldest_record'] = datetime.fromtimestamp(date_range[0]).isoformat()
                    stats['newest_record'] = datetime.fromtimestamp(date_range[1]).isoformat()
                    stats['data_span_days'] = (date_range[1] - date_range[0]) / (24 * 3600)
                
                return stats
        except Exception as e:
            print(f"Error getting database stats: {e}")
            return {}

class DiagnosticStorage:
    """High-level storage interface for diagnostic data"""
    
    def __init__(self, db_path: Optional[str] = None):
        self.db_manager = DatabaseManager(db_path)
        self.config = get_config()
    
    def store_complete_diagnostic(self, run_id: str, platform_type: str, 
                                 results: Dict[str, Any], metrics: Dict[str, Any]) -> bool:
        """Store a complete diagnostic run with all data"""
        try:
            # Store main diagnostic run
            diagnostic_run = DiagnosticRun(
                run_id=run_id,
                timestamp=time.time(),
                platform_type=platform_type,
                overall_status=results.get('overall_status', 'UNKNOWN'),
                total_tests=results.get('total_tests', 0),
                passed_tests=results.get('passed_tests', 0),
                total_duration=results.get('total_duration', 0.0),
                system_info=metrics.get('system', {}),
                configuration=asdict(self.config)
            )
            
            if not self.db_manager.store_diagnostic_run(diagnostic_run):
                return False
            
            # Store test results
            test_results = []
            for test_name, test_data in results.get('test_results', {}).items():
                test_result = TestResult(
                    run_id=run_id,
                    test_name=test_name,
                    status=test_data.get('status', 'UNKNOWN'),
                    message=test_data.get('message', ''),
                    duration=test_data.get('duration', 0.0),
                    details=test_data.get('details', {}),
                    fix_commands=test_data.get('fix_commands', []),
                    error_info=test_data.get('error_info')
                )
                test_results.append(test_result)
            
            if test_results:
                self.db_manager.store_test_results(test_results)
            
            # Store performance metrics
            performance_metrics = []
            for metric_name, metric_value in metrics.get('performance', {}).items():
                if isinstance(metric_value, (int, float)):
                    perf_metric = PerformanceMetric(
                        run_id=run_id,
                        metric_name=metric_name,
                        metric_value=float(metric_value),
                        metric_unit='',
                        target_value=None,
                        timestamp=time.time(),
                        context={}
                    )
                    performance_metrics.append(perf_metric)
            
            if performance_metrics:
                self.db_manager.store_performance_metrics(performance_metrics)
            
            return True
        except Exception as e:
            print(f"Error storing complete diagnostic: {e}")
            return False
    
    def get_trend_analysis(self, days: int = 30) -> Dict[str, Any]:
        """Get comprehensive trend analysis"""
        trend_data = {
            'analysis_period_days': days,
            'test_success_rates': self.db_manager.get_test_success_rate(days),
            'recent_runs': self.db_manager.get_recent_runs(limit=20),
            'database_stats': self.db_manager.get_database_stats()
        }
        
        return trend_data
    
    def check_performance_health(self, current_metrics: Dict[str, float], 
                               platform_type: str) -> Dict[str, Any]:
        """Check current performance against baselines and trends"""
        health_report = {
            'timestamp': time.time(),
            'platform_type': platform_type,
            'current_metrics': current_metrics,
            'baseline_comparison': {},
            'regressions': [],
            'health_score': 100
        }
        
        # Check against baseline
        baseline = self.db_manager.get_active_baseline(platform_type)
        if baseline:
            health_report['baseline_comparison'] = {
                'baseline_date': datetime.fromtimestamp(baseline['collection_date']).isoformat(),
                'baseline_metrics': baseline['baseline_metrics']
            }
            
            # Detect regressions
            regressions = self.db_manager.detect_performance_regression(
                current_metrics, platform_type, threshold=0.2
            )
            health_report['regressions'] = regressions
            
            # Calculate health score
            if regressions:
                penalty = min(len(regressions) * 20, 80)  # Max 80% penalty
                health_report['health_score'] = max(100 - penalty, 20)
        
        return health_report
    
    def maintain_database(self) -> bool:
        """Perform database maintenance"""
        try:
            # Clean up old data
            if self.config.storage.enable_historical_storage:
                self.db_manager.cleanup_old_data()
            
            # Vacuum database to reclaim space
            with self.db_manager._get_connection() as conn:
                conn.execute('VACUUM')
            
            return True
        except Exception as e:
            print(f"Error during database maintenance: {e}")
            return False

# Global storage instance
_diagnostic_storage = None

def get_diagnostic_storage() -> DiagnosticStorage:
    """Get global diagnostic storage instance"""
    global _diagnostic_storage
    if _diagnostic_storage is None:
        _diagnostic_storage = DiagnosticStorage()
    return _diagnostic_storage

def store_diagnostic_data(run_id: str, platform_type: str, 
                         results: Dict[str, Any], metrics: Dict[str, Any]) -> bool:
    """Store diagnostic data using global storage"""
    return get_diagnostic_storage().store_complete_diagnostic(run_id, platform_type, results, metrics)

def get_performance_trends(days: int = 30) -> Dict[str, Any]:
    """Get performance trends using global storage"""
    return get_diagnostic_storage().get_trend_analysis(days)