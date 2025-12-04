# NMAPScanner v4.0 Release Notes
**Released:** November 24, 2025
**Created by:** Jordan Koch & Claude Code

---

## 🎯 Major Update: Code Quality & Port Definition Improvements

### ✅ What's Fixed in v4.0

#### **HomeKit Port Definitions - Clarified**
- **Port 5000:** Now correctly labeled as "AirPlay Audio" for Apple HomeKit
  - Description: "Apple HomeKit AirPlay Audio Stream (HomePod, Apple TV)"
  - Used by: HomePod, Apple TV
  - Category: HomeKit

- **Port 7000:** Now correctly labeled as "AirPlay Control" for Apple HomeKit
  - Description: "Apple HomeKit AirPlay Control Channel (HomePod, Apple TV)"
  - Used by: HomePod, Apple TV
  - Category: HomeKit

#### **Code Quality Improvements**
- ✅ Removed duplicate port definitions (7000, 3689, 80, 443)
- ✅ Fixed MAC address vendor duplicates (98:E0:D9, B4:F0:AB)
- ✅ Cleaned up HomeKitPortDefinitions.swift structure
- ✅ Zero compilation errors
- ✅ Reduced warnings from 28 to minimal count

#### **Build System**
- Clean build successful
- Code signed with Apple Development certificate
- dSYM debugging symbols generated
- Optimized Release configuration

---

## 📊 Complete Feature Set (All Previously Implemented)

### High Priority Features ✅
1. **Network Anomaly Detection** - Real-time intrusion detection
2. **Scheduled Scanning** - Automatic periodic network scans
3. **Device Grouping** - Organize by role, manufacturer, subnet, status
4. **Export Enhancements** - JSON, PDF, CSV export formats

### Medium Priority Features ✅
5. **Service Version Detection** - Banner grabbing for service identification
6. **Historical Comparison** - Device change tracking over time
7. **Custom Port Lists** - User-defined port scanning ranges
8. **Network Topology Map** - Interactive visual network diagram

### Nice to Have Features ✅
9. **Bulk Operations** - Multi-select device actions
10. **Device Notes** - Custom labels and annotations
11. **Filter/Search** - Real-time device search
12. **Dark Mode Support** - System-aware appearance

---

## 🔧 Technical Details

### Port Database
- **4,700+ known services** in ComprehensivePortDatabase.swift
- **HomeKit-specific ports** in HomeKitPortDefinitions.swift
- **Apple device detection** based on open ports and MAC addresses

### HomeKit Device Detection
The app can now accurately identify:
- **HomePod/HomePod mini** (ports 5000, 7000, 3689, 5353, 49152)
- **Apple TV** (ports 7000, 3689, 62078, 5353, 49152)
- **HomeKit Accessories** (port 49152 - HAP protocol)

### Architecture
- **MVVM pattern** with @StateObject managers
- **Async/await** for concurrent operations
- **SwiftUI** native interface
- **ObservableObject** for reactive updates

---

## 📦 Installation

**Binary Location:**
`/Volumes/Data/xcode/Binaries/NMAPScanner-v4.0-20251124-171637/`

**Installed Location:**
`/Applications/NMAPScanner.app`

**Requirements:**
- macOS 13.0 or later
- Apple Silicon or Intel Mac

---

## 🚀 Usage

### Quick Start
1. Launch NMAPScanner from Applications
2. Click "Scan Network" to discover devices
3. View devices in Home app-style cards
4. Click any device for detailed information

### HomeKit Device Identification
When scanning your network, the app will automatically:
- Detect HomePods by ports 5000 and 7000
- Identify Apple TVs by port 62078 and AirPlay ports
- Label HomeKit accessories with port 49152
- Show "AirPlay Audio" and "AirPlay Control" in port lists

### Advanced Features
- **Schedule scans:** Settings → Scanning → Enable Scheduled Scanning
- **Group devices:** Settings → Grouping → Select grouping mode
- **Export data:** Click device → Choose export format
- **View topology:** Click "View Topology" for network map
- **Track changes:** Click device → View "History" tab

---

## 🐛 Bug Fixes

### Fixed in v4.0:
1. ✅ Duplicate HomeKit port definitions (5000, 7000, 3689)
2. ✅ Duplicate web port definitions (80, 443)
3. ✅ MAC address vendor conflicts (98:E0:D9, B4:F0:AB)
4. ✅ Build warnings for duplicate dictionary keys
5. ✅ Improved port description clarity for HomeKit services

---

## 🔐 Security

All security features remain intact:
- Network anomaly detection
- MAC spoofing detection
- CVE vulnerability scanning
- Security audit capabilities
- Encrypted data storage

---

## 📝 Known Issues

**Non-Critical Warnings:**
- 6 Swift 6 concurrency warnings (future compatibility)
- 3 deprecated NSUserNotification API warnings (will migrate to UserNotifications framework in future release)
- Minor unused variable warnings (code cleanup opportunities)

**None of these affect app functionality or stability.**

---

## 🎨 Design

Maintains the clean Home app aesthetic:
- Minimalist card-based interface
- System fonts and colors
- Dark mode support
- Smooth animations
- Intuitive navigation

---

## 🙏 Credits

**Developed by:** Jordan Koch & Claude Code
**Release Date:** November 24, 2025
**Version:** 4.0 (Build 4)
**Platform:** macOS 13.0+

---

## 📞 Support

For issues or feature requests, refer to project documentation:
- `FEATURES_IMPLEMENTED.md` - Complete feature list
- `IMPLEMENTATION_ROADMAP.md` - Development roadmap
- `README.md` - Project overview

---

## 🔄 Upgrade Notes

If upgrading from v3.0:
- All settings and device history preserved
- No configuration changes needed
- Launch app normally after installation

---

**Build Status:** ✅ BUILD SUCCEEDED
**Code Quality:** ✅ CLEAN (zero errors)
**Testing:** ✅ VERIFIED
**Deployment:** ✅ INSTALLED & RUNNING
