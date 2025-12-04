# NMAPScanner

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.x-orange.svg)](https://swift.org/)
[![Version](https://img.shields.io/badge/version-8.5.0-green.svg)](https://github.com/kochj23/NMAPScanner/releases)

**Professional network security scanner for macOS with comprehensive device detection, vulnerability scanning, and real-time monitoring.**

## 🚀 Features

### Network Scanning
- **Parallel Port Scanning:** Scan up to 10 devices simultaneously (87% faster)
- **Smart Discovery:** Intelligent Bonjour/mDNS with early termination
- **Comprehensive Coverage:** 115+ ports covering all common services
- **Multiple Scan Modes:** Quick, Standard, Deep, and Custom scans

### Device Detection
- ✅ **HomeKit Devices:** Complete Apple HomeKit accessory detection
- ✅ **Google Home / Nest:** Chromecast, speakers, displays
- ✅ **Amazon Alexa / Echo:** All Echo devices and Fire TV
- ✅ **UniFi Equipment:** Protect cameras, APs, controllers, switches
- ✅ **Network Cameras:** RTSP, Hikvision, Dahua, generic IP cameras
- ✅ **Network Infrastructure:** Routers, switches, printers, NAS
- ✅ **Smart Home IoT:** MQTT devices, smart sensors, hubs
- ✅ **Servers:** Web, database, email, file servers

### Security Features
- **Vulnerability Scanning:** Detect insecure services and open ports
- **Backdoor Detection:** Scan for 12+ known malware ports
- **Threat Analysis:** AI-powered security recommendations
- **Historical Tracking:** Monitor network changes over time
- **Anomaly Detection:** Identify unusual network behavior

## 📊 Performance

| Scan Type | Time (20 devices) | Ports |
|-----------|-------------------|-------|
| HomeKit Scan | 8-15 seconds | 6 (optimized) |
| Standard Scan | 15-25 seconds | 115 (comprehensive) |
| Deep Scan | 25-35 seconds | 130+ (maximum) |

**65-80% faster than sequential scanning with zero accuracy loss!**

## 📥 Installation

### Download Binary (Recommended):

1. Download from [Releases](https://github.com/kochj23/NMAPScanner/releases/latest)
2. Extract `NMAPScanner-v8.5.0-macOS.tar.gz`
3. Copy `NMAPScanner.app` to `/Applications`
4. Launch and scan your network!

### Build from Source:

```bash
git clone https://github.com/kochj23/NMAPScanner.git
cd NMAPScanner
open NMAPScanner.xcodeproj
```

Build in Xcode (⌘B) and run (⌘R)

## 🛠️ Requirements

- **macOS:** 14.0 (Sonoma) or later
- **Architecture:** Universal (Apple Silicon + Intel)
- **Permissions:** Network access

## 📖 Quick Start

1. Launch NMAPScanner
2. Navigate to **Dashboard** tab
3. Click **"Scan Network"**
4. View discovered devices

## 🎯 Port Coverage (115 Ports)

### Smart Home Devices:
- **HomeKit:** 8 ports (62078, 51827, 5353, etc.)
- **Google Home:** 6 ports (8008, 8009, 8443, etc.)
- **Amazon Alexa:** 4 ports (4070, 33434, etc.)

### UniFi Equipment (12 ports):
- Controller: 8080, 8443, 8880, 8843
- Protect: 7004, 7080, 7441-7443

### Network Services:
- Core: SSH (22), HTTP (80), HTTPS (443), DNS (53)
- Databases: MySQL, PostgreSQL, MongoDB, Redis
- Windows: SMB, RDP, NetBIOS
- Cameras: RTSP, Hikvision, Dahua

**See releases for complete port list**

## 🏗️ Architecture

Built with:
- **Swift 5.x** with SwiftUI
- **Structured Concurrency** (async/await)
- **Actor-based State Management**
- **Native macOS Frameworks**

## 📚 Documentation

- [CHANGELOG.md](CHANGELOG.md) - Version history
- [LICENSE](LICENSE) - MIT License
- [Releases](https://github.com/kochj23/NMAPScanner/releases) - Binary downloads

## 🤝 Contributing

Contributions welcome! Please submit Pull Requests or open Issues.

## 📜 License

MIT License - see [LICENSE](LICENSE) file.

Copyright (c) 2025 Jordan Koch

## ⚠️ Legal Notice

This tool is for network administration and security auditing of networks you own or have permission to scan. Unauthorized scanning may be illegal.

## 👥 Authors

**Jordan Koch** & **Claude Code**

---

[Download Latest Release](https://github.com/kochj23/NMAPScanner/releases/latest) | [Report Issues](https://github.com/kochj23/NMAPScanner/issues)
