# AI Image Generation Battle - Emergency Demo

A completely standalone demo showcasing AI image generation performance comparison between Intel and Snapdragon platforms.

## Features

- **Platform Selection**: Choose between Intel and Snapdragon X Elite platforms
- **Realistic Performance Simulation**: 
  - Snapdragon: 8-12 second generation times, 85-95% NPU utilization
  - Intel: 15-25 second generation times, 70-85% GPU utilization
- **40 Pregenerated Images**: "Futuristic retail store" themed images
- **Live Metrics**: Real-time performance monitoring during generation
- **Complete UI State Management**: Ready → Generating → Complete workflow

## Quick Start

### Windows
1. Double-click `launch_demo.bat`
2. The demo will automatically open in your browser
3. Select your platform (Intel or Snapdragon)
4. Click "Generate Image" to start the simulation

### Manual Start
```bash
cd emergency_demo
python server.py
```
Then open `http://localhost:8080` in your browser.

## Directory Structure

```
emergency_demo/
├── index.html              # Main demo interface
├── server.py              # Standalone Python web server
├── launch_demo.bat         # Windows launcher script
├── generate_images.py      # Image generation utility
├── README.md              # This file
├── assets/                # Generated images (40 total)
│   ├── retail_store_00_intel.png
│   ├── retail_store_00_snapdragon.png
│   └── ...
└── static/
    └── js/
        └── demo.js        # Demo simulation engine
```

## How It Works

### Platform Simulation

**Snapdragon X Elite**
- Generation Time: 8-12 seconds
- NPU Utilization: 85-95%
- Memory Usage: 3.8-4.5 GB
- Power Consumption: 12-18W

**Intel Platform**
- Generation Time: 15-25 seconds
- GPU Utilization: 70-85%
- Memory Usage: 5.2-6.8 GB
- Power Consumption: 25-35W

### Demo Flow

1. **Platform Selection**: User selects Intel or Snapdragon
2. **UI Branding**: Interface updates with platform-specific colors and branding
3. **Image Generation**: Click "Generate Image" to start simulation
4. **Live Metrics**: Real-time performance data updates during generation
5. **Progress Animation**: 20-step progress bar with realistic timing
6. **Image Display**: Random image from the appropriate platform set
7. **Completion**: Final metrics and success indicators

### Image Assets

The demo includes 40 pregenerated placeholder images:
- 20 Intel-branded images
- 20 Snapdragon-branded images
- All themed around "futuristic retail store"
- Each image includes platform branding and sample numbering

## Technical Details

### Dependencies
- Python 3.7+ (only standard library modules used)
- Modern web browser (Chrome, Firefox, Safari, Edge)

### Browser Compatibility
- Chrome 80+
- Firefox 75+
- Safari 13+
- Edge 80+

### Network Requirements
- None (completely offline after initial setup)
- Runs on localhost only

## Customization

### Adding New Images
1. Place images in the `assets/` directory
2. Follow naming convention: `retail_store_XX_platform.png`
3. Update the image count in `demo.js` if needed

### Modifying Performance Metrics
Edit the `platformConfigs` object in `static/js/demo.js`:

```javascript
platformConfigs: {
    snapdragon: {
        name: "Snapdragon X Elite",
        generationTime: { min: 8, max: 12 }, // seconds
        processorUtilization: { min: 85, max: 95 },
        // ... other settings
    }
}
```

### Changing Server Port
```bash
python server.py 8081  # Use port 8081 instead of 8080
```

## Troubleshooting

### Server Won't Start
- **Port in use**: The server will automatically try the next available port
- **Python not found**: Ensure Python 3.7+ is installed and in your PATH
- **Permission denied**: Run as administrator on Windows

### Images Not Loading
- Check that the `assets/` directory exists and contains images
- Verify image filenames match the expected pattern
- Check browser console for error messages

### Browser Issues
- Try refreshing the page (Ctrl+F5 or Cmd+Shift+R)
- Clear browser cache
- Try a different browser

## Emergency Mode Purpose

This standalone demo is designed for:
- **Trade shows and demos** where internet connectivity is unreliable
- **Client presentations** requiring guaranteed performance
- **Development testing** without full infrastructure dependencies
- **Quick showcases** of platform performance differences

## Support

This is a self-contained emergency demo. For the full AI Image Generation Battle experience with real AI models, please refer to the main project documentation.

---

**Emergency Demo Version**: 1.0  
**Generated Images**: 40 (futuristic retail store theme)  
**Platforms Supported**: Intel, Snapdragon X Elite  
**Last Updated**: $(date)