//
//  HomeKitDiscoveryMacOS.swift
//  NMAP Scanner - HomeKit Device Discovery for macOS
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  This provides HomeKit device discovery on macOS WITHOUT requiring Mac Catalyst
//  by using Bonjour/mDNS and Home.app database integration
//

import Foundation
import SwiftUI
import Network

/// HomeKit Device Discovery for macOS
/// Uses Bonjour/mDNS and Home.app integration instead of HomeKit framework
@MainActor
class HomeKitDiscoveryMacOS: ObservableObject {
    static let shared = HomeKitDiscoveryMacOS()

    @Published var isAuthorized = false
    @Published var discoveredDevices: [HomeKitDevice] = []
    @Published var devicesByIP: [String: HomeKitDevice] = [:]
    @Published var lastSync: Date?
    @Published var authorizationStatus: String = "Ready"
    @Published var isScanning = false
    @Published var discoveryHistory: [DiscoveryEvent] = []

    private var browsers: [NWBrowser] = []
    private let browserQueue = DispatchQueue(label: "com.nmapscanner.homekit")

    /// HomeKit-specific service types
    private let homeKitServiceTypes = [
        "_homekit._tcp",           // HomeKit general
        "_hap._tcp",               // HomeKit Accessory Protocol
        "_airplay._tcp",           // AirPlay (many HomeKit devices)
        "_raop._tcp",              // Remote Audio (HomePod)
        "_companion-link._tcp",    // Apple ecosystem devices
        "_sleep-proxy._udp"        // Network infrastructure
    ]

    private init() {}

    // MARK: - Discovery

    /// Start HomeKit device discovery
    func requestAuthorization() {
        print("🏠 HomeKit Discovery: Starting macOS-compatible discovery...")
        authorizationStatus = "Scanning for HomeKit devices..."
        Task {
            await startDiscovery()
        }
    }

    /// Quick Scan (5 seconds) - Fast discovery
    func startQuickScan() async {
        await performScan(duration: 5_000_000_000, label: "Quick")
    }

    /// Deep Scan (30 seconds) - Thorough discovery
    func startDeepScan() async {
        await performScan(duration: 30_000_000_000, label: "Deep")
    }

    /// Discover HomeKit devices using Bonjour/mDNS (standard 15 second scan)
    func startDiscovery() async {
        await performScan(duration: 15_000_000_000, label: "Standard")
    }

    /// Generic scan method with configurable duration
    private func performScan(duration: UInt64, label: String) async {
        await MainActor.run {
            isScanning = true
            isAuthorized = true  // No authorization needed for mDNS
            // Don't clear devices - allow accumulation across scans
            // discoveredDevices = []
            // devicesByIP = [:]
        }

        print("🏠 HomeKit Discovery: Starting \(label) scan (\(duration / 1_000_000_000)s)...")

        // Create browsers for HomeKit-specific services
        for serviceType in homeKitServiceTypes {
            await createBrowser(for: serviceType)
        }

        // Wait for discovery (configurable duration)
        try? await Task.sleep(nanoseconds: duration)

        // Stop browsers
        await stopBrowsers()

        await MainActor.run {
            isScanning = false
            lastSync = Date()
            authorizationStatus = "Found \(discoveredDevices.count) HomeKit devices"
            print("🏠 HomeKit Discovery: \(label) scan complete - \(discoveredDevices.count) devices found")
        }

        // Try to read from Home.app database
        await readHomeAppDatabase()

        // Enrich existing network scan devices with HomeKit info
        if discoveredDevices.count > 0 {
            print("🏠 HomeKit Discovery: Enriching scanner devices with HomeKit data...")
            await IntegratedScannerV3.shared.enrichDevicesWithHomeKit()
        }
    }

