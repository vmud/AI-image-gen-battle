@echo off
REM Alternative CORS fix - Modifies demo_client.py to handle CORS without flask-cors
echo ========================================
echo   Alternative CORS Fix for Snapdragon
echo   (No flask-cors dependency required)
echo ========================================
echo.

cd /d C:\AIDemo

echo Creating CORS-enabled demo client without flask-cors dependency...

REM Backup original demo_client.py
if exist src\demo_client.py.backup (
    echo Backup already exists, skipping...
) else (
    echo Backing up original demo_client.py...
    copy src\demo_client.py src\demo_client.py.backup
)

REM Create modified demo_client.py that handles CORS manually
(
echo # AI Demo Client - Snapdragon Version with Manual CORS
echo # Modified to work without flask-cors dependency on ARM64 Windows
echo.
echo import os
echo import sys
echo import json
echo import logging
echo from flask import Flask, request, jsonify, render_template_string, send_from_directory
echo from flask_socketio import SocketIO, emit
echo import eventlet
echo.
echo # Configure logging
echo logging.basicConfig^(level=logging.INFO^)
echo logger = logging.getLogger^(__name__^)
echo.
echo app = Flask^(__name__^)
echo app.config['SECRET_KEY'] = 'snapdragon-ai-demo-secret'
echo.
echo # Initialize SocketIO with eventlet
echo socketio = SocketIO^(app, async_mode='eventlet', cors_allowed_origins="*"^)
echo.
echo # Manual CORS handling ^(replaces flask-cors^)
echo @app.after_request
echo def after_request^(response^):
echo     response.headers.add^('Access-Control-Allow-Origin', '*'^)
echo     response.headers.add^('Access-Control-Allow-Headers', 'Content-Type,Authorization'^)
echo     response.headers.add^('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS'^)
echo     response.headers.add^('Access-Control-Allow-Credentials', 'true'^)
echo     return response
echo.
echo @app.route^('/', methods=['GET']^)
echo def index^(^):
echo     """Serve the main demo page"""
echo     try:
echo         return send_from_directory^('static', 'snapdragon-demo.html'^)
echo     except Exception as e:
echo         logger.error^(f"Error serving index: {e}"^)
echo         return jsonify^({'error': 'Demo page not found'}^), 404
echo.
echo @app.route^('/api/health', methods=['GET']^)
echo def health^(^):
echo     """Health check endpoint"""
echo     return jsonify^({'status': 'healthy', 'platform': 'snapdragon'}^)
echo.
echo @app.route^('/api/generate', methods=['POST', 'OPTIONS']^)
echo def generate_image^(^):
echo     """Generate image endpoint"""
echo     if request.method == 'OPTIONS':
echo         # Handle preflight CORS request
echo         return '', 200
echo     
echo     try:
echo         data = request.get_json^(^)
echo         prompt = data.get^('prompt', 'A beautiful landscape'^)
echo         
echo         # Mock response for demo ^(replace with actual AI pipeline^)
echo         response = {
echo             'status': 'success',
echo             'message': f'Image generation started for: {prompt}',
echo             'platform': 'snapdragon',
echo             'estimated_time': '30-45 seconds'
echo         }
echo         
echo         logger.info^(f"Image generation request: {prompt}"^)
echo         return jsonify^(response^)
echo         
echo     except Exception as e:
echo         logger.error^(f"Error in generate_image: {e}"^)
echo         return jsonify^({'error': str^(e^)}^), 500
echo.
echo @socketio.on^('connect'^)
echo def handle_connect^(^):
echo     """Handle WebSocket connection"""
echo     logger.info^('Client connected to WebSocket'^)
echo     emit^('status', {'message': 'Connected to Snapdragon AI Demo', 'platform': 'snapdragon'}^)
echo.
echo @socketio.on^('disconnect'^)
echo def handle_disconnect^(^):
echo     """Handle WebSocket disconnection"""
echo     logger.info^('Client disconnected from WebSocket'^)
echo.
echo if __name__ == '__main__':
echo     # Load configuration
echo     config_path = 'config/production.json'
echo     if os.path.exists^(config_path^):
echo         with open^(config_path, 'r'^) as f:
echo             config = json.load^(f^)
echo             logger.info^(f"Loaded config for {config.get^('platform', 'unknown'^)} platform"^)
echo     else:
echo         logger.warning^('Config file not found, using defaults'^)
echo         config = {'host': '0.0.0.0', 'port': 5000, 'debug': False}
echo     
echo     host = config.get^('host', '0.0.0.0'^)
echo     port = config.get^('port', 5000^)
echo     debug = config.get^('debug', False^)
echo     
echo     logger.info^(f"Starting Snapdragon AI Demo on {host}:{port}"^)
echo     logger.info^("WebSocket and CORS enabled without flask-cors dependency"^)
echo     
echo     # Run with eventlet
echo     socketio.run^(app, host=host, port=port, debug=debug^)
) > src\demo_client_cors_fixed.py

echo.
echo Replacing demo_client.py with CORS-enabled version...
copy src\demo_client_cors_fixed.py src\demo_client.py

echo.
echo ========================================
echo CORS fix applied!
echo The demo now handles CORS manually
echo without requiring flask-cors package
echo ========================================
echo.
echo You can now run launch_demo.bat
echo.
pause
