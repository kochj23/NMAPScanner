//
//  DashboardView.swift
//  NMAP Scanner - Main Dashboard
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import SwiftUI
import Network

struct DashboardView: View {
    @StateObject private var scanner = NMAPScanner()
    @StateObject private var deviceManager = DeviceManager.shared
    @State private var selectedDevice: DiscoveredDevice?
    @State private var showingScanSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header with status
                    DashboardHeader(scanner: scanner, deviceManager: deviceManager)

                    // Quick Actions
                    QuickActionsGrid(scanner: scanner, showingScanSettings: $showingScanSettings)

                    // Network Topology
                    if !deviceManager.discoveredDevices.isEmpty {
                        NetworkTopologyCard(devices: deviceManager.discoveredDevices)
                    }

                    // Discovered Devices
                    if !deviceManager.discoveredDevices.isEmpty {
                        DiscoveredDevicesSection(
                            devices: deviceManager.discoveredDevices,
                            selectedDevice: $selectedDevice
                        )
                    }

                    // Security Overview
                    if deviceManager.hasSecurityFindings {
                        SecurityOverviewCard()
                    }
                }
                .padding(40)
            }
            .navigationTitle("NMAP Scanner")
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailView(device: device)
        }
        .sheet(isPresented: $showingScanSettings) {
            ScanSettingsView(scanner: scanner)
        }
    }
}

struct DashboardHeader: View {
    @ObservedObject var scanner: NMAPScanner
    @ObservedObject var deviceManager: DeviceManager

