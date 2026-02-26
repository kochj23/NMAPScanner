//
//  SecurityReportView.swift
//  NMAPScanner - LLM-Powered Security Report UI
//
//  SwiftUI view for generating and viewing AI-powered security reports.
//  Integrates with LLMSecurityReportGenerator and MarkdownExporter.
//
//  Created by Jordan Koch on 2026-02-02.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Security Report View

struct SecurityReportView: View {
    let devices: [EnhancedDevice]
    let threats: [ThreatFinding]

    @StateObject private var reportGenerator = LLMSecurityReportGenerator.shared
    @StateObject private var aiBackend = AIBackendManager.shared
    @State private var selectedTab: ReportTab = .generate
    @State private var showingExportSheet = false
    @State private var exportedURL: URL?
    @State private var showingExportSuccess = false
    @Environment(\.dismiss) var dismiss

    enum ReportTab: String, CaseIterable {
        case generate = "Generate Report"
        case executive = "Executive Summary"
        case technical = "Technical Details"
        case remediation = "Remediation Plan"
        case risk = "Risk Assessment"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with AI status
                headerView

                Divider()

                // Tab selector
                tabSelector

                Divider()

                // Main content area
                contentArea
            }
            .navigationTitle("AI Security Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { exportToMarkdown() }) {
                            Label("Export Markdown", systemImage: "doc.text")
                        }
                        .disabled(reportGenerator.reportContent.isEmpty)

                        Button(action: { copyToClipboard() }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                        }
                        .disabled(reportGenerator.reportContent.isEmpty)

                        Divider()

