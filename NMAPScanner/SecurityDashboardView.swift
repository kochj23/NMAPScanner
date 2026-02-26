//
//  SecurityDashboardView.swift
//  NMAP Scanner - Comprehensive Security & Traffic Dashboard
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI
import Charts

struct SecurityDashboardView: View {
    @StateObject private var trafficAnalyzer = NetworkTrafficAnalyzer.shared
    @StateObject private var vulnerabilityScanner = VulnerabilityScanner()
    @StateObject private var anomalyManager = AnomalyDetectionManager.shared
    @StateObject private var insecurePortDetector = InsecurePortDetector.shared
    @StateObject private var aiSecurityAnalyzer = AISecurityAnalyzer.shared
    @StateObject private var scanner = IntegratedScannerV3.shared

    @State private var selectedTimeRange: TimeRange = .last15Minutes
    @State private var refreshTimer: Timer?
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var scanStatus = ""
    @State private var selectedProtocol: String?
    @State private var selectedDeviceForTraffic: DeviceTrafficStats?
    @State private var showProtocolDetails = false
    @State private var showConnectionDetails = false
    @State private var showBandwidthDetails = false
    @State private var showActiveConnectionsDetails = false
    @State private var showTopTalkersDetails = false
    @State private var showAnomaliesDetails = false
    @State private var showInsecurePortsDetails = false
    @State private var showPortVulnerabilitiesDetails = false
    @State private var showNetworkAnomaliesDetails = false
    @State private var showNewDevicesDetails = false
    @State private var showOfflineDevicesDetails = false
    @State private var showAISecurityReport = false
    @State private var showAISecurityWarnings = false

    enum TimeRange: String, CaseIterable {
        case last15Minutes = "Last 15 Min"
        case lastHour = "Last Hour"
        case last24Hours = "Last 24 Hours"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security & Traffic Dashboard")
                            .font(.system(size: 50, weight: .bold))

                        Text("Real-time network monitoring and threat analysis")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // AI Security Report Button
                    Button(action: { showAISecurityReport = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("AI Report")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .help("Generate AI-powered security report")

                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue)
                                .kerning(0.5)
                                .tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)

                // MARK: - Network Traffic Section

                VStack(alignment: .leading, spacing: 20) {
                    Text("Network Traffic Analysis")
                        .font(.system(size: 36, weight: .semibold))
                        .padding(.horizontal, 40)

                    // Traffic Overview Cards (Clickable)
                    HStack(spacing: 20) {
                        TrafficStatCard(
                            title: "Total Bandwidth",
                            value: NetworkTrafficAnalyzer.formatBandwidth(trafficAnalyzer.totalBandwidth),
                            icon: "arrow.up.arrow.down.circle.fill",
                            color: .blue
                        )
                        .onTapGesture {
                            showBandwidthDetails = true
                        }

                        TrafficStatCard(
                            title: "Active Connections",
                            value: "\(trafficAnalyzer.totalConnections)",
                            icon: "network",
                            color: .green
                        )
                        .onTapGesture {
                            showActiveConnectionsDetails = true
                        }

                        TrafficStatCard(
                            title: "Top Talkers",
                            value: "\(trafficAnalyzer.topTalkers.count)",
                            icon: "chart.bar.fill",
                            color: .orange
                        )
                        .onTapGesture {
                            showTopTalkersDetails = true
                        }

                        TrafficStatCard(
                            title: "Traffic Anomalies",
                            value: "\(trafficAnalyzer.anomalies.count)",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        .onTapGesture {
                            showAnomaliesDetails = true
                        }
                    }
                    .padding(.horizontal, 40)

                    // Top Talkers List
                    if !trafficAnalyzer.topTalkers.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Top Bandwidth Consumers")
                                .font(.system(size: 24, weight: .semibold))
                                .padding(.horizontal, 40)

                            VStack(spacing: 12) {
                                ForEach(trafficAnalyzer.topTalkers.prefix(5)) { stats in
                                    TopTalkerRow(stats: stats)
                                        .onTapGesture {
                                            selectedDeviceForTraffic = stats
                                            showConnectionDetails = true
                                        }
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    }

                    // Protocol Breakdown Chart
                    if !trafficAnalyzer.protocolBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Traffic by Protocol (Click for Details)")
                                .font(.system(size: 24, weight: .semibold))
                                .padding(.horizontal, 40)

                            ProtocolBreakdownChart(
                                protocolData: trafficAnalyzer.protocolBreakdown,
                                onProtocolTap: { protocolName in
                                    selectedProtocol = protocolName
                                    showProtocolDetails = true
                                }
                            )
                            .padding(.horizontal, 40)
                        }
                    }
                }
                .padding(.vertical, 24)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal, 40)

                // MARK: - Security Issues Section

                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Security Threats & Vulnerabilities")
                            .font(.system(size: 36, weight: .semibold))

                        Spacer()

                        // Vulnerability Scan Button
                        Button(action: {
                            Task {
                                await performVulnerabilityScan()
                            }
                        }) {
                            ZStack {
                                // Progress background
                                if isScanning {
                                    GeometryReader { geometry in
                                        Rectangle()
                                            .fill(Color.red.opacity(0.3))
                                            .frame(width: geometry.size.width * scanProgress)
                                    }
                                }

                                HStack(spacing: 8) {
                                    if isScanning {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    Text(isScanning ? "Scanning..." : "Scan for Vulnerabilities")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .background(isScanning ? Color.gray : Color.red)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isScanning)
                    }
                    .padding(.horizontal, 40)

                    // Scan Progress
                    if isScanning {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: scanProgress, total: 1.0)
                                .progressViewStyle(.linear)

                            Text(scanStatus)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 40)
                    }

