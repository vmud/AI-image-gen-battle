/**
 * Standalone Demo - JavaScript Simulation Engine
 * Handles platform selection, demo simulation, and state management
 */

class StandaloneDemo {
    constructor() {
        this.currentPlatform = null;
        this.isGenerating = false;
        this.generationStartTime = null;
        this.progressInterval = null;
        this.metricsInterval = null;
        
        // Platform-specific configurations
        this.platformConfigs = {
            snapdragon: {
                name: "Snapdragon X Elite",
                generationTime: { min: 8, max: 12 }, // seconds
                processorType: "NPU",
                processorUtilization: { min: 85, max: 95 },
                memoryUsage: { min: 3.8, max: 4.5 },
                powerConsumption: { min: 12, max: 18 },
                imagePrefix: "snapdragon"
            },
            intel: {
                name: "Intel Platform",
                generationTime: { min: 15, max: 25 }, // seconds
                processorType: "GPU",
                processorUtilization: { min: 70, max: 85 },
                memoryUsage: { min: 5.2, max: 6.8 },
                powerConsumption: { min: 25, max: 35 },
                imagePrefix: "intel"
            }
        };
        
        this.totalSteps = 20;
        this.currentStep = 0;
        this.availableImages = this.generateImageList();
    }

    generateImageList() {
        const images = {};
        for (let platform of ['intel', 'snapdragon']) {
            images[platform] = [];
            for (let i = 0; i < 20; i++) {
                images[platform].push(`assets/retail_store_${i.toString().padStart(2, '0')}_${platform}.png`);
            }
        }
        return images;
    }

    selectPlatform(platform) {
        this.currentPlatform = platform;
        const config = this.platformConfigs[platform];
        
        // Hide platform selection and show demo interface
        document.getElementById('platformSelection').style.display = 'none';
        document.getElementById('demoInterface').style.display = 'flex';
        
        // Update branding
        this.updatePlatformBranding(platform, config);
        
        // Reset demo state
        this.resetDemo();
    }

    updatePlatformBranding(platform, config) {
        const header = document.getElementById('header');
        const imageSection = document.getElementById('imageSection');
        const promptDisplay = document.getElementById('promptDisplay');
        const processorCard = document.getElementById('processorCard');
        const processorTitle = document.getElementById('processorTitle');
        const logo = document.getElementById('platformLogo');
        
        // Update header class
        header.className = `header ${platform}`;
        
        // Update image section class
        imageSection.className = `image-section ${platform}`;
        
        // Update prompt display class
        promptDisplay.className = `prompt-display ${platform}`;
        
        // Update processor card class
        processorCard.className = `metric-card ${platform}`;
        
        // Update logo text
        logo.textContent = config.name;
        
        // Update processor type
        processorTitle.textContent = `${config.processorType} Utilization`;
        
        // Update all metric cards to match platform
        const metricCards = document.querySelectorAll('.metric-card');
        metricCards.forEach(card => {
            if (!card.className.includes(platform)) {
                card.className = `metric-card ${platform}`;
            }
        });
    }

    resetDemo() {
        // Reset UI state
        document.getElementById('status').textContent = '🔄 READY';
        document.getElementById('status').className = 'status ready';
        document.getElementById('placeholderContent').classList.remove('hidden');
        document.getElementById('generatedImage').classList.add('hidden');
        document.getElementById('completionBadge').style.display = 'none';
        document.getElementById('generateBtn').disabled = false;
        document.getElementById('generateBtn').textContent = 'Generate Image';
        
        // Reset metrics
        document.getElementById('timeValue').innerHTML = '--<span class="metric-unit">seconds</span>';
        document.getElementById('processorValue').innerHTML = '--<span class="metric-unit">%</span>';
        document.getElementById('memoryValue').innerHTML = '--<span class="metric-unit">GB</span>';
        document.getElementById('powerValue').innerHTML = '--<span class="metric-unit">W</span>';
        
        // Reset progress
        document.getElementById('progressFill').style.width = '0%';
        document.getElementById('stepInfo').textContent = 'Steps: 0/20';
        document.getElementById('percentInfo').textContent = '0% Complete';
        
        // Reset state
        this.isGenerating = false;
        this.currentStep = 0;
        this.clearIntervals();
    }

    startGeneration() {
        if (this.isGenerating) return;
        
        this.isGenerating = true;
        this.generationStartTime = Date.now();
        this.currentStep = 0;
        
        const config = this.platformConfigs[this.currentPlatform];
        const generationTime = this.randomBetween(config.generationTime.min, config.generationTime.max) * 1000; // Convert to ms
        
        // Update UI state
        document.getElementById('status').textContent = '⚡ GENERATING...';
        document.getElementById('status').className = 'status generating';
        document.getElementById('generateBtn').disabled = true;
        document.getElementById('generateBtn').textContent = 'Generating...';
        
        // Start progress animation
        this.startProgressAnimation(generationTime);
        
        // Start metrics simulation
        this.startMetricsSimulation();
        
        // Complete generation after specified time
        setTimeout(() => {
            this.completeGeneration();
        }, generationTime);
    }

