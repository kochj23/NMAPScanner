//
//  IntegratedDashboardViewV3.swift
//  NMAP Plus Security Scanner - Enhanced Dashboard with Ping Scanning
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI
import Network

struct IntegratedDashboardViewV3: View {
    @StateObject private var scanner = IntegratedScannerV3.shared
    @StateObject private var simpleScanner = SimpleNetworkScanner()
    @StateObject private var anomalyManager = AnomalyDetectionManager.shared
    @StateObject private var scheduledScanManager = ScheduledScanManager.shared
    @StateObject private var groupingManager = DeviceGroupingManager.shared

    // Re-adding DevicePersistenceManager (needed for device history)
    // Note: Not using @StateObject to avoid triggering view updates
    private let persistenceManager = DevicePersistenceManager.shared

    @State private var showingThreatDashboard = false
    @State private var showingDeviceThreats = false
    @State private var showingSettings = false
    @State private var showingNotifications = false
    @State private var showingExport = false
    @State private var showingPresets = false
    @State private var selectedDevice: EnhancedDevice?
    @State private var showingManualScan = false
    @State private var manualIPAddress = ""
    @State private var showingTopology = false
    @State private var showingHistoricalComparison = false
    @State private var showingAnomalies = false
    // @State private var deviceToExport: EnhancedDevice?
    @State private var searchText = ""
    @State private var selectedDevices: Set<String> = [] // For bulk operations
    @AppStorage("enableBulkOperations") private var enableBulkOperations = false
    // Port scanning mode - temporarily disabled until files are added to Xcode project
    // @State private var selectedPortScanMode: PortScanMode = UserDefaults.standard.selectedPortScanMode
    // @State private var showPortScanSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header - Home app style
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Network")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.primary)

