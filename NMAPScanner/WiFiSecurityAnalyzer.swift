//
//  WiFiSecurityAnalyzer.swift
//  NMAP Plus Security Scanner - WiFi Network Security Analysis
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import SwiftUI

/// WiFi Security Analyzer - Analyzes UniFi network security
@MainActor
class WiFiSecurityAnalyzer: ObservableObject {
    static let shared = WiFiSecurityAnalyzer()

    @Published var networks: [WiFiNetwork] = []
    @Published var securityIssues: [WiFiSecurityIssue] = []
    @Published var lastAnalysis: Date?

    private init() {}

    // MARK: - Analysis

    /// Analyze WiFi networks from UniFi controller
    func analyzeNetworks(_ unifiDevices: [UniFiDevice]) {
        print("🔒 WiFi Security: Analyzing \(unifiDevices.count) UniFi devices")

        // Group devices by network
        var networkMap: [String: [UniFiDevice]] = [:]
        for device in unifiDevices {
            if let networkName = device.networkName {
                networkMap[networkName, default: []].append(device)
            }
        }

        // Create WiFiNetwork objects
        networks = networkMap.map { (name, devices) in
            WiFiNetwork(
                ssid: name,
                clientCount: devices.count,
                clients: devices
            )
        }.sorted { $0.clientCount > $1.clientCount }

        // Analyze security issues
        securityIssues = []

        for network in networks {
            analyzeNetworkSecurity(network)
        }

        lastAnalysis = Date()

        print("🔒 WiFi Security: Found \(securityIssues.count) security issues across \(networks.count) networks")
    }

    /// Analyze security for a specific network
    private func analyzeNetworkSecurity(_ network: WiFiNetwork) {
        // Check for weak encryption
        checkWeakEncryption(network)

        // Check for unknown/suspicious devices
        checkSuspiciousDevices(network)

        // Check for signal strength issues
        checkSignalStrength(network)

        // Check for network isolation issues
        checkNetworkIsolation(network)

        // Check for guest network security
        checkGuestNetworkSecurity(network)
    }

    /// Check for weak encryption (WEP, WPA, open networks)
    private func checkWeakEncryption(_ network: WiFiNetwork) {
        // Note: UniFi API doesn't expose encryption type per client
        // This would need to be fetched from /api/s/{site}/rest/wlanconf
        // For now, we'll flag potential issues based on network names

        let insecureKeywords = ["open", "guest", "public", "free"]
        let networkNameLower = network.ssid.lowercased()

        for keyword in insecureKeywords {
            if networkNameLower.contains(keyword) {
                addIssue(
                    network: network.ssid,
                    severity: .medium,
                    type: .weakEncryption,
                    title: "Potentially Open/Insecure Network",
                    description: "Network name suggests it may be open or use weak encryption",
                    recommendation: "Verify WPA3 or WPA2-Enterprise encryption is enabled"
                )
                break
            }
        }
    }

    /// Check for unknown or suspicious devices
    private func checkSuspiciousDevices(_ network: WiFiNetwork) {
        var unknownDevices = 0
        var randomizedMacs = 0

        for client in network.clients {
            // Check for unknown manufacturer
            if client.manufacturer == nil || client.manufacturer?.isEmpty == true {
                unknownDevices += 1
            }

            // Check for locally administered MAC (randomized)
            let mac = client.mac
            let firstOctet = mac.prefix(2)
            if let byte = Int(firstOctet, radix: 16) {
                // Bit 1 of first octet indicates locally administered address
                if (byte & 0x02) != 0 {
                    randomizedMacs += 1
                }
            }
        }

        if unknownDevices > network.clientCount / 2 {
            addIssue(
                network: network.ssid,
                severity: .medium,
                type: .suspiciousDevices,
                title: "Many Unknown Devices",
                description: "\(unknownDevices) devices with unknown manufacturers detected",
                recommendation: "Review connected devices and remove unauthorized clients"
            )
        }

        if randomizedMacs > 0 {
            addIssue(
                network: network.ssid,
                severity: .low,
                type: .suspiciousDevices,
                title: "Devices Using MAC Randomization",
                description: "\(randomizedMacs) devices using randomized MAC addresses",
                recommendation: "This is normal for iOS/Android privacy features, but monitor for unusual activity"
            )
        }
    }

    /// Check signal strength for all clients
    private func checkSignalStrength(_ network: WiFiNetwork) {
        var weakSignals = 0

        for client in network.clients where !(client.isWired ?? false) {
            if let rssi = client.rssi, rssi < -70 {
                weakSignals += 1
            }
        }

        if weakSignals > 0 {
            addIssue(
                network: network.ssid,
                severity: .low,
                type: .signalStrength,
                title: "Weak WiFi Signals Detected",
                description: "\(weakSignals) clients have weak signal strength (< -70 dBm)",
                recommendation: "Add additional access points or adjust AP placement for better coverage"
            )
        }
    }

