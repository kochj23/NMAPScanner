//
//  IntegratedDashboardViewV3.swift
//  NMAP Plus Security Scanner - Enhanced Dashboard with Ping Scanning
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import SwiftUI
import Network

struct IntegratedDashboardViewV3: View {
    @StateObject private var scanner = IntegratedScannerV3()
    @StateObject private var threatAnalyzer = ThreatAnalyzer()
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var searchFilterManager = SearchFilterManager.shared

    @State private var showingThreatDashboard = false
    @State private var showingDeviceThreats = false
    @State private var showingSettings = false
    @State private var showingNotifications = false
    @State private var showingExport = false
    @State private var showingPresets = false
    @State private var selectedDevice: EnhancedDevice?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header with Notification Bell and Settings Button
                    HStack {
                        Text("NMAP Plus Security Scanner")
                            .font(.system(size: 50, weight: .bold))

                        Spacer()

                        // Notification Bell
                        Button(action: {
                            showingNotifications = true
                        }) {
                            ZStack {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)

                                if notificationManager.unreadCount > 0 {
                                    Text("\(notificationManager.unreadCount)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 15, y: -15)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // Settings Button
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    // Scanning Status
                    if scanner.isScanning {
                        ScanningStatusCardV3(scanner: scanner)
                    }

                    // Network Threat Summary (if scan complete)
                    if let summary = threatAnalyzer.networkSummary {
                        Button(action: {
                            showingThreatDashboard = true
                        }) {
                            NetworkThreatSummaryCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Device Threats Summary
                    if !threatAnalyzer.deviceSummaries.isEmpty {
                        Button(action: {
                            showingDeviceThreats = true
                        }) {
                            DeviceThreatsSummaryCard(summaries: threatAnalyzer.deviceSummaries)
                        }
                        .buttonStyle(.plain)
                    }

                    // What's New Widget (Historical Changes)
                    if !scanner.devices.isEmpty {
                        WhatsNewWidget()
                    }

                    // Search and Filter
                    if !scanner.devices.isEmpty {
                        SearchAndFilterView(devices: .constant(scanner.devices))
                    }

                    // Discovered Devices List
                    if !scanner.devices.isEmpty {
                        let filteredDevices = searchFilterManager.filter(scanner.devices)
                        DiscoveredDevicesList(
                            devices: filteredDevices,
                            threatAnalyzer: threatAnalyzer,
                            selectedDevice: $selectedDevice
                        )
                    }

                    // Action Buttons
                    if !scanner.isScanning {
                        HStack(spacing: 20) {
                            // Rescan Button (Ping + Port Scan)
                            Button(action: {
                                Task {
                                    await scanner.startFullScan()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.system(size: 32))
                                    Text("Full Rescan")
                                        .font(.system(size: 28, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)

                            // Quick Scan Button (Ping Only)
                            Button(action: {
                                Task {
                                    await scanner.startQuickScan()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "bolt.circle.fill")
                                        .font(.system(size: 32))
                                    Text("Quick Scan")
                                        .font(.system(size: 28, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }

                        // Deep Scan Button (selected devices only)
                        if !scanner.devices.isEmpty {
                            Button(action: {
                                Task {
                                    await scanner.startDeepScan()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.system(size: 32))
                                    Text("Deep Scan (\(scanner.devices.count) devices)")
                                        .font(.system(size: 28, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }

                        // Additional Action Buttons
                        if !scanner.devices.isEmpty {
                            HStack(spacing: 20) {
                                // Export Results Button
                                Button(action: {
                                    showingExport = true
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up.fill")
                                            .font(.system(size: 32))
                                        Text("Export Results")
                                            .font(.system(size: 28, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)

                                // Scan Presets Button
                                Button(action: {
                                    showingPresets = true
                                }) {
                                    HStack {
                                        Image(systemName: "list.bullet.circle.fill")
                                            .font(.system(size: 32))
                                        Text("Scan Presets")
                                            .font(.system(size: 28, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(40)
            }
            .navigationTitle("Security Analysis")
        }
        .sheet(isPresented: $showingThreatDashboard) {
            if let summary = threatAnalyzer.networkSummary {
                NetworkThreatDashboard(summary: summary)
            }
        }
        .sheet(isPresented: $showingDeviceThreats) {
            DeviceThreatsListView(
                summaries: threatAnalyzer.deviceSummaries,
                selectedDevice: $selectedDevice
            )
        }
        .sheet(item: $selectedDevice) { device in
            // Find the rogue device threat if this is a rogue device
            let rogueThreat = device.isRogue ? threatAnalyzer.allThreats.first {
                $0.isRogueDevice && $0.affectedHost == device.ipAddress
            } : nil
            EnhancedDeviceDetailView(device: device, rogueThreat: rogueThreat)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationCenterView()
        }
        .sheet(isPresented: $showingExport) {
            ExportView(devices: scanner.devices, threats: threatAnalyzer.allThreats)
        }
        .sheet(isPresented: $showingPresets) {
            PresetSelectionView { preset in
                // Handle preset selection - would need to extend scanner to support custom port lists
                showingPresets = false
                NotificationManager.shared.showNotification(
                    .systemAlert,
                    title: "Preset Selected",
                    message: "Selected preset: \(preset.name)"
                )
            }
        }
        .task {
            // Auto-scan on launch if enabled
            if persistenceManager.settings.enableAutomaticScanning && !scanner.hasScanned {
                await scanner.startQuickScan()
            }
        }
        .onChange(of: scanner.devices) { _ in
            // Analyze threats when devices change
            threatAnalyzer.analyzeNetwork(devices: scanner.devices)
        }
    }
}

// MARK: - Scanning Status Card V3

struct ScanningStatusCardV3: View {
    @ObservedObject var scanner: IntegratedScannerV3

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ProgressView()
                    .scaleEffect(1.5)
                Text(scanner.scanPhase)
                    .font(.system(size: 36, weight: .semibold))
            }

            ProgressView(value: scanner.progress)
                .scaleEffect(y: 4)

            Text(scanner.status)
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            HStack(spacing: 40) {
                StatItem(label: "Hosts Scanned", value: "\(scanner.scannedHosts)/254")
                StatItem(label: "Alive", value: "\(scanner.hostsAlive)")
                StatItem(label: "Devices Found", value: "\(scanner.devices.count)")
                StatItem(label: "Threats", value: "\(scanner.threatsDetected)")
            }
        }
        .padding(30)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Integrated Scanner V3

@MainActor
class IntegratedScannerV3: ObservableObject {
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var scanPhase = ""
    @Published var devices: [EnhancedDevice] = []
    @Published var scannedHosts = 0
    @Published var hostsAlive = 0
    @Published var threatsDetected = 0

    private let pingScanner = PingScanner()
    private let portScanner = PortScanner()
    private let arpScanner = ARPScanner()
    private let persistenceManager = DevicePersistenceManager.shared
    private let historicalTracker = HistoricalTracker.shared

    /// Quick scan - ping only to find alive hosts
    func startQuickScan() async {
        isScanning = true
        scanPhase = "Quick Scan"
        progress = 0
        status = "Starting quick ping scan..."
        devices = []
        scannedHosts = 0
        hostsAlive = 0
        threatsDetected = 0

        let subnet = detectSubnet()
        status = "Pinging subnet \(subnet).0/24..."

        // Ping scan
        let aliveHosts = await pingScanner.pingSubnet(subnet)
        hostsAlive = aliveHosts.count
        scannedHosts = 254

        // Get MAC addresses from ARP table
        status = "Gathering MAC addresses..."
        let macAddresses = await arpScanner.getMACAddresses(for: Array(aliveHosts))

        // Create basic devices (no port info yet)
        for host in sortIPAddresses(Array(aliveHosts)) {
            let device = createBasicDevice(host: host, macAddress: macAddresses[host])
            devices.append(device)

            // Update persistence
            persistenceManager.addOrUpdateDevice(device)
        }

        // Update network history
        persistenceManager.addOrUpdateNetwork(subnet: subnet, deviceCount: devices.count)

        // Sort devices by IP address
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        status = "Quick scan complete - \(devices.count) devices found"
        progress = 1.0
        isScanning = false
        hasScanned = true

        // Send notification
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: 0)
    }

    /// Full scan - ping + port scan on all alive hosts
    func startFullScan() async {
        isScanning = true
        scanPhase = "Full Scan"
        progress = 0
        status = "Starting full network scan..."
        devices = []
        scannedHosts = 0
        hostsAlive = 0
        threatsDetected = 0

        let subnet = detectSubnet()

        // Phase 1: Ping scan
        status = "Phase 1: Pinging subnet \(subnet).0/24..."
        let aliveHosts = await pingScanner.pingSubnet(subnet)
        hostsAlive = aliveHosts.count
        scannedHosts = 254
        progress = 0.3 // 30% done after ping

        if aliveHosts.isEmpty {
            status = "No hosts found"
            isScanning = false
            hasScanned = true
            return
        }

        // Phase 2: Get MAC addresses
        status = "Phase 2: Gathering MAC addresses..."
        let macAddresses = await arpScanner.getMACAddresses(for: Array(aliveHosts))
        progress = 0.4 // 40% done after MAC collection

        // Phase 3: Port scan
        scanPhase = "Port Scanning"
        status = "Phase 3: Scanning ports on \(aliveHosts.count) hosts..."

        let sortedHosts = sortIPAddresses(Array(aliveHosts))
        for (index, host) in sortedHosts.enumerated() {
            progress = 0.4 + (Double(index + 1) / Double(sortedHosts.count) * 0.6) // 40-100%
            status = "Scanning \(host) (\(index + 1)/\(sortedHosts.count))..."

            let openPorts = await portScanner.scanPorts(host: host, ports: CommonPorts.standard)

            if !openPorts.isEmpty {
                let device = createEnhancedDevice(host: host, openPorts: openPorts, macAddress: macAddresses[host])
                devices.append(device)

                // Update persistence
                persistenceManager.addOrUpdateDevice(device)
            }

            // Small delay
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        }

        // Update network history
        persistenceManager.addOrUpdateNetwork(subnet: subnet, deviceCount: devices.count)

        // Sort devices by IP address
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        // Analyze and record changes for historical tracking
        historicalTracker.analyzeAndRecordChanges(devices: devices)

        status = "Full scan complete - \(devices.count) devices with open ports"
        progress = 1.0
        isScanning = false
        hasScanned = true

        // Send notification
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: threatsDetected)
    }

    /// Deep scan - comprehensive port scan on current devices
    func startDeepScan() async {
        isScanning = true
        scanPhase = "Deep Scan"
        progress = 0
        status = "Starting deep port scan..."

        let hostsToScan = devices.map { $0.ipAddress }

        for (index, host) in hostsToScan.enumerated() {
            progress = Double(index + 1) / Double(hostsToScan.count)
            status = "Deep scanning \(host) (\(index + 1)/\(hostsToScan.count))..."

            let openPorts = await portScanner.scanPorts(host: host, ports: CommonPorts.full)

            // Update device with new port info
            if let deviceIndex = devices.firstIndex(where: { $0.ipAddress == host }) {
                let updatedDevice = createEnhancedDevice(host: host, openPorts: openPorts, existingDevice: devices[deviceIndex])
                devices[deviceIndex] = updatedDevice

                // Update persistence
                persistenceManager.addOrUpdateDevice(updatedDevice)
            }
        }

        // Sort devices by IP address
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        // Analyze and record changes for historical tracking
        historicalTracker.analyzeAndRecordChanges(devices: devices)

        status = "Deep scan complete"
        progress = 1.0
        isScanning = false

        // Send notification
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: threatsDetected)
    }

    // MARK: - Helper Methods

    private func detectSubnet() -> String {
        // In production, would detect actual local network
        // For now, return common subnet
        return "192.168.1"
    }

    /// Sort IP addresses numerically (e.g., 192.168.1.1, 192.168.1.2, 192.168.1.200)
    private func sortIPAddresses(_ addresses: [String]) -> [String] {
        return addresses.sorted { ip1, ip2 in
            let parts1 = ip1.split(separator: ".").compactMap { Int($0) }
            let parts2 = ip2.split(separator: ".").compactMap { Int($0) }

            // Compare each octet numerically
            for i in 0..<min(parts1.count, parts2.count) {
                if parts1[i] != parts2[i] {
                    return parts1[i] < parts2[i]
                }
            }

            // If all octets are equal, shorter address comes first
            return parts1.count < parts2.count
        }
    }

    private func createBasicDevice(host: String, macAddress: String? = nil) -> EnhancedDevice {
        // Resolve DNS hostname
        let hostname = resolveHostname(for: host)

        // Get manufacturer from MAC address
        let manufacturer = getManufacturer(from: macAddress)

        let persistedFirstSeen = persistenceManager.getFirstSeen(for: EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: .unknown,
            openPorts: [],
            isOnline: true,
            firstSeen: Date(),
            lastSeen: Date(),
            isKnownDevice: false,
            operatingSystem: nil,
            deviceName: nil
        )) ?? Date()

        let isKnown = persistenceManager.isDeviceKnown(EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: .unknown,
            openPorts: [],
            isOnline: true,
            firstSeen: persistedFirstSeen,
            lastSeen: Date(),
            isKnownDevice: false,
            operatingSystem: nil,
            deviceName: nil
        ))

        return EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: .unknown,
            openPorts: [],
            isOnline: true,
            firstSeen: persistedFirstSeen,
            lastSeen: Date(),
            isKnownDevice: isKnown,
            operatingSystem: nil,
            deviceName: nil
        )
    }

    private func createEnhancedDevice(host: String, openPorts: [PortInfo], macAddress: String? = nil, existingDevice: EnhancedDevice? = nil) -> EnhancedDevice {
        // Resolve DNS hostname (or use existing if available)
        let hostname = existingDevice?.hostname ?? resolveHostname(for: host)

        // Detect manufacturer from MAC address
        // ManufacturerDatabase not yet implemented - return nil for now
        let manufacturer: String? = nil // macAddress != nil ? ManufacturerDatabase.shared.getManufacturer(for: macAddress!) : nil

        let firstSeen = existingDevice?.firstSeen ?? persistenceManager.getFirstSeen(for: EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: .unknown,
            openPorts: [],
            isOnline: true,
            firstSeen: Date(),
            lastSeen: Date(),
            isKnownDevice: false,
            operatingSystem: nil,
            deviceName: nil
        )) ?? Date()

        let tempDevice = EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: detectDeviceType(openPorts: openPorts),
            openPorts: openPorts,
            isOnline: true,
            firstSeen: firstSeen,
            lastSeen: Date(),
            isKnownDevice: false,
            operatingSystem: nil,
            deviceName: nil
        )

        let isKnown = persistenceManager.isDeviceKnown(tempDevice)

        return EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: detectDeviceType(openPorts: openPorts),
            openPorts: openPorts,
            isOnline: true,
            firstSeen: firstSeen,
            lastSeen: Date(),
            isKnownDevice: isKnown,
            operatingSystem: nil,
            deviceName: nil
        )
    }

    private func detectDeviceType(openPorts: [PortInfo]) -> EnhancedDevice.DeviceType {
        let ports = Set(openPorts.map { $0.port })

        if ports.intersection([53, 67, 68]).count > 0 { return .router }
        if ports.intersection([3306, 5432, 1433, 27017]).count > 0 { return .server }
        if ports.intersection([631, 9100]).count > 0 { return .printer }
        if ports.intersection([1883, 8883]).count > 0 { return .iot }
        if ports.intersection([139, 445, 548]).count > 0 { return .computer }

        return .unknown
    }

    /// Resolve DNS hostname for an IP address
    private func resolveHostname(for ipAddress: String) -> String? {
        var hostname: String?

        let semaphore = DispatchSemaphore(value: 0)

        // Create a dispatch queue for the DNS lookup
        DispatchQueue.global(qos: .utility).async {
            var hints = addrinfo()
            hints.ai_family = AF_INET  // IPv4
            hints.ai_socktype = SOCK_STREAM
            hints.ai_flags = AI_NUMERICHOST

            var result: UnsafeMutablePointer<addrinfo>?

            // Convert IP string to address
            guard getaddrinfo(ipAddress, nil, &hints, &result) == 0 else {
                semaphore.signal()
                return
            }

            defer {
                if let result = result {
                    freeaddrinfo(result)
                }
            }

            // Get hostname from address
            if let addr = result?.pointee.ai_addr {
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                if getnameinfo(addr, socklen_t(result!.pointee.ai_addrlen),
                              &hostBuffer, socklen_t(hostBuffer.count),
                              nil, 0, NI_NAMEREQD) == 0 {
                    hostname = String(cString: hostBuffer)
                }
            }

            semaphore.signal()
        }

        // Wait up to 2 seconds for DNS resolution
        _ = semaphore.wait(timeout: .now() + 2)

        return hostname
    }

    /// Get MAC address vendor/manufacturer from first 3 octets (OUI)
    private func getManufacturer(from macAddress: String?) -> String? {
        guard let mac = macAddress else { return nil }

        // Extract OUI (first 3 octets)
        let components = mac.components(separatedBy: ":")
        guard components.count >= 3 else { return nil }

        let oui = components[0...2].joined(separator: ":").uppercased()

        // Common OUI to manufacturer mappings
        let ouiDatabase: [String: String] = [
            "00:50:56": "VMware",
            "00:0C:29": "VMware",
            "00:1C:42": "VMware",
            "08:00:27": "Oracle VirtualBox",
            "52:54:00": "QEMU/KVM",
            "00:15:5D": "Microsoft Hyper-V",
            "00:03:FF": "Microsoft",
            "00:0D:3A": "Microsoft",
            "00:12:5A": "Microsoft",
            "00:17:FA": "Microsoft",
            "00:1D:D8": "Microsoft",
            "00:25:AE": "Microsoft",
            "28:18:78": "Microsoft",
            "7C:1E:52": "Microsoft",
            "00:10:18": "Broadcom",
            "00:14:22": "Dell",
            "00:1E:C9": "Dell",
            "D4:AE:52": "Dell",
            "F0:1F:AF": "Dell",
            "00:0A:95": "Apple",
            "00:14:51": "Apple",
            "00:16:CB": "Apple",
            "00:17:F2": "Apple",
            "00:19:E3": "Apple",
            "00:1B:63": "Apple",
            "00:1C:B3": "Apple",
            "00:1D:4F": "Apple",
            "00:1E:52": "Apple",
            "00:1E:C2": "Apple",
            "00:1F:5B": "Apple",
            "00:1F:F3": "Apple",
            "00:21:E9": "Apple",
            "00:22:41": "Apple",
            "00:23:12": "Apple",
            "00:23:32": "Apple",
            "00:23:6C": "Apple",
            "00:23:DF": "Apple",
            "00:24:36": "Apple",
            "00:25:00": "Apple",
            "00:25:4B": "Apple",
            "00:25:BC": "Apple",
            "00:26:08": "Apple",
            "00:26:4A": "Apple",
            "00:26:B0": "Apple",
            "00:26:BB": "Apple",
            "04:0C:CE": "Apple",
            "04:15:52": "Apple",
            "04:26:65": "Apple",
            "04:D3:CF": "Apple",
            "04:DB:56": "Apple",
            "04:E5:36": "Apple",
            "04:F1:3E": "Apple",
            "04:F7:E4": "Apple",
            "08:66:98": "Apple",
            "08:6D:41": "Apple",
            "08:70:45": "Apple",
            "08:74:02": "Apple",
            "10:40:F3": "Apple",
            "10:93:E9": "Apple",
            "10:9A:DD": "Apple",
            "10:DD:B1": "Apple",
            "14:10:9F": "Apple",
            "14:8F:C6": "Apple",
            "18:34:51": "Apple",
            "18:3D:A2": "Apple",
            "18:AF:61": "Apple",
            "18:E7:F4": "Apple",
            "1C:1A:C0": "Apple",
            "1C:36:BB": "Apple",
            "1C:AB:A7": "Apple",
            "20:3C:AE": "Apple",
            "20:7D:74": "Apple",
            "20:AB:37": "Apple",
            "20:C9:D0": "Apple",
            "24:A0:74": "Apple",
            "24:AB:81": "Apple",
            "28:37:37": "Apple",
            "28:6A:B8": "Apple",
            "28:A0:2B": "Apple",
            "28:CF:DA": "Apple",
            "28:E1:4C": "Apple",
            "28:ED:6A": "Apple",
            "2C:F0:A2": "Apple",
            "2C:F0:EE": "Apple",
            "30:07:4D": "Apple",
            "30:90:AB": "Apple",
            "30:F7:C5": "Apple",
            "34:12:F9": "Apple",
            "34:15:9E": "Apple",
            "34:36:3B": "Apple",
            "34:A3:95": "Apple",
            "34:C0:59": "Apple",
            "38:0F:4A": "Apple",
            "38:48:4C": "Apple",
            "38:B5:4D": "Apple",
            "38:C9:86": "Apple",
            "3C:15:C2": "Apple",
            "3C:2E:F9": "Apple",
            "40:30:04": "Apple",
            "40:33:1A": "Apple",
            "40:3C:FC": "Apple",
            "40:4D:7F": "Apple",
            "40:6C:8F": "Apple",
            "40:A6:D9": "Apple",
            "40:B3:95": "Apple",
            "40:CB:C0": "Apple",
            "40:D3:2D": "Apple",
            "44:2A:60": "Apple",
            "44:4C:0C": "Apple",
            "44:D8:84": "Apple",
            "44:FB:42": "Apple",
            "48:43:7C": "Apple",
            "48:60:BC": "Apple",
            "48:74:6E": "Apple",
            "48:A1:95": "Apple",
            "48:BF:6B": "Apple",
            "48:D7:05": "Apple",
            "4C:32:75": "Apple",
            "4C:57:CA": "Apple",
            "4C:7C:5F": "Apple",
            "4C:8D:79": "Apple",
            "50:32:37": "Apple",
            "50:7A:55": "Apple",
            "50:EA:D6": "Apple",
            "54:26:96": "Apple",
            "54:4E:90": "Apple",
            "54:72:4F": "Apple",
            "54:9F:13": "Apple",
            "54:AE:27": "Apple",
            "54:E4:3A": "Apple",
            "58:1F:AA": "Apple",
            "58:55:CA": "Apple",
            "58:B0:35": "Apple",
            "58:E2:8F": "Apple",
            "5C:59:48": "Apple",
            "5C:95:AE": "Apple",
            "5C:96:9D": "Apple",
            "5C:F9:38": "Apple",
            "60:33:4B": "Apple",
            "60:69:44": "Apple",
            "60:92:17": "Apple",
            "60:C5:47": "Apple",
            "60:F8:1D": "Apple",
            "60:FA:CD": "Apple",
            "60:FB:42": "Apple",
            "64:20:0C": "Apple",
            "64:76:BA": "Apple",
            "64:9A:BE": "Apple",
            "64:A3:CB": "Apple",
            "64:B0:A6": "Apple",
            "64:E6:82": "Apple",
            "68:5B:35": "Apple",
            "68:96:7B": "Apple",
            "68:9C:70": "Apple",
            "68:A8:6D": "Apple",
            "68:D9:3C": "Apple",
            "68:DB:F5": "Apple",
            "68:FE:F7": "Apple",
            "6C:19:C0": "Apple",
            "6C:3E:6D": "Apple",
            "6C:40:08": "Apple",
            "6C:72:E7": "Apple",
            "6C:94:66": "Apple",
            "6C:96:CF": "Apple",
            "6C:AB:31": "Apple",
            "6C:C2:6B": "Apple",
            "70:11:24": "Apple",
            "70:3E:AC": "Apple",
            "70:48:0F": "Apple",
            "70:56:81": "Apple",
            "70:73:CB": "Apple",
            "70:CD:60": "Apple",
            "70:DE:E2": "Apple",
            "70:EC:E4": "Apple",
            "74:1B:B2": "Apple",
            "74:E1:B6": "Apple",
            "74:E2:F5": "Apple",
            "78:31:C1": "Apple",
            "78:67:D7": "Apple",
            "78:7B:8A": "Apple",
            "78:A3:E4": "Apple",
            "78:CA:39": "Apple",
            "78:D7:5F": "Apple",
            "78:FD:94": "Apple",
            "7C:01:91": "Apple",
            "7C:04:D0": "Apple",
            "7C:11:BE": "Apple",
            "7C:50:49": "Apple",
            "7C:6D:62": "Apple",
            "7C:C3:A1": "Apple",
            "7C:D1:C3": "Apple",
            "7C:F0:5F": "Apple",
            "80:49:71": "Apple",
            "80:92:9F": "Apple",
            "80:B0:3D": "Apple",
            "80:E6:50": "Apple",
            "84:29:99": "Apple",
            "84:38:35": "Apple",
            "84:85:06": "Apple",
            "84:89:AD": "Apple",
            "84:8E:0C": "Apple",
            "84:FC:FE": "Apple",
            "88:1F:A1": "Apple",
            "88:53:95": "Apple",
            "88:63:DF": "Apple",
            "88:66:39": "Apple",
            "88:6B:6E": "Apple",
            "88:C6:63": "Apple",
            "88:CB:87": "Apple",
            "88:E8:7F": "Apple",
            "8C:00:6D": "Apple",
            "8C:29:37": "Apple",
            "8C:2D:AA": "Apple",
            "8C:58:77": "Apple",
            "8C:7C:92": "Apple",
            "8C:85:80": "Apple",
            "8C:8E:F2": "Apple",
            "90:27:E4": "Apple",
            "90:72:40": "Apple",
            "90:84:0D": "Apple",
            "90:8D:6C": "Apple",
            "90:B0:ED": "Apple",
            "90:B2:1F": "Apple",
            "90:B9:31": "Apple",
            "94:E9:6A": "Apple",
            "98:03:D8": "Apple",
            "98:5A:EB": "Apple",
            "98:B8:E3": "Apple",
            "98:CA:33": "Apple",
            "98:D6:BB": "Apple",
            "98:E0:D9": "Apple",
            "98:F0:AB": "Apple",
            "98:FE:94": "Apple",
            "9C:04:EB": "Apple",
            "9C:20:7B": "Apple",
            "9C:29:76": "Apple",
            "9C:35:EB": "Apple",
            "9C:84:BF": "Apple",
            "9C:FC:E8": "Apple",
            "A0:18:28": "Apple",
            "A0:3B:E3": "Apple",
            "A0:4E:A7": "Apple",
            "A0:99:9B": "Apple",
            "A0:D7:95": "Apple",
            "A0:ED:CD": "Apple",
            "A4:5E:60": "Apple",
            "A4:67:06": "Apple",
            "A4:83:E7": "Apple",
            "A4:B1:97": "Apple",
            "A4:C3:61": "Apple",
            "A4:D1:8C": "Apple",
            "A4:D1:D2": "Apple",
            "A4:F1:E8": "Apple",
            "A8:20:66": "Apple",
            "A8:5B:78": "Apple",
            "A8:66:7F": "Apple",
            "A8:86:DD": "Apple",
            "A8:96:8A": "Apple",
            "A8:BB:CF": "Apple",
            "A8:FA:D8": "Apple",
            "AC:1F:74": "Apple",
            "AC:29:3A": "Apple",
            "AC:3C:0B": "Apple",
            "AC:61:EA": "Apple",
            "AC:87:A3": "Apple",
            "AC:BC:32": "Apple",
            "AC:CF:5C": "Apple",
            "AC:E4:B5": "Apple",
            "AC:FD:EC": "Apple",
            "B0:34:95": "Apple",
            "B0:65:BD": "Apple",
            "B0:CA:68": "Apple",
            "B4:18:D1": "Apple",
            "B4:8B:19": "Apple",
            "B4:F0:AB": "Apple",
            "B4:F6:1C": "Apple",
            "B8:09:8A": "Apple",
            "B8:17:C2": "Apple",
            "B8:41:A4": "Apple",
            "B8:5D:0A": "Apple",
            "B8:63:4D": "Apple",
            "B8:78:2E": "Apple",
            "B8:C1:11": "Apple",
            "B8:C7:5D": "Apple",
            "B8:E8:56": "Apple",
            "B8:F6:B1": "Apple",
            "B8:FF:61": "Apple",
            "BC:3B:AF": "Apple",
            "BC:52:B7": "Apple",
            "BC:6C:21": "Apple",
            "BC:92:6B": "Apple",
            "BC:9F:EF": "Apple",
            "BC:A9:20": "Apple",
            "BC:D0:74": "Apple",
            "BC:EC:5D": "Apple",
            "C0:63:94": "Apple",
            "C0:84:7D": "Apple",
            "C0:9F:42": "Apple",
            "C0:B6:58": "Apple",
            "C0:CE:CD": "Apple",
            "C0:D0:12": "Apple",
            "C4:2C:03": "Apple",
            "C4:61:8B": "Apple",
            "C4:B3:01": "Apple",
            "C8:2A:14": "Apple",
            "C8:33:4B": "Apple",
            "C8:69:CD": "Apple",
            "C8:6F:1D": "Apple",
            "C8:85:50": "Apple",
            "C8:B5:AD": "Apple",
            "C8:BC:C8": "Apple",
            "C8:D0:83": "Apple",
            "CC:08:E0": "Apple",
            "CC:20:E8": "Apple",
            "CC:25:EF": "Apple",
            "CC:29:F5": "Apple",
            "CC:2D:21": "Apple",
            "CC:2D:8C": "Apple",
            "CC:44:63": "Apple",
            "CC:78:5F": "Apple",
            "D0:03:4B": "Apple",
            "D0:23:DB": "Apple",
            "D0:25:98": "Apple",
            "D0:33:11": "Apple",
            "D0:4F:7E": "Apple",
            "D0:81:7A": "Apple",
            "D0:A6:37": "Apple",
            "D0:C5:F3": "Apple",
            "D0:D2:B0": "Apple",
            "D0:E1:40": "Apple",
            "D4:61:DA": "Apple",
            "D4:90:9C": "Apple",
            "D4:9A:20": "Apple",
            "D4:A3:3D": "Apple",
            "D4:DC:CD": "Apple",
            "D4:F4:6F": "Apple",
            "D8:00:4D": "Apple",
            "D8:1C:79": "Apple",
            "D8:30:62": "Apple",
            "D8:96:95": "Apple",
            "D8:A2:5E": "Apple",
            "D8:BB:2C": "Apple",
            "D8:CF:9C": "Apple",
            "D8:D1:CB": "Apple",
            "DC:2B:2A": "Apple",
            "DC:2B:61": "Apple",
            "DC:37:39": "Apple",
            "DC:3F:B3": "Apple",
            "DC:41:E4": "Apple",
            "DC:56:E7": "Apple",
            "DC:86:D8": "Apple",
            "DC:9B:9C": "Apple",
            "DC:A4:CA": "Apple",
            "DC:A9:04": "Apple",
            "DC:D3:A2": "Apple",
            "DC:E5:5B": "Apple",
            "E0:33:8E": "Apple",
            "E0:66:78": "Apple",
            "E0:AC:CB": "Apple",
            "E0:B5:2D": "Apple",
            "E0:B9:A5": "Apple",
            "E0:C7:67": "Apple",
            "E0:C9:7A": "Apple",
            "E0:F5:C6": "Apple",
            "E0:F8:47": "Apple",
            "E4:25:E7": "Apple",
            "E4:8B:7F": "Apple",
            "E4:9A:79": "Apple",
            "E4:C6:3D": "Apple",
            "E4:CE:8F": "Apple",
            "E8:04:0B": "Apple",
            "E8:06:88": "Apple",
            "E8:2A:EA": "Apple",
            "E8:80:2E": "Apple",
            "E8:8D:28": "Apple",
            "E8:B2:AC": "Apple",
            "EC:35:86": "Apple",
            "EC:85:2F": "Apple",
            "F0:18:98": "Apple",
            "F0:24:75": "Apple",
            "F0:2F:74": "Apple",
            "F0:98:9D": "Apple",
            "F0:99:BF": "Apple",
            "F0:9F:C2": "Apple",
            "F0:B0:79": "Apple",
            "F0:B4:79": "Apple",
            "F0:CB:A1": "Apple",
            "F0:D1:A9": "Apple",
            "F0:DB:E2": "Apple",
            "F0:DC:E2": "Apple",
            "F0:F6:1C": "Apple",
            "F4:0F:24": "Apple",
            "F4:1B:A1": "Apple",
            "F4:31:C3": "Apple",
            "F4:37:B7": "Apple",
            "F4:5C:89": "Apple",
            "F4:F1:5A": "Apple",
            "F4:F9:51": "Apple",
            "F8:1E:DF": "Apple",
            "F8:27:93": "Apple",
            "F8:2D:7C": "Apple",
            "F8:95:C7": "Apple",
            "FC:18:3C": "Apple",
            "FC:25:3F": "Apple",
            "FC:E9:98": "Apple",
            "FC:FC:48": "Apple",
            "00:1B:21": "Intel",
            "00:1E:67": "Intel",
            "00:50:F2": "Intel",
            "24:0A:64": "Intel",
            "00:19:D2": "Intel",
            "00:1C:C0": "Intel",
            "00:21:6A": "Intel",
            "00:23:15": "Intel",
            "00:24:D6": "Intel",
            "00:24:D7": "Intel",
            "00:27:0E": "Intel",
            "30:3A:64": "Intel",
            "3C:A9:F4": "Intel",
            "78:84:3C": "Intel",
            "7C:7A:91": "Intel",
            "AC:D1:B8": "Intel",
            "B4:B6:76": "Intel",
            "C8:F7:33": "Intel",
            "D4:BE:D9": "Intel",
            "00:23:AE": "HP",
            "00:26:55": "HP",
            "44:1E:A1": "HP",
            "68:B5:99": "HP",
            "6C:C2:17": "HP",
            "9C:8E:99": "HP",
            "B8:AF:67": "HP",
            "D4:85:64": "HP",
            "EC:B1:D7": "HP",
            "F0:92:1C": "HP",
            "F4:CE:46": "HP",
            "00:1B:44": "Cisco",
            "00:1C:0E": "Cisco",
            "00:1D:70": "Cisco",
            "00:1E:14": "Cisco",
            "00:26:99": "Cisco",
            "00:90:0C": "Cisco",
            "00:D0:06": "Cisco",
            "0C:27:24": "Cisco",
            "14:7D:C5": "Cisco",
            "30:37:A6": "Cisco",
            "34:BD:FA": "Cisco",
            "84:78:AC": "Cisco",
            "F0:7F:06": "Cisco",
            "00:18:19": "Netgear",
            "00:1B:2F": "Netgear",
            "00:1E:2A": "Netgear",
            "00:22:3F": "Netgear",
            "00:24:B2": "Netgear",
            "00:26:F2": "Netgear",
            "20:E5:2A": "Netgear",
            "28:C6:8E": "Netgear",
            "30:46:9A": "Netgear",
            "4C:60:DE": "Netgear",
            "74:44:01": "Netgear",
            "A0:21:B7": "Netgear",
            "A0:63:91": "Netgear",
            "C0:3F:0E": "Netgear",
            "E0:46:9A": "Netgear",
            "00:04:20": "Linksys",
            "00:06:25": "Linksys",
            "00:0C:41": "Linksys",
            "00:0E:08": "Linksys",
            "00:0F:66": "Linksys",
            "00:11:50": "Linksys",
            "00:12:17": "Linksys",
            "00:13:10": "Linksys",
            "00:14:BF": "Linksys",
            "00:16:B6": "Linksys",
            "00:18:39": "Linksys",
            "00:18:F8": "Linksys",
            "00:1A:70": "Linksys",
            "00:1C:10": "Linksys",
            "00:1D:7E": "Linksys",
            "00:1E:E5": "Linksys",
            "00:20:E0": "Linksys",
            "00:21:29": "Linksys",
            "00:22:6B": "Linksys",
            "00:23:69": "Linksys",
            "00:25:9C": "Linksys",
            "20:AA:4B": "Linksys",
            "58:6D:8F": "Linksys",
            "C0:56:27": "Linksys",
            "00:1A:A2": "TP-Link",
            "00:27:19": "TP-Link",
            "10:FE:ED": "TP-Link",
            "14:CF:92": "TP-Link",
            "18:A6:F7": "TP-Link",
            "1C:3B:F3": "TP-Link",
            "50:C7:BF": "TP-Link",
            "54:A0:50": "TP-Link",
            "60:E3:27": "TP-Link",
            "74:DA:38": "TP-Link",
            "7C:8B:CA": "TP-Link",
            "84:16:F9": "TP-Link",
            "88:D7:F6": "TP-Link",
            "90:F6:52": "TP-Link",
            "98:DE:D0": "TP-Link",
            "A0:F3:C1": "TP-Link",
            "B0:4E:26": "TP-Link",
            "B0:95:75": "TP-Link",
            "C0:06:C3": "TP-Link",
            "C4:71:54": "TP-Link",
            "D8:07:B6": "TP-Link",
            "E8:DE:27": "TP-Link",
            "EC:08:6B": "TP-Link",
            "F0:79:59": "TP-Link",
            "00:1F:C6": "D-Link",
            "00:22:B0": "D-Link",
            "00:26:5A": "D-Link",
            "14:D6:4D": "D-Link",
            "1C:7E:E5": "D-Link",
            "28:10:7B": "D-Link",
            "34:08:04": "D-Link",
            "50:46:5D": "D-Link",
            "74:90:50": "D-Link",
            "78:54:2E": "D-Link",
            "84:C9:B2": "D-Link",
            "A0:AB:1B": "D-Link",
            "B8:A3:86": "D-Link",
            "C8:BE:19": "D-Link",
            "CC:B2:55": "D-Link",
            "E4:6F:13": "D-Link",
            "E8:CC:18": "D-Link",
            "00:04:E2": "Samsung",
            "00:12:47": "Samsung",
            "00:12:FB": "Samsung",
            "00:13:77": "Samsung",
            "00:15:99": "Samsung",
            "00:16:32": "Samsung",
            "00:16:6B": "Samsung",
            "00:16:6C": "Samsung",
            "00:16:DB": "Samsung",
            "00:17:C9": "Samsung",
            "00:17:D5": "Samsung",
            "00:18:AF": "Samsung",
            "00:1A:8A": "Samsung",
            "00:1B:98": "Samsung",
            "00:1C:43": "Samsung",
            "00:1D:25": "Samsung",
            "00:1D:F6": "Samsung",
            "00:1E:7D": "Samsung",
            "00:1E:E1": "Samsung",
            "00:1E:E2": "Samsung",
            "00:1F:CD": "Samsung",
            "00:21:19": "Samsung",
            "00:21:4C": "Samsung",
            "00:21:D1": "Samsung",
            "00:21:D2": "Samsung",
            "00:23:39": "Samsung",
            "00:23:99": "Samsung",
            "00:23:C2": "Samsung",
            "00:23:D6": "Samsung",
            "00:23:D7": "Samsung",
            "00:24:54": "Samsung",
            "00:24:90": "Samsung",
            "00:24:91": "Samsung",
            "00:24:E9": "Samsung",
            "00:25:38": "Samsung",
            "00:25:66": "Samsung",
            "00:25:67": "Samsung",
            "00:26:37": "Samsung",
            "00:26:5D": "Samsung",
            "00:26:5F": "Samsung",
            "18:3F:47": "Samsung",
            "1C:5A:3E": "Samsung",
            "20:13:E0": "Samsung",
            "20:64:32": "Samsung",
            "20:D3:90": "Samsung",
            "24:4B:03": "Samsung",
            "28:39:5E": "Samsung",
            "28:57:BE": "Samsung",
            "28:BA:B5": "Samsung",
            "2C:44:01": "Samsung",
            "2C:44:FD": "Samsung",
            "30:19:66": "Samsung",
            "30:CD:A7": "Samsung",
            "34:23:BA": "Samsung",
            "34:AA:8B": "Samsung",
            "34:C7:31": "Samsung",
            "38:0A:94": "Samsung",
            "38:16:D1": "Samsung",
            "3C:5A:37": "Samsung",
            "3C:62:00": "Samsung",
            "3C:8B:FE": "Samsung",
            "3C:BD:D8": "Samsung",
            "40:0E:85": "Samsung",
            "40:1A:C6": "Samsung",
            "40:43:49": "Samsung",
            "40:4E:36": "Samsung",
            "40:5B:D8": "Samsung",
            "40:B0:FA": "Samsung",
            "44:4E:1A": "Samsung",
            "44:6D:57": "Samsung",
            "44:78:3E": "Samsung",
            "48:5A:3F": "Samsung",
            "48:DB:50": "Samsung",
            "4C:BC:A5": "Samsung",
            "4C:BC:98": "Samsung",
            "50:01:BB": "Samsung",
            "50:32:75": "Samsung",
            "50:55:27": "Samsung",
            "50:A7:2B": "Samsung",
            "50:B7:C3": "Samsung",
            "50:CC:F8": "Samsung",
            "54:92:BE": "Samsung",
            "54:B8:0A": "Samsung",
            "54:EF:B1": "Samsung",
            "58:67:1A": "Samsung",
            "58:91:CF": "Samsung",
            "58:A2:B5": "Samsung",
            "58:CB:52": "Samsung",
            "5C:0A:5B": "Samsung",
            "5C:0E:8B": "Samsung",
            "5C:3C:27": "Samsung",
            "5C:51:88": "Samsung",
            "5C:A3:9D": "Samsung",
            "5C:F8:21": "Samsung",
            "60:21:C0": "Samsung",
            "60:57:18": "Samsung",
            "60:6B:BD": "Samsung",
            "60:77:71": "Samsung",
            "60:A1:0A": "Samsung",
            "60:D0:A9": "Samsung",
            "64:1C:67": "Samsung",
            "64:B3:10": "Samsung",
            "68:27:37": "Samsung",
            "68:94:23": "Samsung",
            "68:EB:AE": "Samsung",
            "6C:2F:2C": "Samsung",
            "6C:83:36": "Samsung",
            "6C:8D:C1": "Samsung",
            "6C:F3:73": "Samsung",
            "70:2A:D5": "Samsung",
            "70:5A:0F": "Samsung",
            "70:71:BC": "Samsung",
            "70:9C:D1": "Samsung",
            "70:A8:E3": "Samsung",
            "70:F9:27": "Samsung",
            "74:40:BB": "Samsung",
            "74:45:8A": "Samsung",
            "74:5F:00": "Samsung",
            "78:1F:DB": "Samsung",
            "78:25:AD": "Samsung",
            "78:40:E4": "Samsung",
            "78:47:1D": "Samsung",
            "78:52:1A": "Samsung",
            "78:59:5E": "Samsung",
            "78:BD:BC": "Samsung",
            "78:D6:F0": "Samsung",
            "78:F7:BE": "Samsung",
            "7C:11:CB": "Samsung",
            "7C:61:93": "Samsung",
            "7C:79:E8": "Samsung",
            "80:1F:02": "Samsung",
            "80:38:BC": "Samsung",
            "80:57:19": "Samsung",
            "80:7A:BF": "Samsung",
            "84:11:9E": "Samsung",
            "84:25:DB": "Samsung",
            "84:38:38": "Samsung",
            "88:32:9B": "Samsung",
            "88:36:5F": "Samsung",
            "88:6B:0F": "Samsung",
            "8C:71:F8": "Samsung",
            "8C:77:12": "Samsung",
            "8C:C8:CD": "Samsung",
            "8C:FD:18": "Samsung",
            "90:18:7C": "Samsung",
            "90:1A:CA": "Samsung",
            "94:35:0A": "Samsung",
            "94:63:D1": "Samsung",
            "94:D7:29": "Samsung",
            "94:E9:79": "Samsung",
            "94:EB:CD": "Samsung",
            "98:0C:A5": "Samsung",
            "98:2F:C3": "Samsung",
            "98:52:B1": "Samsung",
            "98:83:89": "Samsung",
            "98:E0:D9": "Samsung",
            "9C:02:98": "Samsung",
            "9C:3A:AF": "Samsung",
            "9C:3D:CF": "Samsung",
            "9C:E6:E7": "Samsung",
            "A0:07:98": "Samsung",
            "A0:0B:BA": "Samsung",
            "A0:82:1F": "Samsung",
            "A0:91:3D": "Samsung",
            "A4:EB:D3": "Samsung",
            "A4:77:33": "Samsung",
            "A8:F2:74": "Samsung",
            "AC:36:13": "Samsung",
            "AC:5F:3E": "Samsung",
            "AC:83:F3": "Samsung",
            "AC:B5:7D": "Samsung",
            "AC:FD:CE": "Samsung",
            "B0:72:BF": "Samsung",
            "B0:D5:9D": "Samsung",
            "B4:07:F9": "Samsung",
            "B4:EF:39": "Samsung",
            "B4:F0:AB": "Samsung",
            "B8:5E:7B": "Samsung",
            "BC:14:85": "Samsung",
            "BC:44:86": "Samsung",
            "BC:72:B1": "Samsung",
            "BC:8C:CD": "Samsung",
            "BC:B1:F3": "Samsung",
            "BC:C6:DB": "Samsung",
            "BC:F5:AC": "Samsung",
            "C0:38:F9": "Samsung",
            "C0:71:FE": "Samsung",
            "C0:97:27": "Samsung",
            "C0:BD:D1": "Samsung",
            "C4:42:02": "Samsung",
            "C4:43:8F": "Samsung",
            "C4:57:6E": "Samsung",
            "C4:73:1E": "Samsung",
            "C4:88:E5": "Samsung",
            "C8:14:79": "Samsung",
            "C8:19:F7": "Samsung",
            "C8:1E:E7": "Samsung",
            "C8:3D:D4": "Samsung",
            "C8:49:3A": "Samsung",
            "C8:A8:23": "Samsung",
            "C8:BA:94": "Samsung",
            "C8:D7:19": "Samsung",
            "C8:DF:84": "Samsung",
            "CC:07:AB": "Samsung",
            "CC:3A:61": "Samsung",
            "CC:6E:A4": "Samsung",
            "CC:FE:3C": "Samsung",
            "D0:22:BE": "Samsung",
            "D0:59:E4": "Samsung",
            "D0:66:7B": "Samsung",
            "D0:87:E2": "Samsung",
            "D0:DF:9A": "Samsung",
            "D4:87:D8": "Samsung",
            "D4:88:90": "Samsung",
            "D4:E8:B2": "Samsung",
            "D8:31:CF": "Samsung",
            "D8:57:EF": "Samsung",
            "DC:1D:E5": "Samsung",
            "DC:71:44": "Samsung",
            "E0:2A:82": "Samsung",
            "E0:61:B2": "Samsung",
            "E0:CB:EE": "Samsung",
            "E0:DB:10": "Samsung",
            "E4:12:1D": "Samsung",
            "E4:32:CB": "Samsung",
            "E4:3E:D7": "Samsung",
            "E4:40:E2": "Samsung",
            "E4:58:B8": "Samsung",
            "E4:92:FB": "Samsung",
            "E4:B0:21": "Samsung",
            "E8:03:9A": "Samsung",
            "E8:11:32": "Samsung",
            "E8:3A:12": "Samsung",
            "E8:50:8B": "Samsung",
            "E8:E5:D6": "Samsung",
            "EC:1D:8B": "Samsung",
            "EC:9B:F3": "Samsung",
            "F0:08:F1": "Samsung",
            "F0:25:B7": "Samsung",
            "F0:5A:09": "Samsung",
            "F0:6B:CA": "Samsung",
            "F0:72:8C": "Samsung",
            "F0:E7:7E": "Samsung",
            "F4:09:D8": "Samsung",
            "F4:0F:1B": "Samsung",
            "F4:7B:5E": "Samsung",
            "F4:D9:FB": "Samsung",
            "F8:04:2E": "Samsung",
            "F8:1A:67": "Samsung",
            "F8:59:71": "Samsung",
            "F8:62:14": "Samsung",
            "F8:D0:BD": "Samsung",
            "FC:00:12": "Samsung",
            "FC:03:9F": "Samsung",
            "FC:A1:3E": "Samsung",
            "FC:C7:34": "Samsung",
            "FC:DB:B3": "Samsung",
            "DC:EB:69": "Raspberry Pi Foundation",
            "B8:27:EB": "Raspberry Pi Foundation",
            "E4:5F:01": "Raspberry Pi Foundation"
        ]

        return ouiDatabase[oui]
    }
}

// MARK: - Stat Item Component

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.blue)
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    IntegratedDashboardViewV3()
}
