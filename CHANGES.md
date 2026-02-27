# NMAPScanner Changes Log

## 2025-11-29 - Version 1.1.0 Build 1840

### Issues Fixed

1. **HomePod Classification** (/Volumes/Data/xcode/NMAPScanner/NMAPScanner/IntegratedDashboardViewV3.swift:1193-1202)
   - Changed detection threshold from 2+ ports to 1+ port for AirPlay/HomeKit
   - HomePods now correctly classified as IoT instead of "Unknown"

2. **Preset View Readability** (/Volumes/Data/xcode/NMAPScanner/NMAPScanner/ScanPresets.swift:297-449)
   - Reduced font sizes from 28-42pt to 13-28pt
   - Adjusted card padding from 24-40px to 16-20px
   - Changed grid minimum width from 300px to 280px
   - Icon sizes reduced from 40pt to 24pt
   - Stat badge sizes reduced from 14-16pt to 11-12pt

3. **Compilation Errors**
   - Fixed service name checking (line 1098): `$0.service?.lowercased()` → `$0.service.lowercased()`
   - Fixed device type for mDNS devices (line 1214): `.networkDevice` → `.router`
   - Removed duplicate OUI entries: 50:C7:BF (TP-Link), 68:5B:35 (Apple/Shelly), 68:C6:3A (Tuya/Kogeek)

### New Features

1. **Google Home & Nest Detection** (/Volumes/Data/xcode/NMAPScanner/NMAPScanner/IntegratedDashboardViewV3.swift:1233-1243)
   - Added 15+ hostname patterns: google-home, googlehome, nest-hub, nest-mini, nest-audio, nest-wifi, nest-cam, nest-protect, chromecast, etc.
   - Added 9 new Google MAC address OUIs (lines 2205-2212)
   - Comprehensive detection across manufacturer, hostname, and MAC address

2. **Enhanced Device Classification** (/Volumes/Data/xcode/NMAPScanner/NMAPScanner/IntegratedDashboardViewV3.swift)
   - **Koogeek** (line 1148): Added to IoT manufacturer list
   - **Kogeek** (line 1149): Added to IoT manufacturer list
   - **Bose** (lines 1101-1103, 1150, 1224-1226): Service name, manufacturer, and hostname detection
   - **Onkyo** (lines 1151, 1229-1231): Manufacturer and hostname detection
   - **HP Printers** (lines 1171-1174): Manufacturer-based detection
   - **iPhones** (lines 1208-1210): Hostname-based mobile classification
   - **mDNS Devices** (lines 1213-1215): Hostname pattern for network infrastructure

3. **Real-Time Port Scanning Status** (/Volumes/Data/xcode/NMAPScanner/NMAPScanner/IntegratedDashboardViewV3.swift)
   - Added status monitoring tasks (lines 729-736, 792-799, 901-908)
   - Displays current port being scanned: "Scanning [host]:[port]..."
   - Updates every 50ms for real-time feedback
   - Applied to 3 scanning contexts: full scan, port rescan, single device scan

### Technical Improvements

1. **Port Info Service Name Access**
   - Changed from optional chaining (`service?`) to direct access (`service`)
   - Matches PortInfo struct definition in ThreatModel.swift:207

2. **Device Type Enum Compliance**
   - Removed invalid `.networkDevice` type
   - Used existing `.router` type for network infrastructure
   - Maintains compatibility with EnhancedDevice.DeviceType enum

3. **OUI Database Cleanup**
   - Removed 3 duplicate MAC address entries
   - Resolved compilation warnings
   - Maintained data integrity (kept first occurrence, commented duplicates)

### Files Modified

| File | Lines Changed | Purpose |
|------|---------------|---------|
| IntegratedDashboardViewV3.swift | ~50 | Device detection, port status, bug fixes |
| ScanPresets.swift | ~40 | UI font/spacing improvements |

### Device Detection Matrix