    var body: some View {
        HStack(spacing: 40) {
            // Network Status
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(scanner.isScanning ? "Scanning..." : "Ready")
                            .font(.system(size: 28, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)

            // Devices Found
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Devices")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(deviceManager.discoveredDevices.count)")
                            .font(.system(size: 28, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)

            // Security Score
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: deviceManager.securityScore > 70 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 36))
                        .foregroundColor(deviceManager.securityScore > 70 ? .green : .red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(deviceManager.securityScore)/100")
                            .font(.system(size: 28, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background((deviceManager.securityScore > 70 ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(16)
        }
    }
}

struct QuickActionsGrid: View {
    @ObservedObject var scanner: NMAPScanner
    @Binding var showingScanSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quick Actions")
                .font(.system(size: 32, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                // Scan Network
                Button(action: {
                    showingScanSettings = true
                }) {
                    QuickActionCard(
                        icon: "magnifyingglass",
                        title: "Scan Network",
                        subtitle: "Discover devices",
                        color: .blue,
                        isActive: scanner.isScanning
                    )
                }
                .buttonStyle(.plain)

                // Network Topology
                NavigationLink(destination: NetworkTopologyView()) {
                    QuickActionCard(
                        icon: "network",
                        title: "Topology",
                        subtitle: "Network map",
                        color: .purple,
                        isActive: false
                    )
                }
                .buttonStyle(.plain)

                // Vulnerability Scan
                NavigationLink(destination: VulnerabilityView()) {
                    QuickActionCard(
                        icon: "exclamationmark.shield",
                        title: "Vulnerabilities",
                        subtitle: "Security scan",
                        color: .red,
                        isActive: false
                    )
                }
                .buttonStyle(.plain)

                // Traffic Monitor
                NavigationLink(destination: NetworkTrafficView()) {
                    QuickActionCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Traffic",
                        subtitle: "Monitor connections",
                        color: .green,
                        isActive: false
                    )
                }
                .buttonStyle(.plain)

                // Packet Capture
                NavigationLink(destination: PacketCaptureView()) {
                    QuickActionCard(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Packets",
                        subtitle: "Capture traffic",
                        color: .orange,
                        isActive: false
                    )
                }
                .buttonStyle(.plain)

                // Security Audit
                NavigationLink(destination: SecurityAuditView()) {
                    QuickActionCard(
                        icon: "checkmark.shield",
                        title: "Audit",
                        subtitle: "Security check",
                        color: .cyan,
                        isActive: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }

            if isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}

struct NetworkTopologyCard: View {
    let devices: [DiscoveredDevice]

    var body: some View {
        NavigationLink(destination: NetworkTopologyView()) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Network Topology")
                        .font(.system(size: 32, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }

                // Mini topology preview
                GeometryReader { geometry in
                    ZStack {
                        // Gateway/Router in center
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                        // Devices around router
                        ForEach(Array(devices.prefix(8).enumerated()), id: \.element.id) { index, device in
                            let angle = Double(index) * (360.0 / 8.0) * .pi / 180.0
                            let radius = min(geometry.size.width, geometry.size.height) / 3
                            let x = geometry.size.width / 2 + cos(angle) * radius
                            let y = geometry.size.height / 2 + sin(angle) * radius

                            Circle()
                                .fill(deviceColor(device))
                                .frame(width: 40, height: 40)
                                .position(x: x, y: y)

                            // Connection line
                            Path { path in
                                path.move(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        }
                    }
                }
                .frame(height: 250)

                Text("\(devices.count) devices connected")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func deviceColor(_ device: DiscoveredDevice) -> Color {
        if device.vulnerabilities > 0 { return .red }
        if device.openPorts.count > 5 { return .orange }
        return .green
    }
}

struct DiscoveredDevicesSection: View {
    let devices: [DiscoveredDevice]
    @Binding var selectedDevice: DiscoveredDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Discovered Devices")
                    .font(.system(size: 32, weight: .semibold))
                Spacer()
                Text("\(devices.count) total")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(devices) { device in
                    Button(action: {
                        selectedDevice = device
                    }) {
                        ModernDeviceCard(device: device)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ModernDeviceCard: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Device icon
                ZStack {
                    Circle()
                        .fill(deviceColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: deviceIcon)
                        .font(.system(size: 28))
                        .foregroundColor(deviceColor)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(device.isOnline ? Color.green : Color.gray)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(device.hostname ?? "Unknown Device")
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(1)

                Text(device.ipAddress)
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(.secondary)

                if let manufacturer = device.manufacturer {
                    Text(manufacturer)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack(spacing: 20) {
                Label("\(device.openPorts.count)", systemImage: "network")
                    .font(.system(size: 18))

                if device.vulnerabilities > 0 {
                    Label("\(device.vulnerabilities)", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue.opacity(0.6))
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(deviceColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var deviceIcon: String {
        if device.deviceType == .router { return "wifi.router" }
        if device.deviceType == .server { return "server.rack" }
        if device.deviceType == .computer { return "desktopcomputer" }
        if device.deviceType == .mobile { return "iphone" }
        if device.deviceType == .iot { return "sensor" }
        if device.deviceType == .printer { return "printer" }
        return "questionmark.circle"
    }

    private var deviceColor: Color {
        if device.vulnerabilities > 0 { return .red }
        if device.openPorts.count > 5 { return .orange }
        return .green
    }
}

struct SecurityOverviewCard: View {
    var body: some View {
        NavigationLink(destination: VulnerabilityView()) {
            HStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Security Issues Found")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Tap to view details and recommendations")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color.red.opacity(0.1))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

struct DiscoveredDevice: Identifiable, Hashable {
    let id = UUID()
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let manufacturer: String?
    let deviceType: DeviceType
    let openPorts: [Int]
    let vulnerabilities: Int
    let isOnline: Bool
    let firstSeen: Date
    let lastSeen: Date

    enum DeviceType {
        case router, server, computer, mobile, iot, printer, unknown
    }
}

@MainActor
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var securityScore: Int = 100
    @Published var hasSecurityFindings: Bool = false

    func addDevice(_ device: DiscoveredDevice) {
        if let index = discoveredDevices.firstIndex(where: { $0.ipAddress == device.ipAddress }) {
            // Update existing device
            discoveredDevices[index] = device
        } else {
            // Add new device
            discoveredDevices.append(device)
        }
        updateSecurityScore()
    }

    func updateSecurityScore() {
        let totalVulns = discoveredDevices.reduce(0) { $0 + $1.vulnerabilities }
        securityScore = max(0, 100 - (totalVulns * 5))
        hasSecurityFindings = totalVulns > 0
    }

    func clearDevices() {
        discoveredDevices.removeAll()
        securityScore = 100
        hasSecurityFindings = false
    }
}

// MARK: - Network Scanner

@MainActor
class NMAPScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var currentHost = ""

    private let deviceManager = DeviceManager.shared

    /// Scan network - defaults to Class C (/24) for speed
    func scanNetwork(subnet: String = "192.168.1", ports: [Int]? = nil) async {
        isScanning = true
        progress = 0
        status = "Starting network scan..."

        let portsToScan = ports ?? defaultPorts
        let hosts = generateHostList(subnet: subnet)

        for (index, host) in hosts.enumerated() {
            currentHost = host
            status = "Scanning \(host)..."
            progress = Double(index) / Double(hosts.count)

            await scanHost(host: host, ports: portsToScan)

            // Small delay to prevent overwhelming the network
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        status = "Scan complete - \(deviceManager.discoveredDevices.count) devices found"
        progress = 1.0
        isScanning = false
    }

    /// Generate list of hosts in /24 subnet (Class C)
    private func generateHostList(subnet: String) -> [String] {
        return (1...254).map { "\(subnet).\($0)" }
    }

    /// Scan a single host for open ports
    private func scanHost(host: String, ports: [Int]) async {
        var openPorts: [Int] = []

        for port in ports {
            if await testPort(host: host, port: port) {
                openPorts.append(port)
            }
        }

        // Only create device if host is reachable (has open ports)
        if !openPorts.isEmpty {
            let device = DiscoveredDevice(
                ipAddress: host,
                macAddress: nil, // Would require ARP lookup
                hostname: nil, // Would require DNS lookup
                manufacturer: nil, // Would require MAC vendor lookup
                deviceType: detectDeviceType(openPorts: openPorts),
                openPorts: openPorts,
                vulnerabilities: countVulnerabilities(openPorts: openPorts),
                isOnline: true,
                firstSeen: Date(),
                lastSeen: Date()
            )

            deviceManager.addDevice(device)
        }
    }

    /// Test if a specific port is open on a host
    private func testPort(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: portNumber,
                using: .tcp
            )

            let queue = DispatchQueue(label: "port-scan-\(host)-\(port)")
            var hasResumed = false
            let lock = NSLock()

            connection.stateUpdateHandler = { state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Timeout after 2 seconds
            queue.asyncAfter(deadline: .now() + 2) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Detect device type based on open ports
    private func detectDeviceType(openPorts: [Int]) -> DiscoveredDevice.DeviceType {
        if openPorts.contains(where: { [80, 443, 8080, 8443].contains($0) }) {
            // Has web ports
            if openPorts.contains(3306) || openPorts.contains(5432) || openPorts.contains(1433) {
                return .server // Database server
            }
            if openPorts.contains(22) || openPorts.contains(3389) {
                return .server // Remote access server
            }
        }

        if openPorts.contains(631) || openPorts.contains(9100) {
            return .printer
        }

        if openPorts.contains(1883) || openPorts.contains(8883) {
            return .iot // MQTT (common for IoT)
        }

        if openPorts.contains(where: { [139, 445, 548].contains($0) }) {
            return .computer // File sharing ports
        }

        if openPorts.contains(where: { [53, 67, 68].contains($0) }) {
            return .router // DNS/DHCP
        }

        return .unknown
    }

    /// Count potential vulnerabilities based on open ports
    private func countVulnerabilities(openPorts: [Int]) -> Int {
        var count = 0

        // Critical vulnerabilities
        if openPorts.contains(21) { count += 1 } // FTP
        if openPorts.contains(23) { count += 1 } // Telnet
        if openPorts.contains(3306) { count += 1 } // MySQL exposed
        if openPorts.contains(5432) { count += 1 } // PostgreSQL exposed
        if openPorts.contains(27017) { count += 1 } // MongoDB exposed

        // High risk
        if openPorts.contains(22) && openPorts.count > 5 { count += 1 } // SSH with many ports
        if openPorts.contains(3389) { count += 1 } // RDP exposed

        // Medium risk
        if openPorts.contains(80) && !openPorts.contains(443) { count += 1 } // HTTP without HTTPS

        return count
    }

    /// Default ports to scan (standard NMAP top ports)
    private let defaultPorts = [
        21,    // FTP
        22,    // SSH
        23,    // Telnet
        25,    // SMTP
        53,    // DNS
        80,    // HTTP
        110,   // POP3
        139,   // NetBIOS
        143,   // IMAP
        443,   // HTTPS
        445,   // SMB
        3306,  // MySQL
        3389,  // RDP
        5432,  // PostgreSQL
        5900,  // VNC
        8080   // HTTP-Alt
    ]
}

// MARK: - Shared Utility Views
// Removed duplicate StatItem and InfoRow - now defined in IntegratedDashboardViewV3.swift and DeviceWhitelistView.swift
