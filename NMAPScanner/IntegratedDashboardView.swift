//
//  IntegratedDashboardView.swift
//  NMAP Scanner - Integrated Threat Analysis Dashboard
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI
import Network

struct IntegratedDashboardView: View {
    @StateObject private var scanner = IntegratedScanner()
    @StateObject private var threatAnalyzer = ThreatAnalyzer()
    @State private var showingThreatDashboard = false
    @State private var showingDeviceThreats = false
    @State private var selectedDevice: EnhancedDevice?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header
                    Text("NMAP Security Scanner")
                        .font(.system(size: 50, weight: .bold))

                    // Scanning Status
                    if scanner.isScanning {
                        ScanningStatusCard(scanner: scanner)
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

                    // Discovered Devices List
                    if !scanner.devices.isEmpty {
                        DiscoveredDevicesList(
                            devices: scanner.devices,
                            threatAnalyzer: threatAnalyzer,
                            selectedDevice: $selectedDevice
                        )
                    }

                    // Rescan Button
                    if !scanner.isScanning {
                        Button(action: {
                            Task {
                                await scanner.startScan()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 32))
                                Text("Rescan Network")
                                    .font(.system(size: 28, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
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
            // Convert EnhancedDevice to HomeKitDevice for the detail view
            let homeKitDevice = HomeKitDevice(
                displayName: device.hostname ?? device.ipAddress,
                serviceType: device.serviceType ?? "",
                category: device.deviceType.rawValue,
                isHomeKitAccessory: HomeKitPortDefinitions.isLikelyHomeKitAccessory(ports: device.openPorts.map { $0.port }),
                discoveredAt: device.lastSeen,
                ipAddress: device.ipAddress
            )
            EnhancedDeviceDetailView(device: homeKitDevice)
        }
        .task {
            // Auto-scan on launch
            if !scanner.hasScanned {
                await scanner.startScan()
            }
        }
    }
}

// MARK: - Scanning Status Card

struct ScanningStatusCard: View {
    @ObservedObject var scanner: IntegratedScanner

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Scanning Network...")
                    .font(.system(size: 36, weight: .semibold))
            }

            ProgressView(value: scanner.progress)
                .scaleEffect(y: 4)

            Text(scanner.status)
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            HStack(spacing: 40) {
                StatItem(label: "Hosts Scanned", value: "\(scanner.scannedHosts)/254")
                StatItem(label: "Devices Found", value: "\(scanner.devices.count)")
                StatItem(label: "Threats Detected", value: "\(scanner.threatsDetected)")
            }
        }
        .padding(30)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Network Threat Summary Card

struct NetworkThreatSummaryCard: View {
    let summary: NetworkThreatSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Network Security Summary")
                    .font(.system(size: 36, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }

            // Risk Score
            HStack(spacing: 30) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: CGFloat(summary.overallRiskScore) / 100.0)
                        .stroke(riskColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Text("\(summary.overallRiskScore)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(riskColor)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(summary.riskLevel)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(riskColor)

                    HStack(spacing: 20) {
                        ThreatBadge(count: summary.criticalThreats.count, label: "Critical", color: .red)
                        ThreatBadge(count: summary.highThreats.count, label: "High", color: .orange)
                        ThreatBadge(count: summary.mediumThreats.count, label: "Medium", color: .yellow)
                    }

                    if !summary.rogueDevices.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("\(summary.rogueDevices.count) Rogue Device\(summary.rogueDevices.count == 1 ? "" : "s")")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }

                    if !summary.backdoorDevices.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .foregroundColor(.red)
                            Text("\(summary.backdoorDevices.count) Backdoor\(summary.backdoorDevices.count == 1 ? "" : "s")")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Text("Tap to view detailed threat analysis →")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .background(riskColor.opacity(0.1))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(riskColor.opacity(0.3), lineWidth: 3)
        )
    }

    private var riskColor: Color {
        switch summary.overallRiskScore {
        case 90...100: return .green
        case 70..<90: return .yellow
        case 40..<70: return .orange
        default: return .red
        }
    }
}

struct ThreatBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Device Threats Summary Card

struct DeviceThreatsSummaryCard: View {
    let summaries: [DeviceThreatSummary]

