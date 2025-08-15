# Emergency Simulation Mode Guide

## Overview

The Emergency Simulation Mode provides a last-resort fallback system for the AI Image Generation Demo when actual AI generation fails. It uses pre-generated static images and realistic telemetry simulation to maintain demo functionality during catastrophic failures.

## Features

### ✅ Realistic Image Generation Simulation
- Pre-generated images categorized by prompt type (landscape, portrait, abstract, etc.)
- Platform-specific timing patterns (Snapdragon: 3-5s, Intel: 30-45s)
- Consistent image selection based on prompt hashing
- Real-time progress callbacks with step-by-step updates

### ✅ Authentic Telemetry Simulation
- Platform-specific CPU/NPU utilization patterns
- Memory usage progression during "generation"
- Power consumption curves matching hardware profiles
- Realistic timing variations (±15% randomization)

### ✅ Seamless Integration
- Automatic activation on AI model failures
- Manual activation via environment variable or API
- Transparent WebSocket event sequences
- Identical data formats and API responses

## Activation Triggers

Emergency mode activates automatically when:

1. **Model Loading Failures**
   - AI models not found or corrupted
   - ONNX/PyTorch initialization errors
   - Hardware acceleration unavailable

2. **System Resource Issues**
   - Memory pressure >95%
   - Disk space <1GB
   - Critical hardware failures

3. **Manual Override**
   - Environment variable: `EMERGENCY_MODE=true`
   - API endpoint: `POST /emergency/activate`
   - Direct method call: `ai_generator.force_emergency_mode()`

## Usage Examples

### Environment Variable Activation
```bash
# Windows
set EMERGENCY_MODE=true
python demo_client.py

# PowerShell
$env:EMERGENCY_MODE = "true"
python demo_client.py

# Linux/Mac
export EMERGENCY_MODE=true
python demo_client.py
```

### API Control
```python
import requests

# Check status
response = requests.get('http://localhost:5000/emergency')
print(response.json())

# Activate emergency mode
response = requests.post('http://localhost:5000/emergency/activate')
print(response.json())

# Deactivate emergency mode
response = requests.post('http://localhost:5000/emergency/deactivate')
print(response.json())
```

### Direct Integration
```python
from ai_pipeline import AIImageGenerator
from platform_detection import PlatformDetector

# Setup
detector = PlatformDetector()
platform_info = detector.detect_hardware()
ai_gen = AIImageGenerator(platform_info)

# Check emergency status
status = ai_gen.get_emergency_status()
print(f"Emergency available: {status['emergency_mode_available']}")

# Force emergency mode
success = ai_gen.force_emergency_mode()
print(f"Emergency activated: {success}")

# Generate with emergency mode
image, metrics = ai_gen.generate_image("A beautiful sunset")
print(f"Backend used: {metrics['backend']}")  # emergency_simulation
```

## Image Asset System

### Directory Structure
```
static/emergency_assets/
├── emergency_landscape_0_snapdragon.png
├── emergency_landscape_1_snapdragon.png
├── emergency_landscape_2_snapdragon.png
├── emergency_portrait_0_intel.png
├── emergency_abstract_0_intel.png
└── ...
```

### Supported Categories
- **landscape**: Mountains, nature, scenic views
- **portrait**: People, faces, characters
- **abstract**: Patterns, geometric shapes, art
- **architecture**: Buildings, cities, structures
- **fantasy**: Dragons, magic, mythical scenes
- **technology**: Robots, futuristic, sci-fi
- **animals**: Pets, wildlife, creatures
- **vehicles**: Cars, planes, transportation
- **food**: Meals, cooking, restaurants
- **space**: Planets, stars, astronomy

### Image Selection Algorithm
```python
def select_image(prompt: str, platform: str) -> str:
    # 1. Categorize prompt by keywords
    category = categorize_prompt(prompt)
    
    # 2. Hash prompt for consistency
    prompt_hash = hashlib.md5(prompt.encode()).hexdigest()
    variant = int(prompt_hash[:2], 16) % 3  # 0-2
    
    # 3. Build filename
    filename = f"emergency_{category}_{variant}_{platform}.png"
    
    # 4. Return with fallbacks
    return find_image_with_fallbacks(filename)
```

## Platform-Specific Behavior

### Snapdragon X Elite Simulation
```python
# Timing Profile
base_generation_time = 4.0  # seconds
steps_per_second = 1.0
default_steps = 4  # Lightning model

# Power Profile
base_power = 8W
peak_power = 15W
npu_utilization = 88-95%

# Performance Targets
excellent_threshold = 5.0  # seconds
good_threshold = 10.0      # seconds
```

