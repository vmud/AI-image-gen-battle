#!/usr/bin/env python3
"""
Standalone Demo - Web Server
Minimal HTTP server for the AI Image Generation Battle standalone demo
"""

import http.server
import socketserver
import os
import sys
import webbrowser
import threading
import time
from urllib.parse import urlparse

class StandaloneDemoServer:
    def __init__(self, port=8080):
        self.port = port
        self.server = None
        self.server_thread = None
        
    def start_server(self):
        """Start the web server"""
        try:
            # Change to the demo directory
            os.chdir(os.path.dirname(os.path.abspath(__file__)))
            
            # Create server
            handler = http.server.SimpleHTTPRequestHandler
            self.server = socketserver.TCPServer(("", self.port), handler)
            
            print(f"Standalone Demo Server starting on port {self.port}")
            print(f"Demo URL: http://localhost:{self.port}")
            print("-" * 50)
            
            # Start server in a separate thread
            self.server_thread = threading.Thread(target=self.server.serve_forever)
            self.server_thread.daemon = True
            self.server_thread.start()
            
            return True
            
        except OSError as e:
            if e.errno == 48:  # Address already in use
                print(f"Port {self.port} is already in use. Trying port {self.port + 1}...")
                self.port += 1
                return self.start_server()
            else:
                print(f"Error starting server: {e}")
                return False
        except Exception as e:
            print(f"Unexpected error: {e}")
            return False
    
    def open_browser(self):
        """Open the demo in the default browser"""
        try:
            # Wait a moment for server to fully start
            time.sleep(1)
            url = f"http://localhost:{self.port}"
            print(f"Opening browser at: {url}")
            webbrowser.open(url)
        except Exception as e:
            print(f"Could not open browser automatically: {e}")
            print(f"Please manually open: http://localhost:{self.port}")
    
    def stop_server(self):
        """Stop the web server"""
        if self.server:
            print("\nShutting down server...")
            self.server.shutdown()
            self.server.server_close()
    
    def run(self, open_browser=True):
        """Run the complete demo server"""
        print("=" * 60)
        print("AI IMAGE GENERATION BATTLE - STANDALONE DEMO")
        print("=" * 60)
        
        if not self.start_server():
            print("Failed to start server. Exiting.")
            return False
        
        if open_browser:
            # Open browser in a separate thread
            browser_thread = threading.Thread(target=self.open_browser)
            browser_thread.daemon = True
            browser_thread.start()
        
        try:
            print("\nDemo is running! Features:")
            print("• Platform selection (Intel vs Snapdragon)")
            print("• Realistic performance simulation")
            print("• 40 pregenerated 'futuristic retail store' images")
            print("• Complete UI state management")
            print("\nPress Ctrl+C to stop the server")
            print("-" * 50)
            
            # Keep the main thread alive
            while True:
                time.sleep(1)
                
        except KeyboardInterrupt:
            self.stop_server()
            print("\nServer stopped. Thank you for using Standalone Demo!")
            return True

def main():
    """Main entry point"""
    # Default port
    port = 8080
    
    # Check command line arguments
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("Invalid port number. Using default port 8080.")
    
    # Verify we're in the right directory
    if not os.path.exists('index.html'):
        print("Error: index.html not found!")
        print("Please run this script from the emergency_demo directory.")
        return False
    
    if not os.path.exists('assets'):
        print("Warning: assets directory not found!")
        print("Image generation may not work properly.")
    
    # Start the demo server
    demo_server = StandaloneDemoServer(port)
    return demo_server.run()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)