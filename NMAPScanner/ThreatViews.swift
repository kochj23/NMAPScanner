//
//  ThreatViews.swift
//  NMAP Scanner - Comprehensive Threat Analysis Views
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI

// MARK: - Network Threat Dashboard

struct NetworkThreatDashboard: View {
    let summary: NetworkThreatSummary
    @State private var selectedSeverity: ThreatSeverity?
    @State private var selectedThreat: ThreatFinding?
    @State private var showingAllThreats = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                Text("Network Security Analysis")
                    .font(.system(size: 50, weight: .bold))

                // Overall Risk Score
                NetworkRiskScoreCard(summary: summary)

                // Critical Alerts
                if !summary.rogueDevices.isEmpty || !summary.backdoorDevices.isEmpty {
                    CriticalAlertsCard(
                        rogueDevices: summary.rogueDevices,
                        backdoorDevices: summary.backdoorDevices,
                        allThreats: summary.criticalThreats + summary.highThreats + summary.mediumThreats + summary.lowThreats
                    )
                }

                // Threat Summary by Severity
                ThreatSeveritySummaryGrid(summary: summary, selectedSeverity: $selectedSeverity)

                // Threat Breakdown
                Button(action: {
                    showingAllThreats = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("View All Threats")
                                .font(.system(size: 32, weight: .semibold))
                            Text("\(summary.totalThreats) total findings across \(summary.threatenedDevices) devices")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }
                    .padding(24)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .sheet(item: $selectedSeverity) { severity in
            ThreatListBySeverityView(
                threats: threatsForSeverity(severity),
                severity: severity
            )
        }
        .sheet(isPresented: $showingAllThreats) {
            AllThreatsView(summary: summary)
        }
    }

    private func threatsForSeverity(_ severity: ThreatSeverity) -> [ThreatFinding] {
        switch severity {
        case .critical: return summary.criticalThreats
        case .high: return summary.highThreats
        case .medium: return summary.mediumThreats
        case .low: return summary.lowThreats
        case .info: return []
        }
    }
}

// MARK: - Network Risk Score Card

struct NetworkRiskScoreCard: View {
    let summary: NetworkThreatSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Overall Network Security")
                .font(.system(size: 36, weight: .semibold))

            HStack(spacing: 40) {
                // Risk Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 200, height: 200)

                    Circle()
                        .trim(from: 0, to: CGFloat(summary.overallRiskScore) / 100.0)
                        .stroke(riskColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 8) {
                        Text("\(summary.overallRiskScore)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(riskColor)
                        Text("/ 100")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }

                // Risk Details
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Risk Level:")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text(summary.riskLevel)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(riskColor)
                    }

                    Divider()

                    StatItem(label: "Total Devices", value: "\(summary.totalDevices)")
                    StatItem(label: "Threatened Devices", value: "\(summary.threatenedDevices)")
                    StatItem(label: "Total Threats", value: "\(summary.totalThreats)")

                    if !summary.rogueDevices.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("\(summary.rogueDevices.count) Rogue Device\(summary.rogueDevices.count == 1 ? "" : "s")")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }

                    if !summary.backdoorDevices.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.open.fill")
                                .foregroundColor(.red)
                            Text("\(summary.backdoorDevices.count) Backdoor\(summary.backdoorDevices.count == 1 ? "" : "s") Detected")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(riskColor.opacity(0.1))
        .cornerRadius(20)
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

// MARK: - Critical Alerts Card

struct CriticalAlertsCard: View {
    let rogueDevices: [EnhancedDevice]
    let backdoorDevices: [EnhancedDevice]
    let allThreats: [ThreatFinding] // All threat findings to look up rogue device reasons
    @State private var selectedDevice: EnhancedDevice?
    @State private var selectedThreat: ThreatFinding? // Associated threat for selected device

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text("CRITICAL ALERTS")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
            }

            if !rogueDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚠️ Rogue Devices Detected")
                        .font(.system(size: 28, weight: .semibold))

