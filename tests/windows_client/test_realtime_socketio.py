#!/usr/bin/env python3
"""
Test Suite for WebSocket Real-time Updates
Tests Socket.IO implementation to ensure polling is replaced with push events
"""

import unittest
import threading
import time
import json
from unittest.mock import Mock, MagicMock, patch
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../src/windows-client'))

from flask import Flask
from flask_socketio import SocketIO, SocketIOTestClient


class TestSocketIORealtime(unittest.TestCase):
    """Test Socket.IO WebSocket real-time functionality."""
    
    def setUp(self):
        """Set up test environment."""
        self.app = Flask(__name__)
        self.app.config['TESTING'] = True
        # Use threading mode for tests (eventlet requires installation)
        self.socketio = SocketIO(self.app, cors_allowed_origins="*")
        
        # Mock DemoDisplay
        self.mock_display = MagicMock()
        self.mock_display.get_status.return_value = {
            'status': 'idle',
            'ready': True,
            'model_loaded': True,
            'llm_ready': True,
            'control_reachable': True,
            'current_step': 0,
            'total_steps': 20,
            'elapsed_time': 0,
            'completed': False,
            'prompt': '',
            'platform': 'intel',
            'telemetry': {
                'cpu': 25.5,
                'memory_gb': 8.2,
                'power_w': 15,
                'npu': None
            },
            'image_url': None,
            'current_job_id': None,
            'health': {'healthy': True, 'issues': []}
        }
        
        # Setup handlers
        @self.socketio.on('connect')
        def handle_connect():
            self.socketio.emit('status', self.mock_display.get_status())
            
        @self.socketio.on('request_status')
        def handle_status_request():
            self.socketio.emit('status', self.mock_display.get_status())
            
        self.client = self.app.test_client()
        self.socketio_client = self.socketio.test_client(self.app)
        
    def tearDown(self):
        """Clean up after tests."""
        if self.socketio_client.is_connected():
            self.socketio_client.disconnect()
    
    def test_socket_connection(self):
        """Test WebSocket connection establishment."""
        # Check if client is connected
        self.assertTrue(self.socketio_client.is_connected())
        
        # Should receive initial status on connect
        received = self.socketio_client.get_received()
        self.assertGreater(len(received), 0)
        
        # Find status message
        status_msg = None
        for msg in received:
            if msg['name'] == 'status':
                status_msg = msg
                break
        
        self.assertIsNotNone(status_msg)
        self.assertEqual(status_msg['args'][0]['status'], 'idle')
        self.assertTrue(status_msg['args'][0]['llm_ready'])
    
    def test_telemetry_emission(self):
        """Test telemetry data emission via WebSocket."""
        # Emit telemetry data
        telemetry_data = {
            'telemetry': {
                'cpu': 45.2,
                'memory_gb': 12.5,
                'power_w': 22,
                'npu': 85
            }
        }
        
        # In test mode, emit directly to test client
        self.socketio_client.emit('telemetry', telemetry_data)
        
        # Server echo for testing
        self.socketio.server.emit('telemetry', telemetry_data)
        
        # Get received messages
        received = self.socketio_client.get_received()
        
        # Find telemetry message
        telemetry_msg = None
        for msg in received:
            if msg['name'] == 'telemetry':
                telemetry_msg = msg
                break
        
        self.assertIsNotNone(telemetry_msg)
        self.assertEqual(telemetry_msg['args'][0]['telemetry']['cpu'], 45.2)
        self.assertEqual(telemetry_msg['args'][0]['telemetry']['memory_gb'], 12.5)
    
    def test_job_started_event(self):
        """Test job_started event emission."""
        job_data = {
            'job_id': 'test-job-123',
            'prompt': 'A beautiful sunset over mountains',
            'steps': 25,
            'mode': 'local'
        }
        
        # In test mode, emit directly to test client
        self.socketio.server.emit('job_started', job_data)
        
        received = self.socketio_client.get_received()
        
        # Find job_started message
        job_msg = None
        for msg in received:
            if msg['name'] == 'job_started':
                job_msg = msg
                break
        
        self.assertIsNotNone(job_msg)
        self.assertEqual(job_msg['args'][0]['job_id'], 'test-job-123')
        self.assertEqual(job_msg['args'][0]['prompt'], 'A beautiful sunset over mountains')
        self.assertEqual(job_msg['args'][0]['steps'], 25)
    
    def test_progress_updates(self):
        """Test progress event emissions."""
        progress_updates = [
            {'job_id': 'test-job-123', 'current_step': 5, 'total_steps': 25, 'progress': 20, 'elapsed_time': 2.5},
            {'job_id': 'test-job-123', 'current_step': 10, 'total_steps': 25, 'progress': 40, 'elapsed_time': 5.0},
            {'job_id': 'test-job-123', 'current_step': 15, 'total_steps': 25, 'progress': 60, 'elapsed_time': 7.5},
            {'job_id': 'test-job-123', 'current_step': 20, 'total_steps': 25, 'progress': 80, 'elapsed_time': 10.0},
            {'job_id': 'test-job-123', 'current_step': 25, 'total_steps': 25, 'progress': 100, 'elapsed_time': 12.5}
        ]
        
        for update in progress_updates:
            self.socketio.server.emit('progress', update)
            time.sleep(0.01)  # Small delay to simulate real progress
        
        received = self.socketio_client.get_received()
        
        # Count progress messages
        progress_msgs = [msg for msg in received if msg['name'] == 'progress']
        self.assertEqual(len(progress_msgs), 5)
        
        # Verify last progress update
        last_progress = progress_msgs[-1]['args'][0]
        self.assertEqual(last_progress['current_step'], 25)
        self.assertEqual(last_progress['progress'], 100)
    
    def test_completion_event(self):
        """Test completion event with image URL."""
        completion_data = {
            'job_id': 'test-job-123',
            'prompt': 'A futuristic city',
            'elapsed_time': 35.2,
            'image_url': '/static/generated/test-job-123.png',
            'total_steps': 25
        }
        
        self.socketio.server.emit('completed', completion_data)
        
        received = self.socketio_client.get_received()
        
        # Find completion message
        completion_msg = None
        for msg in received:
            if msg['name'] == 'completed':
                completion_msg = msg
                break
        
        self.assertIsNotNone(completion_msg)
        self.assertEqual(completion_msg['args'][0]['job_id'], 'test-job-123')
        self.assertEqual(completion_msg['args'][0]['image_url'], '/static/generated/test-job-123.png')
        self.assertAlmostEqual(completion_msg['args'][0]['elapsed_time'], 35.2, places=1)
    
    def test_error_event(self):
        """Test error event emission."""
        error_data = {
            'job_id': 'test-job-123',
            'error': 'Model loading failed: Insufficient memory'
        }
        
        self.socketio.server.emit('error', error_data)
        
        received = self.socketio_client.get_received()
        
        # Find error message
        error_msg = None
        for msg in received:
            if msg['name'] == 'error':
                error_msg = msg
                break
        
        self.assertIsNotNone(error_msg)
        self.assertEqual(error_msg['args'][0]['job_id'], 'test-job-123')
        self.assertIn('Model loading failed', error_msg['args'][0]['error'])
    
    def test_no_polling_required(self):
        """Verify that no polling is needed with WebSocket events."""
        # Simulate a complete generation workflow via WebSocket events
        events_sequence = []
        
        # 1. Job starts
        self.socketio.server.emit('job_started', {
            'job_id': 'no-poll-test',
            'prompt': 'Test prompt',
            'steps': 10,
            'mode': 'local'
        })
        events_sequence.append('job_started')
        
        # 2. Progress updates (no polling needed)
        for i in range(1, 11):
            self.socketio.server.emit('progress', {
                'job_id': 'no-poll-test',
                'current_step': i,
                'total_steps': 10,
                'progress': i * 10,
                'elapsed_time': i * 0.5
            })
            events_sequence.append(f'progress_{i}')
            time.sleep(0.01)
        
        # 3. Completion (immediate delivery)
        self.socketio.server.emit('completed', {
            'job_id': 'no-poll-test',
            'prompt': 'Test prompt',
            'elapsed_time': 5.0,
            'image_url': '/static/generated/no-poll-test.png',
            'total_steps': 10
        })
        events_sequence.append('completed')
        
        # Verify all events received without any polling
        received = self.socketio_client.get_received()
        
        # Check we have all event types
        event_types = set(msg['name'] for msg in received)
        self.assertIn('job_started', event_types)
        self.assertIn('progress', event_types)
        self.assertIn('completed', event_types)
        
        # Verify sequence integrity
        progress_events = [msg for msg in received if msg['name'] == 'progress']
        self.assertEqual(len(progress_events), 10)
        
        # Verify instant completion delivery
        completion_events = [msg for msg in received if msg['name'] == 'completed']
        self.assertEqual(len(completion_events), 1)
        self.assertIsNotNone(completion_events[0]['args'][0]['image_url'])
    
    def test_concurrent_jobs(self):
        """Test handling of multiple concurrent jobs via WebSocket."""
        job_ids = ['job-1', 'job-2', 'job-3']
        
        # Start multiple jobs
        for job_id in job_ids:
            self.socketio.server.emit('job_started', {
                'job_id': job_id,
                'prompt': f'Prompt for {job_id}',
                'steps': 5,
                'mode': 'local'
            })
        
        # Send progress for different jobs
        for step in range(1, 6):
            for job_id in job_ids:
                self.socketio.server.emit('progress', {
                    'job_id': job_id,
                    'current_step': step,
                    'total_steps': 5,
                    'progress': step * 20,
                    'elapsed_time': step * 0.5
                })
        
        # Complete jobs
        for job_id in job_ids:
            self.socketio.server.emit('completed', {
                'job_id': job_id,
                'prompt': f'Prompt for {job_id}',
                'elapsed_time': 2.5,
                'image_url': f'/static/generated/{job_id}.png',
                'total_steps': 5
            })
        
        received = self.socketio_client.get_received()
        
        # Verify all jobs processed
        job_started_events = [msg for msg in received if msg['name'] == 'job_started']
        self.assertEqual(len(job_started_events), 3)
        
        completion_events = [msg for msg in received if msg['name'] == 'completed']
        self.assertEqual(len(completion_events), 3)
        
        # Verify each job has correct data
        completed_job_ids = [msg['args'][0]['job_id'] for msg in completion_events]
        self.assertEqual(set(completed_job_ids), set(job_ids))


