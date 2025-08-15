# Get Snapped - AI Image Generation Demo Web Frontends

## Overview
This directory contains the web-based frontends for the AI image generation demo, featuring both Intel and Snapdragon themed interfaces.

## Files
- `snapdragon-demo.html` - Snapdragon X Elite demo (red theme)
- `intel-demo.html` - Intel Core Ultra demo (blue theme)
- `js/demo-client.js` - Shared JavaScript functionality for both demos

## Features Implemented
✅ **Visual Design**
- Layouts match the mockup design exactly
- Snapdragon: Red color scheme with corporate branding
- Intel: Blue color scheme with neutral copy (no positive marketing)
- "Get Snapped" tagline prominently displayed on both

✅ **Live Telemetry**
- Generation Time display
- NPU Utilization (Snapdragon) / CPU Utilization (Intel)
- Memory Usage (GB)
- Power Consumption (W)
- Real-time updates via polling

✅ **Status Indicators** (Bottom bar, discreet)
- LLM Ready: Shows red/green based on model loading status
- Control PC: Shows red/green based on control hub reachability

✅ **Prompt Generation**
- Text input box for custom prompts
- Quick prompt buttons for easy testing
- Local execution triggered as if from control machine
- Real-time progress tracking with step counter

✅ **Progress Display**
- Animated progress bar
- Step counter (e.g., "Steps: 5/20 | 25% Complete")
- Completion badge when finished
- Generated image placeholder with status text

## Usage

### Starting the Demo

1. **Run the demo client** (includes web server):
```bash
cd src/windows-client
python demo_client.py
```

2. **Access the web interface**:
- Open browser to `http://localhost:5000`
- Choose between Snapdragon or Intel demo
- Or directly access:
  - Snapdragon: `http://localhost:5000/snapdragon`
  - Intel: `http://localhost:5000/intel`

### Using the Interface

1. **Monitor Status Indicators**:
   - Bottom left: LLM Ready indicator (turns green when model is loaded)
   - Bottom right: Control PC indicator (turns green when control hub is reachable)

2. **Generate an Image**:
   - Enter a custom prompt in the text box
   - Or click one of the quick prompt buttons
   - Click "Generate" to start
   - Watch real-time progress and metrics

3. **View Telemetry**:
   - Generation time updates during processing
   - CPU/NPU utilization shows system load
   - Memory usage displays current RAM consumption
   - Power consumption estimates wattage

## API Endpoints

The frontend communicates with these Flask endpoints:

- `GET /status` - Get current system status and metrics
- `POST /command` - Send generation commands
- `GET /info` - Get platform information

## Configuration

To customize the control hub URL for status checking:
```javascript
// In the HTML files, set:
window.controlHubUrl = 'http://your-control-hub:8000';
```

## Architecture

```
┌─────────────────────┐
│   Web Browser       │
│  (HTML + JS UI)     │
└──────────┬──────────┘
           │ HTTP/Polling
           ▼
┌─────────────────────┐
│   Flask Server      │
│   (Port 5000)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Demo Display       │
│  (Python Backend)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  AI Pipeline        │
│  (Image Gen)        │
└─────────────────────┘
```

## Development Notes

### Color Schemes
**Snapdragon (Red)**:
- Primary: `#c41e3a` to `#ff6b6b`
- Success: `#00ff88`
- Background: `#1a1a2e` to `#16213e`

**Intel (Blue)**:
- Primary: `#0071c5` to `#4a90e2`
- Accent: `#ffa500` (orange)
- Background: `#1e3c72` to `#2a5298`

### Polling Intervals
- Status checks: 2 seconds
- Telemetry updates: 1 second
- Progress updates: 500ms during generation

### Browser Compatibility
- Tested on Chrome, Firefox, Edge
- Requires JavaScript enabled
- Best viewed at 1920x1080 or higher

## Troubleshooting

**Status indicators stay red:**
- Ensure Flask server is running on port 5000
- Check that AI models are loaded
- Verify control hub URL if using remote control

**Metrics not updating:**
- Check browser console for errors
- Ensure CORS is enabled in Flask
- Verify network connectivity to localhost:5000

**Generation doesn't start:**
- Check that LLM Ready indicator is green
- Verify Python backend is running
- Check console for API errors

## Demo Requirements Met

| Requirement | Status | Implementation |
|------------|--------|---------------|
| Layout matches mockup | ✅ | Identical structure and styling |
| Snapdragon red theme | ✅ | Corporate red palette applied |
| Intel blue theme | ✅ | Professional blue palette |
| "Get Snapped" tagline | ✅ | Displayed in header |
| Live telemetry | ✅ | 1-second polling updates |
| Status indicators | ✅ | Bottom bar, red/green states |
| Prompt input | ✅ | Text box with generate button |
| Local execution | ✅ | POST to /command endpoint |
| Progress tracking | ✅ | Real-time step updates |
| No Intel promotion | ✅ | Neutral copy only |

## Future Enhancements
- WebSocket support for real-time updates (reduce polling)
- Image preview when generation completes
- History of recent prompts
- Download generated images
- Side-by-side comparison mode
