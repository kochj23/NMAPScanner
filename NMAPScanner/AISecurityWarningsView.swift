//
//  AISecurityWarningsView.swift
//  NMAPScanner - AI/ML Service Security Warnings View
//
//  Created by Jordan Koch on 2026-02-02.
//
//  Displays security warnings for AI/ML services detected on the network.
//

import SwiftUI

// MARK: - AI Security Warnings View

struct AISecurityWarningsView: View {
    @ObservedObject var analyzer: AISecurityAnalyzer
    @ObservedObject var scanner: IntegratedScannerV3

    @State private var selectedSeverityFilter: AISecuritySeverity?
    @State private var showVerifiedOnly = false
    @State private var selectedWarning: AISecurityWarning?
    @State private var showWarningDetail = false
    @State private var expandedWarnings: Set<UUID> = []

    @Environment(\.dismiss) private var dismiss

    var filteredWarnings: [AISecurityWarning] {
        var result = analyzer.warnings

        if let severity = selectedSeverityFilter {
            result = result.filter { $0.severity == severity }
        }

        if showVerifiedOnly {
            result = result.filter { $0.isVerified }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            if analyzer.isAnalyzing {
                analysisProgressView
            } else if analyzer.warnings.isEmpty {
                emptyStateView
            } else {
                warningsListView
            }
        }
        .frame(width: 1000, height: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showWarningDetail) {
            if let warning = selectedWarning {
                AIWarningDetailView(warning: warning)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36))
                            .foregroundColor(.purple)

                        Text("AI/ML Service Security")
                            .font(.system(size: 36, weight: .bold))
                    }

