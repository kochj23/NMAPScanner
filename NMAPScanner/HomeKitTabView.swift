//
//  HomeKitTabView.swift
//  NMAPScanner
//
//  Created by Jordan Koch on 2025-11-30.
//  HomeKit device discovery and management tab
//

import SwiftUI

/// HomeKit discovery tab view - Uses network scanning to detect HomeKit devices
struct HomeKitTabView: View {
    @StateObject private var scanner = IntegratedScannerV3.shared
    @StateObject private var bonjourScanner = BonjourScanner()
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var scanStatus: String = ""
    @State private var homeKitDevices: [EnhancedDevice] = []

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HomeKit Device Discovery")
                        .font(.system(size: 36, weight: .bold))

                    Text("Scanning for HomeKit accessories via mDNS and port detection")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    Task {
                        await scanForHomeKitDevices()
                    }
                }) {
                    HStack {
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isScanning ? "Scanning..." : "Scan Network")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isScanning)
            }
            .padding(.horizontal)

            Divider()

            // Scanning Progress Bar
            if isScanning {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Scanning for HomeKit Devices")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    ProgressView(value: scanProgress)
                        .tint(.blue)

                    Text(scanStatus)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }

            // Device List
            if homeKitDevices.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "homekit")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("No HomeKit Devices Found")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Click 'Scan Network' to discover HomeKit accessories")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if !isScanning {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HomeKit devices are identified by:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text("• HAP (HomeKit Accessory Protocol) on port 49152")
                            Text("• mDNS service advertisements (_hap._tcp)")
                            Text("• Common Apple device ports (AirPlay, etc.)")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
                        ForEach(homeKitDevices) { device in
                            HomeKitDeviceCard(device: device)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            // Initial scan when tab appears
            updateHomeKitDevices()
        }
        .onChange(of: scanner.devices) { _, _ in
            updateHomeKitDevices()
        }
    }

    private func scanForHomeKitDevices() async {
        isScanning = true
        scanProgress = 0
        scanStatus = "Starting HomeKit discovery..."
        print("🏠 HomeKit: ========== OPTIMIZED HOMEKIT DISCOVERY STARTING ==========")

        // OPTIMIZATION: Use HomeKit-specific port list (only 6 ports instead of 40+)
        scanner.customPortList = CommonPorts.homeKit
        print("🏠 HomeKit: Using optimized port list - \(CommonPorts.homeKit.count) ports: \(CommonPorts.homeKit)")

        // PHASE 1: Bonjour/mDNS Discovery (0-25%) with Smart Early Termination
        print("🏠 HomeKit: Phase 1 - Bonjour/mDNS discovery (with early termination)...")
        scanStatus = "Phase 1/6: Scanning via Bonjour/mDNS..."
        scanProgress = 0.05

        await bonjourScanner.startScan()
        let bonjourIPs = bonjourScanner.getDiscoveredIPs()
        print("🏠 HomeKit: Bonjour found \(bonjourIPs.count) unique IPs")
        scanStatus = "Phase 1/6: Found \(bonjourIPs.count) devices via Bonjour"
        scanProgress = 0.25

        // PHASE 2: Import Bonjour devices into scanner (25-40%)
        print("🏠 HomeKit: Phase 2 - Importing Bonjour devices...")
        scanStatus = "Phase 2/6: Importing discovered devices..."
        scanProgress = 0.30

        await scanner.importBonjourDevices(bonjourIPs, bonjourScanner: bonjourScanner)
        print("🏠 HomeKit: Imported \(scanner.devices.count) devices from Bonjour")
        scanStatus = "Phase 2/6: Imported \(scanner.devices.count) devices"
        scanProgress = 0.40

        // PHASE 3: PARALLEL Port scanning on discovered devices (40-60%)
        print("🏠 HomeKit: Phase 3 - Parallel port scanning on \(scanner.devices.count) devices...")
        scanStatus = "Phase 3/6: Parallel scanning \(CommonPorts.homeKit.count) ports on \(scanner.devices.count) devices..."
        scanProgress = 0.45

        await scanner.scanPortsOnDevices()
        print("🏠 HomeKit: Port scanning complete")
        scanStatus = "Phase 3/6: Port scanning complete"
        scanProgress = 0.60

        // PHASE 4: dns-sd direct lookup for _hap._tcp (60-75%)
        print("🏠 HomeKit: Phase 4 - Running dns-sd for _hap._tcp...")
        scanStatus = "Phase 4/6: Running dns-sd discovery..."
        scanProgress = 0.65

        let dnssdDevices = await discoverViaDNSSD()
        print("🏠 HomeKit: dns-sd found \(dnssdDevices.count) additional devices")
        scanStatus = "Phase 4/6: Found \(dnssdDevices.count) devices via dns-sd"
        scanProgress = 0.75

        // PHASE 5: Combine all discovery methods (75-85%)
        print("🏠 HomeKit: Phase 5 - Combining all discovery methods...")
        scanStatus = "Phase 5/6: Combining discovery results..."
        scanProgress = 0.78

        var allDiscoveredIPs = Set<String>()
        var discoveredDevices: [EnhancedDevice] = []

        // Add Bonjour-discovered devices
        for device in scanner.devices {
            allDiscoveredIPs.insert(device.ipAddress)
        }

        // Add dns-sd discovered IPs
        for ip in dnssdDevices {
            allDiscoveredIPs.insert(ip)
        }

        print("🏠 HomeKit: Total unique IPs from all methods: \(allDiscoveredIPs.count)")
        scanStatus = "Phase 5/6: Combined \(allDiscoveredIPs.count) unique devices"
        scanProgress = 0.85

        // PHASE 6: Create enhanced devices with all metadata (85-100%)
        print("🏠 HomeKit: Phase 6 - Creating enhanced devices...")
        scanStatus = "Phase 6/6: Enriching device metadata..."
        scanProgress = 0.88
        for ip in allDiscoveredIPs {
            // Check if we have an existing device from scanner
            if let existingDevice = scanner.devices.first(where: { $0.ipAddress == ip }) {
                // Use existing device with port data
                let device = existingDevice

                // Get TXT record metadata
                let metadata = bonjourScanner.getMetadata(for: ip)
                let services = bonjourScanner.getServices(for: ip)

                // Update with TXT metadata if available
                if let metadata = metadata {
                    print("🏠 HomeKit: ✅ \(ip) - \(metadata.displayName) (\(metadata.category))")
                    // Create new device with updated name
                    var updatedDevice = EnhancedDevice(
                        ipAddress: device.ipAddress,
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
                        deviceName: metadata.displayName
                    )
                    updatedDevice.homeKitMDNSInfo = HomeKitMDNSInfo(
                        deviceName: metadata.displayName,
                        serviceType: services.joined(separator: ", "),
                        category: metadata.category,
                        isHomeKitAccessory: true,
                        discoveredAt: Date()
                    )
                    discoveredDevices.append(updatedDevice)
                } else {
                    print("🏠 HomeKit: ✅ \(ip) - (No TXT metadata)")
                    discoveredDevices.append(device)
                }
            } else {
                // Create new device from dns-sd only
                print("🏠 HomeKit: ✅ \(ip) - (dns-sd only, creating new device)")

                let metadata = bonjourScanner.getMetadata(for: ip)
                let services = bonjourScanner.getServices(for: ip)
                let deviceName = metadata?.displayName ?? ip
                let category = metadata?.category ?? "HomeKit Accessory"

                let homeKitInfo = HomeKitMDNSInfo(
                    deviceName: deviceName,
                    serviceType: services.joined(separator: ", "),
                    category: category,
                    isHomeKitAccessory: true,
                    discoveredAt: Date()
                )

                var device = EnhancedDevice(
                    ipAddress: ip,
                    macAddress: nil,
                    hostname: nil,
                    manufacturer: "Apple",
                    deviceType: .iot,
                    openPorts: [],
                    isOnline: true,
                    firstSeen: Date(),
                    lastSeen: Date(),
                    isKnownDevice: false,
                    operatingSystem: nil,
                    deviceName: deviceName
                )
                device.homeKitMDNSInfo = homeKitInfo
                discoveredDevices.append(device)
            }
        }

        scanStatus = "Finalizing results..."
        scanProgress = 0.95

        print("🏠 HomeKit: ========== DISCOVERY COMPLETE ==========")
        print("🏠 HomeKit: Final count - \(discoveredDevices.count) HomeKit devices")
        print("🏠 HomeKit: Bonjour IPs: \(bonjourIPs.count)")
        print("🏠 HomeKit: dns-sd IPs: \(dnssdDevices.count)")
        print("🏠 HomeKit: Combined unique IPs: \(allDiscoveredIPs.count)")

        // Update device lists
        scanner.devices = discoveredDevices
        homeKitDevices = discoveredDevices

        scanStatus = "Discovery complete - \(discoveredDevices.count) HomeKit devices found"
        scanProgress = 1.0

        // Small delay to show completion before hiding progress
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        isScanning = false
    }

    /// Direct dns-sd discovery for _hap._tcp devices
    private func discoverViaDNSSD() async -> Set<String> {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var discoveredIPs = Set<String>()

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
                process.arguments = ["-B", "_hap._tcp", "."]

                let pipe = Pipe()
                process.standardOutput = pipe

                // Run for 10 seconds to collect results
                var timedOut = false
                let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                    if process.isRunning {
                        process.terminate()
                        timedOut = true
                    }
                }
                defer { timer.invalidate() }
                RunLoop.current.add(timer, forMode: .common)

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        print("🏠 HomeKit: dns-sd output lines: \(output.components(separatedBy: .newlines).count)")

                        // Parse output for service names
                        let lines = output.components(separatedBy: .newlines)
                        var serviceNames: [String] = []

                        for line in lines {
                            if line.contains("Add") && line.contains("_hap._tcp") {
                                // Extract service name from: "Add     3  6 local.  _hap._tcp.  Eve\032Energy\032Strip\032_27CD"
                                let components = line.components(separatedBy: "_hap._tcp.")
                                if components.count > 1 {
                                    let serviceName = components[1].trimmingCharacters(in: .whitespaces)
                                    if !serviceName.isEmpty {
                                        serviceNames.append(serviceName)
                                    }
                                }
                            }
                        }

                        print("🏠 HomeKit: dns-sd found \(serviceNames.count) service names")

                        // Resolve each service to get IP
                        for serviceName in serviceNames.prefix(50) { // Limit to 50 to avoid hanging
                            if let ip = self.resolveServiceToIP(serviceName) {
                                discoveredIPs.insert(ip)
                                print("🏠 HomeKit: dns-sd resolved \(serviceName) -> \(ip)")
                            }
                        }
                    }
                } catch {
                    print("🏠 HomeKit: dns-sd error: \(error)")
                }

                continuation.resume(returning: discoveredIPs)
            }
        }
    }

    /// Resolve a service name to IP address using dns-sd
    private func resolveServiceToIP(_ serviceName: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        process.arguments = ["-L", serviceName, "_hap._tcp", "local."]

        let pipe = Pipe()
        process.standardOutput = pipe

        var timedOut = false
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            if process.isRunning {
                process.terminate()
                timedOut = true
            }
        }
        defer { timer.invalidate() }

        do {
            try process.run()
            process.waitUntilExit()

            guard !timedOut else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for IP address in output
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    // Look for IPv4 addresses
                    if let range = line.range(of: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#, options: .regularExpression) {
                        return String(line[range])
                    }
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private func updateHomeKitDevices() {
        // Filter devices that are HomeKit accessories based on service types
        homeKitDevices = scanner.devices.filter { device in
            // Check service type for HomeKit/Apple indicators
            if let serviceType = device.serviceType {
                return serviceType.contains("_hap._tcp") ||
                       serviceType.contains("_homekit._tcp") ||
                       serviceType.contains("_airplay._tcp") ||
                       serviceType.contains("_raop._tcp") ||
                       serviceType.contains("_companion-link._tcp")
            }

            // Fallback to port-based detection if no service type
            let ports = device.openPorts.map { $0.port }
            let hasHAPPort = ports.contains(49152)
            let hasAirPlay = ports.contains(5000) || ports.contains(7000)
            let hasApplePorts = HomeKitPortDefinitions.isLikelyHomeKitAccessory(ports: ports)

            return hasHAPPort || hasAirPlay || hasApplePorts
        }
    }
}