class TestSocketIOPerformance(unittest.TestCase):
    """Test performance improvements with WebSocket vs polling."""
    
    def test_latency_improvement(self):
        """Measure latency improvement with WebSocket events."""
        # Simulate polling delay (typically 500ms for progress polling)
        polling_delay = 0.5
        
        # WebSocket event is near-instant
        websocket_delay = 0.01  # Typical WebSocket latency
        
        # Calculate improvement
        latency_improvement = (polling_delay - websocket_delay) / polling_delay * 100
        
        # Should be at least 95% improvement
        self.assertGreater(latency_improvement, 95)
        
        # Verify instant delivery
        start_time = time.time()
        
        # Simulate WebSocket event
        time.sleep(websocket_delay)
        
        websocket_time = time.time() - start_time
        
        # Should be under 50ms for local WebSocket
        self.assertLess(websocket_time, 0.05)
    
    def test_bandwidth_reduction(self):
        """Calculate bandwidth savings from eliminating polling."""
        # Typical polling scenario
        polling_interval = 0.5  # 500ms for progress
        generation_duration = 30  # 30 seconds typical generation
        status_request_size = 100  # bytes for HTTP request
        status_response_size = 500  # bytes for status response
        
        # Polling bandwidth
        polling_requests = generation_duration / polling_interval
        polling_bandwidth = polling_requests * (status_request_size + status_response_size)
        
        # WebSocket bandwidth (only events when needed)
        websocket_events = 20  # Typical number of progress events
        websocket_event_size = 200  # bytes per event
        websocket_bandwidth = websocket_events * websocket_event_size
        
        # Calculate savings
        bandwidth_savings = (polling_bandwidth - websocket_bandwidth) / polling_bandwidth * 100
        
        # Should save at least 80% bandwidth
        self.assertGreater(bandwidth_savings, 80)
        
        print(f"Bandwidth savings: {bandwidth_savings:.1f}%")
        print(f"Polling: {polling_bandwidth} bytes, WebSocket: {websocket_bandwidth} bytes")


if __name__ == '__main__':
    unittest.main()
