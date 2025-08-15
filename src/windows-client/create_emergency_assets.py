#!/usr/bin/env python3
"""
Pre-generate Emergency Assets for Snapdragon Demo
Creates all necessary emergency image assets for immediate demo functionality
"""

import os
import sys
import logging
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EmergencyAssetGenerator:
    """Pre-generates emergency demo assets"""
    
    def __init__(self):
        self.assets_dir = Path("static/emergency_assets")
        self.assets_dir.mkdir(parents=True, exist_ok=True)
        
        # Platform-specific configurations
        self.platforms = {
            'snapdragon': {
                'colors': [(196, 30, 58), (255, 107, 107), (255, 165, 0)],  # Red/Orange
                'brand_text': 'Snapdragon X Elite',
                'tagline': 'NPU Accelerated'
            },
            'intel': {
                'colors': [(0, 113, 197), (74, 144, 226), (255, 165, 0)],  # Blue/Orange
                'brand_text': 'Intel Core Ultra',
                'tagline': 'DirectML Powered'
            }
        }
        
        # Image categories with design variations
        self.categories = {
            'landscape': {
                'description': 'Mountain and nature scenes',
                'elements': ['mountains', 'valleys', 'sunsets']
            },
            'portrait': {
                'description': 'Human faces and characters',
                'elements': ['faces', 'profiles', 'expressions']
            },
            'abstract': {
                'description': 'Geometric and artistic patterns',
                'elements': ['circles', 'triangles', 'gradients']
            },
            'technology': {
                'description': 'Futuristic and tech themes',
                'elements': ['circuits', 'grids', 'nodes']
            },
            'architecture': {
                'description': 'Buildings and structures',
                'elements': ['buildings', 'bridges', 'towers']
            },
            'fantasy': {
                'description': 'Magical and mythical themes',
                'elements': ['crystals', 'stars', 'mystical']
            },
            'animals': {
                'description': 'Wildlife and pets',
                'elements': ['silhouettes', 'paws', 'birds']
            },
            'vehicles': {
                'description': 'Cars, planes, and transport',
                'elements': ['wheels', 'wings', 'engines']
            },
            'food': {
                'description': 'Meals and culinary art',
                'elements': ['plates', 'utensils', 'steam']
            },
            'space': {
                'description': 'Cosmos and astronomy',
                'elements': ['planets', 'stars', 'orbits']
            }
        }
    
    def create_landscape_image(self, platform_config, variant, size=(768, 768)):
        """Create landscape-themed image"""
        img = Image.new('RGB', size, color=(20, 30, 40))
        draw = ImageDraw.Draw(img)
        colors = platform_config['colors']
        
        if variant == 0:
            # Mountain silhouette
            points = [(0, 500), (150, 200), (300, 350), (450, 150), (600, 250), (768, 400), (768, 768), (0, 768)]
            draw.polygon(points, fill=colors[0])
            
            # Sun/moon
            draw.ellipse([600, 80, 680, 160], fill=colors[2])
            
        elif variant == 1:
            # Valley scene
            points = [(0, 400), (200, 300), (400, 450), (600, 250), (768, 350), (768, 768), (0, 768)]
            draw.polygon(points, fill=colors[1])
            
            # Water reflection
            for i in range(400, 768, 20):
                draw.line([(0, i), (768, i)], fill=(100, 150, 200), width=2)
                
        else:  # variant == 2
            # Forest silhouette
            for x in range(0, 768, 40):
                height = random.randint(300, 600)
                draw.rectangle([x, height, x + 30, 768], fill=colors[0])
                # Tree tops
                draw.ellipse([x - 10, height - 40, x + 40, height + 20], fill=colors[1])
        
        return img
    
    def create_portrait_image(self, platform_config, variant, size=(768, 768)):
        """Create portrait-themed image"""
        img = Image.new('RGB', size, color=(40, 40, 60))
        draw = ImageDraw.Draw(img)
        colors = platform_config['colors']
        
        center_x, center_y = size[0] // 2, size[1] // 2
        
        if variant == 0:
            # Classic face outline
            draw.ellipse([center_x - 120, center_y - 150, center_x + 120, center_y + 150], 
                        outline=colors[0], width=8)
            # Eyes
            draw.ellipse([center_x - 60, center_y - 40, center_x - 20, center_y], fill=colors[1])
            draw.ellipse([center_x + 20, center_y - 40, center_x + 60, center_y], fill=colors[1])
            # Smile
            draw.arc([center_x - 40, center_y + 20, center_x + 40, center_y + 80], 0, 180, fill=colors[2], width=6)
            
        elif variant == 1:
            # Profile silhouette
            points = [(center_x - 80, center_y - 100), (center_x + 20, center_y - 120),
                     (center_x + 60, center_y - 80), (center_x + 80, center_y),
                     (center_x + 60, center_y + 80), (center_x + 20, center_y + 120),
                     (center_x - 80, center_y + 100)]
            draw.polygon(points, fill=colors[0])
            
        else:  # variant == 2
            # Artistic face fragments
            draw.ellipse([center_x - 100, center_y - 100, center_x + 100, center_y + 100], 
                        outline=colors[0], width=6)
            draw.ellipse([center_x - 40, center_y - 60, center_x - 10, center_y - 30], fill=colors[1])
            draw.ellipse([center_x + 10, center_y - 60, center_x + 40, center_y - 30], fill=colors[1])
            draw.line([(center_x - 20, center_y + 20), (center_x + 20, center_y + 20)], fill=colors[2], width=4)
        
        return img
    
    def create_abstract_image(self, platform_config, variant, size=(768, 768)):
        """Create abstract-themed image"""
        img = Image.new('RGB', size, color=(30, 30, 50))
        draw = ImageDraw.Draw(img)
        colors = platform_config['colors']
        
        if variant == 0:
            # Geometric circles
            for i in range(8):
                x = random.randint(50, size[0] - 150)
                y = random.randint(50, size[1] - 150)
                radius = random.randint(30, 80)
                color_idx = i % len(colors)
                draw.ellipse([x, y, x + radius, y + radius], fill=colors[color_idx])
                
        elif variant == 1:
            # Triangle patterns
            for i in range(6):
                x1, y1 = random.randint(50, size[0] - 100), random.randint(50, size[1] - 100)
                x2, y2 = x1 + random.randint(-80, 80), y1 + random.randint(-80, 80)
                x3, y3 = x1 + random.randint(-80, 80), y1 + random.randint(-80, 80)
                color_idx = i % len(colors)
                draw.polygon([(x1, y1), (x2, y2), (x3, y3)], fill=colors[color_idx])
                
        else:  # variant == 2
            # Wave patterns
            for y in range(0, size[1], 60):
                color_idx = (y // 60) % len(colors)
                points = []
                for x in range(0, size[0] + 1, 30):
                    wave_y = y + 30 * (1 + 0.5 * (x / 100))
                    points.append((x, wave_y))
                for x in range(size[0], -1, -30):
                    wave_y = y + 60 + 20 * (1 + 0.3 * (x / 100))
                    points.append((x, wave_y))
                draw.polygon(points, fill=colors[color_idx])
        
        return img
    
    def create_technology_image(self, platform_config, variant, size=(768, 768)):
        """Create technology-themed image"""
        img = Image.new('RGB', size, color=(15, 25, 35))
        draw = ImageDraw.Draw(img)
        colors = platform_config['colors']
        
        if variant == 0:
            # Circuit board pattern
            for i in range(8):
                x1, y1 = random.randint(50, size[0] - 50), random.randint(50, size[1] - 50)
                x2, y2 = random.randint(50, size[0] - 50), random.randint(50, size[1] - 50)
                draw.line([(x1, y1), (x2, y2)], fill=colors[0], width=3)
                # Circuit nodes
                draw.ellipse([x1 - 8, y1 - 8, x1 + 8, y1 + 8], fill=colors[1])
                draw.ellipse([x2 - 8, y2 - 8, x2 + 8, y2 + 8], fill=colors[2])
                
        elif variant == 1:
            # Grid pattern
            for x in range(0, size[0], 80):
                draw.line([(x, 0), (x, size[1])], fill=colors[0], width=2)
            for y in range(0, size[1], 80):
                draw.line([(0, y), (size[0], y)], fill=colors[0], width=2)
            # Intersection nodes
            for x in range(40, size[0], 80):
                for y in range(40, size[1], 80):
                    if random.random() > 0.6:
                        color = colors[random.randint(1, 2)]
                        draw.ellipse([x - 6, y - 6, x + 6, y + 6], fill=color)
                        
        else:  # variant == 2
            # Neural network style
            nodes = [(random.randint(100, size[0] - 100), random.randint(100, size[1] - 100)) for _ in range(12)]
            for i, (x1, y1) in enumerate(nodes):
                draw.ellipse([x1 - 15, y1 - 15, x1 + 15, y1 + 15], fill=colors[i % len(colors)])
                # Connect to nearby nodes
                for j, (x2, y2) in enumerate(nodes[i + 1:], i + 1):
                    distance = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
                    if distance < 200:
                        draw.line([(x1, y1), (x2, y2)], fill=colors[0], width=2)
        
        return img
    
    def create_category_image(self, category, platform_config, variant, size=(768, 768)):
        """Create image for specific category"""
        if category == 'landscape':
            return self.create_landscape_image(platform_config, variant, size)
        elif category == 'portrait':
            return self.create_portrait_image(platform_config, variant, size)
        elif category == 'abstract':
            return self.create_abstract_image(platform_config, variant, size)
        elif category == 'technology':
            return self.create_technology_image(platform_config, variant, size)
        else:
            # Generic pattern for other categories
            return self.create_generic_image(category, platform_config, variant, size)
    
    def create_generic_image(self, category, platform_config, variant, size=(768, 768)):
        """Create generic image for any category"""
        img = Image.new('RGB', size, color=(25, 35, 45))
        draw = ImageDraw.Draw(img)
        colors = platform_config['colors']
        
        # Create category-appropriate pattern
        center_x, center_y = size[0] // 2, size[1] // 2
        
        # Base geometric pattern
        for i in range(6):
            x = center_x + 100 * (i % 3 - 1)
            y = center_y + 100 * (i // 3 - 1)
            radius = 40 + variant * 10
            color = colors[i % len(colors)]
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color)
        
        return img
    
    def add_branding(self, img, platform_config, category, variant):
        """Add platform branding to image"""
        draw = ImageDraw.Draw(img)
        
        try:
            # Use default font
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        except:
            font_large = None
            font_small = None
        
        # Platform branding
        brand_text = platform_config['brand_text']
        tagline = platform_config['tagline']
        
        # Top-left branding
        draw.text((30, 30), brand_text, fill='white', font=font_large)
        draw.text((30, 60), tagline, fill=(200, 200, 200), font=font_small)
        
        # Bottom info
        category_text = f"AI Generated - {category.title()} #{variant + 1}"
        draw.text((30, img.height - 50), category_text, fill=(180, 180, 180), font=font_small)
        
        return img
    
    def generate_all_assets(self):
        """Generate complete set of emergency assets"""
        logger.info("Starting emergency asset generation...")
        
        total_created = 0
        for platform_name, platform_config in self.platforms.items():
            logger.info(f"Generating assets for {platform_name.upper()} platform...")
            
            for category_name in self.categories.keys():
                for variant in range(3):  # 0, 1, 2
                    filename = f"emergency_{category_name}_{variant}_{platform_name}.png"
                    filepath = self.assets_dir / filename
                    
                    if filepath.exists():
                        logger.debug(f"Skipping existing: {filename}")
                        continue
                    
                    try:
                        # Create base image
                        img = self.create_category_image(category_name, platform_config, variant)
                        
                        # Add branding
                        img = self.add_branding(img, platform_config, category_name, variant)
                        
                        # Save image
                        img.save(filepath, 'PNG', optimize=True)
                        total_created += 1
                        logger.info(f"Created: {filename}")
                        
                    except Exception as e:
                        logger.error(f"Failed to create {filename}: {e}")
        
        logger.info(f"Emergency asset generation complete! Created {total_created} new images.")
        return total_created

def main():
    """Main function"""
    print("🎨 Emergency Asset Generator - Snapdragon X Elite Demo")
    print("=" * 60)
    
    generator = EmergencyAssetGenerator()
    created_count = generator.generate_all_assets()
    
    print(f"\n✅ Generation complete!")
    print(f"📁 Assets location: {generator.assets_dir}")
    print(f"🖼️  Created {created_count} new emergency images")
    print(f"🎯 Ready for emergency demo mode!")

if __name__ == "__main__":
    main()