                        Button(action: { reportGenerator.clearReport() }) {
                            Label("Clear Report", systemImage: "trash")
                        }
                        .disabled(reportGenerator.reportContent.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Report Exported", isPresented: $showingExportSuccess) {
                Button("OK") { }
                if let url = exportedURL {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                    }
                }
            } message: {
                if let url = exportedURL {
                    Text("Report saved to:\n\(url.lastPathComponent)")
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 20) {
            // AI Status
            HStack(spacing: 12) {
                Circle()
                    .fill(aiBackend.activeBackend != nil ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Backend")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    if let backend = aiBackend.activeBackend {
                        Text(backend.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text("Not Available")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )

            Spacer()

            // Network Stats
            HStack(spacing: 24) {
                ReportStatBadge(title: "Devices", value: "\(devices.count)", icon: "desktopcomputer")
                ReportStatBadge(title: "Threats", value: "\(threats.count)", icon: "exclamationmark.shield", color: threats.isEmpty ? .green : .red)
                ReportStatBadge(title: "Critical", value: "\(threats.filter { $0.severity == .critical }.count)", icon: "exclamationmark.triangle.fill", color: .red)
            }

            Spacer()

            // Refresh AI status button
            Button(action: {
                Task {
                    await reportGenerator.checkAvailability()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh AI backend status")
        }
        .padding(20)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ReportTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 8) {
                            Image(systemName: iconForTab(tab))
                            Text(tab.rawValue)
                        }
                        .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.blue : Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func iconForTab(_ tab: ReportTab) -> String {
        switch tab {
        case .generate: return "wand.and.stars"
        case .executive: return "person.2.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .remediation: return "checkmark.shield.fill"
        case .risk: return "exclamationmark.triangle"
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .generate:
            generateTabView
        case .executive:
            sectionView(title: "Executive Summary", content: reportGenerator.executiveSummary, placeholder: "Generate a report to see the executive summary.")
        case .technical:
            sectionView(title: "Technical Details", content: reportGenerator.technicalDetails, placeholder: "Generate a report to see technical details.")
        case .remediation:
            sectionView(title: "Remediation Plan", content: reportGenerator.remediationPlan, placeholder: "Generate a report to see the remediation plan.")
        case .risk:
            sectionView(title: "Risk Assessment", content: reportGenerator.riskAssessment, placeholder: "Generate a report to see the risk assessment.")
        }
    }

    // MARK: - Generate Tab

    private var generateTabView: some View {
        VStack(spacing: 24) {
            if !reportGenerator.isLLMAvailable {
                // AI not available warning
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("AI Backend Not Available")
                        .font(.system(size: 24, weight: .bold))

                    Text("To generate AI-powered security reports, please configure an LLM backend in the settings.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supported backends:")
                            .font(.system(size: 14, weight: .semibold))

                        Text("- Ollama (localhost:11434)")
                        Text("- TinyLLM (localhost:8000)")
                        Text("- TinyChat (localhost:8000)")
                        Text("- OpenWebUI (localhost:8080)")
                        Text("- MLX Toolkit (Apple Silicon)")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )

                    Button("Check Backend Status") {
                        Task {
                            await reportGenerator.checkAvailability()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(40)
            } else if reportGenerator.isGenerating {
                // Generation in progress
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(2)
                        .padding()

                    Text("Generating Security Report...")
                        .font(.system(size: 24, weight: .bold))

                    Text("Current Section: \(reportGenerator.currentSection)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    ProgressView(value: reportGenerator.generationProgress, total: 1.0)
                        .frame(width: 400)

                    Text("\(Int(reportGenerator.generationProgress * 100))% Complete")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("This may take a few minutes depending on your LLM backend...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else if !reportGenerator.reportContent.isEmpty {
                // Report generated - show full report
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Report Generated Successfully")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)

                            Text("Use the tabs above to view individual sections, or scroll below for the full report.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { generateReport() }) {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { exportToMarkdown() }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider()

                    ScrollView {
                        MarkdownTextView(markdown: reportGenerator.reportContent)
                            .padding(20)
                    }
                }
            } else {
                // Ready to generate
                VStack(spacing: 32) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    VStack(spacing: 12) {
                        Text("AI-Powered Security Report")
                            .font(.system(size: 32, weight: .bold))

                        Text("Generate a comprehensive security assessment using AI analysis")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }

                    // Scan summary
                    HStack(spacing: 40) {
                        ReportSummaryCard(
                            title: "Devices",
                            value: "\(devices.count)",
                            subtitle: "\(devices.filter { $0.isOnline }.count) online",
                            icon: "desktopcomputer",
                            color: .blue
                        )

                        ReportSummaryCard(
                            title: "Threats",
                            value: "\(threats.count)",
                            subtitle: "\(threats.filter { $0.severity == .critical }.count) critical",
                            icon: "exclamationmark.shield.fill",
                            color: threats.isEmpty ? .green : .red
                        )

                        ReportSummaryCard(
                            title: "Rogue Devices",
                            value: "\(devices.filter { $0.isRogue }.count)",
                            subtitle: "Unknown devices",
                            icon: "questionmark.circle.fill",
                            color: devices.filter { $0.isRogue }.isEmpty ? .green : .orange
                        )
                    }

                    // Report features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The AI report will include:")
                            .font(.system(size: 16, weight: .semibold))

                        HStack(spacing: 24) {
                            FeatureItem(icon: "person.2.fill", title: "Executive Summary", description: "High-level overview for leadership")
                            FeatureItem(icon: "wrench.fill", title: "Technical Details", description: "In-depth analysis of findings")
                            FeatureItem(icon: "exclamationmark.triangle", title: "Risk Assessment", description: "Quantified risk analysis")
                            FeatureItem(icon: "checkmark.shield", title: "Remediation Plan", description: "Prioritized action items")
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.05))
                    )

                    // Generate button
                    Button(action: { generateReport() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 20))
                            Text("Generate Security Report")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if let error = reportGenerator.lastError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(40)
            }

            Spacer()
        }
    }

    // MARK: - Section View

    private func sectionView(title: String, content: String, placeholder: String) -> some View {
        VStack(spacing: 0) {
            if content.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    if reportGenerator.isLLMAvailable && !reportGenerator.isGenerating {
                        Button("Generate Report") {
                            generateReport()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(title)
                                .font(.system(size: 28, weight: .bold))

                            Spacer()

                            Button(action: { copySection(content) }) {
                                Image(systemName: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        MarkdownTextView(markdown: content)
                    }
                    .padding(24)
                }
            }
        }
    }

    // MARK: - Actions

    private func generateReport() {
        Task {
            await reportGenerator.generateReport(from: devices, vulnerabilities: threats)
        }
    }

    private func exportToMarkdown() {
        do {
            exportedURL = try reportGenerator.exportToMarkdown()
            showingExportSuccess = true
        } catch {
            reportGenerator.lastError = error.localizedDescription
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportGenerator.reportContent, forType: .string)
    }

    private func copySection(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}

// MARK: - Supporting Views

struct ReportStatBadge: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
        }
    }
}

struct ReportSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
        )
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150)
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parseMarkdown(markdown), id: \.self) { section in
                Text(attributedString(from: section))
                    .textSelection(.enabled)
            }
        }
    }

    private func parseMarkdown(_ text: String) -> [String] {
        return text.components(separatedBy: "\n\n")
    }

    private func attributedString(from text: String) -> AttributedString {
        var result = AttributedString(text)

        // Handle headers
        if text.hasPrefix("# ") {
            result = AttributedString(String(text.dropFirst(2)))
            result.font = .system(size: 28, weight: .bold)
        } else if text.hasPrefix("## ") {
            result = AttributedString(String(text.dropFirst(3)))
            result.font = .system(size: 22, weight: .bold)
        } else if text.hasPrefix("### ") {
            result = AttributedString(String(text.dropFirst(4)))
            result.font = .system(size: 18, weight: .semibold)
        } else if text.hasPrefix("#### ") {
            result = AttributedString(String(text.dropFirst(5)))
            result.font = .system(size: 16, weight: .semibold)
        } else if text.hasPrefix("- ") || text.hasPrefix("* ") {
            // List items
            result.font = .system(size: 14)
        } else if text.hasPrefix("---") {
            result = AttributedString("─────────────────────────────────")
            result.foregroundColor = .secondary
        } else {
            result.font = .system(size: 14)
        }

        return result
    }
}