    startProgressAnimation(totalTime) {
        const stepDuration = totalTime / this.totalSteps;
        
        this.progressInterval = setInterval(() => {
            this.currentStep++;
            const progress = (this.currentStep / this.totalSteps) * 100;
            
            document.getElementById('progressFill').style.width = `${progress}%`;
            document.getElementById('stepInfo').textContent = `Steps: ${this.currentStep}/${this.totalSteps}`;
            document.getElementById('percentInfo').textContent = `${Math.round(progress)}% Complete`;
            
            if (this.currentStep >= this.totalSteps) {
                clearInterval(this.progressInterval);
            }
        }, stepDuration);
    }

    startMetricsSimulation() {
        const config = this.platformConfigs[this.currentPlatform];
        
        this.metricsInterval = setInterval(() => {
            // Simulate real-time metrics with small variations
            const processorUtil = this.randomBetween(config.processorUtilization.min, config.processorUtilization.max);
            const memoryUsage = this.randomBetween(config.memoryUsage.min, config.memoryUsage.max);
            const powerConsumption = this.randomBetween(config.powerConsumption.min, config.powerConsumption.max);
            
            document.getElementById('processorValue').innerHTML = 
                `${processorUtil}<span class="metric-unit">%</span>`;
            document.getElementById('memoryValue').innerHTML = 
                `${memoryUsage.toFixed(1)}<span class="metric-unit">GB</span>`;
            document.getElementById('powerValue').innerHTML = 
                `${powerConsumption}<span class="metric-unit">W</span>`;
            
            // Update generation time
            if (this.generationStartTime) {
                const elapsed = (Date.now() - this.generationStartTime) / 1000;
                document.getElementById('timeValue').innerHTML = 
                    `${elapsed.toFixed(1)}<span class="metric-unit">seconds</span>`;
            }
        }, 200); // Update every 200ms for smooth animation
    }

    completeGeneration() {
        this.isGenerating = false;
        this.clearIntervals();
        
        // Update final time
        const totalTime = (Date.now() - this.generationStartTime) / 1000;
        document.getElementById('timeValue').innerHTML = 
            `${totalTime.toFixed(1)}<span class="metric-unit">seconds</span>`;
        
        // Update UI state
        document.getElementById('status').textContent = '✅ COMPLETE!';
        document.getElementById('status').className = 'status complete';
        document.getElementById('completionBadge').style.display = 'block';
        
        // Show generated image
        this.showRandomImage();
        
        // Enable new generation after 3 seconds
        setTimeout(() => {
            document.getElementById('generateBtn').disabled = false;
            document.getElementById('generateBtn').textContent = 'Generate New Image';
        }, 3000);
    }

    showRandomImage() {
        const platformImages = this.availableImages[this.currentPlatform];
        const randomIndex = Math.floor(Math.random() * platformImages.length);
        const selectedImage = platformImages[randomIndex];
        
        const imgElement = document.getElementById('generatedImage');
        const placeholderElement = document.getElementById('placeholderContent');
        
        // Load image
        imgElement.src = selectedImage;
        imgElement.onload = () => {
            placeholderElement.classList.add('hidden');
            imgElement.classList.remove('hidden');
        };
        
        imgElement.onerror = () => {
            console.error('Failed to load image:', selectedImage);
            // Fallback: keep placeholder visible
        };
    }

    clearIntervals() {
        if (this.progressInterval) {
            clearInterval(this.progressInterval);
            this.progressInterval = null;
        }
        if (this.metricsInterval) {
            clearInterval(this.metricsInterval);
            this.metricsInterval = null;
        }
    }

    goBack() {
        this.clearIntervals();
        this.currentPlatform = null;
        
        // Show platform selection and hide demo interface
        document.getElementById('platformSelection').style.display = 'flex';
        document.getElementById('demoInterface').style.display = 'none';
    }

    randomBetween(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }
}

// Global instance
const demo = new StandaloneDemo();

// Global functions for HTML event handlers
function selectPlatform(platform) {
    demo.selectPlatform(platform);
}

function startGeneration() {
    demo.startGeneration();
}

function goBack() {
    demo.goBack();
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    console.log('Standalone Demo initialized');
    console.log('Available platforms:', Object.keys(demo.platformConfigs));
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    demo.clearIntervals();
});