                    Text("Security warnings for AI and Machine Learning services on your network")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Scan button
                Button(action: {
                    Task {
                        await analyzer.analyzeAIServices(devices: scanner.devices)
                    }
                }) {
                    HStack(spacing: 8) {
                        if analyzer.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        }
                        Text(analyzer.isAnalyzing ? "Analyzing..." : "Analyze AI Services")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(analyzer.isAnalyzing ? Color.gray : Color.purple)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(analyzer.isAnalyzing)

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Statistics cards
            if !analyzer.warnings.isEmpty {
                HStack(spacing: 16) {
                    AIStatCard(
                        title: "Total Warnings",
                        value: "\(analyzer.stats.total)",
                        icon: "exclamationmark.shield.fill",
                        color: .purple
                    )

                    AIStatCard(
                        title: "Critical",
                        value: "\(analyzer.stats.critical)",
                        icon: "exclamationmark.octagon.fill",
                        color: .red
                    )

                    AIStatCard(
                        title: "High",
                        value: "\(analyzer.stats.high)",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )

                    AIStatCard(
                        title: "Verified",
                        value: "\(analyzer.stats.verified)",
                        icon: "checkmark.shield.fill",
                        color: .green
                    )

                    AIStatCard(
                        title: "Score Impact",
                        value: "-\(analyzer.securityScoreImpact)",
                        icon: "chart.line.downtrend.xyaxis",
                        color: .red
                    )
                }

                // Filters
                HStack(spacing: 16) {
                    Text("Filter:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    // Severity filter
                    Picker("Severity", selection: $selectedSeverityFilter) {
                        Text("All Severities").tag(AISecuritySeverity?.none)
                        ForEach(AISecuritySeverity.allCases, id: \.self) { severity in
                            HStack {
                                Circle()
                                    .fill(severity.color)
                                    .frame(width: 8, height: 8)
                                Text(severity.rawValue)
                            }
                            .tag(AISecuritySeverity?.some(severity))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)

                    // Verified toggle
                    Toggle("Verified Only", isOn: $showVerifiedOnly)
                        .toggleStyle(.switch)

                    Spacer()

                    Text("\(filteredWarnings.count) of \(analyzer.warnings.count) warnings")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // Last scan info
            if let lastScan = analyzer.lastAnalysisDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Last analyzed: \(formatDate(lastScan))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
    }

    // MARK: - Analysis Progress View

    private var analysisProgressView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(2)

            Text(analyzer.analysisStatus)
                .font(.system(size: 18, weight: .medium))

            ProgressView(value: analyzer.analysisProgress)
                .progressViewStyle(.linear)
                .frame(width: 400)

            Text("\(Int(analyzer.analysisProgress * 100))% complete")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("No AI Service Warnings")
                .font(.system(size: 28, weight: .bold))

            Text("No AI or ML services with security vulnerabilities were detected on your network.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            Button(action: {
                Task {
                    await analyzer.analyzeAIServices(devices: scanner.devices)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Run Analysis")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.purple)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Warnings List View

    private var warningsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredWarnings) { warning in
                    AIWarningCard(
                        warning: warning,
                        isExpanded: expandedWarnings.contains(warning.id),
                        onTap: {
                            if expandedWarnings.contains(warning.id) {
                                expandedWarnings.remove(warning.id)
                            } else {
                                expandedWarnings.insert(warning.id)
                            }
                        },
                        onDetailTap: {
                            selectedWarning = warning
                            showWarningDetail = true
                        }
                    )
                }
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - AI Stat Card

struct AIStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - AI Warning Card

struct AIWarningCard: View {
    let warning: AISecurityWarning
    let isExpanded: Bool
    let onTap: () -> Void
    let onDetailTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Severity indicator
                    ZStack {
                        Circle()
                            .fill(warning.severity.color.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: warning.severity.icon)
                            .font(.system(size: 24))
                            .foregroundColor(warning.severity.color)
                    }

                    // Warning info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(warning.service)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Port \(warning.port)")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)

                            if warning.isVerified {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Verified")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                            }
                        }

                        Text(warning.host)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text(warning.title)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer()

                    // Severity badge
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(warning.severity.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(warning.severity.color)
                            .cornerRadius(6)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(warning.description)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }

                    // Probe result
                    if let probe = warning.probeResult {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Probe Result")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                ProbeResultBadge(
                                    label: "Response",
                                    value: probe.responseReceived ? "Yes" : "No",
                                    color: probe.responseReceived ? .green : .gray
                                )

                                ProbeResultBadge(
                                    label: "Vulnerable",
                                    value: probe.isVulnerable ? "Yes" : "No",
                                    color: probe.isVulnerable ? .red : .green
                                )

                                ProbeResultBadge(
                                    label: "Auth Required",
                                    value: probe.authRequired ? "Yes" : "No",
                                    color: probe.authRequired ? .green : .orange
                                )
                            }

                            Text(probe.details)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Remediation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Remediation")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.secondary)

                        Text(warning.remediation)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // CVE references
                    if let cves = warning.cveReferences, !cves.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CVE References")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(cves, id: \.self) { cve in
                                    Text(cve)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Detail button
                    HStack {
                        Spacer()
                        Button(action: onDetailTap) {
                            HStack {
                                Text("View Full Details")
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(warning.severity.color.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(warning.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Probe Result Badge

struct ProbeResultBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - AI Warning Detail View

struct AIWarningDetailView: View {
    let warning: AISecurityWarning
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(warning.severity.color.opacity(0.2))
                                .frame(width: 60, height: 60)

                            Image(systemName: warning.severity.icon)
                                .font(.system(size: 28))
                                .foregroundColor(warning.severity.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(warning.service)
                                .font(.system(size: 32, weight: .bold))

                            HStack(spacing: 8) {
                                Text(warning.host)
                                    .font(.system(size: 18, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Text(":")
                                    .foregroundColor(.secondary)

                                Text("\(warning.port)")
                                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Text(warning.severity.rawValue.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(warning.severity.color)
                            .cornerRadius(8)

                        if warning.isVerified {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Vulnerability Verified")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                        }

                        Text("Detected: \(formatDate(warning.detectedAt))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
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

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Security Issue")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(warning.title)
                            .font(.system(size: 24, weight: .bold))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(warning.description)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                    }

                    // Probe Results
                    if let probe = warning.probeResult {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Vulnerability Probe Results")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 24) {
                                DetailStatBox(
                                    label: "Response Received",
                                    value: probe.responseReceived ? "Yes" : "No",
                                    color: probe.responseReceived ? .green : .gray
                                )

                                DetailStatBox(
                                    label: "Vulnerable",
                                    value: probe.isVulnerable ? "VULNERABLE" : "Protected",
                                    color: probe.isVulnerable ? .red : .green
                                )

                                DetailStatBox(
                                    label: "Authentication",
                                    value: probe.authRequired ? "Required" : "Not Required",
                                    color: probe.authRequired ? .green : .orange
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Probe Details")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                Text(probe.details)
                                    .font(.system(size: 15))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)

                                Text("Probed at: \(formatDate(probe.probedAt))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(24)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(16)
                    }

                    // Remediation
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            Text("Remediation Steps")
                                .font(.system(size: 20, weight: .semibold))
                        }

                        Text(warning.remediation)
                            .font(.system(size: 15))
                            .lineSpacing(6)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }

                    // CVE References
                    if let cves = warning.cveReferences, !cves.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                Text("CVE References")
                                    .font(.system(size: 20, weight: .semibold))
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(cves, id: \.self) { cve in
                                    HStack {
                                        Text(cve)
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .foregroundColor(.red)

                                        Spacer()

                                        Link(destination: URL(string: "https://nvd.nist.gov/vuln/detail/\(cve)")!) {
                                            HStack {
                                                Text("View in NVD")
                                                Image(systemName: "arrow.up.right.square")
                                            }
                                            .font(.system(size: 14))
                                            .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // Service Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Service Information")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            AIInfoRow(label: "Service", value: warning.service)
                            AIInfoRow(label: "Port", value: "\(warning.port)")
                            AIInfoRow(label: "Host", value: warning.host)
                            AIInfoRow(label: "Severity", value: warning.severity.rawValue)
                            AIInfoRow(label: "Verified", value: warning.isVerified ? "Yes" : "No")
                            AIInfoRow(label: "Detected", value: formatDate(warning.detectedAt))
                        }
                    }
                }
                .padding(32)
            }
        }
        .frame(width: 900, height: 800)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Stat Box

struct DetailStatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - AI Info Row

struct AIInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - AI Security Summary Card (for Dashboard Integration)

struct AISecuritySummaryCard: View {
    @ObservedObject var analyzer: AISecurityAnalyzer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple.opacity(0.5))
                }

                Text("\(analyzer.warnings.count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI/ML Warnings")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)

                        Text("Tap for details")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if analyzer.stats.critical > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .font(.system(size: 12))
                                Text("\(analyzer.stats.critical)")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.red)
                        }

                        if analyzer.stats.high > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text("\(analyzer.stats.high)")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Warning Row Compact (for Dashboard)

struct AIWarningRowCompact: View {
    let warning: AISecurityWarning

    var body: some View {
        HStack(spacing: 16) {
            // Severity icon
            Image(systemName: warning.severity.icon)
                .font(.system(size: 24))
                .foregroundColor(warning.severity.color)

            // Warning info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(warning.service)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Port \(warning.port)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                    if warning.isVerified {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Verified")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                    }
                }

                Text(warning.host)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(warning.title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Severity badge
            Text(warning.severity.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(warning.severity.color)
                .cornerRadius(6)
        }
        .padding(14)
        .background(warning.severity.color.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(warning.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}
