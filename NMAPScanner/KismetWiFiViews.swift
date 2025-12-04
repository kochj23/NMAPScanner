//
//  KismetWiFiViews.swift
//  NMAP Plus Security Scanner - Kismet-Style WiFi UI
//
//  Created by Jordan Koch on 2025-12-01.
//
//  Comprehensive WiFi analysis views inspired by Kismet
//

import SwiftUI

// MARK: - Kismet Dashboard View

/// Main Kismet-style dashboard for WiFi analysis
struct KismetDashboardView: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer
    let networks: [WiFiNetworkInfo]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Kismet WiFi Analysis")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 20)

                // Run Analysis Button
                if !analyzer.isAnalyzing {
                    Button(action: {
                        Task {
                            await analyzer.performKismetAnalysis(networks: networks)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Run Kismet Analysis")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
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
                    .padding(.horizontal, 20)
                }

                // Analysis Progress
                if analyzer.isAnalyzing {
                    KismetAnalysisProgressCard(analyzer: analyzer)
                }

                // Statistics Overview
                if !analyzer.networkHistory.isEmpty {
                    KismetStatisticsCard(statistics: analyzer.getKismetStatistics())
                }

                // Critical Alerts
                if analyzer.alertCount > 0 {
                    KismetAlertsCard(analyzer: analyzer)
                }

                // Section Tabs
                if !analyzer.networkHistory.isEmpty {
                    KismetSectionTabs(analyzer: analyzer)
                }
            }
            .padding(.vertical, 20)
        }
        .frame(width: 900, height: 700)
    }
}

// MARK: - Analysis Progress Card

struct KismetAnalysisProgressCard: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Kismet Analysis Running")
                    .font(.system(size: 20, weight: .semibold))
            }

            ProgressView(value: analyzer.progress)
                .tint(.purple)

            Text(analyzer.status)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Statistics Card

struct KismetStatisticsCard: View {
    let statistics: KismetStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security Overview")
                .font(.system(size: 22, weight: .semibold))

            // Security Grade
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(gradeColor.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Text(statistics.securityGrade)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(gradeColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Security Score: \(statistics.overallSecurityScore)/100")
                        .font(.system(size: 18, weight: .semibold))

                    if statistics.criticalAlerts > 0 {
                        Label("\(statistics.criticalAlerts) Critical Alerts", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }

                    if statistics.highAlerts > 0 {
                        Label("\(statistics.highAlerts) High Alerts", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                }
            }

            Divider()

            // Statistics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                KismetStatItem(icon: "wifi", label: "Networks", value: "\(statistics.totalNetworksAnalyzed)", color: .blue)
                KismetStatItem(icon: "person.2", label: "Clients", value: "\(statistics.totalClientsDetected)", color: .green)
                KismetStatItem(icon: "exclamationmark.shield", label: "Rogue APs", value: "\(statistics.rogueAPsDetected)", color: .red)
                KismetStatItem(icon: "lock.trianglebadge.exclamationmark", label: "Vulnerabilities", value: "\(statistics.vulnerabilitiesFound)", color: .orange)
                KismetStatItem(icon: "chart.bar", label: "Optimal Channels", value: "\(statistics.optimalChannels)", color: .green)
                KismetStatItem(icon: "antenna.radiowaves.left.and.right.slash", label: "Congested", value: "\(statistics.congestedChannels)", color: .red)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }

    private var gradeColor: Color {
        switch statistics.securityGrade {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        default: return .red
        }
    }
}

struct KismetStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Alerts Card

struct KismetAlertsCard: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Critical Alerts")
                    .font(.system(size: 22, weight: .semibold))
            }

            // Rogue APs
            if !analyzer.rogueAccessPoints.isEmpty {
                ForEach(analyzer.rogueAccessPoints.prefix(3)) { rogue in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(severityColor(rogue.severity))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rogue.ssid)
                                .font(.system(size: 15, weight: .semibold))
                            Text(rogue.detectionReason.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(rogue.severity.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(severityColor(rogue.severity))
                    }
                    .padding(.vertical, 8)
                }
            }