// MARK: - Compact Report Button (for embedding in other views)

struct AIReportButton: View {
    let devices: [EnhancedDevice]
    let threats: [ThreatFinding]

    @State private var showingReportView = false
    @StateObject private var aiBackend = AIBackendManager.shared

    var body: some View {
        Button(action: { showingReportView = true }) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                Text("AI Security Report")
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
            .opacity(aiBackend.activeBackend != nil ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .help(aiBackend.activeBackend != nil ? "Generate AI-powered security report" : "AI backend not available")
        .sheet(isPresented: $showingReportView) {
            SecurityReportView(devices: devices, threats: threats)
        }
    }
}

// MARK: - Menu Bar Item

struct AIReportMenuItem: View {
    let devices: [EnhancedDevice]
    let threats: [ThreatFinding]

    @State private var showingReportView = false
    @StateObject private var aiBackend = AIBackendManager.shared

    var body: some View {
        Button(action: { showingReportView = true }) {
            Label("Generate AI Security Report", systemImage: "wand.and.stars")
        }
        .disabled(aiBackend.activeBackend == nil)
        .sheet(isPresented: $showingReportView) {
            SecurityReportView(devices: devices, threats: threats)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SecurityReportView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityReportView(
            devices: [
                EnhancedDevice(
                    ipAddress: "192.168.1.1",
                    macAddress: "AA:BB:CC:DD:EE:FF",
                    hostname: "Router",
                    manufacturer: "Ubiquiti",
                    deviceType: .router,
                    openPorts: [
                        PortInfo(port: 22, service: "SSH", version: "OpenSSH 8.0", state: .open, protocolType: "TCP", banner: nil),
                        PortInfo(port: 80, service: "HTTP", version: nil, state: .open, protocolType: "TCP", banner: nil)
                    ],
                    isOnline: true,
                    firstSeen: Date(),
                    lastSeen: Date(),
                    isKnownDevice: true,
                    operatingSystem: "Linux",
                    deviceName: "Main Router"
                )
            ],
            threats: []
        )
    }
}
#endif