    /// Create browser for a specific service type
    private func createBrowser(for serviceType: String) async {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("🏠 HomeKit Discovery: Browser ready for \(serviceType)")
            case .failed(let error):
                print("🏠 HomeKit Discovery: Browser failed for \(serviceType): \(error)")
            case .cancelled:
                print("🏠 HomeKit Discovery: Browser cancelled for \(serviceType)")
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                await self?.processResults(results, serviceType: serviceType)
            }
        }

        browser.start(queue: browserQueue)
        await MainActor.run {
            self.browsers.append(browser)
        }
    }

    /// Process discovered service results
    private func processResults(_ results: Set<NWBrowser.Result>, serviceType: String) async {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, let interface):
                print("🏠 HomeKit Discovery: Found \(name) (\(type)) on \(interface?.name ?? "unknown")")

                // Extract device information
                let device = HomeKitDevice(
                    name: name,
                    serviceType: type,
                    domain: domain ?? "local.",
                    interface: interface?.name,
                    discoveredAt: Date()
                )

                await MainActor.run {
                    // Add or update device (deduplicate by device name)
                    if let existingIndex = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                        // Device already exists - prefer HAP/HomeKit service types over AirPlay
                        let existing = discoveredDevices[existingIndex]
                        if device.isHomeKitAccessory && !existing.isHomeKitAccessory {
                            // Upgrade to HomeKit service type
                            discoveredDevices[existingIndex] = device
                            print("🏠 HomeKit Discovery: Upgraded \(device.name) to HomeKit service")

                            // Log update event
                            let event = DiscoveryEvent(
                                timestamp: Date(),
                                eventType: .updated,
                                deviceName: device.displayName,
                                deviceIP: device.ipAddress,
                                serviceType: device.serviceType
                            )
                            discoveryHistory.insert(event, at: 0)
                        }
                    } else {
                        // New device
                        discoveredDevices.append(device)
                        print("🏠 HomeKit Discovery: Added device: \(device.name)")

                        // Log discovery event
                        let event = DiscoveryEvent(
                            timestamp: Date(),
                            eventType: .discovered,
                            deviceName: device.displayName,
                            deviceIP: device.ipAddress,
                            serviceType: device.serviceType
                        )
                        discoveryHistory.insert(event, at: 0)
                    }
                }

                // Try to resolve IP address
                await resolveIPAddress(for: result, device: device)

            default:
                break
            }
        }
    }

    /// Resolve IP address for a discovered device
    private func resolveIPAddress(for result: NWBrowser.Result, device: HomeKitDevice) async {
        guard case .service(let name, let type, let domain, _) = result.endpoint else { return }

        let connection = NWConnection(to: .service(name: name, type: type, domain: domain, interface: nil), using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, _) = endpoint {
                    Task { @MainActor in
                        let ipAddress = "\(host)"
                        print("🏠 HomeKit Discovery: Resolved \(device.name) to \(ipAddress)")

                        // Update device with IP
                        var updatedDevice = device
                        updatedDevice.ipAddress = ipAddress

                        if let index = self?.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                            self?.discoveredDevices[index] = updatedDevice
                            self?.devicesByIP[ipAddress] = updatedDevice
                        }
                    }
                }
                connection.cancel()
            }
        }

        connection.start(queue: browserQueue)

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            connection.cancel()
        }
    }

    /// Stop all browsers
    private func stopBrowsers() async {
        await MainActor.run {
            for browser in browsers {
                browser.cancel()
            }
            browsers.removeAll()
        }
    }

    /// Read HomeKit data from Home.app database (best effort)
    private func readHomeAppDatabase() async {
        // Home.app stores data in ~/Library/HomeKit/
        let homeKitPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/HomeKit")

        print("🏠 HomeKit Discovery: Checking Home.app data at \(homeKitPath.path)")

        guard FileManager.default.fileExists(atPath: homeKitPath.path) else {
            print("🏠 HomeKit Discovery: No Home.app data found")
            return
        }

        // Try to find configuration files
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: homeKitPath, includingPropertiesForKeys: nil)
            print("🏠 HomeKit Discovery: Found \(contents.count) files in HomeKit directory")

            // Look for plist files
            for file in contents where file.pathExtension == "plist" {
                await parseHomeKitPlist(at: file)
            }
        } catch {
            print("🏠 HomeKit Discovery: Error reading Home.app data: \(error)")
        }
    }

    /// Parse HomeKit plist file
    private func parseHomeKitPlist(at url: URL) async {
        print("🏠 HomeKit Discovery: Parsing \(url.lastPathComponent)")

        do {
            let data = try Data(contentsOf: url)
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                print("🏠 HomeKit Discovery: Found plist with \(plist.keys.count) keys")
                // Extract relevant HomeKit device information
                // Note: This is best-effort parsing of Home.app's internal format
            }
        } catch {
            print("🏠 HomeKit Discovery: Error parsing plist: \(error)")
        }
    }

    /// Get device info for an IP address
    func getDeviceInfo(for ipAddress: String) -> HomeKitDevice? {
        return devicesByIP[ipAddress]
    }
}

// MARK: - Data Models

