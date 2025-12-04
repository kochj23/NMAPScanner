//
//  WiFiVisualCards.swift
//  NMAP Plus Security Scanner - Visual WiFi Statistics Cards
//
//  Created by Jordan Koch & Claude Code on 2025-12-01.
//
//  Beautiful, clickable visual cards for WiFi statistics and analysis
//

import SwiftUI

// MARK: - WiFi Overview Cards Section

struct WiFiOverviewCardsSection: View {
    let networks: [WiFiNetworkInfo]
    let kismetAnalyzer: KismetWiFiAnalyzer
    @Binding var showingKismetDashboard: Bool
    @Binding var showingStatistics: Bool

    var statistics: WiFiNetworkStatistics {
        WiFiNetworkScanner.shared.getNetworkStatistics()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                // Network Count Card
                WiFiStatCard(
                    icon: "wifi",
                    iconColor: .blue,
                    title: "Networks",
                    value: "\(networks.count)",
                    subtitle: "\(statistics.networks2_4GHz) on 2.4GHz, \(statistics.networks5GHz) on 5GHz",
                    gradientColors: [.blue, .cyan]
                ) {
                    showingStatistics = true
                }

                // Security Card
                WiFiStatCard(
                    icon: securityIcon,
                    iconColor: securityColor,
                    title: "Security",
                    value: "\(statistics.secureNetworks)/\(networks.count)",
                    subtitle: "\(statistics.openNetworks) open networks",
                    gradientColors: [securityColor, securityColor.opacity(0.7)]
                ) {
                    showingKismetDashboard = true
                }

                // Signal Quality Card
                WiFiStatCard(
                    icon: "antenna.radiowaves.left.and.right",
                    iconColor: signalColor,
                    title: "Avg Signal",
                    value: "\(statistics.averageRSSI) dBm",
                    subtitle: signalQuality,
                    gradientColors: [signalColor, signalColor.opacity(0.7)]
                ) {
                    showingStatistics = true
                }

                // Channel Congestion Card
                WiFiStatCard(
                    icon: "waveform",
                    iconColor: congestionColor,
                    title: "Channel \(statistics.mostCongestedChannel)",
                    value: "\(statistics.mostCongestedChannelCount)",
                    subtitle: "networks (most congested)",
                    gradientColors: [congestionColor, congestionColor.opacity(0.7)]
                ) {
                    showingKismetDashboard = true
                }

                // Kismet Analysis Card
                if kismetAnalyzer.networkHistory.isEmpty {
                    WiFiStatCard(
                        icon: "waveform.path.ecg",
                        iconColor: .purple,
                        title: "Kismet",
                        value: "Run",
                        subtitle: "Advanced WiFi analysis",
                        gradientColors: [.purple, .purple.opacity(0.7)]
                    ) {
                        showingKismetDashboard = true
                    }
                } else {
                    WiFiStatCard(
                        icon: kismetAnalyzer.alertCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                        iconColor: kismetAnalyzer.alertCount > 0 ? .red : .green,
                        title: "Security",
                        value: kismetAnalyzer.getKismetStatistics().securityGrade,
                        subtitle: kismetAnalyzer.alertCount > 0 ? "\(kismetAnalyzer.alertCount) alerts" : "No threats",
                        gradientColors: kismetAnalyzer.alertCount > 0 ? [.red, .orange] : [.green, .green.opacity(0.7)]
                    ) {
                        showingKismetDashboard = true
                    }
                }

                // Clients Card (if Kismet has run)
                if kismetAnalyzer.totalClientsDetected > 0 {
                    WiFiStatCard(
                        icon: "person.2.fill",
                        iconColor: .green,
                        title: "Clients",
                        value: "\(kismetAnalyzer.totalClientsDetected)",
                        subtitle: "connected devices",
                        gradientColors: [.green, .green.opacity(0.7)]
                    ) {
                        showingKismetDashboard = true
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var securityIcon: String {
        statistics.openNetworks > 0 ? "lock.open.fill" : "lock.shield.fill"
    }

    private var securityColor: Color {
        if statistics.openNetworks > 0 {
            return .red
        } else if Double(statistics.secureNetworks) / Double(max(networks.count, 1)) > 0.8 {
            return .green
        } else {
            return .orange
        }
    }

    private var signalColor: Color {
        switch statistics.averageRSSI {
        case -30...0: return .green
        case -60..<(-30): return .blue
        case -70..<(-60): return .orange
        default: return .red
        }
    }

    private var signalQuality: String {
        switch statistics.averageRSSI {
        case -30...0: return "Excellent"
        case -60..<(-30): return "Good"
        case -70..<(-60): return "Fair"
        default: return "Weak"
        }
    }

    private var congestionColor: Color {
        switch statistics.mostCongestedChannelCount {
        case 0...2: return .green
        case 3...4: return .yellow
        case 5...7: return .orange
        default: return .red
        }
    }
}

// MARK: - WiFi Stat Card

struct WiFiStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let gradientColors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                // Title
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                // Value
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: gradientColors.map { $0.opacity(0.08) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors.map { $0.opacity(0.3) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: gradientColors[0].opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WiFi Debug Info Card

struct WiFiDebugInfoCard: View {
    let networks: [WiFiNetworkInfo]
    @State private var showingDebug = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showingDebug.toggle() }) {
                HStack {
                    Image(systemName: "ladybug")
                        .foregroundColor(.orange)
                    Text("Debug Info (Show SSID extraction details)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showingDebug ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showingDebug {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SSID Extraction Results:")
                            .font(.system(size: 13, weight: .semibold))

                        ForEach(networks) { network in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SSID: '\(network.ssid)'")
                                        .font(.system(size: 12, design: .monospaced))
                                    Text("BSSID: \(network.bssid)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    if network.ssid == "Hidden Network" {
                                        Text("⚠️ SSID extraction failed")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }
}

// MARK: - WiFi Band Distribution Chart Card

struct WiFiBandChartCard: View {
    let networks: [WiFiNetworkInfo]

    var band2_4Count: Int {
        networks.filter { $0.channelBand.contains("2.4") }.count
    }

    var band5Count: Int {
        networks.filter { $0.channelBand.contains("5") }.count
    }

    var band2_4Percent: Double {
        guard networks.count > 0 else { return 0 }
        return Double(band2_4Count) / Double(networks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                Text("Band Distribution")
                    .font(.system(size: 18, weight: .semibold))
            }

            // Visual bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * band2_4Percent)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (1 - band2_4Percent))
                }
                .frame(height: 40)
                .cornerRadius(8)
                .overlay(
                    HStack {
                        if band2_4Count > 0 {
                            Text("\(band2_4Count)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                        if band5Count > 0 {
                            Text("\(band5Count)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                )
            }
            .frame(height: 40)

            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                    Text("2.4 GHz: \(band2_4Count) networks")
                        .font(.system(size: 13))
                }

                HStack(spacing: 8) {
                    Circle().fill(Color.blue).frame(width: 12, height: 12)
                    Text("5 GHz: \(band5Count) networks")
                        .font(.system(size: 13))
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Top Networks Card

struct TopNetworksCard: View {
    let networks: [WiFiNetworkInfo]

    var topNetworks: [WiFiNetworkInfo] {
        Array(networks.sorted { $0.rssi > $1.rssi }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)

                Text("Strongest Networks")
                    .font(.system(size: 18, weight: .semibold))
            }

            ForEach(topNetworks) { network in
                HStack(spacing: 12) {
                    // Rank circle
                    ZStack {
                        Circle()
                            .fill(rankColor(for: network).opacity(0.15))
                            .frame(width: 32, height: 32)

                        Text("\(topNetworks.firstIndex(where: { $0.id == network.id })! + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(rankColor(for: network))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(network.ssid)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)

                        Text("\(network.channel) • \(network.channelBand)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Signal bars
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index < signalBars(for: network) ? rankColor(for: network) : Color.gray.opacity(0.2))
                                .frame(width: 4, height: CGFloat(8 + index * 3))
                        }
                    }

                    Text("\(network.rssi)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }

    private func rankColor(for network: WiFiNetworkInfo) -> Color {
        switch network.rssi {
        case -40...0: return .green
        case -60..<(-40): return .blue
        case -70..<(-60): return .orange
        default: return .red
        }
    }

    private func signalBars(for network: WiFiNetworkInfo) -> Int {
        switch network.rssi {
        case -40...0: return 5
        case -50..<(-40): return 4
        case -60..<(-50): return 3
        case -70..<(-60): return 2
        case -80..<(-70): return 1
        default: return 0
        }
    }
}

// MARK: - Security Overview Card

struct SecurityOverviewCard: View {
    let networks: [WiFiNetworkInfo]
    @Binding var showingKismetDashboard: Bool

    var secureNetworks: Int {
        networks.filter { !$0.securityType.contains("Open") && !$0.securityType.contains("WEP") }.count
    }

    var openNetworks: Int {
        networks.filter { $0.securityType.contains("Open") }.count
    }

    var wepNetworks: Int {
        networks.filter { $0.securityType.contains("WEP") }.count
    }

    var wpa2Networks: Int {
        networks.filter { $0.securityType.contains("WPA2") }.count
    }

    var wpa3Networks: Int {
        networks.filter { $0.securityType.contains("WPA3") }.count
    }

    var body: some View {
        Button(action: { showingKismetDashboard = true }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 20))
                        .foregroundColor(overallSecurityColor)

                    Text("Security Overview")
                        .font(.system(size: 18, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }

                // Security breakdown
                VStack(spacing: 10) {
                    if wpa3Networks > 0 {
                        SecurityRow(icon: "checkmark.shield.fill", label: "WPA3", count: wpa3Networks, color: .green)
                    }
                    if wpa2Networks > 0 {
                        SecurityRow(icon: "checkmark.shield", label: "WPA2", count: wpa2Networks, color: .blue)
                    }
                    if openNetworks > 0 {
                        SecurityRow(icon: "lock.open.fill", label: "Open", count: openNetworks, color: .red)
                    }
                    if wepNetworks > 0 {
                        SecurityRow(icon: "exclamationmark.triangle.fill", label: "WEP", count: wepNetworks, color: .orange)
                    }
                }

                Divider()

                HStack {
                    Text("\(secureNetworks)/\(networks.count) networks secure")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(overallSecurityColor)

                    Spacer()

                    Text("Tap for details")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var overallSecurityColor: Color {
        if openNetworks > 0 || wepNetworks > 0 {
            return .red
        } else if Double(secureNetworks) / Double(max(networks.count, 1)) > 0.8 {
            return .green
        } else {
            return .orange
        }
    }
}

struct SecurityRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 60, alignment: .leading)

            Spacer()

            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
    }
}