// MARK: - HomeKit Device Card

struct HomeKitDeviceCard: View {
    let device: EnhancedDevice
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: deviceIcon)
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    // Show device name from metadata or hostname/IP
                    Text(device.deviceName ?? device.hostname ?? device.ipAddress)
                        .font(.system(size: 18, weight: .semibold))

                    // Show category from metadata or detected type
                    if let category = device.homeKitMDNSInfo?.category {
                        Text(category)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    } else if let deviceType = device.detectAppleDeviceType() {
                        Text(deviceType)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }

                    Text(device.ipAddress)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(device.isOnline ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
            }

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if let manufacturer = device.manufacturer {
                        infoRow(label: "Manufacturer", value: manufacturer)
                    }

                    if let serviceType = device.serviceType {
                        infoRow(label: "Service", value: serviceType)
                    }

                    if !device.openPorts.isEmpty {
                        infoRow(label: "Open Ports", value: device.openPorts.prefix(5).map { "\($0.port)" }.joined(separator: ", "))
                    }

                    infoRow(label: "Last Seen", value: DateFormatter.localizedString(from: device.lastSeen, dateStyle: .short, timeStyle: .short))
                }
                .font(.system(size: 13))
            }

            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var deviceIcon: String {
        let ports = device.openPorts.map { $0.port }

        if HomeKitPortDefinitions.isLikelyHomePod(ports: ports) {
            return "homepod.fill"
        } else if HomeKitPortDefinitions.isLikelyAppleTV(ports: ports) {
            return "appletv.fill"
        } else if ports.contains(49152) {
            return "homekit"
        } else {
            return "sensor.fill"
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
            Spacer()
        }
    }
}

#Preview {
    HomeKitTabView()
}