            // Vulnerabilities
            if !analyzer.securityVulnerabilities.isEmpty {
                ForEach(analyzer.securityVulnerabilities.prefix(3)) { vuln in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(severityColor(vuln.severity))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vuln.ssid)
                                .font(.system(size: 15, weight: .semibold))
                            Text(vuln.vulnerability.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(vuln.severity.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(severityColor(vuln.severity))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func severityColor(_ severity: ThreatSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

// MARK: - Section Tabs

struct KismetSectionTabs: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer
    @State private var selectedTab: KismetTab = .clients

    enum KismetTab: String, CaseIterable {
        case clients = "Clients"
        case rogueAPs = "Rogue APs"
        case channels = "Channels"
        case vulnerabilities = "Vulnerabilities"
        case history = "History"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tab Selector
            HStack(spacing: 8) {
                ForEach(KismetTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.purple : Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Tab Content
            Group {
                switch selectedTab {
                case .clients:
                    ClientsListView(analyzer: analyzer)
                case .rogueAPs:
                    RogueAPsListView(analyzer: analyzer)
                case .channels:
                    ChannelUtilizationView(analyzer: analyzer)
                case .vulnerabilities:
                    VulnerabilitiesListView(analyzer: analyzer)
                case .history:
                    NetworkHistoryListView(analyzer: analyzer)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Clients List View

struct ClientsListView: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Clients (\(analyzer.totalClientsDetected))")
                .font(.system(size: 20, weight: .semibold))

            if analyzer.detectedClients.isEmpty {
                Text("No clients detected. Run Kismet analysis to discover connected devices.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(analyzer.detectedClients.keys.sorted()), id: \.self) { bssid in
                    if let clients = analyzer.detectedClients[bssid], !clients.isEmpty {
                        ClientGroupCard(bssid: bssid, clients: clients)
                    }
                }
            }
        }
    }
}

struct ClientGroupCard: View {
    let bssid: String
    let clients: [WiFiClient]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AP: \(bssid)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(clients) { client in
                HStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.displayName)
                            .font(.system(size: 14, weight: .medium))
                        if let manufacturer = client.manufacturer {
                            Text(manufacturer)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(client.signalStrength) dBm")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Rogue APs View

struct RogueAPsListView: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rogue Access Points (\(analyzer.rogueAccessPoints.count))")
                .font(.system(size: 20, weight: .semibold))

            if analyzer.rogueAccessPoints.isEmpty {
                Text("No rogue access points detected. Your network is secure!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(analyzer.rogueAccessPoints) { rogue in
                    RogueAPCard(rogue: rogue)
                }
            }
        }
    }
}

struct RogueAPCard: View {
    let rogue: RogueAccessPoint

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(rogue.ssid)
                    .font(.system(size: 16, weight: .semibold))

                Text(rogue.detectionReason.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Label("Ch \(rogue.channel)", systemImage: "waveform")
                    Label("\(rogue.bssid)", systemImage: "network")
                    Label("\(rogue.signalStrength) dBm", systemImage: "antenna.radiowaves.left.and.right")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            }

            Spacer()

            Text(rogue.severity.rawValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(severityColor)
                .cornerRadius(6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(severityColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(severityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var severityColor: Color {
        switch rogue.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

// MARK: - Channel Utilization View

struct ChannelUtilizationView: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channel Utilization (\(analyzer.channelUtilization.count) channels)")
                .font(.system(size: 20, weight: .semibold))

            if analyzer.channelUtilization.isEmpty {
                Text("No channel data available. Run Kismet analysis first.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(analyzer.channelUtilization, id: \.channel) { channel in
                    ChannelCard(channel: channel)
                }
            }
        }
    }
}

struct ChannelCard: View {
    let channel: ChannelUtilization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Channel \(channel.channel)")
                    .font(.system(size: 16, weight: .semibold))

                Text(channel.band)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(channel.band.contains("5") ? Color.blue : Color.green)
                    .cornerRadius(4)

                Spacer()

                if channel.isOptimal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            ProgressView(value: channel.utilizationPercent / 100.0) {
                HStack {
                    Text("Utilization: \(Int(channel.utilizationPercent))%")
                    Spacer()
                    Text("\(channel.networkCount) networks")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .tint(interferenceColor)

            HStack {
                Label("Interference: \(channel.interferenceLevel.rawValue)", systemImage: "waveform.path.ecg")
                    .font(.system(size: 13))
                    .foregroundColor(interferenceColor)

                Spacer()

                if let primary = channel.primaryNetwork {
                    Text("Primary: \(primary)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var interferenceColor: Color {
        switch channel.interferenceLevel {
        case .none: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Vulnerabilities View

struct VulnerabilitiesListView: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security Vulnerabilities (\(analyzer.securityVulnerabilities.count))")
                .font(.system(size: 20, weight: .semibold))

            if analyzer.securityVulnerabilities.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("No vulnerabilities detected. All networks are secure!")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(analyzer.securityVulnerabilities) { vuln in
                    KismetVulnerabilityCard(vulnerability: vuln)
                }
            }
        }
    }
}

struct KismetVulnerabilityCard: View {
    let vulnerability: WiFiSecurityVulnerability
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.trianglebadge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(severityColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vulnerability.ssid)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(vulnerability.vulnerability.rawValue)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(vulnerability.severity.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(severityColor)
                            .cornerRadius(6)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description:")
                        .font(.system(size: 13, weight: .semibold))
                    Text(vulnerability.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("Remediation:")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 4)
                    Text(vulnerability.remediation)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("BSSID: \(vulnerability.bssid)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(severityColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(severityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var severityColor: Color {
        switch vulnerability.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

// MARK: - Network History View

struct NetworkHistoryListView: View {
    @ObservedObject var analyzer: KismetWiFiAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network History (\(analyzer.networkHistory.count) networks tracked)")
                .font(.system(size: 20, weight: .semibold))

            if analyzer.networkHistory.isEmpty {
                Text("No historical data. Networks will be tracked over time.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(analyzer.networkHistory.sorted(by: { $0.lastSeen > $1.lastSeen })) { history in
                    KismetNetworkHistoryCard(history: history)
                }
            }
        }
    }
}

struct KismetNetworkHistoryCard: View {
    let history: WiFiNetworkHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(history.ssid)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Text("\(history.observationCount) observations")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                GridRow {
                    Text("BSSID:")
                        .foregroundColor(.secondary)
                    Text(history.bssid)
                        .font(.system(size: 13, design: .monospaced))
                }

                GridRow {
                    Text("First Seen:")
                        .foregroundColor(.secondary)
                    Text(formatDate(history.firstSeen))
                }

                GridRow {
                    Text("Last Seen:")
                        .foregroundColor(.secondary)
                    Text(formatDate(history.lastSeen))
                }

                GridRow {
                    Text("Channels:")
                        .foregroundColor(.secondary)
                    Text(history.channelsObserved.sorted().map(String.init).joined(separator: ", "))
                }

                GridRow {
                    Text("Signal Range:")
                        .foregroundColor(.secondary)
                    Text("\(history.minSignalStrength) to \(history.maxSignalStrength) dBm (avg: \(Int(history.avgSignalStrength)))")
                }
            }
            .font(.system(size: 13))
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    KismetDashboardView(analyzer: KismetWiFiAnalyzer.shared, networks: [])
}
