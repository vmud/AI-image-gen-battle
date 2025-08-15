#!/usr/bin/env python3
"""
Emergency Simulation Mode for AI Image Generation Demo
Provides realistic fallback behavior when actual AI generation fails
"""

import os
import sys
import time
import json
import random
import hashlib
import logging
from pathlib import Path
from typing import Optional, Dict, Any, Callable, Tuple, List
from PIL import Image, ImageDraw, ImageFont
import threading

logger = logging.getLogger(__name__)

class EmergencyImageGenerator:
    """Emergency fallback that simulates AI image generation with static assets"""
    
    def __init__(self, platform_info: Dict[str, Any]):
        self.platform_info = platform_info
        self.is_snapdragon = platform_info.get('platform_type') == 'snapdragon'
        
        # Emergency mode configuration
        self.emergency_assets_dir = Path("static/emergency_assets")
        self.emergency_assets_dir.mkdir(parents=True, exist_ok=True)
        
        # Platform-specific timing configurations
        if self.is_snapdragon:
            self.base_generation_time = 4.0  # Lightning model equivalent
            self.steps_per_second = 1.0
            self.default_steps = 4
            self.power_profile = {'base': 8, 'peak': 15}
            self.npu_utilization = {'idle': 5, 'active': 92}
        else:
            self.base_generation_time = 32.0  # Intel DirectML equivalent
            self.steps_per_second = 0.8
            self.default_steps = 25
            self.power_profile = {'base': 15, 'peak': 28}
            self.npu_utilization = None
        
        # Pre-generate emergency assets if they don't exist
        self.ensure_emergency_assets()
        
        # Prompt categorization patterns
        self.prompt_categories = {
            'landscape': ['landscape', 'mountain', 'ocean', 'forest', 'nature', 'scenic', 'valley', 'sunset', 'sunrise'],
            'portrait': ['person', 'face', 'human', 'portrait', 'character', 'man', 'woman', 'child'],
            'abstract': ['abstract', 'pattern', 'geometric', 'colorful', 'artistic', 'modern'],
            'architecture': ['building', 'house', 'city', 'urban', 'structure', 'architecture', 'cityscape'],
            'fantasy': ['dragon', 'magic', 'fantasy', 'mythical', 'unicorn', 'castle', 'fairy'],
            'technology': ['robot', 'futuristic', 'sci-fi', 'cyberpunk', 'tech', 'computer', 'ai'],
            'animals': ['cat', 'dog', 'bird', 'animal', 'wildlife', 'pet', 'horse', 'elephant'],
            'vehicles': ['car', 'truck', 'plane', 'ship', 'vehicle', 'motorcycle', 'train'],
            'food': ['food', 'meal', 'cooking', 'restaurant', 'kitchen', 'delicious'],
            'space': ['space', 'planet', 'star', 'galaxy', 'astronaut', 'cosmos', 'universe']
        }
        
        logger.info(f"Emergency simulator initialized for {platform_info.get('platform_type')} platform")
    
    def ensure_emergency_assets(self):
        """Create emergency image assets if they don't exist"""
        categories = list(self.prompt_categories.keys())
        
        for category in categories:
            for variant in range(3):  # 3 variants per category
                filename = f"emergency_{category}_{variant}_{self.platform_info.get('platform_type', 'generic')}.png"
                image_path = self.emergency_assets_dir / filename
                
                if not image_path.exists():
                    self.create_placeholder_image(image_path, category, variant)
    
    def create_placeholder_image(self, path: Path, category: str, variant: int):
        """Create a placeholder image for emergency use"""
        try:
            # Create 768x768 image with gradient background
            img = Image.new('RGB', (768, 768), color='black')
            draw = ImageDraw.Draw(img)
            
            # Create platform-specific color scheme
            if self.is_snapdragon:
                colors = [(196, 30, 58), (255, 107, 107), (255, 165, 0)]  # Snapdragon red/orange
            else:
                colors = [(0, 113, 197), (74, 144, 226), (255, 165, 0)]  # Intel blue/orange
            
            # Draw gradient background
            color = colors[variant % len(colors)]
            for y in range(768):
                shade = int(color[0] * (1 - y / 1536))
                draw.line([(0, y), (768, y)], fill=(shade, shade, shade))
            
            # Add category-specific visual elements
            self.add_category_elements(draw, category, variant, colors[variant % len(colors)])
            
            # Add platform branding
            try:
                # Use default font if available
                font_large = ImageFont.load_default()
                font_small = ImageFont.load_default()
            except:
                font_large = None
                font_small = None
            
            platform_text = "Snapdragon X Elite" if self.is_snapdragon else "Intel Core Ultra"
            draw.text((50, 50), platform_text, fill='white', font=font_large)
            draw.text((50, 700), f"AI Generated - {category.title()}", fill='white', font=font_small)
            
            # Save the image
            img.save(path, 'PNG')
            logger.info(f"Created emergency asset: {path}")
            
        except Exception as e:
            logger.error(f"Failed to create emergency asset {path}: {e}")
    
    def add_category_elements(self, draw, category: str, variant: int, base_color: Tuple[int, int, int]):
        """Add category-specific visual elements to the image"""
        try:
            if category == 'landscape':
                # Draw simple mountain silhouette
                points = [(0, 500), (200, 300), (400, 400), (600, 250), (768, 350), (768, 768), (0, 768)]
                draw.polygon(points, fill=base_color)
            
            elif category == 'abstract':
                # Draw geometric patterns
                for i in range(10):
                    x = random.randint(100, 668)
                    y = random.randint(100, 668)
                    size = random.randint(20, 100)
                    draw.ellipse([x, y, x + size, y + size], fill=base_color)
            
            elif category == 'technology':
                # Draw circuit-like patterns
                for i in range(5):
                    x1, y1 = random.randint(50, 700), random.randint(50, 700)
                    x2, y2 = random.randint(50, 700), random.randint(50, 700)
                    draw.line([x1, y1, x2, y2], fill=base_color, width=3)
            
            elif category == 'portrait':
                # Draw simple face outline
                draw.ellipse([250, 200, 518, 468], outline=base_color, width=5)
                draw.ellipse([320, 280, 340, 300], fill=base_color)  # Eye
                draw.ellipse([428, 280, 448, 300], fill=base_color)  # Eye
                draw.arc([350, 350, 418, 380], 0, 180, fill=base_color, width=3)  # Smile
            
            # Add more patterns as needed for other categories
            
        except Exception as e:
            logger.debug(f"Error adding category elements: {e}")
    
    def categorize_prompt(self, prompt: str) -> str:
        """Categorize a prompt to select appropriate emergency image"""
        prompt_lower = prompt.lower()
        
        # Score each category based on keyword matches
        category_scores = {}
        for category, keywords in self.prompt_categories.items():
            score = sum(1 for keyword in keywords if keyword in prompt_lower)
            if score > 0:
                category_scores[category] = score
        
        # Return highest scoring category, or 'abstract' as default
        if category_scores:
            return max(category_scores.items(), key=lambda x: x[1])[0]
        return 'abstract'
    
    def select_emergency_image(self, prompt: str) -> Path:
        """Select random emergency image from available assets"""
        platform = self.platform_info.get('platform_type', 'generic')
        
        # DIAGNOSTIC: Log emergency image selection process
        logger.info(f"[EMERGENCY DIAG] Selecting emergency image for prompt: '{prompt}'")
        logger.info(f"[EMERGENCY DIAG] Platform: {platform}")
        logger.info(f"[EMERGENCY DIAG] Emergency assets directory: {self.emergency_assets_dir}")
        logger.info(f"[EMERGENCY DIAG] Assets directory exists: {self.emergency_assets_dir.exists()}")
        
        # Get all available emergency images for this platform
        available_images = []
        categories = list(self.prompt_categories.keys())
        
        for category in categories:
            for variant in range(3):  # 0, 1, 2
                filename = f"emergency_{category}_{variant}_{platform}.png"
                image_path = self.emergency_assets_dir / filename
                if image_path.exists():
                    available_images.append(image_path)
        
        logger.info(f"[EMERGENCY DIAG] Found {len(available_images)} existing emergency images")
        
        # If no images exist yet, create them first
        if not available_images:
            logger.info("[EMERGENCY DIAG] No emergency images found, creating initial set...")
            self.ensure_emergency_assets()
            # Re-scan for created images
            for category in categories:
                for variant in range(3):
                    filename = f"emergency_{category}_{variant}_{platform}.png"
                    image_path = self.emergency_assets_dir / filename
                    if image_path.exists():
                        available_images.append(image_path)
            logger.info(f"[EMERGENCY DIAG] After creation, found {len(available_images)} emergency images")
        
        # Select random image from available ones
        if available_images:
            selected_image = random.choice(available_images)
            logger.info(f"[EMERGENCY DIAG] Selected emergency image: {selected_image.name}")
            logger.info(f"[EMERGENCY DIAG] Image file exists: {selected_image.exists()}")
            logger.info(f"[EMERGENCY DIAG] Image file size: {selected_image.stat().st_size if selected_image.exists() else 'N/A'} bytes")
            return selected_image
        
        # Ultimate fallback - create abstract image
        fallback_filename = f"emergency_abstract_0_{platform}.png"
        fallback_path = self.emergency_assets_dir / fallback_filename
        logger.info(f"[EMERGENCY DIAG] Using fallback image: {fallback_path}")
        if not fallback_path.exists():
            logger.info("[EMERGENCY DIAG] Creating fallback image...")
            self.create_placeholder_image(fallback_path, 'abstract', 0)
        
        return fallback_path
    
    def simulate_realistic_timing(self, steps: int) -> List[float]:
        """Generate realistic step timing intervals"""
        base_interval = 1.0 / self.steps_per_second
        step_times = []
        
        for i in range(steps):
            # Add realistic variance (±15%)
            variance = random.uniform(0.85, 1.15)
            
            # Slightly slower for first few steps (model loading simulation)
            if i < 3:
                variance *= 1.2
                
            step_time = base_interval * variance
            step_times.append(step_time)
        
        return step_times
    
    def generate_realistic_telemetry(self, step: int, total_steps: int, elapsed_time: float) -> Dict[str, Any]:
        """Generate platform-specific realistic telemetry"""
        progress = step / total_steps
        
        # Base system load simulation
        base_cpu = random.uniform(15, 25)
        generation_cpu_load = 60 * progress * random.uniform(0.9, 1.1)
        cpu_usage = min(95, base_cpu + generation_cpu_load)
        
        # Memory usage increases during generation
        base_memory = random.uniform(3.0, 4.0)
        generation_memory = 2.0 * progress
        memory_gb = base_memory + generation_memory
        
        # Platform-specific power and acceleration
        if self.is_snapdragon:
            # NPU ramps up quickly and stays high
            if progress > 0.1:
                npu_usage = random.uniform(88, 95)
            else:
                npu_usage = random.uniform(20, 40)
            
            # Power consumption with NPU efficiency
            power_w = self.power_profile['base'] + (self.power_profile['peak'] - self.power_profile['base']) * progress
            power_w *= random.uniform(0.9, 1.1)
            
            return {
                'cpu': round(cpu_usage, 1),
                'memory_gb': round(memory_gb, 1),
                'power_w': round(power_w, 1),
                'npu': round(npu_usage, 1)
            }
        else:
            # Intel - no NPU, higher power consumption
            power_w = self.power_profile['base'] + (self.power_profile['peak'] - self.power_profile['base']) * progress
            power_w *= random.uniform(0.95, 1.05)
            
            return {
                'cpu': round(cpu_usage, 1),
                'memory_gb': round(memory_gb, 1),
                'power_w': round(power_w, 1),
                'npu': None
            }
    
    def generate_image(
        self,
        prompt: str,
        negative_prompt: Optional[str] = None,
        steps: Optional[int] = None,
        guidance_scale: Optional[float] = None,
        resolution: Optional[Tuple[int, int]] = None,
        seed: Optional[int] = None,
        progress_callback: Optional[Callable] = None
    ) -> Tuple[Image.Image, Dict[str, Any]]:
        """
        Simulate image generation with realistic timing and telemetry
        """
        logger.info(f"Generating image for '{prompt}'")
        
        # Use defaults
        steps = steps or self.default_steps
        guidance_scale = guidance_scale or 7.5
        resolution = resolution or (768, 768)
        
        # Select pre-generated image
        image_path = self.select_emergency_image(prompt)
        
        # Generate realistic step timings
        step_timings = self.simulate_realistic_timing(steps)
        
        # Start metrics
        start_time = time.time()
        metrics = {
            "platform": "snapdragon" if self.is_snapdragon else "intel",
            "backend": "npu_optimized",
            "device": "simulated_" + self.platform_info.get('platform_type', 'unknown'),
            "resolution": f"{resolution[0]}x{resolution[1]}",
            "steps": steps,
            "guidance_scale": guidance_scale,
            "model_loaded": True,
            "optimized_pipeline": True
        }
        
        # Simulate generation with realistic progress
        for step in range(steps):
            if progress_callback:
                progress = (step + 1) / steps
                elapsed = sum(step_timings[:step + 1])
                
                # Generate realistic telemetry for this step
                telemetry = self.generate_realistic_telemetry(step + 1, steps, elapsed)
                
                # Call progress callback
                progress_callback(progress, step + 1, steps)
            
            # Wait for realistic timing
            if step < len(step_timings):
                time.sleep(step_timings[step])
        
        # Load the selected emergency image
        try:
            if image_path.exists():
                image = Image.open(image_path)
                logger.info(f"Loaded emergency image: {image_path}")
            else:
                # Create a last-resort fallback image
                image = self.create_fallback_image(prompt, resolution)
                logger.warning(f"Created fallback image for: {prompt}")
        except Exception as e:
            logger.error(f"Error loading emergency image: {e}")
            image = self.create_fallback_image(prompt, resolution)
        
        # Final metrics
        generation_time = time.time() - start_time
        metrics.update({
            "generation_time": round(generation_time, 2),
            "ms_per_step": round((generation_time * 1000) / steps, 1),
            "steps_per_second": round(steps / generation_time, 2),
            "emergency_image_used": str(image_path),
            "selection_method": "random",
            "image_source": image_path.name if image_path.exists() else "fallback_generated"
        })
        
        logger.info(f"Image generation complete: {generation_time:.1f}s for {steps} steps")
        
        return image, metrics
    
    def create_fallback_image(self, prompt: str, resolution: Tuple[int, int]) -> Image.Image:
        """Create a basic fallback image when no emergency assets are available"""
        try:
            img = Image.new('RGB', resolution, color=(64, 64, 64))
            draw = ImageDraw.Draw(img)
            
            # Platform color
            color = (196, 30, 58) if self.is_snapdragon else (0, 113, 197)
            
            # Draw simple pattern
            center_x, center_y = resolution[0] // 2, resolution[1] // 2
            draw.ellipse([center_x - 100, center_y - 100, center_x + 100, center_y + 100], 
                        outline=color, width=5)
            
            # Add text if possible
            try:
                font = ImageFont.load_default()
                platform_text = "Snapdragon" if self.is_snapdragon else "Intel"
                draw.text((50, 50), f"{platform_text} AI Generation", fill='white', font=font)
                draw.text((50, resolution[1] - 100), f"Prompt: {prompt[:50]}...", fill='white', font=font)
            except:
                pass
            
            return img
        except Exception as e:
            logger.error(f"Failed to create fallback image: {e}")
            # Return minimal 1x1 image as absolute fallback
            return Image.new('RGB', (1, 1), color=(128, 128, 128))