/// HomeKit Device discovered via mDNS
struct HomeKitDevice: Identifiable, Hashable {
    let name: String
    let serviceType: String
    let domain: String
    let interface: String?
    let discoveredAt: Date
    var ipAddress: String?
    var txtRecords: [String: String]?  // mDNS TXT records

    /// Stable ID based on name to deduplicate devices across service types
    var id: String {
        // Use device name as primary key for deduplication
        // Same device advertising multiple services (_hap, _airplay, etc.) will have same ID
        return name
    }

    /// Hash based on device name for Set operations
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    /// Equality based on device name for deduplication
    static func == (lhs: HomeKitDevice, rhs: HomeKitDevice) -> Bool {
        return lhs.name == rhs.name
    }

    /// Friendly display name
    var displayName: String {
        // Clean up the name (remove service type suffixes)
        let cleanName = name
            .replacingOccurrences(of: "._homekit._tcp", with: "")
            .replacingOccurrences(of: "._hap._tcp", with: "")
            .replacingOccurrences(of: "._airplay._tcp", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleanName.isEmpty ? "HomeKit Device" : cleanName
    }

    /// Device category based on service type
    var category: String {
        if serviceType.contains("airplay") {
            return "AirPlay Device"
        } else if serviceType.contains("hap") || serviceType.contains("homekit") {
            return "HomeKit Accessory"
        } else if serviceType.contains("companion") {
            return "Apple Device"
        } else {
            return "Smart Home Device"
        }
    }

    /// Check if this is a genuine HomeKit device
    var isHomeKitAccessory: Bool {
        return serviceType.contains("hap") || serviceType.contains("homekit")
    }
}

// MARK: - Settings View

struct HomeKitDiscoverySettingsView: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("HomeKit Device Discovery")
                .font(.system(size: 22, weight: .semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("HomeKit (mDNS)", systemImage: "homekit")
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        if homeKitDiscovery.isAuthorized {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Active")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if homeKitDiscovery.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    Text("Discovers HomeKit and smart home devices using Bonjour/mDNS network discovery. No iOS HomeKit framework required.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(homeKitDiscovery.authorizationStatus)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    HStack(spacing: 12) {
                        Button(homeKitDiscovery.isScanning ? "Scanning..." : "Discover Devices") {
                            homeKitDiscovery.requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(homeKitDiscovery.isScanning)

                        if homeKitDiscovery.isAuthorized && !homeKitDiscovery.discoveredDevices.isEmpty {
                            Button("Rescan") {
                                Task {
                                    await homeKitDiscovery.startDiscovery()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if homeKitDiscovery.isAuthorized && !homeKitDiscovery.discoveredDevices.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(homeKitDiscovery.discoveredDevices.count)")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("Devices")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(homeKitDiscovery.discoveredDevices.filter { $0.isHomeKitAccessory }.count)")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("HomeKit")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(homeKitDiscovery.devicesByIP.count)")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("With IPs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let lastSync = homeKitDiscovery.lastSync {
                                Text("Last scanned: \(lastSync, style: .relative) ago")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
            }

            // Device list
            if !homeKitDiscovery.discoveredDevices.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Discovered HomeKit Devices")
                            .font(.system(size: 15, weight: .medium))

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(homeKitDiscovery.discoveredDevices.sorted(by: { $0.name < $1.name })) { device in
                                    HomeKitDeviceRow(device: device)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding(16)
                }
            }
        }
    }
}

struct HomeKitDeviceRow: View {
    let device: HomeKitDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.isHomeKitAccessory ? "homekit" : "network")
                .font(.system(size: 20))
                .foregroundColor(device.isHomeKitAccessory ? .orange : .blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 13, weight: .medium))

                HStack(spacing: 8) {
                    Text(device.category)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let ip = device.ipAddress {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(ip)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if device.isHomeKitAccessory {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Discovery History

/// Discovery event for timeline tracking
struct DiscoveryEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let eventType: EventType
    let deviceName: String
    let deviceIP: String?
    let serviceType: String

    enum EventType: String {
        case discovered = "Discovered"
        case updated = "Updated"
        case disappeared = "Disappeared"
    }

    var icon: String {
        switch eventType {
        case .discovered:
            return "plus.circle.fill"
        case .updated:
            return "arrow.triangle.2.circlepath"
        case .disappeared:
            return "minus.circle.fill"
        }
    }

    var color: Color {
        switch eventType {
        case .discovered:
            return .green
        case .updated:
            return .blue
        case .disappeared:
            return .orange
        }
    }
}
