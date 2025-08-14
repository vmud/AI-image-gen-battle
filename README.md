# AI Image Generation Battle - Snapdragon vs Intel Demo

## Project Overview

This is a coordinated demonstration system that showcases Snapdragon X Elite's AI processing superiority over Intel Core Ultra processors using real-time Stable Diffusion image generation.

## Architecture

- **MacOS Control Hub**: Simple command-line control for synchronized demo execution
- **Windows Clients**: Polished full-screen displays showing real-time image generation progress
- **Synchronized Execution**: Both machines generate the same prompt simultaneously for direct comparison

## Project Structure

```
AI-image-gen-battle/
├── src/                   # Source code
│   ├── control-hub/       # MacOS coordination scripts
│   └── windows-client/    # Windows client with AI generation
├── deployment/            # Setup and deployment scripts
│   ├── setup.ps1          # Main Windows setup (with logging)
│   ├── monitor.ps1        # Real-time setup monitoring
│   ├── diagnose.ps1       # DirectML troubleshooting
│   ├── prepare_models.ps1 # AI model download/preparation
│   └── verify.ps1         # Setup verification
├── docs/                  # Documentation
│   ├── AI_IMPLEMENTATION.md     # AI architecture details
│   ├── MODEL_ACQUISITION_GUIDE.md # Model download guide
│   └── PERFORMANCE_BENCHMARKS.md  # Expected performance
└── mockups/               # UI design mockups
```

## Demo Flow

1. Deploy configuration to both fresh Windows machines
2. Run command: `./demo-control.py --prompt "a futuristic cityscape"`
3. Both machines simultaneously show real-time image generation
4. Snapdragon completes faster, demonstrating NPU advantage

## Target Hardware

- **Snapdragon**: Samsung Galaxy Book4 Edge (Snapdragon X Elite with NPU)
- **Intel**: Lenovo Yoga 7 2-in-1 16IML9 (Intel Core Ultra 7 155U)
- **Control**: MacOS development laptop

## Key Features

- Real-time image generation visualization
- Step-by-step diffusion progress display
- Platform-specific performance metrics
- Professional branded interfaces
- Synchronized execution timing
- Winner announcement system