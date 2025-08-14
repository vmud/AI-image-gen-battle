# Deployment Checklist

## Pre-Demo Setup (Day Before)

### Hardware Preparation
- [ ] Confirm Snapdragon X Elite laptop (Samsung Galaxy Book4 Edge) 
- [ ] Confirm Intel Core Ultra laptop (Lenovo Yoga 7 2-in-1 16IML9)
- [ ] Confirm MacOS control laptop
- [ ] Test WiFi network connectivity between all devices
- [ ] Ensure all devices are fully charged/plugged in

### Software Deployment
- [ ] Run `deployment/setup_windows.ps1` on both Windows machines
- [ ] Copy `windows-client/` files to `C:\AIDemo\client\` on both machines
- [ ] Test platform detection on both machines
- [ ] Verify client applications start correctly
- [ ] Test network discovery from MacOS control hub

### Demo Testing
- [ ] Run full system test: `python control-hub/test_demo.py`
- [ ] Test synchronized demo execution with sample prompt
- [ ] Verify Snapdragon completes faster than Intel
- [ ] Confirm UI displays are working and visible
- [ ] Test with multiple different prompts

## Demo Day Setup (30 minutes)

### Physical Setup
- [ ] Position both laptops for audience visibility
- [ ] Connect displays/projectors if needed
- [ ] Ensure stable network connection
- [ ] Test screen visibility from audience perspective

### Software Startup
- [ ] Start demo clients on both Windows machines
- [ ] Verify "READY" status on both displays
- [ ] Test control hub connectivity: `python control-hub/demo_control.py --discover`
- [ ] Run practice demo with simple prompt

### Presentation Preparation
- [ ] Prepare 3-5 compelling prompts for demo
- [ ] Brief presenter on control commands
- [ ] Set up backup demo scenarios
- [ ] Test microphone/presentation setup

## During Demo

### Demo Execution
1. **Introduction** (30 seconds)
   - Show both machines in ready state
   - Explain hardware platforms

2. **Live Demo** (60 seconds)
   ```bash
   python control-hub/demo_control.py --prompt "a futuristic city with flying cars"
   ```
   - Point out real-time progress on both screens
   - Highlight speed difference as it happens

3. **Results Analysis** (30 seconds)
   - Show final timing comparison
   - Emphasize power efficiency difference
   - Highlight NPU acceleration advantage

### Key Talking Points
- **Speed**: Snapdragon completes 30-40% faster
- **Efficiency**: Uses ~50% less power
- **Technology**: Dedicated NPU vs shared CPU/GPU resources
- **Real-world Impact**: Better battery life, cooler operation

## Post-Demo

### Immediate Actions
- [ ] Save demo results/screenshots if needed
- [ ] Reset both machines to ready state for next demo
- [ ] Check system performance logs

### Follow-up
- [ ] Document any issues encountered
- [ ] Note audience questions and feedback
- [ ] Update demo prompts based on effectiveness

## Emergency Procedures

### If Snapdragon Client Fails
1. Restart client: `C:\AIDemo\start_demo.bat`
2. Check network connectivity
3. Use backup prompt or run Intel-only demonstration

### If Network Issues
1. Switch to manual timing demo
2. Use pre-recorded results if available
3. Focus on architectural differences

### If Both Clients Fail
1. Use mockup displays: Open `mockups/side-by-side-comparison.html`
2. Walk through expected results manually
3. Emphasize technical architecture benefits

## Success Metrics

### Technical Validation
- [ ] Snapdragon consistently completes 20-40% faster
- [ ] Power consumption difference clearly visible
- [ ] UI displays professional and clear
- [ ] Network coordination reliable

### Audience Engagement
- [ ] Clear visual demonstration of performance difference
- [ ] Real-time progress creates compelling narrative
- [ ] Technical metrics support marketing claims
- [ ] Questions focus on implementation and benefits

## Demo Variants

### Quick Demo (2 minutes)
- Single prompt execution
- Focus on speed difference
- Brief explanation of NPU advantage

### Technical Deep Dive (5 minutes)
- Multiple prompt comparisons
- Detailed metrics analysis
- Platform architecture explanation
- Q&A session

### Executive Summary (1 minute)
- Pre-loaded results comparison
- Key performance metrics
- Business impact highlights