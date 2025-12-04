//
//  WiFiNetworksView.swift
//  NMAP Plus Security Scanner - WiFi Networks Tab
//
//  Created by Jordan Koch on 2025-12-01.
//
//  Displays all visible WiFi networks with detailed information and security analysis.
//

import SwiftUI

struct WiFiNetworksView: View {
    @StateObject private var scanner = WiFiNetworkScanner.shared
    @StateObject private var kismetAnalyzer = KismetWiFiAnalyzer.shared
    @State private var showingStatistics = false
    @State private var showingKismetDashboard = false
    @State private var selectedNetwork: WiFiNetworkInfo?
    @State private var sortBy: SortOption = .signalStrength
    @State private var errorMessage: String?
    @State private var showingError = false

    enum SortOption: String, CaseIterable {
        case signalStrength = "Signal Strength"
        case ssid = "Name"
        case channel = "Channel"
        case security = "Security"
    }

    var sortedNetworks: [WiFiNetworkInfo] {
        switch sortBy {
        case .signalStrength:
            return scanner.discoveredNetworks.sorted { $0.rssi > $1.rssi }
        case .ssid:
            return scanner.discoveredNetworks.sorted { $0.ssid < $1.ssid }
        case .channel:
            return scanner.discoveredNetworks.sorted { $0.channel < $1.channel }
        case .security:
            return scanner.discoveredNetworks.sorted { $0.securityLevel > $1.securityLevel }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WiFi Networks")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.primary)

                            if !scanner.discoveredNetworks.isEmpty {
                                Text("\(scanner.discoveredNetworks.count) networks")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Kismet Analysis Button
                        if !scanner.discoveredNetworks.isEmpty {
                            Button(action: {
                                showingKismetDashboard = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 20, weight: .medium))
                                    if kismetAnalyzer.alertCount > 0 {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 20, height: 20)
                                            Text("\(kismetAnalyzer.alertCount)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .foregroundColor(.purple)
                            }
                            .buttonStyle(.plain)
                        }

                        // Statistics Button
                        if !scanner.discoveredNetworks.isEmpty {
                            Button(action: {
                                showingStatistics = true
                            }) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Scanning Status
                    if scanner.isScanning {
                        WiFiScanningStatusCard(scanner: scanner)
                    }

                    // Kismet Analysis Status
                    if kismetAnalyzer.isAnalyzing {
                        KismetAnalysisProgressCard(analyzer: kismetAnalyzer)
                            .padding(.horizontal, 20)
                    }

                    // Kismet Alerts Banner
                    if kismetAnalyzer.alertCount > 0 && !kismetAnalyzer.isAnalyzing {
                        Button(action: { showingKismetDashboard = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(kismetAnalyzer.alertCount) Security Alerts Detected")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Tap to view Kismet analysis details")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }

                    // Visual Statistics Cards (NEW!)
                    if !scanner.discoveredNetworks.isEmpty {
                        WiFiOverviewCardsSection(
                            networks: scanner.discoveredNetworks,
                            kismetAnalyzer: kismetAnalyzer,
                            showingKismetDashboard: $showingKismetDashboard,
                            showingStatistics: $showingStatistics
                        )
                    }

                    // Band Distribution Chart (NEW!)
                    if !scanner.discoveredNetworks.isEmpty {
                        WiFiBandChartCard(networks: scanner.discoveredNetworks)
                    }

                    // Top Networks (NEW!)
                    if !scanner.discoveredNetworks.isEmpty {
                        TopNetworksCard(networks: scanner.discoveredNetworks)
                    }

                    // Security Overview (NEW!)
                    if !scanner.discoveredNetworks.isEmpty {
                        SecurityOverviewCard(
                            networks: scanner.discoveredNetworks,
                            showingKismetDashboard: $showingKismetDashboard
                        )
                    }

                    // Debug Info (shows SSID extraction details)
                    if !scanner.discoveredNetworks.isEmpty {
                        WiFiDebugInfoCard(networks: scanner.discoveredNetworks)
                    }

                    // Current Network Card
                    if let currentNetwork = scanner.currentNetwork {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Network")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)

                            WiFiNetworkInfoCard(network: currentNetwork, isCurrent: true, kismetAnalyzer: kismetAnalyzer)
                                .padding(.horizontal, 20)
                        }
                    }

                    // Sort Options
                    if !scanner.discoveredNetworks.isEmpty {
                        HStack(spacing: 8) {
                            Text("Sort by:")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)

                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    sortBy = option
                                }) {
                                    Text(option.rawValue)
                                        .font(.system(size: 14, weight: sortBy == option ? .semibold : .regular))
                                        .foregroundColor(sortBy == option ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(sortBy == option ? Color.blue : Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Networks Grid
                    if !scanner.discoveredNetworks.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Networks")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                            ], spacing: 16) {
                                ForEach(sortedNetworks) { network in
                                    WiFiNetworkInfoCard(network: network, isCurrent: false, kismetAnalyzer: kismetAnalyzer)
                                        .onTapGesture {
                                            selectedNetwork = network
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Scan Button
                    if !scanner.isScanning {
                        Button(action: {
                            Task {
                                do {
                                    try await scanner.scanNetworks()
                                } catch WiFiScanError.noInterface {
                                    errorMessage = "No WiFi interface found. Please ensure WiFi is enabled."
                                    showingError = true
                                } catch WiFiScanError.permissionDenied {
                                    errorMessage = "Permission denied. Please grant Location Services access in System Settings > Privacy & Security > Location Services."
                                    showingError = true
                                } catch WiFiScanError.scanFailed(let message) {
                                    errorMessage = "WiFi scan failed: \(message)"
                                    showingError = true
                                } catch {
                                    errorMessage = "Unexpected error: \(error.localizedDescription)"
                                    showingError = true
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "wifi.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Scan WiFi Networks")
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
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .sheet(isPresented: $showingStatistics) {
                WiFiStatisticsView(statistics: scanner.getNetworkStatistics())
            }
            .sheet(isPresented: $showingKismetDashboard) {
                KismetDashboardView(analyzer: kismetAnalyzer, networks: scanner.discoveredNetworks)
            }
            .sheet(item: $selectedNetwork) { network in
                WiFiNetworkDetailView(network: network)
            }
            .alert("WiFi Scan Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
}

// MARK: - WiFi Scanning Status Card

struct WiFiScanningStatusCard: View {
    @ObservedObject var scanner: WiFiNetworkScanner

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Scanning WiFi Networks")
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(scanner.discoveredNetworks.count)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Networks")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
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

// MARK: - WiFi Network Card

struct WiFiNetworkInfoCard: View {
    let network: WiFiNetworkInfo
    let isCurrent: Bool
    @ObservedObject var kismetAnalyzer: KismetWiFiAnalyzer

    var clientCount: Int {
        kismetAnalyzer.detectedClients[network.bssid]?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // SSID and Signal
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(signalColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: wifiIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(signalColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(network.ssid)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if isCurrent {
                            Text("CONNECTED")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green)
                                .cornerRadius(6)
                        }

                        // Client count badge
                        if clientCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 9))
                                Text("\(clientCount)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                        }
                    }

                    Text("\(network.signalStrength) • \(network.rssi) dBm")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Network Details
            VStack(alignment: .leading, spacing: 8) {
                WiFiDetailRow(icon: "lock.shield", label: "Security", value: network.securityType, color: securityColor)
                WiFiDetailRow(icon: "antenna.radiowaves.left.and.right", label: "Channel", value: "\(network.channel) (\(network.channelBand))", color: .blue)
                WiFiDetailRow(icon: "speedometer", label: "Width", value: network.channelWidth, color: .purple)
                WiFiDetailRow(icon: "wave.3.right", label: "Standards", value: network.supportedPHYModes.suffix(2).joined(separator: ", "), color: .orange)
            }

            // Security Badge
            if network.securityType.contains("Open") {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("Unsecured Network")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red)
                .cornerRadius(8)
            } else if network.securityType.contains("WEP") {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 12))
                    Text("Weak Security")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrent ? Color.green : Color.gray.opacity(0.1), lineWidth: isCurrent ? 2 : 1)
        )
    }

    private var wifiIcon: String {
        let quality = network.signalQuality
        if quality > 75 {
            return "wifi"
        } else if quality > 50 {
            return "wifi"
        } else if quality > 25 {
            return "wifi"
        } else {
            return "wifi.slash"
        }
    }

    private var signalColor: Color {
        let quality = network.signalQuality
        if quality > 75 {
            return .green
        } else if quality > 50 {
            return .blue
        } else if quality > 25 {
            return .orange
        } else {
            return .red
        }
    }

    private var securityColor: Color {
        switch network.securityLevel {
        case "Excellent": return .green
        case "Good": return .blue
        case "Fair": return .orange
        case "Weak": return .red
        case "None": return .red
        default: return .gray
        }
    }
}

// MARK: - Detail Row

struct WiFiDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

// MARK: - WiFi Network Detail View

struct WiFiNetworkDetailView: View {
    let network: WiFiNetworkInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(network.ssid)
                        .font(.system(size: 28, weight: .bold))

                    Text("BSSID: \(network.bssid)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Signal Information
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        WiFiInfoRow(label: "Signal Strength", value: network.signalStrength)
                        WiFiInfoRow(label: "RSSI", value: "\(network.rssi) dBm")
                        WiFiInfoRow(label: "Signal Quality", value: "\(network.signalQuality)%")
                        WiFiInfoRow(label: "Noise Level", value: "\(network.noise) dBm")
                    }
                } label: {
                    Label("Signal Information", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .semibold))
                }

                // Security Information
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        WiFiInfoRow(label: "Security Type", value: network.securityType)
                        WiFiInfoRow(label: "Security Level", value: network.securityLevel)
                    }
                } label: {
                    Label("Security", systemImage: "lock.shield")
                        .font(.system(size: 17, weight: .semibold))
                }

                // Channel Information
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        WiFiInfoRow(label: "Channel", value: "\(network.channel)")
                        WiFiInfoRow(label: "Band", value: network.channelBand)
                        WiFiInfoRow(label: "Channel Width", value: network.channelWidth)
                        WiFiInfoRow(label: "Congestion", value: network.estimatedCongestion)
                    }
                } label: {
                    Label("Channel Information", systemImage: "waveform")
                        .font(.system(size: 17, weight: .semibold))
                }

                // Technical Details
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        WiFiInfoRow(label: "PHY Modes", value: network.supportedPHYModes.joined(separator: ", "))
                        WiFiInfoRow(label: "Beacon Interval", value: "\(network.beaconInterval) ms")
                        if let countryCode = network.countryCode {
                            WiFiInfoRow(label: "Country Code", value: countryCode)
                        }
                        WiFiInfoRow(label: "IBSS (Ad-hoc)", value: network.isIBSS ? "Yes" : "No")
                        WiFiInfoRow(label: "Personal Hotspot", value: network.isPersonalHotspot ? "Yes" : "No")
                    }
                } label: {
                    Label("Technical Details", systemImage: "info.circle")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .padding(24)
        }
        .frame(width: 600, height: 700)
    }
}