    /// Check for network isolation issues
    private func checkNetworkIsolation(_ network: WiFiNetwork) {
        // If guest network has many devices, ensure isolation is enabled
        if network.ssid.lowercased().contains("guest") && network.clientCount > 5 {
            addIssue(
                network: network.ssid,
                severity: .high,
                type: .networkIsolation,
                title: "Guest Network May Need Isolation",
                description: "\(network.clientCount) devices on guest network",
                recommendation: "Verify client isolation is enabled to prevent guest-to-guest communication"
            )
        }
    }

    /// Check guest network security
    private func checkGuestNetworkSecurity(_ network: WiFiNetwork) {
        if network.ssid.lowercased().contains("guest") {
            // Guest networks should have additional restrictions
            addIssue(
                network: network.ssid,
                severity: .medium,
                type: .guestNetwork,
                title: "Guest Network Security Review",
                description: "Guest network detected - verify security settings",
                recommendation: "Ensure: Client isolation enabled, VLAN segregation, bandwidth limits, and portal authentication if appropriate"
            )
        }
    }

    /// Add a security issue
    private func addIssue(network: String, severity: WiFiSecurityIssue.Severity, type: WiFiSecurityIssue.IssueType, title: String, description: String, recommendation: String) {
        let issue = WiFiSecurityIssue(
            networkSSID: network,
            severity: severity,
            type: type,
            title: title,
            description: description,
            recommendation: recommendation,
            detectedAt: Date()
        )
        securityIssues.append(issue)
    }

    // MARK: - Statistics

    /// Get total client count across all networks
    var totalClients: Int {
        networks.reduce(0) { $0 + $1.clientCount }
    }

    /// Get issues grouped by severity
    var criticalIssues: [WiFiSecurityIssue] {
        securityIssues.filter { $0.severity == .critical }
    }

    var highIssues: [WiFiSecurityIssue] {
        securityIssues.filter { $0.severity == .high }
    }

    var mediumIssues: [WiFiSecurityIssue] {
        securityIssues.filter { $0.severity == .medium }
    }

    var lowIssues: [WiFiSecurityIssue] {
        securityIssues.filter { $0.severity == .low }
    }
}

// MARK: - WiFi Network Model

struct WiFiNetwork: Identifiable {
    let id = UUID()
    let ssid: String
    let clientCount: Int
    let clients: [UniFiDevice]

    /// Get wireless clients only
    var wirelessClients: [UniFiDevice] {
        clients.filter { !($0.isWired ?? false) }
    }

    /// Get wired clients only
    var wiredClients: [UniFiDevice] {
        clients.filter { $0.isWired ?? false }
    }

    /// Average signal strength
    var averageRSSI: Int? {
        let wirelessWithRSSI = wirelessClients.compactMap { $0.rssi }
        guard !wirelessWithRSSI.isEmpty else { return nil }
        return wirelessWithRSSI.reduce(0, +) / wirelessWithRSSI.count
    }
}

// MARK: - WiFi Security Issue Model

struct WiFiSecurityIssue: Identifiable {
    let id = UUID()
    let networkSSID: String
    let severity: Severity
    let type: IssueType
    let title: String
    let description: String
    let recommendation: String
    let detectedAt: Date

    enum Severity: String {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .high: return "exclamationmark.triangle"
            case .medium: return "exclamationmark.circle"
            case .low: return "info.circle"
            }
        }
    }

    enum IssueType {
        case weakEncryption
        case suspiciousDevices
        case signalStrength
        case networkIsolation
        case guestNetwork
        case other
    }
}

// MARK: - WiFi Security Dashboard View

struct WiFiSecurityDashboard: View {
    @ObservedObject var analyzer: WiFiSecurityAnalyzer
    @ObservedObject var unifiController: UniFiController
    @State private var selectedNetwork: WiFiNetwork?
    @State private var showingIssueDetail: WiFiSecurityIssue?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WiFi Security")
                            .font(.system(size: 34, weight: .bold))