| Device | Method | Detection Pattern |
|--------|--------|-------------------|
| HomePod | Ports + Manufacturer | Apple + (49152\|32498\|7000\|3689\|5000) >= 1 |
| Google Home | Hostname + Manufacturer + MAC | "google-home"\|"nest-*"\|"chromecast" + Google OUIs |
| Bose | Service + Hostname + Manufacturer | Service name "bose" OR hostname "bose" OR manufacturer "bose" |
| Onkyo | Hostname + Manufacturer | Hostname "onkyo" OR manufacturer "onkyo" |
| Koogeek | Manufacturer | Manufacturer "koogeek"\|"kogeek" |
| HP Printer | Manufacturer | Manufacturer "hp"\|"hewlett"\|"hewlett-packard" |
| iPhone | Hostname | Hostname contains "iphone" |
| mDNS Device | Hostname | Hostname contains "_mcast"\|".mcast"\|"mcast.dns" |

### Build Information

- **Xcode Project**: /Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj
- **Build Configuration**: Release
- **Target**: macOS (arm64)
- **Archive Path**: /tmp/NMAPScanner.xcarchive
- **Export Path**: /Volumes/Data/xcode/binaries/NMAPScanner-2025-11-29-1840/
- **App Size**: 4.2 MB
- **Signing**: Apple Development ([REDACTED])
- **Team ID**: ZU5X76C98X

### Testing Recommendations

1. **HomePod Detection**
   - Verify HomePods appear under "IoT Devices" category
   - Check devices with only 1 AirPlay/HomeKit port are detected

2. **Google Home/Nest Detection**
   - Test with various Nest device hostnames
   - Verify Google-manufactured devices are classified as IoT
   - Check Chromecast devices are properly identified

3. **Port Scanning Feedback**
   - Monitor status line during port scans
   - Verify "Scanning [IP]:[port]..." appears
   - Confirm status updates in real-time

4. **Preset View Usability**
   - Open scan presets dialog
   - Verify all text is readable at normal window sizes
   - Check card layouts display properly

### Known Issues & Future Work

1. **Port Scan Mode Files Not Integrated**
   - PortScanConfiguration.swift exists but not in Xcode project
   - PortScanModeSelector.swift exists but not in Xcode project
   - Feature temporarily disabled (code commented out)
   - Manual file addition required via Xcode UI

2. **Visualization Features Pending**
   - RealtimeTrafficManager.swift created but not integrated
   - NetworkVisualizationComponents.swift created but not integrated
   - EnhancedDeviceCard.swift created but not integrated
   - EnhancedTopologyView.swift created but not integrated
   - See ADD_FILES_INSTRUCTIONS.md for integration steps

### Deployment

```bash
# Build command used:
cd /Volumes/Data/xcode/NMAPScanner
xcodebuild -project NMAPScanner.xcodeproj -scheme NMAPScanner -configuration Release archive -archivePath /tmp/NMAPScanner.xcarchive

# Export command used:
xcodebuild -exportArchive -archivePath /tmp/NMAPScanner.xcarchive -exportPath /Volumes/Data/xcode/binaries/NMAPScanner-2025-11-29-1840 -exportOptionsPlist <plist with method=mac-application>
```

### Commit Message Suggestion

```
Enhanced device detection and UI improvements (v1.1.0)

- Fixed HomePod classification (now IoT instead of Unknown)
- Added comprehensive Google Home/Nest detection (15+ patterns)
- Enhanced IoT device recognition (Koogeek, Bose, Onkyo)
- Added HP printer detection
- iPhone now classified as mobile device
- mDNS devices properly identified as network infrastructure
- Real-time port scanning status (displays current port)
- Fixed Preset View readability (adjusted font sizes)
- Resolved 3 compilation errors and warnings
- Cleaned up OUI database (removed duplicates)

🤖 Generated with Claude Code (https://claude.com/claude-code)


```

---

**Created by:** Jordan Koch
**Date:** 2025-11-29
**Build:** 1840
**Version:** 1.1.0