struct WiFiInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - WiFi Statistics View

struct WiFiStatisticsView: View {
    let statistics: WiFiNetworkStatistics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("WiFi Network Statistics")
                    .font(.system(size: 28, weight: .bold))

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Total Networks", value: "\(statistics.totalNetworks)")
                        StatRow(label: "2.4 GHz Networks", value: "\(statistics.networks2_4GHz)")
                        StatRow(label: "5 GHz Networks", value: "\(statistics.networks5GHz)")
                    }
                } label: {
                    Label("Network Distribution", systemImage: "chart.bar")
                        .font(.system(size: 17, weight: .semibold))
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Secure Networks", value: "\(statistics.secureNetworks)")
                        StatRow(label: "Open Networks", value: "\(statistics.openNetworks)")
                        StatRow(label: "Personal Hotspots", value: "\(statistics.personalHotspots)")
                    }
                } label: {
                    Label("Security", systemImage: "lock.shield")
                        .font(.system(size: 17, weight: .semibold))
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Average Signal", value: "\(statistics.averageRSSI) dBm")
                        StatRow(label: "Most Congested Channel", value: "\(statistics.mostCongestedChannel)")
                        StatRow(label: "Networks on Channel", value: "\(statistics.mostCongestedChannelCount)")
                    }
                } label: {
                    Label("Signal Analysis", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 600)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    WiFiNetworksView()
}