                    ForEach(rogueDevices) { device in
                        Button(action: {
                            selectedDevice = device
                            // Find the rogue device threat for this device
                            selectedThreat = allThreats.first {
                                $0.isRogueDevice && $0.affectedHost == device.ipAddress
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.hostname ?? device.ipAddress)
                                        .font(.system(size: 24, weight: .semibold))
                                    if device.hostname != nil {
                                        Text(device.ipAddress)
                                            .font(.system(size: 20, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    if let mac = device.macAddress {
                                        Text("MAC: \(mac)")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red)
                            }
                            .padding(20)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !backdoorDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🚨 Backdoor Ports Detected")
                        .font(.system(size: 28, weight: .semibold))

                    ForEach(backdoorDevices) { device in
                        Button(action: {
                            selectedDevice = device
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.hostname ?? device.ipAddress)
                                        .font(.system(size: 24, weight: .semibold))
                                    if device.hostname != nil {
                                        Text(device.ipAddress)
                                            .font(.system(size: 20, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    Text("Backdoor ports: \(device.openPorts.filter { $0.isBackdoorPort }.map { String($0.port) }.joined(separator: ", "))")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red)
                            }
                            .padding(20)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(30)
        .background(Color.red.opacity(0.15))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red, lineWidth: 3)
        )
        .sheet(item: $selectedDevice) { device in
            ThreatDeviceDetailView(device: device, rogueThreat: selectedThreat)
        }
    }
}

// MARK: - Threat Severity Summary Grid

struct ThreatSeveritySummaryGrid: View {
    let summary: NetworkThreatSummary
    @Binding var selectedSeverity: ThreatSeverity?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Threats by Severity")
                .font(.system(size: 36, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ThreatSeverityCard(
                    severity: .critical,
                    count: summary.criticalThreats.count,
                    color: .red
                ) {
                    selectedSeverity = .critical
                }

                ThreatSeverityCard(
                    severity: .high,
                    count: summary.highThreats.count,
                    color: .orange
                ) {
                    selectedSeverity = .high
                }

                ThreatSeverityCard(
                    severity: .medium,
                    count: summary.mediumThreats.count,
                    color: .yellow
                ) {
                    selectedSeverity = .medium
                }

                ThreatSeverityCard(
                    severity: .low,
                    count: summary.lowThreats.count,
                    color: .blue
                ) {
                    selectedSeverity = .low
                }
            }
        }
    }
}

struct ThreatSeverityCard: View {
    let severity: ThreatSeverity
    let count: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: iconName)
                        .font(.system(size: 50))
                        .foregroundColor(color)
                }

                VStack(spacing: 8) {
                    Text("\(count)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(color)

                    Text(severity.rawValue)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(count == 1 ? "Threat" : "Threats")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                if count > 0 {
                    HStack {
                        Text("Tap to view")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(count > 0 ? color.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(count > 0 ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
    }

    private var iconName: String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .info: return "info.circle"
        }
    }
}

// MARK: - Threat List by Severity View

struct ThreatListBySeverityView: View {
    let threats: [ThreatFinding]
    let severity: ThreatSeverity
    @Environment(\.dismiss) var dismiss
    @State private var selectedThreat: ThreatFinding?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Text("\(severity.rawValue) Threats")
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

                Text("\(threats.count) \(severity.rawValue.lowercased()) severity \(threats.count == 1 ? "threat" : "threats") detected")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)

                ForEach(threats) { threat in
                    Button(action: {
                        selectedThreat = threat
                    }) {
                        ThreatCard(threat: threat)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedThreat) { threat in
            ThreatDetailView(threat: threat)
        }
    }
}

// MARK: - Threat Card

struct ThreatCard: View {
    let threat: ThreatFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(severityColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: severityIcon)
                        .font(.system(size: 28))
                        .foregroundColor(severityColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(threat.title)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(threat.description)
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 20) {
                        Label(threat.affectedHost, systemImage: "network")
                            .font(.system(size: 18, design: .monospaced))

                        if let port = threat.affectedPort {
                            Label("Port \(port)", systemImage: "cable.connector")
                                .font(.system(size: 18))
                        }

                        Label(threat.category.rawValue, systemImage: "tag")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(severityColor)
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
        switch threat.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    private var severityIcon: String {
        switch threat.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .info: return "info.circle"
        }
    }
}

// MARK: - Threat Detail View

struct ThreatDetailView: View {
    let threat: ThreatFinding
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                HStack {
                    Text("Threat Details")
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

                // Severity Badge
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(severityColor.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: severityIcon)
                            .font(.system(size: 40))
                            .foregroundColor(severityColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(threat.severity.rawValue.uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(severityColor)

                        Text(threat.category.rawValue)
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)

                        if let cvss = threat.cvssScore {
                            Text("CVSS Score: \(String(format: "%.1f", cvss))/10.0")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(severityColor)
                        }
                    }
                }
                .padding(24)
                .background(severityColor.opacity(0.1))
                .cornerRadius(16)

                // Title and Description
                VStack(alignment: .leading, spacing: 16) {
                    Text(threat.title)
                        .font(.system(size: 36, weight: .bold))

                    Text(threat.description)
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }

                // Affected System
                SectionCard(title: "Affected System", icon: "network") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRowSimple(label: "Host", value: threat.affectedHost)
                        if let port = threat.affectedPort {
                            InfoRowSimple(label: "Port", value: "\(port)")
                        }
                        InfoRowSimple(label: "Detected", value: formatDate(threat.detectedAt))
                    }
                }

                // Technical Details
                SectionCard(title: "Technical Details", icon: "terminal") {
                    Text(threat.technicalDetails)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Impact Assessment
                SectionCard(title: "Impact Assessment", icon: "exclamationmark.shield") {
                    Text(threat.impactAssessment)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Remediation
                SectionCard(title: "Recommended Actions", icon: "wrench.and.screwdriver") {
                    Text(threat.remediation)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green, lineWidth: 3)
                )

                // CVE References
                if !threat.cveReferences.isEmpty {
                    SectionCard(title: "CVE References", icon: "doc.text") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(threat.cveReferences, id: \.self) { cve in
                                Text(cve)
                                    .font(.system(size: 20, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(40)
        }
    }

    private var severityColor: Color {
        switch threat.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    private var severityIcon: String {
        switch threat.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .info: return "info.circle"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 32, weight: .semibold))
            }

            content
        }
        .padding(24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Info Row Simple

struct InfoRowSimple: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.system(size: 20, design: .monospaced))
        }
    }
}

// MARK: - All Threats View

struct AllThreatsView: View {
    let summary: NetworkThreatSummary
    @Environment(\.dismiss) var dismiss
    @State private var selectedThreat: ThreatFinding?
    @State private var filterSeverity: ThreatSeverity?

