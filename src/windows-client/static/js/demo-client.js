// Demo Client JavaScript - Shared functionality for both Intel and Snapdragon frontends

class DemoClient {
    constructor(theme = 'snapdragon') {
        this.theme = theme;
        this.apiBase = window.location.hostname === 'localhost' 
            ? `http://localhost:5000` 
            : `http://${window.location.hostname}:5000`;
        
        this.isGenerating = false;
        this.socket = null;
        this.currentJobId = null;
        
        this.init();
    }
    
    async init() {
        // Set up event listeners
        this.setupEventListeners();
        
        // Setup WebSocket connection
        this.setupSocket();
        
        // Show ready state after socket connects
        // (ready state will be set in socket connect handler)
    }
    
    setupEventListeners() {
        // Prompt submission
        const generateBtn = document.getElementById('generateBtn');
        const promptInput = document.getElementById('promptInput');
        
        if (generateBtn && promptInput) {
            generateBtn.addEventListener('click', () => this.handleGenerate());
            promptInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    this.handleGenerate();
                }
            });
        }
        
        // Sample prompts
        document.querySelectorAll('.sample-prompt').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const prompt = e.target.dataset.prompt;
                if (prompt && promptInput) {
                    promptInput.value = prompt;
                }
            });
        });
    }
    
    async handleGenerate() {
        const promptInput = document.getElementById('promptInput');
        const prompt = promptInput?.value?.trim();
        
        if (!prompt) {
            this.showNotification('Please enter a prompt', 'warning');
            return;
        }
        
        if (this.isGenerating) {
            this.showNotification('Generation already in progress', 'info');
            return;
        }
        
        try {
            this.isGenerating = true;
            this.updateStatus('🟠 PROCESSING...');
            
            // Update UI
            document.getElementById('promptDisplay').textContent = prompt;
            document.getElementById('generateBtn').disabled = true;
            document.getElementById('generateBtn').textContent = 'Generating...';
            
            // Reset progress
            this.updateProgress(0, 0, 20);
            
            // Start generation
            const response = await fetch(`${this.apiBase}/command`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    command: 'start_generation',
                    data: {
                        prompt: prompt,
                        steps: 20,
                        mode: 'local'
                    }
                })
            });
            
            const result = await response.json();
            
            if (result.success && result.job_id) {
                // Store job ID
                this.currentJobId = result.job_id;
                
                // Clear the input
                promptInput.value = '';
                
                // Socket events will handle progress updates
            } else {
                throw new Error(result.message || 'Failed to start generation');
            }
            
        } catch (error) {
            console.error('Generation error:', error);
            this.showNotification(`Error: ${error.message}`, 'error');
            this.isGenerating = false;
            this.updateStatus('❌ ERROR');
            this.resetGenerateButton();
        }
    }
    
    setupSocket() {
        // Initialize Socket.IO connection
        this.socket = io(this.apiBase, {
            transports: ['websocket'],
            reconnection: true,
            reconnectionAttempts: 5,
            reconnectionDelay: 1000
        });
        
        // Connection events
        this.socket.on('connect', () => {
            console.log('WebSocket connected');
            this.updateStatus('✅ READY');
            
            // Update connection indicators
            const indicators = document.querySelectorAll('.status-indicator');
            indicators.forEach(indicator => {
                if (indicator.id === 'llmStatus') {
                    indicator.className = 'status-indicator status-green';
                    indicator.textContent = '● LLM Ready';
                }
            });
        });
        
        this.socket.on('disconnect', () => {
            console.log('WebSocket disconnected');
            this.updateStatus('⚠️ DISCONNECTED');
        });
        
        this.socket.on('reconnect', () => {
            console.log('WebSocket reconnected');
            this.updateStatus('✅ READY');
        });
        
        // Status updates
        this.socket.on('status', (data) => {
            this.handleStatusUpdate(data);
        });
        
        // Telemetry updates
        this.socket.on('telemetry', (data) => {
            this.handleTelemetryUpdate(data);
        });
        
        // Job events
        this.socket.on('job_started', (data) => {
            console.log('Job started:', data);
            this.currentJobId = data.job_id;
            this.isGenerating = true;
            this.updateStatus('🟠 PROCESSING...');
            document.getElementById('promptDisplay').textContent = data.prompt;
            document.getElementById('generateBtn').disabled = true;
            document.getElementById('generateBtn').textContent = 'Generating...';
            this.updateProgress(0, 0, data.steps);
        });
        
        // Progress updates
        this.socket.on('progress', (data) => {
            if (data.job_id === this.currentJobId) {
                this.updateProgress(data.progress, data.current_step, data.total_steps);
                this.updateMetric('time', data.elapsed_time.toFixed(1), 'seconds');
            }
        });
        
        // Completion event
        this.socket.on('completed', (data) => {
            if (data.job_id === this.currentJobId) {
                this.onGenerationComplete({
                    job_id: data.job_id,
                    prompt: data.prompt,
                    elapsed_time: data.elapsed_time,
                    image_url: data.image_url,
                    total_steps: data.total_steps,
                    completed: true,
                    status: 'completed'
                });
            }
        });
        
        // Error event
        this.socket.on('error', (data) => {
            if (data.job_id === this.currentJobId) {
                console.error('Generation error:', data.error);
                this.showNotification(`Error: ${data.error}`, 'error');
                this.isGenerating = false;
                this.updateStatus('❌ ERROR');
                this.resetGenerateButton();
            }
        });
    }
    
    onGenerationComplete(status) {
        // Update UI
        this.isGenerating = false;
        this.updateStatus('✅ COMPLETE!');
        this.updateProgress(100, status.total_steps, status.total_steps);
        
        // Show completion badge
        const badge = document.getElementById('completionBadge');
        if (badge) {
            badge.style.display = 'block';
        }
        
        // Update image display
        const imageDisplay = document.getElementById('generatedImage');
        if (imageDisplay && status.image_url) {
            // Display the actual generated image
            imageDisplay.innerHTML = `
                <img src="${status.image_url}" alt="Generated Image" style="max-width: 100%; max-height: 100%; border-radius: 10px;">
                <div style="text-align: center; color: white; margin-top: 10px;">
                    <small style="opacity: 0.8;">
                        "${status.prompt}"<br>
                        powered by ${this.theme === 'snapdragon' ? 'Snapdragon NPU' : 'Intel DirectML'}
                    </small>
                </div>
            `;
        } else {
            imageDisplay.innerHTML = `
                <div style="text-align: center; color: white;">
                    🖼️ Generated Image:<br>
                    "${status.prompt}"<br>
                    <small style="opacity: 0.8; margin-top: 10px;">
                        Complete AI-generated artwork<br>
                        powered by ${this.theme === 'snapdragon' ? 'Snapdragon NPU' : 'Intel DirectML'}
                    </small>
                </div>
            `;
        }
        
        // Reset button
        this.resetGenerateButton();
        
        // Clear job ID
        this.currentJobId = null;
        
        // Show notification
        this.showNotification(`Generation complete in ${status.elapsed_time.toFixed(1)}s!`, 'success');
    }
    
    resetGenerateButton() {
        const btn = document.getElementById('generateBtn');
        if (btn) {
            btn.disabled = false;
            btn.textContent = 'Generate';
        }
    }
    
    handleStatusUpdate(status) {
        // Update LLM status
        const llmIndicator = document.getElementById('llmStatus');
        if (llmIndicator) {
            if (status.llm_ready || (status.ready && status.model_loaded)) {
                llmIndicator.className = 'status-indicator status-green';
                llmIndicator.textContent = '● LLM Ready';
            } else {
                llmIndicator.className = 'status-indicator status-red';
                llmIndicator.textContent = '● LLM Loading...';
            }
        }
        
        // Update control status
        const controlIndicator = document.getElementById('controlStatus');
        if (controlIndicator) {
            if (status.control_reachable) {
                controlIndicator.className = 'status-indicator status-green';
                controlIndicator.textContent = '● Control PC Connected';
            } else {
                controlIndicator.className = 'status-indicator status-red';
                controlIndicator.textContent = '● Control PC Offline';
            }
        }
        
        // Update generation time if active
        if (status.status === 'active' && status.elapsed_time) {
            this.updateMetric('time', status.elapsed_time.toFixed(1), 'seconds');
        }
    }
    
    handleTelemetryUpdate(data) {
        if (data.telemetry) {
            // Update metrics based on platform
            if (this.theme === 'snapdragon' && data.telemetry.npu !== null && data.telemetry.npu !== undefined) {
                this.updateMetric('npu', Math.round(data.telemetry.npu), '%');
            } else {
                this.updateMetric('cpu', Math.round(data.telemetry.cpu || 0), '%');
            }
            
            // Update memory and power
            this.updateMetric('memory', (data.telemetry.memory_gb || 0).toFixed(1), 'GB');
            this.updateMetric('power', Math.round(data.telemetry.power_w || 0), 'W');
        }
    }
    
    updateMetric(metric, value, unit) {
        const valueEl = document.getElementById(`${metric}Value`);
        const unitEl = document.getElementById(`${metric}Unit`);
        
        if (valueEl) valueEl.textContent = value;
        if (unitEl) unitEl.textContent = unit;
    }
    
    updateProgress(percent, currentStep, totalSteps) {
        const progressBar = document.querySelector('.progress-fill');
        const progressText = document.getElementById('progressText');
        
        if (progressBar) {
            progressBar.style.width = `${percent}%`;
        }
        
        if (progressText) {
            progressText.textContent = `Steps: ${currentStep}/${totalSteps} | ${Math.round(percent)}% Complete`;
        }
    }
    
    updateStatus(statusText) {
        const statusEl = document.querySelector('.status');
        if (statusEl) {
            statusEl.textContent = statusText;
            
            // Update color based on status
            if (statusText.includes('COMPLETE')) {
                statusEl.style.color = '#00ff88';
            } else if (statusText.includes('PROCESSING')) {
                statusEl.style.color = '#ffa500';
            } else if (statusText.includes('ERROR')) {
                statusEl.style.color = '#ff6b6b';
            } else if (statusText.includes('READY')) {
                statusEl.style.color = '#00ff88';
            }
        }
    }
    
    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;
        
        // Style based on type
        const colors = {
            success: '#00ff88',
            error: '#ff6b6b',
            warning: '#ffa500',
            info: '#00a8ff'
        };
        
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 15px 20px;
            background: ${colors[type] || colors.info};
            color: black;
            border-radius: 8px;
            font-weight: bold;
            z-index: 10000;
            animation: slideIn 0.3s ease;
        `;
        
        document.body.appendChild(notification);
        
        // Remove after 3 seconds
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
}

// Add animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
`;
document.head.appendChild(style);