    private var threatenedDevices: [DeviceThreatSummary] {
        summaries.filter { $0.hasThreats }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Device Security Status")
                    .font(.system(size: 36, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(threatenedDevices.count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.red)
                    Text("Devices with Threats")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(summaries.count - threatenedDevices.count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                    Text("Secure Devices")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }

            // Top 3 threatened devices
            if !threatenedDevices.isEmpty {
                Text("Most Threatened:")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.secondary)

                ForEach(threatenedDevices.prefix(3)) { summary in
                    HStack {
                        Text(summary.device.displayName)
                            .font(.system(size: 20))
                        Spacer()
                        HStack(spacing: 12) {
                            if !summary.criticalThreats.isEmpty {
                                Text("\(summary.criticalThreats.count)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            if !summary.highThreats.isEmpty {
                                Text("\(summary.highThreats.count)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            if !summary.mediumThreats.isEmpty {
                                Text("\(summary.mediumThreats.count)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Text("Tap to view all device threats →")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Discovered Devices List

struct DiscoveredDevicesList: View {
    let devices: [EnhancedDevice]
    @ObservedObject var threatAnalyzer: ThreatAnalyzer
    @Binding var selectedDevice: EnhancedDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Discovered Devices (\(devices.count))")
                .font(.system(size: 36, weight: .semibold))

            ForEach(devices) { device in
                Button(action: {
                    selectedDevice = device
                }) {
                    DiscoveredDeviceCard(device: device, threatSummary: getThreatSummary(for: device))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func getThreatSummary(for device: EnhancedDevice) -> DeviceThreatSummary? {
        threatAnalyzer.deviceSummaries.first { $0.device.id == device.id }
    }
}

struct DiscoveredDeviceCard: View {
    let device: EnhancedDevice
    let threatSummary: DeviceThreatSummary?

    var body: some View {
        HStack(spacing: 20) {
            // Device icon
            ZStack {
                Circle()
                    .fill(deviceColor.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: deviceIcon)
                    .font(.system(size: 35))
                    .foregroundColor(deviceColor)
            }

            // Device info
            VStack(alignment: .leading, spacing: 8) {
                Text(device.displayName)
                    .font(.system(size: 26, weight: .semibold))

                Text(device.ipAddress)
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(.secondary)

                if let summary = threatSummary, summary.hasThreats {
                    HStack(spacing: 12) {
                        if !summary.criticalThreats.isEmpty {
                            ThreatCountBadge(count: summary.criticalThreats.count, color: .red)
                        }
                        if !summary.highThreats.isEmpty {
                            ThreatCountBadge(count: summary.highThreats.count, color: .orange)
                        }
                        if !summary.mediumThreats.isEmpty {
                            ThreatCountBadge(count: summary.mediumThreats.count, color: .yellow)
                        }
                    }
                }

                if device.isRogue {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("ROGUE DEVICE")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(deviceColor)
        }
        .padding(24)
        .background(deviceColor.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(deviceColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var deviceIcon: String {
        switch device.deviceType {
        case .router: return "wifi.router"
        case .server: return "server.rack"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "sensor"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }

    private var deviceColor: Color {
        if device.isRogue { return .red }
        if let summary = threatSummary {
            switch summary.overallSeverity {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            case .info: return .gray
            }
        }
        return .green
    }
}

struct ThreatCountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Device Threats List View

struct DeviceThreatsListView: View {
    let summaries: [DeviceThreatSummary]
    @Binding var selectedDevice: EnhancedDevice?
    @Environment(\.dismiss) var dismiss

    private var threatenedDevices: [DeviceThreatSummary] {
        summaries.filter { $0.hasThreats }.sorted { $0.overallSeverity < $1.overallSeverity }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Text("Device Threats")
                        .font(.system(size: 50, weight: .bold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 28))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }

                Text("\(threatenedDevices.count) device\(threatenedDevices.count == 1 ? "" : "s") with security threats")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)

                ForEach(threatenedDevices) { summary in
                    Button(action: {
                        selectedDevice = summary.device
                        dismiss()
                    }) {
                        DeviceThreatSummaryCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
    }
}

struct DeviceThreatSummaryCard: View {
    let summary: DeviceThreatSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(summary.device.displayName)
                    .font(.system(size: 28, weight: .semibold))
                Spacer()
                Text(summary.overallSeverity.rawValue.uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(severityColor)
                    .cornerRadius(8)
            }

            Text(summary.device.ipAddress)
                .font(.system(size: 22, design: .monospaced))
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                if !summary.criticalThreats.isEmpty {
                    ThreatStat(count: summary.criticalThreats.count, label: "Critical", color: .red)
                }
                if !summary.highThreats.isEmpty {
                    ThreatStat(count: summary.highThreats.count, label: "High", color: .orange)
                }
                if !summary.mediumThreats.isEmpty {
                    ThreatStat(count: summary.mediumThreats.count, label: "Medium", color: .yellow)
                }
                if !summary.lowThreats.isEmpty {
                    ThreatStat(count: summary.lowThreats.count, label: "Low", color: .blue)
                }
            }

            // Sample threats
            ForEach(summary.allThreats.prefix(2)) { threat in
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(threatColor(threat.severity))
                    Text(threat.title)
                        .font(.system(size: 18))
                        .lineLimit(1)
                }
            }

            if summary.totalThreats > 2 {
                Text("+ \(summary.totalThreats - 2) more threat\(summary.totalThreats - 2 == 1 ? "" : "s")")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(severityColor.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(severityColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var severityColor: Color {
        switch summary.overallSeverity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    private func threatColor(_ severity: ThreatSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

struct ThreatStat: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Integrated Scanner

@MainActor
class IntegratedScanner: ObservableObject {
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var devices: [EnhancedDevice] = []
    @Published var scannedHosts = 0
    @Published var threatsDetected = 0

    private let threatAnalyzer: ThreatAnalyzer

    init() {
        self.threatAnalyzer = ThreatAnalyzer()
    }

    func startScan() async {
        isScanning = true
        progress = 0
        status = "Starting network scan..."
        devices = []
        scannedHosts = 0
        threatsDetected = 0

        // Detect local subnet
        let subnet = detectSubnet()
        status = "Scanning subnet \(subnet).0/24..."

        // Scan all hosts in /24 subnet
        let hosts = (1...254).map { "\(subnet).\($0)" }

        for (index, host) in hosts.enumerated() {
            scannedHosts = index + 1
            progress = Double(index + 1) / Double(hosts.count)
            status = "Scanning \(host)..."

            await scanHost(host)

            // Small delay
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        }

        status = "Analyzing threats..."
        let analyzer = ThreatAnalyzer()
        analyzer.analyzeNetwork(devices: devices)

        // Update threat count
        if let summary = analyzer.networkSummary {
            threatsDetected = summary.totalThreats
        }

        status = "Scan complete - \(devices.count) devices found, \(threatsDetected) threats detected"
        isScanning = false
        hasScanned = true
    }

    private func detectSubnet() -> String {
        // For now, return common subnet
        // In production, would detect actual local network
        return "192.168.1"
    }

    private func scanHost(_ host: String) async {
        var openPorts: [PortInfo] = []

        // Scan common ports
        let portsToScan = [
            21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445,
            3306, 3389, 5432, 5900, 8080,
            // Backdoor ports
            31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374,
            2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002
        ]

        for port in portsToScan {
            if await testPort(host: host, port: port) {
                let portInfo = PortInfo(
                    port: port,
                    service: serviceForPort(port),
                    version: nil,
                    state: .open,
                    protocolType: "TCP",
                    banner: nil
                )
                openPorts.append(portInfo)
            }
        }

        // Only add device if it has open ports (is reachable)
        if !openPorts.isEmpty {
            let device = EnhancedDevice(
                ipAddress: host,
                macAddress: nil,
                hostname: nil,
                manufacturer: nil,
                deviceType: detectDeviceType(openPorts: openPorts),
                openPorts: openPorts,
                isOnline: true,
                firstSeen: Date(),
                lastSeen: Date(),
                isKnownDevice: false, // Would check against whitelist
                operatingSystem: nil,
                deviceName: nil
            )
            devices.append(device)
        }
    }

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

            // Timeout after 1 second (faster for auto-scan)
            queue.asyncAfter(deadline: .now() + 1) {
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

    private func serviceForPort(_ port: Int) -> String {
        let services: [Int: String] = [
            21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
            80: "HTTP", 110: "POP3", 139: "NetBIOS", 143: "IMAP", 443: "HTTPS",
            445: "SMB", 3306: "MySQL", 3389: "RDP", 5432: "PostgreSQL",
            5900: "VNC", 8080: "HTTP-Alt",
            31337: "Back Orifice", 12345: "NetBus", 6667: "IRC", 27374: "SubSeven"
        ]
        return services[port] ?? "Unknown"
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

    private func convertDeviceType(_ type: EnhancedDevice.DeviceType) -> DiscoveredDevice.DeviceType {
        switch type {
        case .router: return .router
        case .server: return .server
        case .computer: return .computer
        case .mobile: return .mobile
        case .iot: return .iot
        case .printer: return .printer
        case .unknown: return .unknown
        }
    }
}