### Intel Core Ultra Simulation
```python
# Timing Profile
base_generation_time = 32.0  # seconds
steps_per_second = 0.8
default_steps = 25  # DirectML optimized

# Power Profile
base_power = 15W
peak_power = 28W
cpu_utilization = 60-90%

# Performance Targets
excellent_threshold = 35.0  # seconds
good_threshold = 45.0       # seconds
```

## Telemetry Data Format

Emergency mode generates telemetry identical to real generation:

```json
{
  "telemetry": {
    "cpu": 45.2,
    "memory_gb": 3.8,
    "power_w": 18.5,
    "npu": 92.0  // Snapdragon only
  }
}
```

## WebSocket Event Sequence

Emergency mode maintains identical WebSocket events:

1. **job_started** - Immediate with job metadata
2. **progress** - Step-by-step with realistic timing
3. **telemetry** - Continuous metrics at 1-second intervals
4. **completed** - Final event with image URL
5. **error** - If simulation errors occur

## Testing Emergency Mode

### Run Test Suite
```bash
cd src/windows-client
python test_emergency_mode.py
```

### Manual Testing Steps

1. **Environment Variable Test**
   ```bash
   set EMERGENCY_MODE=true
   python demo_client.py
   # Visit http://localhost:5000/intel or /snapdragon
   # Generate images - should use emergency mode
   ```

2. **API Test**
   ```bash
   # Start normal demo
   python demo_client.py
   
   # In another terminal
   curl -X POST http://localhost:5000/emergency/activate
   # Generate images - should use emergency mode
   
   curl -X POST http://localhost:5000/emergency/deactivate
   # Return to normal mode
   ```

3. **Failure Simulation**
   ```bash
   # Rename models directory to trigger failure
   mv C:\AIDemo\models C:\AIDemo\models_backup
   python demo_client.py
   # Should automatically activate emergency mode
   ```

## Status Monitoring

### Check Emergency Status
```bash
curl http://localhost:5000/emergency
```

Response:
```json
{
  "emergency_mode_available": true,
  "emergency_mode_active": false,
  "emergency_generator_initialized": false,
  "activation_reasons": []
}
```

### System Status Integration
Emergency status is included in `/status` endpoint:
```json
{
  "status": "idle",
  "emergency_mode": {
    "emergency_mode_available": true,
    "emergency_mode_active": true,
    "activation_reasons": ["Manual override via EMERGENCY_MODE environment variable"]
  }
}
```

## Performance Metrics

Emergency mode provides realistic metrics:

```json
{
  "platform": "intel",
  "backend": "emergency_simulation",
  "generation_time": 31.2,
  "steps_per_second": 0.8,
  "emergency_mode": true,
  "prompt_category": "landscape",
  "emergency_image_used": "static/emergency_assets/emergency_landscape_1_intel.png"
}
```

## Troubleshooting

### Emergency Mode Not Available
- Ensure `emergency_simulator.py` is in the Python path
- Check that Pillow (PIL) is installed for image generation
- Verify write permissions for `static/emergency_assets/`

### Images Not Generating
- Check emergency assets directory exists: `static/emergency_assets/`
- Verify image files are present (auto-generated on first run)
- Check file permissions for image reading

### API Endpoints Not Working
- Ensure Flask server is running
- Check that emergency mode integration is loaded
- Verify CORS is enabled for cross-origin requests

### Timing Issues
- Emergency mode uses realistic timing - Snapdragon is faster than Intel
- Check platform detection is working correctly
- Verify step timing calculations in telemetry

## Integration Notes

- Emergency mode is fully transparent to the frontend
- All WebSocket events maintain identical structure
- Image URLs follow same pattern: `/static/generated/{job_id}.png`
- Metrics include `emergency_mode: true` flag for identification
- Job management and error handling remain unchanged

## Future Enhancements

1. **Dynamic Asset Generation**
   - Generate images on-demand using simple graphics
   - Implement text-to-image placeholder generation

2. **Enhanced Categorization**
   - AI-powered prompt analysis for better image selection
   - Support for style and mood-based categorization

3. **Telemetry Learning**
   - Record real telemetry patterns for more accurate simulation
   - Platform-specific performance modeling

4. **Network Simulation**
   - Simulate model download delays
   - Progressive loading indicators