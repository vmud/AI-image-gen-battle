// Enhanced Demo Client with Error Mitigation and Robustness
// Addresses common issues in the prompt-to-image workflow

class EnhancedDemoClient {
    constructor(theme = 'snapdragon') {
        this.theme = theme;
        this.apiBase = window.location.hostname === 'localhost' 
            ? `http://localhost:5000` 
            : `http://${window.location.hostname}:5000`;
        
        // State management
        this.isGenerating = false;
        this.currentJobId = null;
        this.statusCheckInterval = null;
        this.telemetryInterval = null;
        this.progressInterval = null;
        
        // Error mitigation settings
        this.maxRetries = 3;
        this.retryDelay = 1000;
        this.pollTimeout = 300000; // 5 minutes max for generation
        this.connectionCheckInterval = 5000;
        this.lastSuccessfulPoll = Date.now();
        
        // Job history for recovery
        this.jobHistory = [];
        this.maxJobHistory = 10;
        
        // Connection state
        this.isConnected = false;
        this.connectionRetries = 0;
        
        this.init();
    }
    
    async init() {
        try {
            // Check connection first
            await this.checkConnection();
            
            // Setup with error boundaries
            this.setupEventListeners();
            this.startMonitoring();
            
            // Initial status check
            await this.checkEnvironmentStatus();
            await this.checkControlStatus();
            
            // Show ready state
            this.updateStatus('✅ READY');
            
            // Setup error handlers
            this.setupGlobalErrorHandlers();
            
        } catch (error) {
            console.error('Initialization error:', error);
            this.showNotification('Failed to initialize. Retrying...', 'warning');
            setTimeout(() => this.init(), 3000);
        }
    }
    
    setupGlobalErrorHandlers() {
        // Handle unhandled promise rejections
        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled promise rejection:', event.reason);
            this.handleGlobalError(event.reason);
        });
        
        // Handle general errors
        window.addEventListener('error', (event) => {
            console.error('Global error:', event.error);
            this.handleGlobalError(event.error);
        });
    }
    
    handleGlobalError(error) {
        // Don't show notifications for network polling errors
        if (error && error.message && !error.message.includes('fetch')) {
            this.showNotification(`System error: ${error.message}`, 'error');
        }
    }
    
    async checkConnection() {
        try {
            const response = await fetch(`${this.apiBase}/info`, {
                method: 'GET',
                timeout: 3000
            });
            
            if (response.ok) {
                this.isConnected = true;
                this.connectionRetries = 0;
                return true;
            }
        } catch (error) {
            this.isConnected = false;