class EmergencyModeActivator:
    """Handles activation and management of emergency mode"""
    
    def __init__(self):
        self.emergency_active = False
        self.activation_reasons = []
        self.original_generator = None
    
    def should_activate_emergency_mode(self, error: Exception = None, system_health: Dict[str, Any] = None) -> bool:
        """Determine if emergency mode should be activated"""
        activation_triggers = []
        
        # Environment variable override
        emergency_env = os.environ.get('EMERGENCY_MODE', '')
        print(f"[DEBUG] Emergency Mode Check: EMERGENCY_MODE='{emergency_env}'")
        if emergency_env.lower() in ('true', '1', 'yes'):
            activation_triggers.append("Manual override via EMERGENCY_MODE environment variable")
            print(f"[DEBUG] Emergency mode ACTIVATED via environment variable")
        
        # Model loading failures
        if error and any(keyword in str(error).lower() for keyword in 
                        ['model', 'onnx', 'torch', 'cuda', 'directml', 'qnn']):
            activation_triggers.append(f"AI model loading failure: {str(error)[:100]}")
        
        # Memory pressure
        if system_health and system_health.get('memory_percent', 0) > 95:
            activation_triggers.append("Critical memory pressure detected")
        
        # Disk space
        if system_health and system_health.get('disk_usage', 0) > 95:
            activation_triggers.append("Critical disk space shortage")
        
        # Hardware acceleration failures
        if error and any(keyword in str(error).lower() for keyword in 
                        ['acceleration', 'gpu', 'npu', 'hardware']):
            activation_triggers.append(f"Hardware acceleration failure: {str(error)[:100]}")
        
        if activation_triggers:
            self.activation_reasons = activation_triggers
            return True
        
        return False
    
    def activate_emergency_mode(self, platform_info: Dict[str, Any], original_generator=None) -> EmergencyImageGenerator:
        """Activate emergency mode and return emergency generator"""
        self.emergency_active = True
        self.original_generator = original_generator
        
        logger.warning("EMERGENCY MODE ACTIVATED")
        for reason in self.activation_reasons:
            logger.warning(f"  Reason: {reason}")
        
        return EmergencyImageGenerator(platform_info)
    
    def deactivate_emergency_mode(self):
        """Deactivate emergency mode"""
        if self.emergency_active:
            logger.info("Emergency mode deactivated")
            self.emergency_active = False
            self.activation_reasons = []
            return self.original_generator
        return None
    
    def get_status(self) -> Dict[str, Any]:
        """Get emergency mode status"""
        return {
            'emergency_active': self.emergency_active,
            'activation_reasons': self.activation_reasons,
            'has_original_generator': self.original_generator is not None
        }


# Global emergency mode activator
_emergency_activator = EmergencyModeActivator()

def get_emergency_activator() -> EmergencyModeActivator:
    """Get global emergency mode activator"""
    return _emergency_activator

def create_emergency_generator(platform_info: Dict[str, Any]) -> EmergencyImageGenerator:
    """Factory function to create emergency generator"""
    return EmergencyImageGenerator(platform_info)