#!/usr/bin/env python3
"""
Emergency Demo Image Generator
Creates placeholder images for the "futuristic retail store" prompt
"""

import os
from PIL import Image, ImageDraw, ImageFont
import random

def create_placeholder_image(filename, platform, index, width=512, height=512):
    """Create a placeholder image with text overlay"""
    # Generate a gradient background
    img = Image.new('RGB', (width, height), color='black')
    draw = ImageDraw.Draw(img)
    
    # Create gradient effect
    for y in range(height):
        # Different color schemes for different platforms
        if platform.lower() == 'snapdragon':
            # Red-orange gradient for Snapdragon
            r = int(196 + (255 - 196) * (y / height))
            g = int(30 + (107 - 30) * (y / height))
            b = int(58 + (107 - 58) * (y / height))
        else:  # Intel
            # Blue gradient for Intel
            r = int(26 + (102 - 26) * (y / height))
            g = int(33 + (153 - 33) * (y / height))
            b = int(62 + (255 - 62) * (y / height))
        
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    # Add some geometric patterns to simulate retail elements
    for i in range(8):
        x = random.randint(50, width - 50)
        y = random.randint(50, height - 50)
        size = random.randint(20, 80)
        
        # Draw rectangles to simulate store elements
        draw.rectangle([x, y, x + size, y + size//2], 
                      outline='white', width=2)
    
    # Add circles to simulate lighting
    for i in range(5):
        x = random.randint(30, width - 30)
        y = random.randint(30, height - 30)
        radius = random.randint(10, 30)
        draw.ellipse([x-radius, y-radius, x+radius, y+radius], 
                    outline='yellow', width=1)
    
    # Add text overlay
    try:
        # Try to use a default font, fall back to basic if not available
        font = ImageFont.load_default()
    except:
        font = None
    
    # Platform branding
    platform_text = f"{platform.upper()}"
    text_bbox = draw.textbbox((0, 0), platform_text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    
    draw.text(((width - text_width) // 2, 20), platform_text, 
              fill='white', font=font)
    
    # Image description
    desc_text = "Futuristic Retail Store"
    desc_bbox = draw.textbbox((0, 0), desc_text, font=font)
    desc_width = desc_bbox[2] - desc_bbox[0]
    
    draw.text(((width - desc_width) // 2, height - 60), desc_text, 
              fill='white', font=font)
    
    # Image number
    num_text = f"Sample #{index + 1}"
    num_bbox = draw.textbbox((0, 0), num_text, font=font)
    num_width = num_bbox[2] - num_bbox[0]
    
    draw.text(((width - num_width) // 2, height - 40), num_text, 
              fill='white', font=font)
    
    # Save the image
    img.save(filename, 'PNG')
    print(f"Generated: {filename}")

def main():
    """Generate all placeholder images"""
    assets_dir = "emergency_demo/assets"
    os.makedirs(assets_dir, exist_ok=True)
    
    print("Generating 40 placeholder images for 'futuristic retail store' prompt...")
    
    # Generate 20 Intel images
    for i in range(20):
        filename = os.path.join(assets_dir, f"retail_store_{i:02d}_intel.png")
        create_placeholder_image(filename, "Intel", i)
    
    # Generate 20 Snapdragon images
    for i in range(20):
        filename = os.path.join(assets_dir, f"retail_store_{i:02d}_snapdragon.png")
        create_placeholder_image(filename, "Snapdragon", i)
    
    print(f"Successfully generated 40 images in {assets_dir}/")
    print("Images are ready for the emergency demo!")

if __name__ == "__main__":
    main()