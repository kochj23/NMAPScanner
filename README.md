# NMAPScanner v8.6.0

![Build](https://github.com/kochj23/NMAPScanner/actions/workflows/build.yml/badge.svg)

**Advanced network security scanner with AI-powered threat detection and device management**

Comprehensive network scanning, vulnerability detection, and device action controls—all with local AI processing on Apple Silicon.

---

![NMAPScanner Dashboard](Screenshots/main-window.png)


## What is NMAPScanner?

NMAPScanner is a native macOS application that wraps nmap with an intuitive GUI, adding AI-powered threat detection, device management actions, and real-time network monitoring. It provides professional security scanning capabilities with the ease of a native Mac app.

**Key Benefits:**
- **Advanced Device Actions (v8.6.0)**: Whitelist, block, deep scan, isolate devices
- **AI Threat Detection**: MLX-powered security analysis
- **Real-Time Monitoring**: Live network activity tracking
- **UniFi Integration**: Control network devices via UniFi Controller
- **Professional Reports**: Detailed security audit reports

**Perfect For:**
- **Network Administrators**: Monitor and secure networks
- **Security Professionals**: Vulnerability assessment and penetration testing
- **Home Users**: Identify rogue devices on home network
- **IT Teams**: Asset discovery and inventory management

---

## What's New in v8.6.0 (January 2026)

### 🛡️ Advanced Device Actions
**Comprehensive device management:**

**Whitelist Devices:**
- Add to trusted devices list (UserDefaults + MAC address tracking)
- Disable security alerts for whitelisted devices
- Persistent across app restarts

**Block Devices:**
- Add to blocklist
- Optional firewall rules via pfctl (requires admin)
- System notifications on block actions

**Deep Scan:**
- Launch aggressive nmap scan (-A -T4 -p-)
- All ports, OS detection, service version detection
- Background processing with completion notifications

**Isolate Devices:**
- Mark as isolated in app
- Integration with UniFi Controller for VLAN isolation
- Persistent isolation tracking

**Implementation:**
```swift
private func handleBlock() {
    // Add to blocklist
    var blocklist = UserDefaults.standard.stringArray(forKey: "DeviceBlocklist") ?? []
    blocklist.append(device.ipAddress)
    UserDefaults.standard.set(blocklist, forKey: "DeviceBlocklist")

    // Add firewall rule (requires admin)
    let script = "do shell script \"pfctl -t blocklist -T add \(device.ipAddress)\" with administrator privileges"
    // Execute AppleScript
}
```

### 🚀 MLX Backend Implementation
**Apple Silicon native threat analysis:**

- **Local AI**: Security analysis without cloud
- **Model Support**: mlx-community security models
- **Vulnerability Detection**: AI-powered pattern recognition
- **Threat Scoring**: Intelligent risk assessment
- **Neural Engine**: Fast inference on Apple Silicon

---

## Features

### Core Scanning
- **Network Discovery**: Identify all devices on network
- **Port Scanning**: Detect open ports and services
- **OS Detection**: Identify device operating systems
- **Service Version**: Detect software versions
- **Vulnerability Scanning**: Check for known CVEs
- **Live Monitoring**: Real-time network activity

### Device Management (v8.6.0)
- **Whitelist**: Trust specific devices
- **Block**: Prevent network access
- **Deep Scan**: Aggressive security assessment
- **Isolate**: VLAN isolation via UniFi
- **Device Tracking**: MAC address and IP tracking
- **History**: Device appearance/disappearance logging

### Security Features
- **Threat Detection**: AI-powered anomaly detection
- **Rogue Device Alerts**: Identify unauthorized devices
- **Vulnerability Database**: Known exploit checking
- **Security Dashboard**: Visual risk assessment
- **Audit Reports**: Comprehensive security reports
- **Compliance Checking**: Security policy verification

### UniFi Integration
- **Controller Connection**: UniFi API integration
- **Device Identification**: Match UniFi devices to scan results
- **Firewall Rules**: Create rules via UniFi
- **VLAN Management**: Isolate devices to specific VLANs
- **Real-Time Status**: Live UniFi device status

### Reporting
- **PDF Reports**: Professional security audit documents
- **CSV Export**: Data for further analysis
- **Timeline View**: Historical network changes
- **Statistics**: Network health metrics
- **Compliance Reports**: Regulatory compliance documentation

---

## Security

### Privacy & Data Protection
- **Local Scanning**: All scanning happens on your network
- **No Cloud Upload**: Scan results stay on your Mac
- **MLX AI**: Threat analysis runs locally
- **Encrypted Storage**: Sensitive data encrypted at rest
- **Keychain Integration**: UniFi credentials in Keychain

### Ethical Use
- **Authorized Networks Only**: Only scan networks you own/manage
- **Legal Compliance**: Follow local computer security laws
- **No Attack Tools**: Defensive security only
- **Audit Logging**: All operations logged for accountability

### Best Practices
- Only scan authorized networks
- Get written permission for client networks
- Use whitelist to reduce false positives
- Review firewall rules before applying
- Keep nmap and app updated

---

## Requirements

### System Requirements
- **macOS 13.0 (Ventura) or later**
- **Architecture**: Universal (Apple Silicon recommended)
- **nmap**: `brew install nmap`

### For MLX Backend
- **Apple Silicon**: M1/M2/M3/M4
- **Python 3.9+**
- **mlx-lm**: `pip install mlx-lm`
- **8GB+ RAM**

### Network Requirements
- **Admin Access**: For deep scanning and firewall rules
- **Network Access**: Must be on network to scan
- **UniFi Controller** (Optional): For isolation features

### Dependencies
**Required:**
- nmap: `brew install nmap`

**Built-in:**
- SwiftUI, AppKit, Foundation

**Optional:**
- mlx-lm (for MLX AI)
- UniFi Controller (for isolation)

---

## Installation

### Install nmap

```bash
brew install nmap
```

### Install NMAPScanner

```bash
open "/Volumes/Data/xcode/binaries/20260127-NMAPScanner-v8.6.0/NMAPScanner-v8.6.0-build14.dmg"
```

### Build from Source

```bash
git clone https://github.com/kochj23/NMAPScanner.git
cd NMAPScanner
open "NMAPScanner.xcodeproj"
```

---

## Usage

### Quick Scan

1. Launch NMAPScanner
2. Enter network range (e.g., 192.168.1.0/24)
3. Click "Scan Network"
4. View discovered devices

### Device Actions

**Whitelist Device:**
1. Right-click device in list
2. Select "Whitelist"
3. Device added to trusted list

**Block Device:**
1. Right-click device
2. Select "Block"
3. Optionally add firewall rule (requires admin)

**Deep Scan:**
1. Right-click device
2. Select "Deep Scan"
3. Wait for aggressive scan to complete

**Isolate Device:**
1. Right-click device
2. Select "Isolate"
3. Device marked for VLAN isolation

---

## Troubleshooting

**nmap Not Found:**
- Install: `brew install nmap`
- Verify: `which nmap`

**Can't Scan Network:**
- Check network connectivity
- Verify IP range format
- Try with admin privileges

**Firewall Rules Fail:**
- Need administrator password
- Check pfctl is available
- Verify firewall enabled

---

## Version History

### v8.6.0 (January 2026)
- Device actions (whitelist, block, deep scan, isolate)
- MLX backend integration
- UniFi improvements

### v8.0.0 (2025)
- Initial release
- Network scanning
- Threat detection

---

## License

MIT License - Copyright © 2026 Jordan Koch

---

**Last Updated:** January 27, 2026
**Status:** ✅ Production Ready

---

## More Apps by Jordan Koch

| App | Description |
|-----|-------------|
| [Bastion](https://github.com/kochj23/Bastion) | Authorized security testing and penetration toolkit |
| [URL-Analysis](https://github.com/kochj23/URL-Analysis) | Network traffic analysis and URL monitoring |
| [rtsp-rotator](https://github.com/kochj23/rtsp-rotator) | RTSP camera stream rotation and monitoring |
| [MLXCode](https://github.com/kochj23/MLXCode) | Local AI coding assistant for Apple Silicon |
| [TopGUI](https://github.com/kochj23/TopGUI) | macOS system monitor with real-time metrics |

> **[View all projects](https://github.com/kochj23?tab=repositories)**