                        if let lastAnalysis = analyzer.lastAnalysis {
                            Text("Last analyzed: \(lastAnalysis, style: .relative) ago")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("Refresh") {
                        Task {
                            _ = await unifiController.fetchDevices()
                            analyzer.analyzeNetworks(unifiController.devices)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Summary Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    SummaryCard(
                        title: "Networks",
                        value: "\(analyzer.networks.count)",
                        icon: "wifi",
                        color: .blue
                    )

                    SummaryCard(
                        title: "Total Clients",
                        value: "\(analyzer.totalClients)",
                        icon: "person.3.fill",
                        color: .green
                    )

                    SummaryCard(
                        title: "Security Issues",
                        value: "\(analyzer.securityIssues.count)",
                        icon: "shield.lefthalf.filled",
                        color: analyzer.securityIssues.isEmpty ? .green : .orange
                    )

                    SummaryCard(
                        title: "Critical",
                        value: "\(analyzer.criticalIssues.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: analyzer.criticalIssues.isEmpty ? .gray : .red
                    )
                }
                .padding(.horizontal, 20)

                // Networks List
                if !analyzer.networks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Networks")
                            .font(.system(size: 22, weight: .semibold))
                            .padding(.horizontal, 20)

                        ForEach(analyzer.networks) { network in
                            Button(action: {
                                selectedNetwork = network
                            }) {
                                WiFiNetworkCard(network: network, analyzer: analyzer)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Security Issues
                if !analyzer.securityIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Security Issues")
                            .font(.system(size: 22, weight: .semibold))
                            .padding(.horizontal, 20)

                        ForEach(analyzer.securityIssues) { issue in
                            Button(action: {
                                showingIssueDetail = issue
                            }) {
                                SecurityIssueCard(issue: issue)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if analyzer.networks.isEmpty && unifiController.isConfigured {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Networks Found")
                            .font(.system(size: 20, weight: .semibold))

                        Text("Sync with your UniFi Controller to analyze WiFi security")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Sync Now") {
                            Task {
                                _ = await unifiController.fetchDevices()
                                analyzer.analyzeNetworks(unifiController.devices)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $selectedNetwork) { network in
            NetworkDetailView(network: network, analyzer: analyzer)
        }
        .sheet(item: $showingIssueDetail) { issue in
            IssueDetailView(issue: issue)
        }
        .onAppear {
            if unifiController.isConfigured && !unifiController.devices.isEmpty {
                analyzer.analyzeNetworks(unifiController.devices)
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - WiFi Network Card

struct WiFiNetworkCard: View {
    let network: WiFiNetwork
    let analyzer: WiFiSecurityAnalyzer

    var networkIssues: [WiFiSecurityIssue] {
        analyzer.securityIssues.filter { $0.networkSSID == network.ssid }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "wifi")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(network.ssid)
                    .font(.system(size: 17, weight: .semibold))

                HStack(spacing: 12) {
                    Label("\(network.clientCount) clients", systemImage: "person.2.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let avgRSSI = network.averageRSSI {
                        Label("\(avgRSSI) dBm", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Issues badge
            if !networkIssues.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("\(networkIssues.count)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Security Issue Card

struct SecurityIssueCard: View {
    let issue: WiFiSecurityIssue

    var body: some View {
        HStack(spacing: 16) {
            // Severity icon
            ZStack {
                Circle()
                    .fill(issue.severity.color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: issue.severity.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(issue.severity.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(issue.severity.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(issue.severity.color)
                        .cornerRadius(6)

                    Text(issue.networkSSID)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text(issue.title)
                    .font(.system(size: 15, weight: .semibold))

                Text(issue.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Network Detail View

struct NetworkDetailView: View {
    let network: WiFiNetwork
    let analyzer: WiFiSecurityAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(network.ssid)
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Stats
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("\(network.clientCount)")
                                .font(.system(size: 28, weight: .bold))
                            Text("Total Clients")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading) {
                            Text("\(network.wirelessClients.count)")
                                .font(.system(size: 28, weight: .bold))
                            Text("Wireless")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading) {
                            Text("\(network.wiredClients.count)")
                                .font(.system(size: 28, weight: .bold))
                            Text("Wired")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        if let avgRSSI = network.averageRSSI {
                            VStack(alignment: .leading) {
                                Text("\(avgRSSI) dBm")
                                    .font(.system(size: 28, weight: .bold))
                                Text("Avg Signal")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Clients list
                    Text("Connected Devices")
                        .font(.system(size: 18, weight: .semibold))

                    ForEach(network.clients, id: \.id) { client in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.hostname ?? client.ip ?? "Unknown")
                                    .font(.system(size: 15, weight: .medium))

                                HStack(spacing: 8) {
                                    Text(client.mac)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)

                                    if let mfr = client.manufacturer {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(mfr)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            if let rssi = client.rssi, !(client.isWired ?? false) {
                                Text("\(rssi) dBm")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(rssi > -60 ? .green : rssi > -70 ? .orange : .red)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - Issue Detail View

struct IssueDetailView: View {
    let issue: WiFiSecurityIssue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(issue.severity.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: issue.severity.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(issue.severity.color)
            }

            // Title
            VStack(spacing: 8) {
                Text(issue.title)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Text(issue.severity.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(issue.severity.color)
                        .cornerRadius(8)

                    Text(issue.networkSSID)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }

            // Description
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(issue.description)
                        .font(.system(size: 15))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendation")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(issue.recommendation)
                        .font(.system(size: 15))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(issue.detectedAt, style: .relative) + Text(" ago")
                        .font(.system(size: 15))
                }
            }
            .padding(.horizontal, 40)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 600, height: 550)
    }
}