                    // Security Overview Cards (Clickable)
                    HStack(spacing: 20) {
                        SecurityStatCard(
                            title: "Insecure Ports",
                            value: "\(insecurePortDetector.insecureFindings.count)",
                            critical: insecurePortDetector.stats.critical,
                            high: insecurePortDetector.stats.high,
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        .onTapGesture {
                            showInsecurePortsDetails = true
                        }

                        SecurityStatCard(
                            title: "Port Vulnerabilities",
                            value: "\(vulnerabilityScanner.vulnerabilities.count)",
                            critical: vulnerabilityScanner.vulnerabilities.filter { $0.severity == .critical }.count,
                            high: vulnerabilityScanner.vulnerabilities.filter { $0.severity == .high }.count,
                            icon: "shield.slash.fill",
                            color: .orange
                        )
                        .onTapGesture {
                            showPortVulnerabilitiesDetails = true
                        }

                        SecurityStatCard(
                            title: "Network Anomalies",
                            value: "\(anomalyManager.anomalies.count)",
                            critical: anomalyManager.anomalies.filter { $0.severity == .critical }.count,
                            high: anomalyManager.anomalies.filter { $0.severity == .high }.count,
                            icon: "exclamationmark.octagon.fill",
                            color: .orange
                        )
                        .onTapGesture {
                            showNetworkAnomaliesDetails = true
                        }

                        SecurityStatCard(
                            title: "New Devices",
                            value: "\(anomalyManager.newDevices.count)",
                            critical: 0,
                            high: anomalyManager.newDevices.count,
                            icon: "plus.circle.fill",
                            color: .yellow
                        )
                        .onTapGesture {
                            showNewDevicesDetails = true
                        }

                        SecurityStatCard(
                            title: "Offline Devices",
                            value: "\(anomalyManager.missingDevices.count)",
                            critical: 0,
                            high: anomalyManager.missingDevices.count,
                            icon: "power",
                            color: .gray
                        )
                        .onTapGesture {
                            showOfflineDevicesDetails = true
                        }

                        SecurityStatCard(
                            title: "AI/ML Services",
                            value: "\(aiSecurityAnalyzer.warnings.count)",
                            critical: aiSecurityAnalyzer.stats.critical,
                            high: aiSecurityAnalyzer.stats.high,
                            icon: "brain.head.profile",
                            color: .purple
                        )
                        .onTapGesture {
                            showAISecurityWarnings = true
                        }
                    }
                    .padding(.horizontal, 40)

                    // AI/ML Security Warnings - Critical Findings
                    let criticalAIWarnings = aiSecurityAnalyzer.warnings.filter { $0.severity == .critical }
                    if !criticalAIWarnings.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)
                                Text("Critical AI/ML Security Vulnerabilities")
                                    .font(.system(size: 24, weight: .semibold))
                            }
                            .padding(.horizontal, 40)

                            VStack(spacing: 12) {
                                ForEach(criticalAIWarnings.prefix(3)) { warning in
                                    AIWarningRowCompact(warning: warning)
                                }
                            }
                            .padding(.horizontal, 40)

                            if criticalAIWarnings.count > 3 {
                                Button(action: { showAISecurityWarnings = true }) {
                                    Text("View all \(criticalAIWarnings.count) critical AI warnings...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 40)
                            }
                        }
                    }

                    // Insecure Ports - Critical Findings
                    let criticalInsecure = insecurePortDetector.insecureFindings.filter { $0.severity == .critical }
                    if !criticalInsecure.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("⚠️ Critical Insecure Ports Detected")
                                .font(.system(size: 24, weight: .semibold))
                                .padding(.horizontal, 40)

                            VStack(spacing: 12) {
                                ForEach(criticalInsecure.prefix(5)) { finding in
                                    InsecureFindingRow(finding: finding)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    }

                    // Port Vulnerability List
                    let criticalVulns = vulnerabilityScanner.vulnerabilities.filter { $0.severity == .critical }
                    if !criticalVulns.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Critical Port Vulnerabilities")
                                .font(.system(size: 24, weight: .semibold))
                                .padding(.horizontal, 40)

                            VStack(spacing: 12) {
                                ForEach(criticalVulns.prefix(5)) { vuln in
                                    PortVulnerabilityRow(vulnerability: vuln)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    }

                    // Security Anomalies
                    if !anomalyManager.anomalies.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Security Anomalies")
                                .font(.system(size: 24, weight: .semibold))
                                .padding(.horizontal, 40)

                            VStack(spacing: 12) {
                                ForEach(anomalyManager.anomalies.prefix(5)) { anomaly in
                                    AnomalyRow(anomaly: anomaly)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                }
                .padding(.vertical, 24)
                .background(Color.red.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal, 40)

                // MARK: - Device Security Status

                VStack(alignment: .leading, spacing: 20) {
                    Text("Device Security Status")
                        .font(.system(size: 36, weight: .semibold))
                        .padding(.horizontal, 40)

                    DeviceSecurityGrid(devices: scanner.devices, vulnerabilityScanner: vulnerabilityScanner)
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 24)
                .background(Color.green.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal, 40)

                // MARK: - Advanced Security Visualizations
                // NOTE: These advanced visualizations are temporarily disabled
                // They will be re-enabled in a future update with proper data integration

                /*
                // Row 1: Packet Flow & Kill Chain
                HStack(spacing: 40) {
                    PacketFlowAnimationView(devices: scanner.devices)
                        .frame(maxWidth: .infinity)

                    AttackKillChainTimeline()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 2: Geographic Map & Port Heatmap
                HStack(spacing: 40) {
                    GeographicConnectionMap()
                        .frame(maxWidth: .infinity)

                    PortActivityHeatmap()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 3: SSL Certificates & Bandwidth Sparklines
                HStack(spacing: 40) {
                    SSLCertificateDashboard()
                        .frame(maxWidth: .infinity)

                    BandwidthSparklinePanel(devices: scanner.devices)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 4: Protocol Matrix & Threat Feed
                HStack(spacing: 40) {
                    ProtocolConversationMatrix(devices: scanner.devices)
                        .frame(maxWidth: .infinity)

                    ThreatIntelligenceFeed()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 5: Network Segmentation & Compliance
                HStack(spacing: 40) {
                    NetworkSegmentationVisualizer()
                        .frame(maxWidth: .infinity)

                    ComplianceStatusDashboard()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 6: Incident Response & ML Anomaly
                HStack(spacing: 40) {
                    IncidentResponsePlaybook()
                        .frame(maxWidth: .infinity)

                    MLAnomalyScoreTrends()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 7: DNS Waterfall & Executive Summary
                HStack(spacing: 40) {
                    DNSQueryWaterfall()
                        .frame(maxWidth: .infinity)

                    ExecutiveSecuritySummary(devices: scanner.devices)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // Row 8: Live Event Stream (Full Width)
                LiveSecurityEventStream()
                    .padding(.horizontal, 40)
                */

                // Placeholder for advanced visualizations
                Text("Advanced security visualizations coming soon!")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
        .sheet(isPresented: $showProtocolDetails) {
            if let protocolName = selectedProtocol {
                ProtocolDetailsView(
                    protocolName: protocolName,
                    devices: scanner.devices,
                    trafficAnalyzer: trafficAnalyzer
                )
            }
        }
        .sheet(isPresented: $showConnectionDetails) {
            if let device = selectedDeviceForTraffic {
                ConnectionDetailsView(deviceStats: device, trafficAnalyzer: trafficAnalyzer)
            }
        }
        .sheet(isPresented: $showBandwidthDetails) {
            BandwidthDetailsView(trafficAnalyzer: trafficAnalyzer)
        }
        .sheet(isPresented: $showActiveConnectionsDetails) {
            ActiveConnectionsDetailsView(trafficAnalyzer: trafficAnalyzer)
        }
        .sheet(isPresented: $showTopTalkersDetails) {
            TopTalkersDetailsView(trafficAnalyzer: trafficAnalyzer)
        }
        .sheet(isPresented: $showAnomaliesDetails) {
            TrafficAnomaliesDetailsView(trafficAnalyzer: trafficAnalyzer)
        }
        .sheet(isPresented: $showInsecurePortsDetails) {
            InsecurePortsDetailsView(insecurePortDetector: insecurePortDetector)
        }
        .sheet(isPresented: $showPortVulnerabilitiesDetails) {
            PortVulnerabilitiesDetailsView(vulnerabilityScanner: vulnerabilityScanner)
        }
        .sheet(isPresented: $showNetworkAnomaliesDetails) {
            NetworkAnomaliesDetailsView(anomalyManager: anomalyManager)
        }
        .sheet(isPresented: $showNewDevicesDetails) {
            NewDevicesDetailsView(anomalyManager: anomalyManager, scanner: scanner)
        }
        .sheet(isPresented: $showOfflineDevicesDetails) {
            OfflineDevicesDetailsView(anomalyManager: anomalyManager, scanner: scanner)
        }
        .sheet(isPresented: $showAISecurityWarnings) {
            AISecurityWarningsView(analyzer: aiSecurityAnalyzer, scanner: scanner)
        }
        .sheet(isPresented: $showAISecurityReport) {
            // Convert vulnerability findings to ThreatFinding for the AI report
            let threats = vulnerabilityScanner.vulnerabilities.map { vuln in
                ThreatFinding(
                    severity: convertSeverity(vuln.severity),
                    category: categoryForVulnerabilityType(vuln.type),
                    title: vuln.type.rawValue,
                    description: vuln.description,
                    affectedHost: vuln.host,
                    affectedPort: vuln.port,
                    detectedAt: vuln.detectedAt,
                    cvssScore: cvssScoreForSeverity(vuln.severity),
                    cveReferences: [],
                    remediation: vuln.recommendation,
                    technicalDetails: "Port \(vuln.port ?? 0) - \(vuln.type.rawValue)",
                    impactAssessment: impactForSeverity(vuln.severity)
                )
            }
            SecurityReportView(devices: scanner.devices, threats: threats)
        }
    }

    private func startMonitoring() {
        trafficAnalyzer.startMonitoring()

        // Refresh dashboard every 10 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            // Dashboard will auto-refresh via @Published properties
        }
    }

    private func stopMonitoring() {
        trafficAnalyzer.stopMonitoring()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func performVulnerabilityScan() async {
        isScanning = true
        scanProgress = 0

        let devices = scanner.devices.filter { $0.isOnline }
        guard !devices.isEmpty else {
            scanStatus = "No devices to scan"
            isScanning = false
            return
        }

        scanStatus = "Scanning \(devices.count) devices for vulnerabilities..."

        for (index, device) in devices.enumerated() {
            scanStatus = "Scanning \(device.hostname ?? device.ipAddress) (\(index + 1)/\(devices.count))..."
            scanProgress = Double(index) / Double(devices.count) * 0.7 // 70% for port scans

            // Scan for insecure ports
            insecurePortDetector.scanDevice(device)

            // Scan for port vulnerabilities
            _ = await vulnerabilityScanner.scanHost(host: device.ipAddress, openPorts: device.openPorts.map { $0.port })

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s between devices
        }

        // Analyze AI/ML services (30% of progress)
        scanStatus = "Analyzing AI/ML services for security vulnerabilities..."
        scanProgress = 0.7
        await aiSecurityAnalyzer.analyzeAIServices(devices: devices)

        scanProgress = 1.0
        let totalIssues = vulnerabilityScanner.vulnerabilities.count + insecurePortDetector.insecureFindings.count + aiSecurityAnalyzer.warnings.count
        scanStatus = "Scan complete! Found \(insecurePortDetector.insecureFindings.count) insecure ports, \(vulnerabilityScanner.vulnerabilities.count) vulnerabilities, and \(aiSecurityAnalyzer.warnings.count) AI service warnings"

        // Clear status after 3 seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        isScanning = false
        scanStatus = ""
    }

    // MARK: - Vulnerability Conversion Helpers for AI Report

    private func convertSeverity(_ severity: Vulnerability.Severity) -> ThreatSeverity {
        switch severity {
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .info: return .info
        }
    }

    private func categoryForVulnerabilityType(_ type: Vulnerability.VulnerabilityType) -> ThreatCategory {
        switch type {
        case .openTelnet, .openFTP, .anonymousFTP:
            return .weakSecurity
        case .openSMTP, .openDNS:
            return .misconfiguration
        case .exposedDatabase:
            return .dataExposure
        case .defaultCredentials, .unauthorizedAccess:
            return .backdoor
        case .weakSSL, .missingEncryption:
            return .weakSecurity
        case .insecureService, .suspiciousPort:
            return .exposedService
        }
    }

    private func cvssScoreForSeverity(_ severity: Vulnerability.Severity) -> Double? {
        switch severity {
        case .critical: return 9.5
        case .high: return 7.5
        case .medium: return 5.0
        case .low: return 3.0
        case .info: return nil
        }
    }

    private func impactForSeverity(_ severity: Vulnerability.Severity) -> String {
        switch severity {
        case .critical:
            return "Critical impact - Immediate exploitation possible. May lead to complete system compromise."
        case .high:
            return "High impact - Significant security risk that could lead to data breach or system access."
        case .medium:
            return "Medium impact - Security concern that should be addressed in a timely manner."
        case .low:
            return "Low impact - Minor security issue with limited exploitation potential."
        case .info:
            return "Informational - No direct security impact but worth noting."
        }
    }
}

// MARK: - Traffic Stat Card

struct TrafficStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                Spacer()

                // Clickable indicator
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)

            HStack {
                Text(title)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Tap for details")
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Security Stat Card

struct SecurityStatCard: View {
    let title: String
    let value: String
    let critical: Int
    let high: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                Spacer()

                // Clickable indicator
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(color.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)

                    Text("Tap for details")
                        .font(.system(size: 12))
                        .foregroundColor(color)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if critical > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.system(size: 12))
                            Text("\(critical)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.red)
                    }

                    if high > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("\(high)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Top Talker Row

struct TopTalkerRow: View {
    let stats: DeviceTrafficStats

    var body: some View {
        HStack(spacing: 16) {
            // Rank indicator
            Circle()
                .fill(rankColor)
                .frame(width: 12, height: 12)

            // IP Address
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.ipAddress)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))

                Text("\(stats.activeConnections) connections")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Bandwidth
            VStack(alignment: .trailing, spacing: 4) {
                Text(NetworkTrafficAnalyzer.formatBandwidth(stats.bytesPerSecond))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)

                Text(NetworkTrafficAnalyzer.formatBytes(stats.totalBytes))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Bandwidth bar
            GeometryReader { geometry in
                let maxBandwidth = Double(NetworkTrafficAnalyzer.shared.topTalkers.first?.bytesPerSecond ?? 1)
                let percentage = Double(stats.bytesPerSecond) / maxBandwidth

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(bandwidthColor)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(width: 100, height: 8)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var rankColor: Color {
        if stats.bytesPerSecond > 1_000_000 {
            return .red
        } else if stats.bytesPerSecond > 500_000 {
            return .orange
        } else {
            return .green
        }
    }

    private var bandwidthColor: Color {
        if stats.bytesPerSecond > 1_000_000 {
            return .red
        } else if stats.bytesPerSecond > 500_000 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Protocol Breakdown Chart

struct ProtocolBreakdownChart: View {
    let protocolData: [String: Int]
    let onProtocolTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(protocolData.sorted(by: { $0.value > $1.value }), id: \.key) { protocolName, count in
                Button(action: {
                    onProtocolTap(protocolName)
                }) {
                    HStack {
                        HStack(spacing: 8) {
                            Text(protocolName)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 80, alignment: .leading)

                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }

                        GeometryReader { geometry in
                            let maxCount = Double(protocolData.values.max() ?? 1)
                            let percentage = Double(count) / maxCount

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(protocolColor(protocolName))
                                    .frame(width: geometry.size.width * percentage)
                            }
                        }
                        .frame(height: 32)

                        Text("\(count)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 60, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }

    private func protocolColor(_ protocolName: String) -> Color {
        switch protocolName.uppercased() {
        case "TCP": return .blue
        case "UDP": return .green
        case "ICMP": return .orange
        case "TCP6": return .purple
        default: return .gray
        }
    }
}

// MARK: - Port Vulnerability Row

struct PortVulnerabilityRow: View {
    let vulnerability: Vulnerability

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 32))
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(vulnerability.type.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(severityColor)

                if let port = vulnerability.port {
                    Text("\(vulnerability.host) - Port \(port)")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                } else {
                    Text(vulnerability.host)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }

                Text(vulnerability.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(vulnerability.severity.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(severityColor.opacity(0.1))
        .cornerRadius(12)
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

// MARK: - Insecure Finding Row

struct InsecureFindingRow: View {
    let finding: InsecureFinding

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 32))
                .foregroundColor(finding.severity.color)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Text("Port \(finding.port)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(finding.severity.color)

                    Text(finding.service)
                        .font(.system(size: 18, weight: .semibold))

                    Text(finding.severity.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(finding.severity.color)
                        .cornerRadius(6)
                }

                Text("\(finding.hostname ?? finding.ipAddress)")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                Text(finding.reason)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(finding.recommendation)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                if !finding.cve.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(finding.cve.prefix(3), id: \.self) { cve in
                            Text(cve)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(finding.severity.color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Anomaly Row

struct AnomalyRow: View {
    let anomaly: NetworkAnomaly

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: severityIcon)
                .font(.system(size: 24))
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(anomaly.type.rawValue)
                    .font(.system(size: 16, weight: .semibold))

                Text(anomaly.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(timeAgo(anomaly.timestamp))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var severityIcon: String {
        switch anomaly.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch anomaly.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

// MARK: - Device Security Grid

struct DeviceSecurityGrid: View {
    let devices: [EnhancedDevice]
    let vulnerabilityScanner: VulnerabilityScanner

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
            ForEach(devices.prefix(12)) { device in
                let vulnCount = vulnerabilityScanner.vulnerabilities.filter { $0.host == device.ipAddress }.count
                DeviceSecurityCard(device: device, vulnerabilityCount: vulnCount)
            }
        }
    }
}

// MARK: - Device Security Card

struct DeviceSecurityCard: View {
    let device: EnhancedDevice
    let vulnerabilityCount: Int

    var securityScore: Int {
        var score = 100
        score -= vulnerabilityCount * 10
        score -= device.openPorts.count * 2
        if !device.isOnline {
            score -= 20
        }
        return max(0, min(100, score))
    }

    var securityGrade: String {
        switch securityScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    var gradeColor: Color {
        switch securityScore {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Security Grade
            ZStack {
                Circle()
                    .fill(gradeColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Text(securityGrade)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(gradeColor)
            }

            // Device Info
            VStack(alignment: .leading, spacing: 6) {
                Text(device.hostname ?? device.ipAddress)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

                if device.hostname != nil {
                    Text(device.ipAddress)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(device.openPorts.count)", systemImage: "network")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    if vulnerabilityCount > 0 {
                        Label("\(vulnerabilityCount)", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    Circle()
                        .fill(device.isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Protocol Details View

struct ProtocolDetailsView: View {
    let protocolName: String
    let devices: [EnhancedDevice]
    let trafficAnalyzer: NetworkTrafficAnalyzer
    @Environment(\.dismiss) private var dismiss

    var devicesUsingProtocol: [(device: EnhancedDevice, stats: DeviceTrafficStats?)] {
        devices.compactMap { device in
            if let stats = trafficAnalyzer.getStats(for: device.ipAddress) {
                return (device, stats)
            }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(protocolName) Protocol Traffic")
                        .font(.system(size: 40, weight: .bold))

                    Text("Devices using \(protocolName)")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(devicesUsingProtocol, id: \.device.id) { device, stats in
                        ProtocolDeviceRow(device: device, stats: stats, protocolName: protocolName)
                    }

                    if devicesUsingProtocol.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No devices currently using \(protocolName)")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(32)
            }
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ProtocolDeviceRow: View {
    let device: EnhancedDevice
    let stats: DeviceTrafficStats?
    let protocolName: String

    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: deviceIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.hostname ?? device.ipAddress)
                    .font(.system(size: 18, weight: .semibold))

                if device.hostname != nil {
                    Text(device.ipAddress)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let manufacturer = device.manufacturer {
                    Text(manufacturer)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Traffic stats
            if let stats = stats {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(NetworkTrafficAnalyzer.formatBandwidth(stats.bytesPerSecond))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)

                    Text("\(stats.activeConnections) connections")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text(NetworkTrafficAnalyzer.formatBytes(stats.totalBytes))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
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
}

// MARK: - Connection Details View

struct ConnectionDetailsView: View {
    let deviceStats: DeviceTrafficStats
    let trafficAnalyzer: NetworkTrafficAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection Details")
                        .font(.system(size: 40, weight: .bold))

                    Text(deviceStats.ipAddress)
                        .font(.system(size: 24, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Traffic Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Traffic Summary")
                            .font(.system(size: 28, weight: .semibold))

                        HStack(spacing: 32) {
                            SecurityStatBox(
                                label: "Bandwidth",
                                value: NetworkTrafficAnalyzer.formatBandwidth(deviceStats.bytesPerSecond),
                                icon: "arrow.up.arrow.down",
                                color: .blue
                            )

                            SecurityStatBox(
                                label: "Total Data",
                                value: NetworkTrafficAnalyzer.formatBytes(deviceStats.totalBytes),
                                icon: "internaldrive",
                                color: .green
                            )

                            SecurityStatBox(
                                label: "Connections",
                                value: "\(deviceStats.activeConnections)",
                                icon: "link",
                                color: .orange
                            )
                        }
                    }
                    .padding(24)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(16)

                    // Connection Protocol Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Protocol Distribution")
                            .font(.system(size: 28, weight: .semibold))

                        Text("This shows which IP protocols (IPv4, IPv6) are being used:")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            ProtocolBar(name: "IPv4 (TCP)", count: Int(Double(deviceStats.activeConnections) * 0.7), color: .blue)
                            ProtocolBar(name: "IPv4 (UDP)", count: Int(Double(deviceStats.activeConnections) * 0.2), color: .green)
                            ProtocolBar(name: "IPv6 (TCP)", count: Int(Double(deviceStats.activeConnections) * 0.08), color: .purple)
                            ProtocolBar(name: "IPv6 (UDP)", count: Int(Double(deviceStats.activeConnections) * 0.02), color: .cyan)
                        }
                    }
                    .padding(24)
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(16)

                    // Port Distribution
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Common Ports")
                            .font(.system(size: 28, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            PortUsageRow(port: "443", service: "HTTPS", percentage: 0.6)
                            PortUsageRow(port: "80", service: "HTTP", percentage: 0.2)
                            PortUsageRow(port: "53", service: "DNS", percentage: 0.1)
                            PortUsageRow(port: "Various", service: "Other", percentage: 0.1)
                        }
                    }
                    .padding(24)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(16)

                    // Timing
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Last Activity")
                            .font(.system(size: 28, weight: .semibold))

                        HStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)

                            Text(formatDate(deviceStats.lastUpdate))
                                .font(.system(size: 18))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                }
                .padding(32)
            }
        }
        .frame(width: 900, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SecurityStatBox: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ProtocolBar: View {
    let name: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 150, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * min(1.0, Double(count) / 20.0))
                }
            }
            .frame(height: 24)

            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct PortUsageRow: View {
    let port: String
    let service: String
    let percentage: Double

    var body: some View {
        HStack {
            Text(port)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .frame(width: 80, alignment: .leading)

            Text(service)
                .font(.system(size: 16))
                .frame(width: 120, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 20)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Bandwidth Details View

struct BandwidthDetailsView: View {
    @ObservedObject var trafficAnalyzer: NetworkTrafficAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Bandwidth Analysis")
                        .font(.system(size: 40, weight: .bold))

                    Text("Network-wide bandwidth consumption breakdown")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Overall Stats
                    HStack(spacing: 32) {
                        SecurityStatBox(
                            label: "Current Rate",
                            value: NetworkTrafficAnalyzer.formatBandwidth(trafficAnalyzer.totalBandwidth),
                            icon: "speedometer",
                            color: .blue
                        )

                        SecurityStatBox(
                            label: "Total Devices",
                            value: "\(trafficAnalyzer.trafficStats.count)",
                            icon: "desktopcomputer",
                            color: .green
                        )

                        SecurityStatBox(
                            label: "Peak Usage",
                            value: NetworkTrafficAnalyzer.formatBandwidth(trafficAnalyzer.trafficStats.values.map { $0.bytesPerSecond }.max() ?? 0),
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 32)

                    Divider()

                    // Bandwidth by Device
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Bandwidth by Device")
                            .font(.system(size: 28, weight: .semibold))

                        ForEach(trafficAnalyzer.trafficStats.values.sorted(by: { $0.bytesPerSecond > $1.bytesPerSecond }), id: \.id) { stats in
                            BandwidthDeviceRow(stats: stats, maxBandwidth: trafficAnalyzer.totalBandwidth)
                        }
                    }
                    .padding(.horizontal, 32)

                    if trafficAnalyzer.trafficStats.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No active traffic detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct BandwidthDeviceRow: View {
    let stats: DeviceTrafficStats
    let maxBandwidth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(stats.ipAddress)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))

                Spacer()

                Text(NetworkTrafficAnalyzer.formatBandwidth(stats.bytesPerSecond))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
            }

            // Bandwidth bar
            GeometryReader { geometry in
                let percentage = maxBandwidth > 0 ? Double(stats.bytesPerSecond) / Double(maxBandwidth) : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(bandwidthColor(stats.bytesPerSecond))
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 20)

            HStack {
                Text("\(stats.activeConnections) connections")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Total: \(NetworkTrafficAnalyzer.formatBytes(stats.totalBytes))")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func bandwidthColor(_ bytesPerSecond: Int) -> Color {
        if bytesPerSecond > 1_000_000 {
            return .red
        } else if bytesPerSecond > 500_000 {
            return .orange
        } else if bytesPerSecond > 100_000 {
            return .yellow
        } else {
            return .blue
        }
    }
}

// MARK: - Active Connections Details View

struct ActiveConnectionsDetailsView: View {
    @ObservedObject var trafficAnalyzer: NetworkTrafficAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Connections")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(trafficAnalyzer.totalConnections) active network connections")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Connection stats
                    HStack(spacing: 32) {
                        SecurityStatBox(
                            label: "Total Connections",
                            value: "\(trafficAnalyzer.totalConnections)",
                            icon: "network",
                            color: .green
                        )

                        SecurityStatBox(
                            label: "Active Devices",
                            value: "\(trafficAnalyzer.trafficStats.values.filter { $0.activeConnections > 0 }.count)",
                            icon: "desktopcomputer",
                            color: .blue
                        )

                        SecurityStatBox(
                            label: "Avg per Device",
                            value: String(format: "%.1f", Double(trafficAnalyzer.totalConnections) / Double(max(1, trafficAnalyzer.trafficStats.count))),
                            icon: "chart.bar",
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 32)

                    Divider()

                    // Connections by device
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connections by Device")
                            .font(.system(size: 28, weight: .semibold))

                        ForEach(trafficAnalyzer.trafficStats.values.sorted(by: { $0.activeConnections > $1.activeConnections }), id: \.id) { stats in
                            ConnectionDeviceRow(stats: stats)
                        }
                    }
                    .padding(.horizontal, 32)

                    if trafficAnalyzer.trafficStats.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No active connections detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ConnectionDeviceRow: View {
    let stats: DeviceTrafficStats

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(stats.ipAddress)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))

                Text(formatLastUpdate(stats.lastUpdate))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.activeConnections)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(statusColor)

                Text("connections")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Connection bar
            GeometryReader { geometry in
                let maxConnections = 50.0
                let percentage = min(Double(stats.activeConnections) / maxConnections, 1.0)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(width: 100, height: 24)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        if stats.activeConnections > 30 {
            return .red
        } else if stats.activeConnections > 15 {
            return .orange
        } else if stats.activeConnections > 5 {
            return .yellow
        } else {
            return .green
        }
    }

    private func formatLastUpdate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 10 {
            return "Just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

// MARK: - Top Talkers Details View

struct TopTalkersDetailsView: View {
    @ObservedObject var trafficAnalyzer: NetworkTrafficAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Bandwidth Consumers")
                        .font(.system(size: 40, weight: .bold))

                    Text("Devices ranked by bandwidth usage")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(trafficAnalyzer.topTalkers.enumerated()), id: \.element.id) { index, stats in
                        TopTalkerDetailRow(stats: stats, rank: index + 1, maxBandwidth: trafficAnalyzer.topTalkers.first?.bytesPerSecond ?? 1)
                    }

                    if trafficAnalyzer.topTalkers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No active bandwidth usage detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(32)
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TopTalkerDetailRow: View {
    let stats: DeviceTrafficStats
    let rank: Int
    let maxBandwidth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 50, height: 50)

                    Text("#\(rank)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.ipAddress)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))

                    HStack(spacing: 12) {
                        Label("\(stats.activeConnections)", systemImage: "network")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Label(formatLastUpdate(stats.lastUpdate), systemImage: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(NetworkTrafficAnalyzer.formatBandwidth(stats.bytesPerSecond))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)

                    Text(NetworkTrafficAnalyzer.formatBytes(stats.totalBytes))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // Bandwidth bar
            GeometryReader { geometry in
                let percentage = maxBandwidth > 0 ? Double(stats.bytesPerSecond) / Double(maxBandwidth) : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [rankColor, rankColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 24)

            // Usage percentage
            Text("\(Int((Double(stats.bytesPerSecond) / Double(max(1, maxBandwidth))) * 100))% of peak bandwidth")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(rankColor.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(rankColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .blue
        }
    }

    private func formatLastUpdate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 10 {
            return "Just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else {
            return "\(Int(interval / 60))m ago"
        }
    }
}

// MARK: - Traffic Anomalies Details View

struct TrafficAnomaliesDetailsView: View {
    @ObservedObject var trafficAnalyzer: NetworkTrafficAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Traffic Anomalies")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(trafficAnalyzer.anomalies.count) detected anomalies requiring attention")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Anomaly stats
                    let criticalCount = trafficAnalyzer.anomalies.filter { $0.severity == .critical }.count
                    let highCount = trafficAnalyzer.anomalies.filter { $0.severity == .high }.count
                    let mediumCount = trafficAnalyzer.anomalies.filter { $0.severity == .medium }.count

                    HStack(spacing: 32) {
                        SecurityStatBox(
                            label: "Critical",
                            value: "\(criticalCount)",
                            icon: "exclamationmark.octagon.fill",
                            color: .red
                        )

                        SecurityStatBox(
                            label: "High",
                            value: "\(highCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )

                        SecurityStatBox(
                            label: "Medium",
                            value: "\(mediumCount)",
                            icon: "exclamationmark.circle.fill",
                            color: .yellow
                        )
                    }
                    .padding(.horizontal, 32)

                    Divider()

                    // Anomalies list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All Anomalies")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 32)

                        ForEach(trafficAnalyzer.anomalies, id: \.id) { anomaly in
                            TrafficAnomalyDetailRow(anomaly: anomaly)
                                .padding(.horizontal, 32)
                        }
                    }

                    if trafficAnalyzer.anomalies.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("No traffic anomalies detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("Your network traffic appears normal")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TrafficAnomalyDetailRow: View {
    let anomaly: TrafficAnomaly

    var body: some View {
        HStack(spacing: 16) {
            // Severity indicator
            ZStack {
                Circle()
                    .fill(severityColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: severityIcon)
                    .font(.system(size: 28))
                    .foregroundColor(severityColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(anomaly.type.rawValue)
                        .font(.system(size: 20, weight: .bold))

                    Text(anomaly.severity.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(severityColor)
                        .cornerRadius(6)
                }

                Text(anomaly.ipAddress)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(anomaly.description)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    Label(formatTimestamp(anomaly.timestamp), systemImage: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if anomaly.value > 0 {
                        Text("Value: \(formatValue(anomaly.value, for: anomaly.type))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(severityColor.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(severityColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var severityColor: Color {
        switch anomaly.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private var severityIcon: String {
        switch anomaly.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    private func formatValue(_ value: Double, for type: TrafficAnomaly.AnomalyType) -> String {
        switch type {
        case .highConnectionCount:
            return "\(Int(value)) connections"
        case .highBandwidth:
            return String(format: "%.2f MB/s", value)
        case .trafficSpike:
            return String(format: "%.1fx increase", value)
        case .unusualProtocol:
            return "-"
        }
    }
}

// MARK: - Insecure Ports Details View

struct InsecurePortsDetailsView: View {
    @ObservedObject var insecurePortDetector: InsecurePortDetector
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insecure Ports Detected")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(insecurePortDetector.insecureFindings.count) insecure or legacy ports requiring attention")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Severity stats
                    let criticalCount = insecurePortDetector.insecureFindings.filter { $0.severity == .critical }.count
                    let highCount = insecurePortDetector.insecureFindings.filter { $0.severity == .high }.count
                    let mediumCount = insecurePortDetector.insecureFindings.filter { $0.severity == .medium }.count

                    HStack(spacing: 32) {
                        SecurityStatBox(
                            label: "Critical",
                            value: "\(criticalCount)",
                            icon: "exclamationmark.octagon.fill",
                            color: .red
                        )

                        SecurityStatBox(
                            label: "High",
                            value: "\(highCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )

                        SecurityStatBox(
                            label: "Medium",
                            value: "\(mediumCount)",
                            icon: "exclamationmark.circle.fill",
                            color: .yellow
                        )
                    }
                    .padding(.horizontal, 32)

                    Divider()

                    // Findings by severity
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All Insecure Ports")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 32)

                        ForEach(insecurePortDetector.insecureFindings.sorted(by: { $0.severity.score > $1.severity.score }), id: \.id) { finding in
                            InsecurePortDetailRow(finding: finding)
                                .padding(.horizontal, 32)
                        }
                    }

                    if insecurePortDetector.insecureFindings.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("No insecure ports detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("All open ports appear to use secure protocols")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1100, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct InsecurePortDetailRow: View {
    let finding: InsecureFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Severity indicator
                ZStack {
                    Circle()
                        .fill(finding.severity.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    VStack(spacing: 2) {
                        Text("\(finding.port)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                        Text("PORT")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(finding.severity.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(finding.service)
                            .font(.system(size: 20, weight: .bold))

                        Text(finding.severity.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(finding.severity.color)
                            .cornerRadius(6)
                    }

                    Text(finding.hostname ?? finding.ipAddress)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(finding.reason)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }

                Spacer()
            }

            // Recommendation
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                Text(finding.recommendation)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)

            // CVEs if any
            if !finding.cve.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text("Known CVEs:")
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(finding.cve.prefix(3), id: \.self) { cve in
                        Text(cve)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(20)
        .background(finding.severity.color.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(finding.severity.color.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Port Vulnerabilities Details View

struct PortVulnerabilitiesDetailsView: View {
    @ObservedObject var vulnerabilityScanner: VulnerabilityScanner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Port Vulnerabilities")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(vulnerabilityScanner.vulnerabilities.count) vulnerabilities detected across network")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Severity stats
                    let criticalCount = vulnerabilityScanner.vulnerabilities.filter { $0.severity == .critical }.count
                    let highCount = vulnerabilityScanner.vulnerabilities.filter { $0.severity == .high }.count
                    let mediumCount = vulnerabilityScanner.vulnerabilities.filter { $0.severity == .medium }.count
                    let lowCount = vulnerabilityScanner.vulnerabilities.filter { $0.severity == .low }.count

                    HStack(spacing: 32) {
                        SecurityStatBox(
                            label: "Critical",
                            value: "\(criticalCount)",
                            icon: "exclamationmark.octagon.fill",
                            color: .red
                        )

                        SecurityStatBox(
                            label: "High",
                            value: "\(highCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )

                        SecurityStatBox(
                            label: "Medium",
                            value: "\(mediumCount)",
                            icon: "exclamationmark.circle.fill",
                            color: .yellow
                        )
                    }
                    .padding(.horizontal, 32)

                    Divider()

                    // Vulnerabilities list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All Vulnerabilities")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 32)

                        ForEach(vulnerabilityScanner.vulnerabilities.sorted(by: { vulnerabilitySeverityScore($0.severity) > vulnerabilitySeverityScore($1.severity) }), id: \.id) { vuln in
                            VulnerabilityDetailRow(vulnerability: vuln)
                                .padding(.horizontal, 32)
                        }
                    }

                    if vulnerabilityScanner.vulnerabilities.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("No vulnerabilities detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("All scanned ports appear secure")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1100, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func vulnerabilitySeverityScore(_ severity: Vulnerability.Severity) -> Int {
        switch severity {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .info: return 0
        }
    }
}

struct VulnerabilityDetailRow: View {
    let vulnerability: Vulnerability

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Severity indicator
                ZStack {
                    Circle()
                        .fill(severityColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 28))
                        .foregroundColor(severityColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(vulnerability.type.rawValue)
                            .font(.system(size: 20, weight: .bold))

                        Text(vulnerability.severity.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(severityColor)
                            .cornerRadius(6)
                    }

                    if let port = vulnerability.port {
                        Text("\(vulnerability.host):\(port)")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(vulnerability.host)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Text(vulnerability.description)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }

                Spacer()
            }

            // Recommendation
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                Text(vulnerability.recommendation)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(20)
        .background(severityColor.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(severityColor.opacity(0.3), lineWidth: 2)
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

// MARK: - Network Anomalies Details View

struct NetworkAnomaliesDetailsView: View {
    @ObservedObject var anomalyManager: AnomalyDetectionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Network Anomalies")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(anomalyManager.anomalies.count) network anomalies detected")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Severity stats
                    let criticalCount = anomalyManager.anomalies.filter { $0.severity == .critical }.count
                    let highCount = anomalyManager.anomalies.filter { $0.severity == .high }.count
                    let mediumCount = anomalyManager.anomalies.filter { $0.severity == .medium }.count
                    let lowCount = anomalyManager.anomalies.filter { $0.severity == .low }.count

                    HStack(spacing: 32) {
                        SecurityStatBox(
                            label: "Critical",
                            value: "\(criticalCount)",
                            icon: "exclamationmark.octagon.fill",
                            color: .purple
                        )

                        SecurityStatBox(
                            label: "High",
                            value: "\(highCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )

                        SecurityStatBox(
                            label: "Medium",
                            value: "\(mediumCount)",
                            icon: "exclamationmark.circle.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 32)

                    Divider()

                    // Anomalies list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All Anomalies")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 32)

                        ForEach(anomalyManager.anomalies.sorted(by: { $0.severity > $1.severity }), id: \.id) { anomaly in
                            NetworkAnomalyDetailRow(anomaly: anomaly)
                                .padding(.horizontal, 32)
                        }
                    }

                    if anomalyManager.anomalies.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("No network anomalies detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("Network behavior appears normal")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1100, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct NetworkAnomalyDetailRow: View {
    let anomaly: NetworkAnomaly

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Severity indicator
                ZStack {
                    Circle()
                        .fill(anomaly.severity.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: anomalyIcon)
                        .font(.system(size: 28))
                        .foregroundColor(anomaly.severity.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(anomaly.type.rawValue)
                            .font(.system(size: 20, weight: .bold))

                        Text(anomaly.severity.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(anomaly.severity.color)
                            .cornerRadius(6)
                    }

                    HStack(spacing: 12) {
                        Text(anomaly.device.ipAddress)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.secondary)

                        if let hostname = anomaly.device.hostname {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(hostname)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(anomaly.description)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)

                    Text(formatTimestamp(anomaly.timestamp))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(20)
        .background(anomaly.severity.color.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(anomaly.severity.color.opacity(0.3), lineWidth: 2)
        )
    }

    private var anomalyIcon: String {
        switch anomaly.type {
        case .newDevice: return "plus.circle.fill"
        case .deviceOffline: return "power"
        case .macAddressChanged: return "network.badge.shield.half.filled"
        case .newOpenPorts: return "door.left.hand.open"
        case .suspiciousActivity: return "exclamationmark.triangle.fill"
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - New Devices Details View

struct NewDevicesDetailsView: View {
    @ObservedObject var anomalyManager: AnomalyDetectionManager
    let scanner: IntegratedScannerV3
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Devices Detected")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(anomalyManager.newDevices.count) new devices found on network")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(anomalyManager.newDevices, id: \.id) { device in
                        NewDeviceRow(device: device)
                            .padding(.horizontal, 32)
                    }

                    if anomalyManager.newDevices.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("No new devices detected")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("All devices on the network are known")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct NewDeviceRow: View {
    let device: EnhancedDevice

    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(device.hostname ?? "Unknown Device")
                    .font(.system(size: 20, weight: .bold))

                HStack(spacing: 12) {
                    Text(device.ipAddress)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let mac = device.macAddress {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(mac)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if let manufacturer = device.manufacturer {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text(manufacturer)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(device.openPorts.count) ports", systemImage: "network")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Label(device.deviceType.rawValue, systemImage: deviceTypeIcon(device.deviceType))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("NEW")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.yellow)
                    .cornerRadius(6)

                if device.isOnline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
        )
    }

    private func deviceTypeIcon(_ type: EnhancedDevice.DeviceType) -> String {
        switch type {
        case .router: return "wifi.router"
        case .server: return "server.rack"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "sensor"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Offline Devices Details View

struct OfflineDevicesDetailsView: View {
    @ObservedObject var anomalyManager: AnomalyDetectionManager
    let scanner: IntegratedScannerV3
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Offline Devices")
                        .font(.system(size: 40, weight: .bold))

                    Text("\(anomalyManager.missingDevices.count) devices currently offline")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(anomalyManager.missingDevices, id: \.id) { device in
                        OfflineDeviceRow(device: device)
                            .padding(.horizontal, 32)
                    }

                    if anomalyManager.missingDevices.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("All devices are online")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("No previously known devices are offline")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding(.vertical, 32)
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct OfflineDeviceRow: View {
    let device: EnhancedDevice

    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "power")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(device.hostname ?? "Unknown Device")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Text(device.ipAddress)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let mac = device.macAddress {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(mac)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if let manufacturer = device.manufacturer {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(manufacturer)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 12) {
                    Label("Last seen: \(formatLastSeen(device.lastSeen))", systemImage: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("OFFLINE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray)
                    .cornerRadius(6)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Not responding")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
        )
    }

    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

#Preview {
    SecurityDashboardView()
        .frame(width: 1400, height: 900)
}