                            if !scanner.devices.isEmpty {
                                Text("\(scanner.devices.count) devices")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Settings Button - minimalist style
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Scanning Status
                    if scanner.isScanning {
                        ScanningStatusCardV3(scanner: scanner)
                    } else if simpleScanner.isScanning {
                        SimpleScanningStatusCard(scanner: simpleScanner)
                    }


                    // Network Threat Summary - DISABLED (ThreatAnalyzer removed)
                    /*
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
                    */

                    // Devices Grid - Home app style cards
                    if !scanner.devices.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Devices")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                            ], spacing: 16) {
                                ForEach(scanner.devices) { device in
                                    DeviceCard(
                                        device: device,
                                        onTap: { selectedDevice = device },
                                        onScan: {
                                            Task {
                                                await scanner.scanSingleDevice(device.ipAddress)
                                                anomalyManager.analyzeScanResults(scanner.devices)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Action Buttons - Home app style
                    if !scanner.isScanning && !simpleScanner.isScanning {
                        VStack(spacing: 12) {
                            // Manual Scan Button (New!)
                            Button(action: {
                                showingManualScan = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Scan Single Host")
                                        .font(.system(size: 17, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.cyan.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)

                            // Comprehensive Discovery Button - Uses ping sweep
                            Button(action: {
                                Task {
                                    await simpleScanner.scanPingSweep(subnet: "192.168.1")
                                    await scanner.importSimpleDevices(simpleScanner.discoveredIPs)
                                    anomalyManager.analyzeScanResults(scanner.devices)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "network.badge.shield.half.filled")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Discover All Devices (Ping Sweep)")
                                        .font(.system(size: 17, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)

                            // Port Scan Button
                            if !scanner.devices.isEmpty {
                                Button(action: {
                                    Task {
                                        await scanner.scanPortsOnDevices()
                                        anomalyManager.analyzeScanResults(scanner.devices)
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.system(size: 20, weight: .semibold))
                                        Text("Scan Ports")
                                            .font(.system(size: 17, weight: .semibold))
                                        Spacer()
                                        Text("\(scanner.devices.count)")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.purple, Color.purple.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                            }

                            // Full Rescan Button (Ping + Port Scan) - DISABLED (blocks main thread)
                            /*
                            Button(action: {
                                Task {
                                    await scanner.startFullScan()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.system(size: 24))
                                    Text("Full Rescan (ICMP)")
                                        .font(.system(size: 22, weight: .semibold))
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 18)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)

                            // Quick Scan Button (Ping Only)
                            Button(action: {
                                Task {
                                    await scanner.startQuickScan()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bolt.circle.fill")
                                        .font(.system(size: 24))
                                    Text("Quick Scan (ICMP)")
                                        .font(.system(size: 22, weight: .semibold))
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 18)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                            */
                        }

                        // Deep Scan Button - DISABLED (port scanning blocks main thread)
                        /*
                        if !scanner.devices.isEmpty {
                            Button(action: {
                                Task {
                                    await scanner.startDeepScan()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.system(size: 24))
                                    Text("Deep Scan (\(scanner.devices.count) devices)")
                                        .font(.system(size: 22, weight: .semibold))
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 18)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                        }
                        */

                            // Export & Settings Buttons
                            if !scanner.devices.isEmpty {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        showingExport = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 17, weight: .semibold))
                                            Text("Export")
                                                .font(.system(size: 17, weight: .semibold))
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        showingPresets = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "list.bullet")
                                                .font(.system(size: 17, weight: .semibold))
                                            Text("Presets")
                                                .font(.system(size: 17, weight: .semibold))
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                .padding(.bottom, 20)
            }  // ScrollView
            .background(Color(NSColor.windowBackgroundColor))
            .sheet(item: $selectedDevice) { device in
                ComprehensiveDeviceDetailView(device: device)
            }
            .sheet(isPresented: $showingSettings) {
                EnhancedSettingsView()
            }
            .sheet(isPresented: $showingExport) {
                ExportView(devices: scanner.devices, threats: [])
            }
            .sheet(isPresented: $showingPresets) {
                PresetSelectionView { preset in
                    showingPresets = false
                    Task {
                        await scanner.startScanWithPreset(preset)
                        anomalyManager.analyzeScanResults(scanner.devices)
                    }
                }
            }
            .sheet(isPresented: $showingManualScan) {
                ManualScanView(
                    ipAddress: $manualIPAddress,
                    onScan: {
                        Task {
                            await scanner.scanSingleDevice(manualIPAddress)
                            showingManualScan = false
                            anomalyManager.analyzeScanResults(scanner.devices)
                        }
                    },
                    onCancel: {
                        showingManualScan = false
                    }
                )
            }
            .sheet(isPresented: $showingTopology) {
                NetworkTopologyView(devices: scanner.devices)
            }
        }  // NavigationStack
    }  // body
}  // IntegratedDashboardViewV3

// MARK: - Scanning Status Card V3 - Home App Style

struct ScanningStatusCardV3: View {
    @ObservedObject var scanner: IntegratedScannerV3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text(scanner.scanPhase)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }

            ProgressView(value: scanner.progress)
                .tint(.blue)

            Text(scanner.status)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 24) {
                ScanStatItem(label: "Scanned", value: "\(scanner.scannedHosts)")
                ScanStatItem(label: "Alive", value: "\(scanner.hostsAlive)")
                ScanStatItem(label: "Devices", value: "\(scanner.devices.count)")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Simple Scanning Status Card - Home App Style

struct SimpleScanningStatusCard: View {
    @ObservedObject var scanner: SimpleNetworkScanner

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Discovering Devices")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }

            ProgressView(value: scanner.progress)
                .tint(.green)

            Text(scanner.status)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 24) {
                ScanStatItem(label: "Found", value: "\(scanner.discoveredIPs.count)")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Scan Stat Item

struct ScanStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Integrated Scanner V3

@MainActor
class IntegratedScannerV3: ObservableObject {
    static let shared = IntegratedScannerV3()

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
    private let dnsResolver = CustomDNSResolver.shared

    /// Custom port list for preset scans (nil = use standard ports)
    var customPortList: [Int]?

    private init() {
        // Load persisted devices from last session
        Task { @MainActor in
            await loadPersistedDevices()
        }
    }

    /// Load devices from persistent storage (from previous app sessions)
    func loadPersistedDevices() async {
        print("💾 Scanner: Loading persisted devices from previous sessions...")

        let persistedDevices = persistenceManager.persistedDevices
        guard !persistedDevices.isEmpty else {
            print("💾 Scanner: No persisted devices found")
            return
        }

        print("💾 Scanner: Found \(persistedDevices.count) persisted devices")

        // Convert persisted devices to EnhancedDevice
        var loadedDevices: [EnhancedDevice] = []
        for persisted in persistedDevices {
            let deviceType: EnhancedDevice.DeviceType
            switch persisted.deviceType {
            case "Router": deviceType = .router
            case "Server": deviceType = .server
            case "Computer": deviceType = .computer
            case "Mobile Device": deviceType = .mobile
            case "IoT Device": deviceType = .iot
            case "Printer": deviceType = .printer
            default: deviceType = .unknown
            }

            let device = EnhancedDevice(
                ipAddress: persisted.ipAddress,
                macAddress: persisted.macAddress,
                hostname: persisted.hostname,
                manufacturer: persisted.manufacturer,
                deviceType: deviceType,
                openPorts: [], // Will be updated during incremental scan
                isOnline: false, // Will be verified during incremental scan
                firstSeen: persisted.firstSeen,
                lastSeen: persisted.lastSeen,
                isKnownDevice: persisted.isWhitelisted,
                operatingSystem: nil,
                deviceName: persisted.customName
            )
            loadedDevices.append(device)
        }

        devices = loadedDevices
        hasScanned = true
        print("💾 Scanner: Loaded \(devices.count) devices into memory")
    }

    /// Get ports to scan based on user preference or custom preset
    private var portsToScan: [Int] {
        // Use custom port list if set (from preset), otherwise use standard ports
        if let customPorts = customPortList {
            return customPorts
        }
        return CommonPorts.standard
    }

    /// Import devices discovered via Bonjour/mDNS
    func importBonjourDevices(_ ipAddresses: Set<String>, bonjourScanner: BonjourScanner) async {
        status = "Processing Bonjour discoveries..."
        devices = []

        for host in sortIPAddresses(Array(ipAddresses)) {
            let services = bonjourScanner.getServices(for: host)

            // Create basic device with Bonjour info
            let device = createBasicDevice(host: host, macAddress: nil)
            devices.append(device)

            // Update persistence
            persistenceManager.addOrUpdateDevice(device)
        }

        // Update network history
        let subnet = detectSubnet()
        persistenceManager.addOrUpdateNetwork(subnet: subnet, deviceCount: devices.count)

        // Remove duplicates
        deduplicateDevices()

        // Sort devices by IP address
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        status = "Bonjour discovery complete - \(devices.count) devices found"
        hasScanned = true

        // Send notification
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: 0)
    }

    /// Enrich discovered devices with HomeKit information
    func enrichDevicesWithHomeKit() async {
        let homeKitDiscovery = HomeKitDiscoveryMacOS.shared

        // Check if HomeKit discovery has run
        guard !homeKitDiscovery.discoveredDevices.isEmpty else {
            print("📱 HomeKit: No devices to enrich with")
            return
        }

        print("📱 HomeKit: Enriching \(devices.count) devices with HomeKit data")

        var updatedDevices: [EnhancedDevice] = []

        for device in devices {
            var enrichedDevice = device

            // Check if this device has HomeKit info
            if let homeKitDevice = homeKitDiscovery.getDeviceInfo(for: device.ipAddress) {
                print("📱 HomeKit: Found HomeKit info for \(device.ipAddress) - \(homeKitDevice.displayName)")

                // Create HomeKit info
                let homeKitInfo = HomeKitMDNSInfo(
                    deviceName: homeKitDevice.displayName,
                    serviceType: homeKitDevice.serviceType,
                    category: homeKitDevice.category,
                    isHomeKitAccessory: homeKitDevice.isHomeKitAccessory,
                    discoveredAt: homeKitDevice.discoveredAt
                )

                // Create updated device with HomeKit info
                enrichedDevice = EnhancedDevice(
                    ipAddress: device.ipAddress,
                    macAddress: device.macAddress,
                    hostname: device.hostname,
                    manufacturer: device.manufacturer,
                    deviceType: device.deviceType,  // Keep original device type
                    openPorts: device.openPorts,
                    isOnline: device.isOnline,
                    firstSeen: device.firstSeen,
                    lastSeen: device.lastSeen,
                    isKnownDevice: device.isKnownDevice,
                    operatingSystem: device.operatingSystem,
                    deviceName: homeKitDevice.displayName,
                    homeKitMDNSInfo: homeKitInfo
                )

                print("📱 HomeKit: Enriched device: \(enrichedDevice.displayName) [\(homeKitInfo.category)]")
            }

            updatedDevices.append(enrichedDevice)
        }

        await MainActor.run {
            self.devices = updatedDevices
            print("📱 HomeKit: Enrichment complete - \(devices.count) devices processed")
        }

        // Update persistence
        for device in updatedDevices {
            persistenceManager.addOrUpdateDevice(device)
        }
    }

    /// Check if HomeKit data exists for an IP address and return it
    private func getHomeKitInfoForIP(_ ipAddress: String) -> HomeKitMDNSInfo? {
        let homeKitDiscovery = HomeKitDiscoveryMacOS.shared

        guard let homeKitDevice = homeKitDiscovery.getDeviceInfo(for: ipAddress) else {
            return nil
        }

        return HomeKitMDNSInfo(
            deviceName: homeKitDevice.displayName,
            serviceType: homeKitDevice.serviceType,
            category: homeKitDevice.category,
            isHomeKitAccessory: homeKitDevice.isHomeKitAccessory,
            discoveredAt: homeKitDevice.discoveredAt
        )
    }

    /// Start a network scan with a specific preset configuration
    func startScanWithPreset(_ preset: ScanPreset) async {
        print("🎯 Starting scan with preset: \(preset.name)")
        print("🎯 Scanning \(preset.ports.count) ports: \(preset.ports)")

        // Set custom port list for this scan
        customPortList = preset.ports

        // Set scanner to scanning state
        isScanning = true
        status = "Starting \(preset.name) scan..."
        scanPhase = "Initializing"
        progress = 0

        // Run the port scan with custom ports
        await scanPortsOnDevices()

        // Clear custom port list after scan
        customPortList = nil

        print("🎯 Preset scan complete: \(preset.name)")
    }

    /// Remove duplicate devices based on IP address (keeps most recent/complete)
    /// Handles interface suffixes like "192.168.1.100$/en1" from Bonjour
    private func deduplicateDevices() {
        var devicesByBaseIP: [String: [EnhancedDevice]] = [:]

        // Group devices by base IP (strip interface suffix)
        for device in devices {
            let baseIP = stripInterfaceSuffix(device.ipAddress)
            if devicesByBaseIP[baseIP] == nil {
                devicesByBaseIP[baseIP] = []
            }
            devicesByBaseIP[baseIP]?.append(device)
        }

        var uniqueDevices: [EnhancedDevice] = []
        var mergedCount = 0

        // For each base IP, merge all versions into best one
        for (baseIP, duplicates) in devicesByBaseIP {
            if duplicates.count > 1 {
                print("🔧 Dedup: Found \(duplicates.count) versions of \(baseIP) - merging...")
                mergedCount += duplicates.count - 1

                // Merge all duplicates into single device with combined data
                let merged = mergeDevices(duplicates, baseIP: baseIP)
                uniqueDevices.append(merged)

                print("🔧 Dedup: Merged into \(merged.ipAddress) with \(merged.openPorts.count) ports")
            } else {
                // Single device, just use it (but ensure clean IP)
                var device = duplicates[0]
                if device.ipAddress != baseIP {
                    print("🔧 Dedup: Cleaning IP \(device.ipAddress) → \(baseIP)")
                    device = EnhancedDevice(
                        ipAddress: baseIP,  // Use clean IP
                        macAddress: device.macAddress,
                        hostname: device.hostname,
                        manufacturer: device.manufacturer,
                        deviceType: device.deviceType,
                        openPorts: device.openPorts,
                        isOnline: device.isOnline,
                        firstSeen: device.firstSeen,
                        lastSeen: device.lastSeen,
                        isKnownDevice: device.isKnownDevice,
                        operatingSystem: device.operatingSystem,
                        deviceName: device.deviceName
                    )
                }
                uniqueDevices.append(device)
            }
        }

        if mergedCount > 0 {
            print("✅ Dedup: Merged \(mergedCount) duplicate devices")
        }

        devices = uniqueDevices
    }

    /// Strip interface suffix from IP address (e.g., "192.168.1.100$/en1" → "192.168.1.100")
    private func stripInterfaceSuffix(_ ip: String) -> String {
        if let dollarIndex = ip.firstIndex(of: "$") {
            return String(ip[..<dollarIndex])
        }
        return ip
    }

    /// Merge multiple device instances into single best representation
    private func mergeDevices(_ devices: [EnhancedDevice], baseIP: String) -> EnhancedDevice {
        // Start with first device as base
        var merged = devices[0]

        // Merge data from all versions
        var allPorts: [PortInfo] = []
        var bestHostname: String? = merged.hostname
        var bestMac: String? = merged.macAddress
        var bestManufacturer: String? = merged.manufacturer
        var bestDeviceName: String? = merged.deviceName
        var earliestFirstSeen = merged.firstSeen
        var latestLastSeen = merged.lastSeen
        var isAnyOnline = merged.isOnline
        var homeKitInfo: HomeKitMDNSInfo? = merged.homeKitMDNSInfo

        for device in devices {
            // Collect all unique ports
            for port in device.openPorts {
                if !allPorts.contains(where: { $0.port == port.port }) {
                    allPorts.append(port)
                }
            }

            // Keep best hostname (prefer non-nil, non-IP)
            if let hostname = device.hostname, !hostname.isEmpty, !hostname.contains(".") || bestHostname == nil {
                bestHostname = hostname
            }

            // Keep MAC if available
            if device.macAddress != nil {
                bestMac = device.macAddress
            }

            // Keep manufacturer if available
            if device.manufacturer != nil {
                bestManufacturer = device.manufacturer
            }

            // Keep device name if available
            if device.deviceName != nil {
                bestDeviceName = device.deviceName
            }

            // Track earliest first seen
            if device.firstSeen < earliestFirstSeen {
                earliestFirstSeen = device.firstSeen
            }

            // Track latest last seen
            if device.lastSeen > latestLastSeen {
                latestLastSeen = device.lastSeen
            }

            // Online if any version is online
            if device.isOnline {
                isAnyOnline = true
            }

            // Keep HomeKit info if available
            if device.homeKitMDNSInfo != nil {
                homeKitInfo = device.homeKitMDNSInfo
            }
        }

        // Create merged device with clean IP and combined data
        var mergedDevice = EnhancedDevice(
            ipAddress: baseIP,  // Use clean base IP without suffix
            macAddress: bestMac,
            hostname: bestHostname,
            manufacturer: bestManufacturer,
            deviceType: merged.deviceType,
            openPorts: allPorts.sorted { $0.port < $1.port },
            isOnline: isAnyOnline,
            firstSeen: earliestFirstSeen,
            lastSeen: latestLastSeen,
            isKnownDevice: merged.isKnownDevice,
            operatingSystem: merged.operatingSystem,
            deviceName: bestDeviceName
        )

        mergedDevice.homeKitMDNSInfo = homeKitInfo

        return mergedDevice
    }

    /// Import devices discovered via SimpleNetworkScanner (ARP/Ping) with incremental updates
    func importSimpleDevices(_ ipAddresses: [String]) async {
        print("📥 IntegratedScannerV3: ========== STARTING INCREMENTAL IMPORT ==========")
        print("📥 IntegratedScannerV3: Importing \(ipAddresses.count) devices from SimpleNetworkScanner...")
        print("📥 IntegratedScannerV3: IP addresses: \(ipAddresses)")

        print("📥 IntegratedScannerV3: Setting status message...")
        status = "Processing discovered devices (incremental mode)..."

        // Keep existing devices dictionary for quick lookup
        var existingDevicesByIP: [String: EnhancedDevice] = [:]
        for device in devices {
            existingDevicesByIP[device.ipAddress] = device
        }
        print("📥 IntegratedScannerV3: Found \(existingDevicesByIP.count) existing devices in memory")

        // Track changes
        var updatedDevices: [EnhancedDevice] = []
        var newDevicesCount = 0
        var existingDevicesCount = 0
        var offlineDevicesCount = 0

        // Get MAC addresses from ARP table for all discovered IPs
        print("📥 IntegratedScannerV3: Getting MAC addresses from ARP scanner...")
        let macAddresses = await arpScanner.getMACAddresses(for: ipAddresses)
        print("📥 IntegratedScannerV3: Got \(macAddresses.count) MAC addresses: \(macAddresses)")

        print("📥 IntegratedScannerV3: Sorting IP addresses...")
        let sortedIPs = sortIPAddresses(ipAddresses)
        print("📥 IntegratedScannerV3: Sorted IPs: \(sortedIPs)")

        print("📥 IntegratedScannerV3: Processing devices (incremental mode)...")
        for (index, host) in sortedIPs.enumerated() {
            print("📥 IntegratedScannerV3: [\(index+1)/\(sortedIPs.count)] Processing \(host)...")

            if let existingDevice = existingDevicesByIP[host] {
                // Device already exists - update it (mark as online, update lastSeen)
                print("📥 IntegratedScannerV3: [\(index+1)/\(sortedIPs.count)] Existing device found - updating...")
                var updatedDevice = existingDevice
                updatedDevice = EnhancedDevice(
                    ipAddress: existingDevice.ipAddress,
                    macAddress: macAddresses[host] ?? existingDevice.macAddress,
                    hostname: existingDevice.hostname,
                    manufacturer: existingDevice.manufacturer,
                    deviceType: existingDevice.deviceType,
                    openPorts: existingDevice.openPorts,
                    isOnline: true, // Mark as online
                    firstSeen: existingDevice.firstSeen,
                    lastSeen: Date(), // Update lastSeen
                    isKnownDevice: existingDevice.isKnownDevice,
                    operatingSystem: existingDevice.operatingSystem,
                    deviceName: existingDevice.deviceName
                )
                updatedDevices.append(updatedDevice)
                existingDevicesCount += 1
                print("📥 IntegratedScannerV3: [\(index+1)/\(sortedIPs.count)] Device updated")
            } else {
                // New device discovered
                print("📥 IntegratedScannerV3: [\(index+1)/\(sortedIPs.count)] New device - creating...")
                let device = createBasicDevice(host: host, macAddress: macAddresses[host])
                updatedDevices.append(device)
                newDevicesCount += 1
                print("📥 IntegratedScannerV3: [\(index+1)/\(sortedIPs.count)] New device created: \(device.ipAddress), MAC: \(device.macAddress ?? "none")")
            }

            // Update persistence for all devices
            persistenceManager.addOrUpdateDevice(updatedDevices.last!)
        }

        // Mark offline devices (existed before but not found in current scan)
        for existingDevice in existingDevicesByIP.values {
            if !ipAddresses.contains(existingDevice.ipAddress) {
                print("📥 IntegratedScannerV3: Device \(existingDevice.ipAddress) is now offline")
                var offlineDevice = existingDevice
                offlineDevice = EnhancedDevice(
                    ipAddress: existingDevice.ipAddress,
                    macAddress: existingDevice.macAddress,
                    hostname: existingDevice.hostname,
                    manufacturer: existingDevice.manufacturer,
                    deviceType: existingDevice.deviceType,
                    openPorts: existingDevice.openPorts,
                    isOnline: false, // Mark as offline
                    firstSeen: existingDevice.firstSeen,
                    lastSeen: existingDevice.lastSeen,
                    isKnownDevice: existingDevice.isKnownDevice,
                    operatingSystem: existingDevice.operatingSystem,
                    deviceName: existingDevice.deviceName
                )
                updatedDevices.append(offlineDevice)
                offlineDevicesCount += 1
            }
        }

        // Replace devices with updated list
        devices = updatedDevices

        // Update network history
        print("📥 IntegratedScannerV3: Detecting subnet...")
        let subnet = detectSubnet()
        print("📥 IntegratedScannerV3: Subnet: \(subnet)")

        print("📥 IntegratedScannerV3: Updating network history...")
        persistenceManager.addOrUpdateNetwork(subnet: subnet, deviceCount: devices.count)
        print("📥 IntegratedScannerV3: Network history updated")

        // Remove duplicates
        print("📥 IntegratedScannerV3: Deduplicating devices...")
        deduplicateDevices()
        print("📥 IntegratedScannerV3: After deduplication: \(devices.count) devices")

        // Sort devices by IP address
        print("📥 IntegratedScannerV3: Final sort of devices...")
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }
        print("📥 IntegratedScannerV3: Devices sorted")

        print("📥 IntegratedScannerV3: Setting completion status...")
        let onlineCount = devices.filter { $0.isOnline }.count
        status = "Incremental scan complete - \(onlineCount) online, \(newDevicesCount) new, \(offlineDevicesCount) offline"
        hasScanned = true
        print("📥 IntegratedScannerV3: Status set, hasScanned = true")
        print("📥 IntegratedScannerV3: Summary - New: \(newDevicesCount), Existing: \(existingDevicesCount), Offline: \(offlineDevicesCount)")

        // Send notification with change details
        print("📥 IntegratedScannerV3: Sending completion notification...")
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: 0)
        print("📥 IntegratedScannerV3: Notification sent")

        print("📥 IntegratedScannerV3: ========== INCREMENTAL IMPORT COMPLETE - \(devices.count) TOTAL DEVICES ==========")
    }

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

        // Remove duplicates
        deduplicateDevices()

        // Sort devices by IP address
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        status = "Quick scan complete - \(devices.count) devices found"
        progress = 1.0
        isScanning = false
        hasScanned = true

        // Send notification
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: 0)
    }

    /// Full scan - ping + port scan + HomeKit discovery on all alive hosts
    func startFullScan() async {
        isScanning = true
        scanPhase = "Full Scan"
        progress = 0
        status = "Starting comprehensive network scan..."
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
        progress = 0.2 // 20% done after ping

        if aliveHosts.isEmpty {
            status = "No hosts found"
            isScanning = false
            hasScanned = true
            return
        }

        // Phase 2: Get MAC addresses
        status = "Phase 2: Gathering MAC addresses..."
        let macAddresses = await arpScanner.getMACAddresses(for: Array(aliveHosts))
        progress = 0.3 // 30% done after MAC collection

        // Phase 3: HomeKit/Bonjour Discovery
        status = "Phase 3: Discovering HomeKit devices..."
        let bonjourScanner = BonjourScanner()
        await bonjourScanner.startScan()
        let bonjourIPs = bonjourScanner.getDiscoveredIPs()
        print("📱 Full Scan: Bonjour found \(bonjourIPs.count) HomeKit/Apple devices")
        progress = 0.4 // 40% done after Bonjour

        // Phase 4: PARALLEL Port scan (OPTIMIZED)
        scanPhase = "Port Scanning"
        status = "Phase 4: Scanning ports on \(aliveHosts.count) hosts in parallel..."

        let sortedHosts = sortIPAddresses(Array(aliveHosts))
        let totalHosts = sortedHosts.count
        var completedCount = 0

        print("🚀 Full Scan: Starting PARALLEL port scan of \(totalHosts) hosts with concurrency limit of 10")

        await withTaskGroup(of: (String, [PortInfo]).self) { group in
            var activeScans = 0
            let maxConcurrent = 10

            for host in sortedHosts {
                // Wait if we've hit the concurrency limit
                while activeScans >= maxConcurrent {
                    if let result = await group.next() {
                        activeScans -= 1
                        completedCount += 1
                        progress = 0.4 + (Double(completedCount) / Double(totalHosts) * 0.6)
                        status = "Phase 4: Scanned \(completedCount)/\(totalHosts) hosts..."

                        // Process completed scan
                        let (completedHost, openPorts) = result
                        if !openPorts.isEmpty || bonjourIPs.contains(completedHost) {
                            var device = createEnhancedDevice(host: completedHost, openPorts: openPorts, macAddress: macAddresses[completedHost])

                            // Enrich with HomeKit/Bonjour metadata
                            if bonjourIPs.contains(completedHost) {
                                let services = bonjourScanner.getServices(for: completedHost)
                                let metadata = bonjourScanner.getMetadata(for: completedHost)

                                if let metadata = metadata {
                                    device = EnhancedDevice(
                                        ipAddress: device.ipAddress,
                                        macAddress: device.macAddress,
                                        hostname: device.hostname,
                                        manufacturer: device.manufacturer,
                                        deviceType: .iot,
                                        openPorts: device.openPorts,
                                        isOnline: device.isOnline,
                                        firstSeen: device.firstSeen,
                                        lastSeen: device.lastSeen,
                                        isKnownDevice: device.isKnownDevice,
                                        operatingSystem: device.operatingSystem,
                                        deviceName: metadata.displayName
                                    )
                                    device.homeKitMDNSInfo = HomeKitMDNSInfo(
                                        deviceName: metadata.displayName,
                                        serviceType: services.joined(separator: ", "),
                                        category: metadata.category,
                                        isHomeKitAccessory: true,
                                        discoveredAt: Date()
                                    )
                                    print("📱 Full Scan: Enriched \(completedHost) with HomeKit data: \(metadata.displayName)")
                                } else {
                                    device.homeKitMDNSInfo = HomeKitMDNSInfo(
                                        deviceName: completedHost,
                                        serviceType: services.joined(separator: ", "),
                                        category: "HomeKit Device",
                                        isHomeKitAccessory: true,
                                        discoveredAt: Date()
                                    )
                                }
                            }

                            devices.append(device)
                            persistenceManager.addOrUpdateDevice(device)
                        }
                    }
                }

                // Start new scan
                group.addTask {
                    let ports = await self.portScanner.scanPorts(host: host, ports: self.portsToScan)
                    return (host, ports)
                }
                activeScans += 1
            }

            // Process remaining results
            for await result in group {
                completedCount += 1
                progress = 0.4 + (Double(completedCount) / Double(totalHosts) * 0.6)
                status = "Phase 4: Scanned \(completedCount)/\(totalHosts) hosts..."

                let (completedHost, openPorts) = result
                if !openPorts.isEmpty || bonjourIPs.contains(completedHost) {
                    var device = createEnhancedDevice(host: completedHost, openPorts: openPorts, macAddress: macAddresses[completedHost])

                    if bonjourIPs.contains(completedHost) {
                        let services = bonjourScanner.getServices(for: completedHost)
                        let metadata = bonjourScanner.getMetadata(for: completedHost)

                        if let metadata = metadata {
                            device = EnhancedDevice(
                                ipAddress: device.ipAddress,
                                macAddress: device.macAddress,
                                hostname: device.hostname,
                                manufacturer: device.manufacturer,
                                deviceType: .iot,
                                openPorts: device.openPorts,
                                isOnline: device.isOnline,
                                firstSeen: device.firstSeen,
                                lastSeen: device.lastSeen,
                                isKnownDevice: device.isKnownDevice,
                                operatingSystem: device.operatingSystem,
                                deviceName: metadata.displayName
                            )
                            device.homeKitMDNSInfo = HomeKitMDNSInfo(
                                deviceName: metadata.displayName,
                                serviceType: services.joined(separator: ", "),
                                category: metadata.category,
                                isHomeKitAccessory: true,
                                discoveredAt: Date()
                            )
                        } else {
                            device.homeKitMDNSInfo = HomeKitMDNSInfo(
                                deviceName: completedHost,
                                serviceType: services.joined(separator: ", "),
                                category: "HomeKit Device",
                                isHomeKitAccessory: true,
                                discoveredAt: Date()
                            )
                        }
                    }

                    devices.append(device)
                    persistenceManager.addOrUpdateDevice(device)
                }
            }
        }

        print("🚀 Full Scan: Parallel port scanning complete - scanned \(completedCount) hosts")

        // Update network history
        persistenceManager.addOrUpdateNetwork(subnet: subnet, deviceCount: devices.count)

        // Remove duplicates
        deduplicateDevices()

        // Sort devices by IP address
        devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        // Analyze and record changes for historical tracking
        historicalTracker.analyzeAndRecordChanges(devices: devices)

        let homeKitCount = devices.filter { $0.homeKitMDNSInfo != nil }.count
        status = "Full scan complete - \(devices.count) devices (\(homeKitCount) HomeKit)"
        progress = 1.0
        isScanning = false
        hasScanned = true

        // Send notification
        NotificationManager.shared.notifyScanComplete(deviceCount: devices.count, threatCount: threatsDetected)
    }

    /// Port scan on discovered devices (non-blocking, uses Task groups) + HomeKit enrichment
    /// Helper function to process a scanned device (extracted for parallel scanning)
    private func processScannedDevice(_ host: String, openPorts: [PortInfo], bonjourIPs: Set<String>, bonjourScanner: BonjourScanner, scannedDevices: inout [EnhancedDevice]) async {
        // Update device with port info
        if let deviceIndex = devices.firstIndex(where: { $0.ipAddress == host }) {
            let existingDevice = devices[deviceIndex]
            var updatedDevice = createEnhancedDevice(
                host: host,
                openPorts: openPorts,
                macAddress: existingDevice.macAddress,
                existingDevice: existingDevice
            )

            // Enrich with HomeKit/Bonjour metadata if available
            if bonjourIPs.contains(host) {
                let services = bonjourScanner.getServices(for: host)
                let metadata = bonjourScanner.getMetadata(for: host)

                if let metadata = metadata {
                    // Create new device with HomeKit metadata
                    updatedDevice = EnhancedDevice(
                        ipAddress: updatedDevice.ipAddress,
                        macAddress: updatedDevice.macAddress,
                        hostname: updatedDevice.hostname,
                        manufacturer: updatedDevice.manufacturer,
                        deviceType: .iot,
                        openPorts: updatedDevice.openPorts,
                        isOnline: updatedDevice.isOnline,
                        firstSeen: updatedDevice.firstSeen,
                        lastSeen: updatedDevice.lastSeen,
                        isKnownDevice: updatedDevice.isKnownDevice,
                        operatingSystem: updatedDevice.operatingSystem,
                        deviceName: metadata.displayName
                    )
                    updatedDevice.homeKitMDNSInfo = HomeKitMDNSInfo(
                        deviceName: metadata.displayName,
                        serviceType: services.joined(separator: ", "),
                        category: metadata.category,
                        isHomeKitAccessory: true,
                        discoveredAt: Date()
                    )
                    print("📱 processScannedDevice: Enriched \(host) with HomeKit data: \(metadata.displayName) (\(metadata.category))")
                } else {
                    // No TXT metadata, but has services
                    updatedDevice.homeKitMDNSInfo = HomeKitMDNSInfo(
                        deviceName: host,
                        serviceType: services.joined(separator: ", "),
                        category: "HomeKit Device",
                        isHomeKitAccessory: true,
                        discoveredAt: Date()
                    )
                    print("📱 processScannedDevice: Found HomeKit device \(host) with services: \(services.joined(separator: ", "))")
                }
            }

            scannedDevices.append(updatedDevice)
        }
    }

    func scanPortsOnDevices() async {
        print("🔌 scanPortsOnDevices: Starting comprehensive scan on \(devices.count) devices")
        isScanning = true
        scanPhase = "Port Scan + HomeKit"
        progress = 0
        status = "Scanning \(devices.count) devices..."

        // Phase 1: HomeKit/Bonjour Discovery
        status = "Discovering HomeKit devices..."
        let bonjourScanner = BonjourScanner()
        await bonjourScanner.startScan()
        let bonjourIPs = bonjourScanner.getDiscoveredIPs()
        print("📱 scanPortsOnDevices: Bonjour found \(bonjourIPs.count) HomeKit/Apple devices")

        let hostsToScan = devices.map { $0.ipAddress }
        var scannedDevices: [EnhancedDevice] = []
        let totalHosts = hostsToScan.count
        var completedCount = 0

        // Phase 2: PARALLEL port scan with HomeKit enrichment (OPTIMIZED)
        status = "Scanning \(totalHosts) devices in parallel..."
        print("🚀 scanPortsOnDevices: Starting PARALLEL scan of \(totalHosts) devices with concurrency limit of 10")

        await withTaskGroup(of: (String, [PortInfo]).self) { group in
            var activeScans = 0
            let maxConcurrent = 10 // Limit concurrent scans to avoid overwhelming network

            for host in hostsToScan {
                // Wait if we've hit the concurrency limit
                while activeScans >= maxConcurrent {
                    if let result = await group.next() {
                        activeScans -= 1
                        completedCount += 1
                        progress = Double(completedCount) / Double(totalHosts)
                        status = "Scanned \(completedCount)/\(totalHosts) devices..."

                        // Process completed scan
                        let (completedHost, openPorts) = result
                        await processScannedDevice(completedHost, openPorts: openPorts, bonjourIPs: bonjourIPs, bonjourScanner: bonjourScanner, scannedDevices: &scannedDevices)
                    }
                }

                // Start new scan
                group.addTask {
                    print("🔌 scanPortsOnDevices: Scanning \(host)...")
                    let ports = await self.portScanner.scanPorts(host: host, ports: self.portsToScan)
                    print("🔌 scanPortsOnDevices: Found \(ports.count) open ports on \(host)")
                    return (host, ports)
                }
                activeScans += 1
            }

            // Process remaining results
            for await result in group {
                completedCount += 1
                progress = Double(completedCount) / Double(totalHosts)
                status = "Scanned \(completedCount)/\(totalHosts) devices..."

                let (completedHost, openPorts) = result
                await processScannedDevice(completedHost, openPorts: openPorts, bonjourIPs: bonjourIPs, bonjourScanner: bonjourScanner, scannedDevices: &scannedDevices)
            }
        }

        print("🚀 scanPortsOnDevices: Parallel scanning complete - scanned \(completedCount) devices")

        // Update devices array
        print("🔌 scanPortsOnDevices: Updating devices array with \(scannedDevices.count) scanned devices")
        devices = scannedDevices.sorted { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }

        // Update persistence
        for device in devices {
            persistenceManager.addOrUpdateDevice(device)
        }

        let homeKitCount = devices.filter { $0.homeKitMDNSInfo != nil }.count
        status = "Scan complete - \(devices.count) devices (\(homeKitCount) HomeKit)"
        progress = 1.0
        isScanning = false

        print("🔌 scanPortsOnDevices: Scan complete - \(homeKitCount) HomeKit devices found")
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

        // Remove duplicates
        deduplicateDevices()

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

    /// Scan a single device (or add new one if not in list)
    func scanSingleDevice(_ ipAddress: String) async {
        print("🎯 scanSingleDevice: Starting scan of \(ipAddress)")

        isScanning = true
        scanPhase = "Single Host Scan"
        progress = 0
        status = "Scanning \(ipAddress)..."

        // Get MAC address from ARP table
        let macAddresses = await arpScanner.getMACAddresses(for: [ipAddress])
        let macAddress = macAddresses[ipAddress]

        progress = 0.3

        // Scan ports
        // Start a task to monitor port scanner status and update main status
        let statusTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                if !portScanner.status.isEmpty {
                    self.status = portScanner.status
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // Update every 0.05s
            }
        }

        let openPorts = await Task.detached {
            await self.portScanner.scanPorts(host: ipAddress, ports: self.portsToScan)
        }.value

        statusTask.cancel()
        progress = 0.8

        // Create or update device
        let device = createEnhancedDevice(
            host: ipAddress,
            openPorts: openPorts,
            macAddress: macAddress,
            existingDevice: devices.first(where: { $0.ipAddress == ipAddress })
        )

        // Update or add to devices list
        if let index = devices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            devices[index] = device
        } else {
            devices.append(device)
            devices.sort { sortIPAddresses([$0.ipAddress, $1.ipAddress])[0] == $0.ipAddress }
        }

        // Update persistence
        persistenceManager.addOrUpdateDevice(device)

        // Update network history
        let subnet = detectSubnet()
        persistenceManager.addOrUpdateNetwork(subnet: subnet, deviceCount: devices.count)

        status = "Scan complete - \(openPorts.count) ports found"
        progress = 1.0
        isScanning = false

        print("🎯 scanSingleDevice: Complete - found \(openPorts.count) ports on \(ipAddress)")
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
        print("🔧 createBasicDevice: Creating device for \(host)")

        // Use custom DNS resolver if enabled, otherwise skip hostname resolution
        // (Old resolveHostname() blocks main thread with DispatchSemaphore)
        print("🔧 createBasicDevice: Attempting hostname resolution via custom DNS")
        var hostname: String? = nil

        // NOTE: Hostname resolution is skipped here to avoid blocking the main thread.
        // The legacy resolveHostname() used DispatchSemaphore which deadlocks on MainActor.
        // Future optimization: resolve hostnames in a background TaskGroup after device
        // creation completes, then update devices with resolved names asynchronously.
        // hostname = await dnsResolver.resolveHostname(for: host)

        // Get manufacturer from MAC address
        print("🔧 createBasicDevice: Getting manufacturer for MAC \(macAddress ?? "none")...")
        let manufacturer = getManufacturer(from: macAddress)
        print("🔧 createBasicDevice: Manufacturer: \(manufacturer ?? "none")")

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

        // Check for cached HomeKit data and apply it
        let homeKitInfo = getHomeKitInfoForIP(host)
        let deviceNameToUse = homeKitInfo?.deviceName ?? nil

        if let homeKitInfo = homeKitInfo {
            print("📱 HomeKit: Applying cached HomeKit data to basic device \(host) - \(homeKitInfo.deviceName)")
        }

        var device = EnhancedDevice(
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
            deviceName: deviceNameToUse
        )

        // Apply HomeKit info if available
        device.homeKitMDNSInfo = homeKitInfo

        return device
    }

    private func createEnhancedDevice(host: String, openPorts: [PortInfo], macAddress: String? = nil, existingDevice: EnhancedDevice? = nil) -> EnhancedDevice {
        // SKIP hostname resolution - it blocks the main thread with DispatchSemaphore
        // Use existing hostname if available, otherwise skip
        let hostname = existingDevice?.hostname
        // let hostname = existingDevice?.hostname ?? resolveHostname(for: host)

        // Get manufacturer from MAC address using our OUI database
        let manufacturer = existingDevice?.manufacturer ?? getManufacturer(from: macAddress)

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
            deviceType: detectDeviceType(openPorts: openPorts, manufacturer: manufacturer, hostname: hostname),
            openPorts: openPorts,
            isOnline: true,
            firstSeen: firstSeen,
            lastSeen: Date(),
            isKnownDevice: false,
            operatingSystem: nil,
            deviceName: nil
        )

        let isKnown = persistenceManager.isDeviceKnown(tempDevice)

        // Check for cached HomeKit data and apply it
        let homeKitInfo = getHomeKitInfoForIP(host)
        let deviceNameToUse = homeKitInfo?.deviceName ?? nil

        if let homeKitInfo = homeKitInfo {
            print("📱 HomeKit: Applying cached HomeKit data to \(host) - \(homeKitInfo.deviceName)")
        }

        var device = EnhancedDevice(
            ipAddress: host,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: detectDeviceType(openPorts: openPorts, manufacturer: manufacturer, hostname: hostname),
            openPorts: openPorts,
            isOnline: true,
            firstSeen: firstSeen,
            lastSeen: Date(),
            isKnownDevice: isKnown,
            operatingSystem: nil,
            deviceName: deviceNameToUse
        )

        // Apply HomeKit info if available
        device.homeKitMDNSInfo = homeKitInfo

        return device
    }

    private func detectDeviceType(openPorts: [PortInfo], manufacturer: String? = nil, hostname: String? = nil) -> EnhancedDevice.DeviceType {
        let ports = Set(openPorts.map { $0.port })

        // Check port service names for specific device types
        let serviceNames = openPorts.compactMap { $0.service.lowercased() }

        // Bose devices detected by service name
        if serviceNames.contains(where: { $0.contains("bose") }) {
            return .iot
        }

        // Check manufacturer and hostname patterns for IoT devices first
        if let mfr = manufacturer?.lowercased() {
            // Ubiquiti - Context-aware classification
            if mfr.contains("ubiquiti") {
                // Check hostname for device type
                if let host = hostname?.lowercased() {
                    // UniFi Protect cameras are IoT
                    if host.contains("camera") || host.contains("protect") || host.contains("g3") ||
                       host.contains("g4") || host.contains("g5") || host.contains("ai") {
                        return .iot
                    }
                    // Dream Machine, switches, APs are network infrastructure
                    if host.contains("udm") || host.contains("dream") || host.contains("switch") ||
                       host.contains("ap") || host.contains("access") || host.contains("gateway") {
                        return .router
                    }
                }
                // Port-based detection: RTSP (554, 7447) = camera, other networking ports = router
                if ports.intersection([554, 7447, 7442, 7080]).count > 0 {  // RTSP and UniFi Protect ports
                    return .iot  // UniFi Protect camera
                }
                if ports.intersection([22, 80, 443, 8443]).count >= 2 {  // SSH + Web interface
                    return .router  // UniFi network device (Dream Machine, Switch, AP)
                }
                // Default: if we can't determine, assume network infrastructure
                return .router
            }

            // ALWAYS IoT manufacturers (smart home devices)
            if mfr.contains("philips lighting") || mfr.contains("hue") ||
               mfr.contains("sengled") || mfr.contains("lifx") ||
               mfr.contains("ge lighting") || mfr.contains("ikea tradfri") ||
               mfr.contains("wemo") || mfr.contains("kasa") ||
               mfr.contains("wyze") || mfr.contains("ring") ||
               mfr.contains("ecobee") || mfr.contains("nest") ||
               mfr.contains("smartthings") || mfr.contains("shelly") ||
               mfr.contains("tuya") || mfr.contains("aqara") ||
               mfr.contains("lutron") || mfr.contains("sonos") ||
               mfr.contains("koogeek") || // Koogeek smart home devices
               mfr.contains("kogeek") || // Kogeek smart home devices
               mfr.contains("bose") || // Bose smart speakers/audio
               mfr.contains("onkyo") || // Onkyo receivers/audio
               mfr.contains("amazon") && !mfr.contains("aws") ||  // Amazon Echo, not AWS servers
               mfr.contains("google") && !mfr.contains("cloud") || // Google Home, not Google Cloud
               mfr.contains("xiaomi") ||
               mfr.contains("espressif") ||  // ESP32/ESP8266 - always IoT
               mfr.contains("azurewave technology") ||  // WiFi modules for IoT
               mfr.contains("texas instruments") && ports.intersection([1883, 8883, 8123, 49152, 32498]).count > 0 {  // TI chips in IoT context
                return .iot
            }

            // HP devices - printers
            if mfr.contains("hp") || mfr.contains("hewlett") || mfr.contains("hewlett-packard") {
                return .printer
            }

            // Raspberry Pi - check if it's being used as IoT/HomeKit device or as a computer
            if mfr.contains("raspberry") {
                // If it has HomeKit/MQTT/IoT ports, classify as IoT
                if ports.intersection([1883, 8883, 8123, 49152, 32498]).count > 0 {
                    return .iot
                }
                // If it has web server + specific IoT patterns, it's likely Home Assistant, HomeBridge, etc.
                if (ports.contains(8123) || ports.contains(51826)) { // Home Assistant or HomeBridge
                    return .iot
                }
                // Check hostname for IoT patterns
                if let host = hostname?.lowercased() {
                    if host.contains("homebridge") || host.contains("homeassistant") ||
                       host.contains("pihole") || host.contains("home-") {
                        return .iot
                    }
                }
                // Otherwise, treat as a computer/server (SSH, general purpose)
                return .computer
            }

            // Apple IoT devices (Apple TV, HomePod, etc.)
            if mfr.contains("apple") {
                if let host = hostname?.lowercased() {
                    if host.contains("appletv") || host.contains("apple-tv") {
                        return .iot
                    }
                    if host.contains("homepod") || host.contains("home-pod") {
                        return .iot
                    }
                }
                // Check for Apple TV / HomePod ports (AirPlay, HomeKit)
                // HomePods typically have AirPlay (3689, 5000, 7000) and/or HomeKit (49152, 32498) ports
                if ports.intersection([3689, 5000, 7000, 32498, 49152]).count >= 1 {
                    // If it has AirPlay or HomeKit ports and is Apple, likely HomePod or Apple TV
                    return .iot
                }
                // Check for AirPlay RAOP port (often used by HomePods)
                if ports.contains(7000) || ports.contains(49152) {
                    return .iot
                }
            }
        }

        // Check hostname patterns for common IoT devices
        if let host = hostname?.lowercased() {
            // iPhones - mobile category
            if host.contains("iphone") {
                return .mobile
            }

            // mDNS networking devices
            if host.contains("_mcast") || host.contains(".mcast") || host.contains("mcast.dns") {
                return .router
            }

            // Apple IoT
            if host.contains("appletv") || host.contains("apple-tv") ||
               host.contains("homepod") || host.contains("home-pod") {
                return .iot
            }

            // Bose devices
            if host.contains("bose") {
                return .iot
            }

            // Onkyo devices
            if host.contains("onkyo") {
                return .iot
            }

            // Google Home and Nest devices (more patterns)
            if host.contains("google-home") || host.contains("googlehome") ||
               host.contains("google home") || host.contains("nest-") ||
               host.contains("nest-hub") || host.contains("nesthub") ||
               host.contains("nest-mini") || host.contains("nestmini") ||
               host.contains("nest-audio") || host.contains("nestaudio") ||
               host.contains("nest-wifi") || host.contains("nestwifi") ||
               host.contains("nest-cam") || host.contains("nestcam") ||
               host.contains("nest-protect") || host.contains("chromecast") {
                return .iot
            }

            // Smart home hubs and controllers
            if host.contains("hue") || host.contains("philips") ||
               host.contains("homekit") || host.contains("homebridge") ||
               host.contains("smartthings") || host.contains("alexa") ||
               host.contains("nest") ||
               host.contains("lutron") || host.contains("caseta") ||
               host.contains("koogeek") || host.contains("kogeek") {
                return .iot
            }

            // Smart switches and outlets
            if host.contains("switch") || host.contains("plug") ||
               host.contains("outlet") || host.contains("dimmer") ||
               host.contains("bulb") || host.contains("light") {
                return .iot
            }
        }

        // Network Infrastructure (routers, switches, gateways)
        if ports.intersection([53, 67, 68]).count > 0 { return .router }

        // Servers and NAS
        if ports.intersection([3306, 5432, 1433, 27017]).count > 0 { return .server }
        if ports.intersection([5000, 5001]).count > 0 && ports.contains(22) { return .server } // Synology NAS
        if ports.intersection([8080, 8443, 9000]).count > 0 && ports.contains(22) { return .server } // Web/App servers

        // Printers
        if ports.intersection([631, 9100]).count > 0 { return .printer }

        // IoT devices (MQTT, HomeKit, smart home)
        if ports.intersection([1883, 8883, 1400]).count > 0 { return .iot } // MQTT, Sonos
        if ports.intersection([49152, 32498]).count > 0 { return .iot } // HomeKit accessory ports (HomePods, etc.)

        // Apple AirPlay devices (HomePods, Apple TVs) - fallback if manufacturer not detected
        if ports.intersection([3689, 5000, 7000]).count >= 2 { return .iot } // AirPlay ports

        // Computers (file sharing, SMB)
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
            "28:CD:C1": "Raspberry Pi Foundation",
            "2C:CF:67": "Raspberry Pi Foundation",
            "B8:27:EB": "Raspberry Pi Foundation",
            "D8:3A:DD": "Raspberry Pi Foundation",
            "DC:A6:32": "Raspberry Pi Foundation",
            "DC:EB:69": "Raspberry Pi Foundation",
            "E4:5F:01": "Raspberry Pi Foundation",

            // Common IoT Device Manufacturers
            "40:9F:38": "AzureWave Technology",  // WiFi modules for IoT
            "B4:BC:7C": "Texas Instruments",     // TI IoT chips (smart switches, sensors)
            "C4:F7:C1": "Espressif",            // ESP32/ESP8266 WiFi modules (very common in DIY IoT)
            "24:0A:C4": "Espressif",            // ESP32/ESP8266
            "A4:CF:12": "Espressif",            // ESP32/ESP8266
            "3C:71:BF": "Espressif",            // ESP8266
            "30:AE:A4": "Espressif",            // ESP32
            "DC:4F:22": "Espressif",            // ESP32
            "58:D3:49": "Philips Lighting",     // Philips Hue
            "00:17:88": "Philips Lighting",     // Philips Hue
            "EC:B5:FA": "Philips Lighting",     // Philips Hue
            "40:ED:CF": "Sengled",              // Sengled smart bulbs
            "C0:97:27": "Samsung SmartThings",  // SmartThings IoT hub
            "D0:52:A8": "Samsung SmartThings",  // SmartThings IoT hub
            "28:6D:97": "Amazon",               // Echo devices
            "00:FC:8B": "Amazon",               // Echo/Alexa devices
            "84:D6:D0": "Amazon",               // Echo/Alexa devices
            "AC:63:BE": "Amazon",               // Echo/Alexa devices
            "6C:56:97": "Google",               // Google Home/Nest
            "F4:F5:D8": "Google",               // Google Home/Nest
            "48:D6:D5": "Google",               // Google Home/Nest
            "1C:F2:9A": "Sonos",                // Sonos smart speakers
            "5C:AA:FD": "Sonos",                // Sonos smart speakers
            "94:9F:3E": "Sonos",                // Sonos smart speakers
            "B8:E9:37": "Sonos",                // Sonos smart speakers
            "00:0E:58": "Sonos",                // Sonos smart speakers
            "54:2A:1B": "TP-Link Kasa",         // Kasa smart plugs/switches
            // "50:C7:BF": "TP-Link Kasa" - duplicate entry, already assigned to TP-Link above
            "B0:95:75": "TP-Link Kasa",         // Kasa smart devices
            "C0:06:C3": "TP-Link Kasa",         // Kasa smart devices
            "44:32:C8": "Wyze Labs",            // Wyze cameras, sensors
            "7C:78:B2": "Wyze Labs",            // Wyze devices
            "2C:AA:8E": "Wyze Labs",            // Wyze devices
            "D0:3F:27": "Xiaomi",               // Xiaomi smart home devices
            "64:90:C1": "Xiaomi",               // Xiaomi IoT
            "34:CE:00": "Xiaomi",               // Xiaomi IoT
            "50:EC:50": "Xiaomi",               // Xiaomi IoT
            "6C:5A:B0": "LIFX",                 // LIFX smart bulbs
            "D0:73:D5": "LIFX",                 // LIFX smart bulbs
            "00:22:A9": "Ring",                 // Ring doorbells/cameras
            "B4:7C:9C": "Ring",                 // Ring devices
            "1C:53:F9": "GE Lighting",          // C by GE smart bulbs
            "6C:02:E0": "Belkin Wemo",          // Wemo smart plugs
            "94:10:3E": "Belkin Wemo",          // Wemo devices
            "EC:1A:59": "Belkin Wemo",          // Wemo devices
            "DC:EF:09": "ecobee",               // ecobee smart thermostats
            "44:61:32": "ecobee",               // ecobee thermostats
            "00:09:B0": "Lutron",               // Lutron Caseta smart switches
            // "68:5B:35": "Shelly" - duplicate entry, already assigned to Apple above
            "C4:5B:BE": "Shelly",               // Shelly IoT devices
            "80:64:6F": "Tuya",                 // Tuya Smart (white label IoT platform)
            "84:F3:EB": "Tuya",                 // Tuya Smart devices
            "68:C6:3A": "Tuya",                 // Tuya Smart devices
            "1C:90:FF": "Tuya",                 // Tuya Smart devices
            "D8:1F:12": "Aqara",                // Aqara (Xiaomi) smart home
            "54:EF:44": "Aqara",                // Aqara sensors/switches
            "00:15:8D": "IKEA Tradfri",         // IKEA smart lighting
            "CC:86:EC": "IKEA Tradfri",         // IKEA smart lighting

            // Additional Google/Nest Devices
            "3C:5A:B4": "Google",               // Google Home/Nest
            "54:60:09": "Google",               // Google Nest devices
            "1C:43:09": "Google",               // Google Chromecast/Nest
            "30:FD:38": "Google",               // Google WiFi/Nest WiFi
            "CC:D7:86": "Google",               // Google Nest Protect
            "00:1A:11": "Google",               // Google devices
            "6C:56:97": "Google",               // Google Home/Nest (already listed above)
            "F4:F5:D8": "Google",               // Google Home/Nest (already listed above)
            "48:D6:D5": "Google",               // Google Home/Nest (already listed above)
            "B4:F0:AB": "Google",               // Google Chromecast
            "D0:E7:82": "Google",               // Google Home
            "A4:77:33": "Google",               // Google Nest
            "18:B4:30": "Google",               // Google devices
            "F4:60:E2": "Google",               // Google Nest Hub

            // Kogeek Smart Home Devices
            "78:A5:04": "Kogeek",               // Kogeek smart plugs, switches
            // "68:C6:3A": "Kogeek" - duplicate entry, already assigned to Tuya above
            "50:8A:06": "Kogeek",               // Kogeek smart home

            // Ubiquiti Networks (UniFi Protect cameras, Dream Machine, Access Points)
            "FC:EC:DA": "Ubiquiti",             // UniFi devices (cameras, APs, switches)
            "74:AC:B9": "Ubiquiti",             // UniFi Dream Machine, Protect cameras
            "68:D7:9A": "Ubiquiti",             // UniFi Access Points
            "04:18:D6": "Ubiquiti",             // UniFi devices
            "80:2A:A8": "Ubiquiti",             // UniFi devices
            "F0:9F:C2": "Ubiquiti",             // UniFi devices
            "24:A4:3C": "Ubiquiti",             // UniFi devices
            "18:E8:29": "Ubiquiti",             // UniFi devices
            "DC:9F:DB": "Ubiquiti",             // UniFi devices
            "F4:E2:C6": "Ubiquiti",             // UniFi devices
            "78:8A:20": "Ubiquiti",             // UniFi devices
            "44:D9:E7": "Ubiquiti",             // UniFi devices
            "E0:63:DA": "Ubiquiti",             // UniFi devices
            "B4:FB:E4": "Ubiquiti"              // UniFi devices
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

// MARK: - Device Card - Home App Style

struct DeviceCard: View {
    let device: EnhancedDevice
    let onTap: () -> Void
    let onScan: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Device Icon and Online Status
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(deviceColor.opacity(0.15))
                            .frame(width: 48, height: 48)

                        // Use manufacturer-specific icon if available, otherwise device type icon
                        let iconManager = ManufacturerIconManager.shared
                        if let manufacturerIcon = iconManager.getIcon(for: device.manufacturer) {
                            Image(systemName: manufacturerIcon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(iconManager.getColor(for: device.manufacturer) ?? deviceColor)
                        } else if let manufacturer = device.manufacturer, let logo = manufacturerLogo(manufacturer) {
                            Text(logo)
                                .font(.system(size: 24))
                        } else {
                            Image(systemName: deviceIcon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(deviceColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        // Device Role Badge
                        if let role = deviceRole {
                            Text(role)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(roleColor)
                                .cornerRadius(6)
                        }
                    }

                    Spacer()

                    // Online indicator
                    Circle()
                        .fill(device.isOnline ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                }

                // Device Name/IP
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.hostname ?? device.ipAddress)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if device.hostname != nil {
                        Text(device.ipAddress)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Manufacturer with logo
                if let manufacturer = device.manufacturer {
                    HStack(spacing: 6) {
                        if let logo = manufacturerLogo(manufacturer) {
                            Text(logo)
                                .font(.system(size: 16))
                        }
                        Text(manufacturer)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Open Ports with Names
                if !device.openPorts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "network")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                            Text("\(device.openPorts.count) ports open")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)

                        // Show first 3 ports with names
                        ForEach(device.openPorts.prefix(3)) { portInfo in
                            HStack(spacing: 6) {
                                Text("\(portInfo.port)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.blue)
                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(portInfo.service)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if device.openPorts.count > 3 {
                            Text("+ \(device.openPorts.count - 3) more")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Scan button at bottom of card
                Button(action: onScan) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Rescan")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // Determine device role based on open ports and type
    private var deviceRole: String? {
        let ports = Set(device.openPorts.map { $0.port })

        // Gateway/Router detection
        if ports.contains(53) || ports.contains(67) || ports.contains(68) {
            return "GATEWAY"
        }

        // Web Server detection
        if ports.contains(80) || ports.contains(443) || ports.contains(8080) {
            return "WEB SERVER"
        }

        // Database Server detection
        if ports.intersection([3306, 5432, 1433, 27017, 6379]).count > 0 {
            return "DATABASE"
        }

        // File Server detection
        if ports.intersection([445, 139, 548, 2049]).count > 0 {
            return "FILE SERVER"
        }

        // Print Server detection
        if ports.intersection([631, 9100]).count > 0 {
            return "PRINTER"
        }

        // Mail Server detection
        if ports.intersection([25, 465, 587, 143, 993, 110, 995]).count > 0 {
            return "MAIL SERVER"
        }

        // SSH/Remote Access detection
        if ports.contains(22) || ports.contains(3389) || ports.contains(5900) {
            return "REMOTE ACCESS"
        }

        // IoT/Smart Home detection
        if ports.intersection([1883, 8883, 8123, 1400]).count > 0 {
            return "SMART HOME"
        }

        // Media Server detection
        if ports.intersection([32400, 8096, 8920, 9091]).count > 0 {
            return "MEDIA SERVER"
        }

        // NAS detection
        if ports.intersection([5000, 5001]).count > 0 {
            return "NAS"
        }

        return nil
    }

    private var roleColor: Color {
        guard let role = deviceRole else { return .gray }

        switch role {
        case "GATEWAY": return .blue
        case "WEB SERVER": return .green
        case "DATABASE": return .purple
        case "FILE SERVER": return .orange
        case "PRINTER": return .pink
        case "MAIL SERVER": return .cyan
        case "REMOTE ACCESS": return .red
        case "SMART HOME": return .mint
        case "MEDIA SERVER": return .indigo
        case "NAS": return .teal
        default: return .gray
        }
    }

    private var deviceIcon: String {
        switch device.deviceType {
        case .router: return "wifi.router"
        case .server: return "server.rack"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "sensor.fill"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }

    private var deviceColor: Color {
        switch device.deviceType {
        case .router: return .blue
        case .server: return .purple
        case .computer: return .orange
        case .mobile: return .green
        case .iot: return .cyan
        case .printer: return .pink
        case .unknown: return .gray
        }
    }

    // Manufacturer logo/emoji mapping
    private func manufacturerLogo(_ manufacturer: String) -> String? {
        let logos: [String: String] = [
            "Apple": "🍎",
            "Microsoft": "🪟",
            "Dell": "💻",
            "HP": "🖨️",
            "Samsung": "📱",
            "Intel": "⚡️",
            "Cisco": "🌐",
            "Netgear": "📡",
            "Linksys": "📶",
            "TP-Link": "🔗",
            "D-Link": "🔌",
            "Broadcom": "📟",
            "VMware": "☁️",
            "Oracle VirtualBox": "📦",
            "QEMU/KVM": "🖥️",
            "Raspberry Pi Foundation": "🥧"
        ]

        return logos[manufacturer]
    }
}

// MARK: - Manual Scan View

struct ManualScanView: View {
    @Binding var ipAddress: String
    let onScan: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Scan Single Host")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("Enter an IP address to scan")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            TextField("192.168.1.100", text: $ipAddress)
                .font(.system(size: 17, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onScan) {
                    Text("Scan")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(ipAddress.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 500, height: 300)
    }
}

#Preview {
    IntegratedDashboardViewV3()
}
