# Instructions to Add New Files to Xcode Project

The following files need to be added to the Xcode project:

1. **PortScanConfiguration.swift** - Port scanning modes configuration
2. **PortScanModeSelector.swift** - UI for selecting scan mode
3. **RealtimeTrafficManager.swift** - Real-time traffic monitoring
4. **NetworkVisualizationComponents.swift** - Visualization components
5. **EnhancedDeviceCard.swift** - Enhanced device cards with animations
6. **EnhancedTopologyView.swift** - Advanced topology view

## Steps to Add Files in Xcode:

1. Open **NMAPScanner.xcodeproj** in Xcode (already open)
2. In the Project Navigator (left sidebar), right-click on the **NMAPScanner** folder
3. Select **"Add Files to NMAPScanner..."**
4. Navigate to `/Volumes/Data/xcode/NMAPScanner/NMAPScanner/`
5. Select all the following files (hold Command to select multiple):
   - PortScanConfiguration.swift
   - PortScanModeSelector.swift
   - RealtimeTrafficManager.swift
   - NetworkVisualizationComponents.swift
   - EnhancedDeviceCard.swift
   - EnhancedTopologyView.swift
6. Make sure "Copy items if needed" is **UNCHECKED** (files are already in the correct location)
7. Make sure "Add to targets: NMAPScanner" is **CHECKED**
8. Click **"Add"**
9. Build the project (⌘B)

## After Adding Files:

The app will have three port scanning modes available:
- **Standard Ports (1-1024)** - Well-known ports, ~10-30 seconds per host
- **Common Ports (~100)** - Current mode, fastest, ~2-5 seconds per host
- **All Ports (1-65536)** - Complete scan, ~10-30 minutes per host

Users can select the scan mode from the main dashboard using the "Change Scan Mode" button.