    private var allThreats: [ThreatFinding] {
        let threats = summary.criticalThreats + summary.highThreats + summary.mediumThreats + summary.lowThreats
        if let filter = filterSeverity {
            return threats.filter { $0.severity == filter }
        }
        return threats.sorted { $0.severity < $1.severity }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Text("All Threats")
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

                // Filter buttons
                HStack(spacing: 16) {
                    FilterButton(title: "All", isSelected: filterSeverity == nil) {
                        filterSeverity = nil
                    }

                    ForEach(ThreatSeverity.allCases, id: \.self) { severity in
                        if severity != .info {
                            FilterButton(title: severity.rawValue, isSelected: filterSeverity == severity) {
                                filterSeverity = severity
                            }
                        }
                    }
                }

                Text("\(allThreats.count) \(allThreats.count == 1 ? "threat" : "threats") found")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)

                ForEach(allThreats) { threat in
                    Button(action: {
                        selectedThreat = threat
                    }) {
                        ThreatCard(threat: threat)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedThreat) { threat in
            ThreatDetailView(threat: threat)
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Threat Device Detail View

struct ThreatDeviceDetailView: View {
    let device: EnhancedDevice
    let rogueThreat: ThreatFinding? // Optional threat finding for rogue devices
    @Environment(\.dismiss) var dismiss
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @State private var showingTrustedConfirmation = false
    @State private var showingAnnotationSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Text("Device Details")
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

                // Device header with rogue indicator
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(device.isRogue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: deviceIcon)
                                .font(.system(size: 50))
                                .foregroundColor(device.isRogue ? .red : .blue)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(device.hostname ?? device.ipAddress)
                                .font(.system(size: 36, weight: .bold))

                            if device.isRogue {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("ROGUE DEVICE")
                                }
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                            }

                            if device.hostname != nil {
                                Text(device.ipAddress)
                                    .font(.system(size: 24, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            if let hostname = device.hostname {
                                HStack(spacing: 8) {
                                    Image(systemName: "network")
                                    Text("DNS: \(hostname)")
                                }
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            }

                            if let manufacturer = device.manufacturer {
                                HStack(spacing: 8) {
                                    Image(systemName: "building.2")
                                    Text("Manufacturer: \(manufacturer)")
                                }
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(30)
                .background(device.isRogue ? Color.red.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(20)

                // Rogue Device Explanation
                if device.isRogue, let threat = rogueThreat {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                            Text("Why is this device flagged as ROGUE?")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.red)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Detection Reason")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(threat.description)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            // Technical Details
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Technical Details", systemImage: "terminal")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(threat.technicalDetails)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Divider()

                            // Impact Assessment
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Security Impact", systemImage: "exclamationmark.shield.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.orange)
                                Text(threat.impactAssessment)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Divider()

                            // Recommended Actions
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Recommended Actions", systemImage: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.green)
                                Text(threat.remediation)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // CVSS Score
                            if let cvss = threat.cvssScore {
                                HStack(spacing: 12) {
                                    Image(systemName: "gauge.high")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red)
                                    Text("CVSS Score: \(String(format: "%.1f", cvss))/10.0")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(20)
                        .background(Color.yellow.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(24)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red, lineWidth: 2)
                    )

                    // Mark as Trusted Button
                    Button(action: {
                        showingTrustedConfirmation = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 28))
                            Text("Mark This Device as Trusted")
                                .font(.system(size: 28, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .alert("Mark as Trusted", isPresented: $showingTrustedConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Mark as Trusted") {
                            persistenceManager.whitelistDevice(ipAddress: device.ipAddress)
                            dismiss()
                        }
                    } message: {
                        Text("This will mark \(device.displayName) as a trusted device and it will no longer be flagged as rogue.")
                    }
                }

                // Edit Device Info Button
                Button(action: {
                    showingAnnotationSheet = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                        Text("Edit Device Info")
                            .font(.system(size: 28, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingAnnotationSheet) {
                    DeviceAnnotationSheet(device: device)
                }

                // Open Ports
                if !device.openPorts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Open Ports (\(device.openPorts.count))")
                            .font(.system(size: 32, weight: .semibold))

                        ForEach(device.openPorts) { port in
                            PortInfoCard(port: port)
                        }
                    }
                }
            }
            .padding(40)
        }
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

struct PortInfoCard: View {
    let port: PortInfo

    var body: some View {
        HStack(spacing: 20) {
            // Port number
            Text("\(port.port)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(portColor)
                .frame(width: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text(port.service)
                    .font(.system(size: 24, weight: .semibold))

                if let version = port.version {
                    Text("Version: \(version)")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }

                if port.isBackdoorPort {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.octagon.fill")
                        Text("KNOWN BACKDOOR PORT")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                } else if port.isSuspicious {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Suspicious")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(portColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var portColor: Color {
        if port.isBackdoorPort { return .red }
        if port.isSuspicious { return .orange }
        return .green
    }
}

// MARK: - Make ThreatSeverity Identifiable

extension ThreatSeverity: Identifiable {
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "checkmark.circle.fill"
        case .info: return "info.circle"
        }
    }
}
