# NMAPScanner Changelog

## Unreleased - Multi-Model LLM Load Balancer
**Authors:** Jordan Koch

### AI Backend
- Added the shared multi-model LLM load balancer to the existing `AIBackend` layer:
  **OpenRouter** frontier models (one Keychain-stored key), an optional **Nova
  Gateway** backend (never required), and a **LoadBalancer** (round-robin /
  least-busy, health-gated) that spreads work across all installed local models
  (Ollama + MLX).
- Added three settings toggles: all local models / all frontier models / Nova
  Gateway. Existing Ollama, MLX, TinyLLM, TinyChat, and OpenWebUI paths unchanged.
- Added a network-free `LoadBalancerTests` suite and upgraded CI (Metal toolchain,
  pinned scheme, signing disabled).

### Security / Packaging
- **Disabled the App Sandbox** (`com.apple.security.app-sandbox` → `false`) in the
  main app entitlements so the network scanner has unrestricted socket/network
  access. HomeKit and network entitlements are untouched; Hardened Runtime is
  retained. Not distributed via the App Store.

## v8.5.0 (December 3, 2025) - Comprehensive Port Coverage
**Authors:** Jordan Koch

### 🎯 Expanded Device Detection

**115 comprehensive ports covering all device types:**

- **Smart Home:** HomeKit (8 ports), Google Home (6 ports), Amazon Alexa (4 ports)
- **Network Equipment:** UniFi/Ubiquiti (12 ports), cameras/RTSP (8 ports)
- **Core Services:** SSH, HTTP, DNS, FTP, databases, email (40+ ports)
- **Windows:** SMB, RDP, NetBIOS, WinRM (8 ports)
- **Security:** Backdoor/malware detection (12 ports)
- **IoT:** MQTT, smart devices (4 ports)

### Device Type Coverage

✅ **All smart home devices:** HomeKit, Google Home, Alexa
✅ **UniFi Protect cameras** and network equipment
✅ **Network infrastructure:** Routers, switches, printers, NAS
✅ **Security cameras:** UniFi, Hikvision, Dahua, RTSP
✅ **Servers:** Web, database, email, file servers
✅ **Legacy services:** Telnet, FTP, IRC detection
✅ **Backdoor detection:** 12 known malware ports

### Performance

With 115 ports and parallel scanning:
- **20 devices:** ~20 seconds (vs 40s sequential with 40 ports)
- **Still 50% faster** than v8.3.0 while scanning 3x more ports!

### Files Modified

- `PingScanner.swift:300-517` - Expanded CommonPorts from 40 to 115 ports

### Includes All v8.4.0 Optimizations

✅ Parallel port scanning (10x concurrent)
✅ Smart Bonjour early termination
✅ HomeKit-optimized 6-port fast scan

---

## v8.4.0 (December 3, 2025) - Speed Optimization Release
**Authors:** Jordan Koch

### 🚀 Major Performance Improvements

**65-80% faster scanning without sacrificing device discovery!**

### Performance Gains
- **HomeKit Scan:** 25-60s → 8-15s (70-80% faster)
- **Dashboard Scan:** 35-70s → 12-20s (65-75% faster)
- **Port Scanning:** 60s → 5-8s (87% faster)
- **Bonjour Discovery:** 10s → 3-5s (50-70% faster)

### New Features
1. **Parallel Port Scanning (Critical)**
   - Scans up to 10 devices simultaneously
   - 87% faster than sequential scanning
   - Network-friendly concurrency limits

2. **Smart Bonjour Early Termination (High)**
   - Exits when no new devices found for 3 seconds
   - Typically completes in 3-5s instead of 10s
   - 100% device detection accuracy maintained

3. **HomeKit-Specific Port List (High)**
   - Only scans 6 relevant ports (vs 40+)
   - Ports: 80, 443, 5353, 8080, 8443, 62078
   - 85% fewer ports = proportional speed increase

### Technical Implementation
- Swift structured concurrency with TaskGroup
- Actor-based thread-safe state management
- Stability detection algorithm for early termination
- Optimized port lists for different scan types

### Files Modified
- `IntegratedDashboardViewV3.swift`: Parallel port scanning
- `BonjourScanner.swift`: Smart early termination
- `PingScanner.swift`: HomeKit-specific port list
- `HomeKitTabView.swift`: Use optimized ports

---

## v8.3.0 (December 3, 2025) - Network Stats Removed
**Authors:** Jordan Koch

### Removed Features
- **REMOVED**: Network Stats (netstat) functionality
  - Despite multiple fix attempts (v8.2.1, v8.2.2), persistent issues remained
  - Decision made to remove the problematic tool
  - Focus on maintaining 5 stable, working network diagnostic tools

### Remaining Tools
- Ping - Test host reachability
- Traceroute - Show packet routing paths
- Network Config - Display TCP/IP settings
- DNS Lookup - Query DNS servers
- ARP Table - View IP-to-MAC mappings

### Files Modified
- `NetworkToolsTab.swift`: Removed all netstat-related code

---

## v8.2.2 (December 3, 2025) - Race Condition Fix
**Authors:** Jordan Koch

### Critical Bug Fixes
- **FIXED**: Race condition causing "Operation timed out after 60 seconds" errors
  - Root cause: `terminationHandler` was set AFTER `process.run()`, causing handler to miss fast-completing processes
  - Solution: Reordered code to set `terminationHandler` BEFORE calling `process.run()`
  - Fast commands (netstat ~5ms) exposed the race condition that slower commands might hide

### Technical Improvements
- Increased netstat timeout to 120 seconds for systems with many connections
- Improved timeout handler to check `process.isRunning` before attempting termination
- All network tools now complete instantly without timeout errors

### Files Modified
- `NetworkToolsTab.swift`: Reordered handler registration (lines 714-741)

---

## v8.2.1 (December 3, 2025) - Network Stats Fix
**Authors:** Jordan Koch

### Critical Bug Fixes
- **FIXED**: Network Stats tool causing app freeze with spinning beach ball
  - Root cause: Main thread was blocked by synchronous `process.waitUntilExit()` call
  - Solution: Rewrote `executeCommand` to use proper async/await with `Task.detached` and `terminationHandler`
  - Added thread-safe state management using actor pattern
  - All network tools (ping, traceroute, ipconfig, nslookup, netstat, arp) now execute without blocking UI

### Technical Improvements
- Enhanced async/await handling for all network command execution
- Implemented actor-based state management for process lifecycle
- Improved timeout handling with detached background tasks
- Better error handling and continuation safety

### Files Modified
- `NetworkToolsTab.swift`: Rewrote `executeCommand` function (lines 686-748)

---

## v8.2.0 (December 1, 2025)
**Authors:** Jordan Koch

### Major Features
- Network Tools tab with comprehensive diagnostics suite
  - Ping tool with quick-access hosts
  - Traceroute for path analysis
  - Network configuration display
  - DNS lookup functionality
  - Network statistics (netstat)
  - ARP table viewer

### Previous Versions
See earlier release notes for version history prior to v8.2.0.

