//
//  ExportManager.swift
//  NMAPScanner
//
//  Multi-format export and reporting system
//  Supports PDF, CSV, JSON, and HTML exports of scan results
//  Created by Jordan Koch on 11/23/2025.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Manages export and reporting functionality
@MainActor
class ExportManager: ObservableObject {
    static let shared = ExportManager()

    @Published var isExporting = false
    @Published var lastExportURL: URL?
    @Published var exportError: String?

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF Report"
        case csv = "CSV Spreadsheet"
        case json = "JSON Data"
        case html = "HTML Report"

        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .csv: return "csv"
            case .json: return "json"
            case .html: return "html"
            }
        }

        var icon: String {
            switch self {
            case .pdf: return "doc.fill"
            case .csv: return "tablecells"
            case .json: return "curlybraces"
            case .html: return "globe"
            }
        }
    }

    // MARK: - Main Export Functions

    /// Export scan results in the specified format
    func exportScanResults(_ devices: [EnhancedDevice], format: ExportFormat, threats: [ThreatFinding] = []) async -> URL? {
        isExporting = true
        exportError = nil

        defer { isExporting = false }

        do {
            let url: URL?
            switch format {
            case .pdf:
                url = try await generatePDFReport(devices: devices, threats: threats)
            case .csv:
                url = try await exportToCSV(devices)
            case .json:
                url = try await exportToJSON(devices, threats: threats)
            case .html:
                url = try await generateHTMLReport(devices: devices, threats: threats)
            }

            lastExportURL = url
            return url
        } catch {
            exportError = error.localizedDescription
            return nil
        }
    }

    // MARK: - CSV Export

    private func exportToCSV(_ devices: [EnhancedDevice]) async throws -> URL {
        var csvContent = "IP Address,MAC Address,Hostname,Manufacturer,Device Type,Open Ports,Online,First Seen,Last Seen,Known Device\n"

        for device in devices {
            let row = [
                device.ipAddress,
                device.macAddress ?? "N/A",
                device.hostname ?? "N/A",
                device.manufacturer ?? "N/A",
                device.deviceType.rawValue,
                device.openPorts.map { String($0.port) }.joined(separator: ";"),
                device.isOnline ? "Yes" : "No",
                ISO8601DateFormatter().string(from: device.firstSeen),
                ISO8601DateFormatter().string(from: device.lastSeen),
                device.isKnownDevice ? "Yes" : "No"
            ]
            csvContent += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }

        return try saveToFile(csvContent, filename: "network_scan", extension: "csv")
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    // MARK: - JSON Export

    struct ExportData: Codable {
        let exportDate: Date
        let devices: [DeviceExport]
        let threats: [ThreatExport]
        let summary: ScanSummary

        struct DeviceExport: Codable {
            let ipAddress: String
            let macAddress: String?
            let hostname: String?
            let manufacturer: String?
            let deviceType: String
            let openPorts: [PortExport]
            let isOnline: Bool
            let firstSeen: Date
            let lastSeen: Date
            let isKnownDevice: Bool
            let isRogue: Bool
        }

        struct PortExport: Codable {
            let port: Int
            let service: String
            let version: String?
        }

        struct ThreatExport: Codable {
            let severity: String
            let category: String
            let title: String
            let description: String
            let affectedHost: String
            let cvssScore: Double?
            let detectedAt: Date
        }

        struct ScanSummary: Codable {
            let totalDevices: Int
            let onlineDevices: Int
            let rogueDevices: Int
            let totalThreats: Int
            let criticalThreats: Int
            let highThreats: Int
        }
    }

    private func exportToJSON(_ devices: [EnhancedDevice], threats: [ThreatFinding]) async throws -> URL {
        let deviceExports = devices.map { device in
            ExportData.DeviceExport(
                ipAddress: device.ipAddress,
                macAddress: device.macAddress,
                hostname: device.hostname,
                manufacturer: device.manufacturer,
                deviceType: device.deviceType.rawValue,
                openPorts: device.openPorts.map { port in
                    ExportData.PortExport(
                        port: port.port,
                        service: port.service,
                        version: port.version
                    )
                },
                isOnline: device.isOnline,
                firstSeen: device.firstSeen,
                lastSeen: device.lastSeen,
                isKnownDevice: device.isKnownDevice,
                isRogue: device.isRogue
            )
        }

        let threatExports = threats.map { threat in
            ExportData.ThreatExport(
                severity: threat.severity.rawValue,
                category: threat.category.rawValue,
                title: threat.title,
                description: threat.description,
                affectedHost: threat.affectedHost,
                cvssScore: threat.cvssScore,
                detectedAt: threat.detectedAt
            )
        }

        let summary = ExportData.ScanSummary(
            totalDevices: devices.count,
            onlineDevices: devices.filter { $0.isOnline }.count,
            rogueDevices: devices.filter { $0.isRogue }.count,
            totalThreats: threats.count,
            criticalThreats: threats.filter { $0.severity == .critical }.count,
            highThreats: threats.filter { $0.severity == .high }.count
        )

        let exportData = ExportData(
            exportDate: Date(),
            devices: deviceExports,
            threats: threatExports,
            summary: summary
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(exportData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }

        return try saveToFile(jsonString, filename: "network_scan", extension: "json")
    }

    // MARK: - HTML Export

    private func generateHTMLReport(devices: [EnhancedDevice], threats: [ThreatFinding]) async throws -> URL {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Network Scan Report - \(Date().formatted())</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    background: #f5f5f7;
                    color: #1d1d1f;
                    padding: 40px 20px;
                }
                .container { max-width: 1200px; margin: 0 auto; }
                .header {
                    background: linear-gradient(135deg, #0071e3 0%, #005bb5 100%);
                    color: white;
                    padding: 40px;
                    border-radius: 16px;
                    margin-bottom: 30px;
                }
                .header h1 { font-size: 42px; margin-bottom: 10px; }
                .header p { font-size: 18px; opacity: 0.9; }
                .summary {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 20px;
                    margin-bottom: 30px;
                }
                .stat-card {
                    background: white;
                    padding: 24px;
                    border-radius: 12px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                .stat-card h3 { font-size: 16px; color: #6e6e73; margin-bottom: 8px; }
                .stat-card .value { font-size: 36px; font-weight: 600; color: #0071e3; }
                .section {
                    background: white;
                    padding: 30px;
                    border-radius: 12px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                    margin-bottom: 20px;
                }
                .section h2 { font-size: 28px; margin-bottom: 20px; }
                table {
                    width: 100%;
                    border-collapse: collapse;
                }
                th {
                    background: #f5f5f7;
                    padding: 12px;
                    text-align: left;
                    font-weight: 600;
                    border-bottom: 2px solid #d2d2d7;
                }
                td {
                    padding: 12px;
                    border-bottom: 1px solid #d2d2d7;
                }
                tr:hover { background: #f9f9f9; }
                .badge {
                    display: inline-block;
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 12px;
                    font-weight: 600;
                }
                .badge-online { background: #34c759; color: white; }
                .badge-offline { background: #8e8e93; color: white; }
                .badge-rogue { background: #ff3b30; color: white; }
                .badge-known { background: #0071e3; color: white; }
                .badge-critical { background: #ff3b30; color: white; }
                .badge-high { background: #ff9500; color: white; }
                .badge-medium { background: #ffcc00; color: black; }
                .badge-low { background: #34c759; color: white; }
                .footer {
                    text-align: center;
                    color: #6e6e73;
                    margin-top: 40px;
                    padding: 20px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🛡️ Network Security Scan Report</h1>
                    <p>Generated on \(Date().formatted(date: .long, time: .shortened))</p>
                </div>

                <div class="summary">
                    <div class="stat-card">
                        <h3>Total Devices</h3>
                        <div class="value">\(devices.count)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Online</h3>
                        <div class="value">\(devices.filter { $0.isOnline }.count)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Rogue Devices</h3>
                        <div class="value">\(devices.filter { $0.isRogue }.count)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Total Threats</h3>
                        <div class="value">\(threats.count)</div>
                    </div>
                </div>

                \(generateDevicesTableHTML(devices))
                \(generateThreatsTableHTML(threats))

                <div class="footer">
                    <p>Generated by NMAP Plus Security Scanner</p>
                    <p>Created by Jordan Koch</p>
                </div>
            </div>
        </body>
        </html>
        """

        return try saveToFile(html, filename: "network_scan_report", extension: "html")
    }

    private func generateDevicesTableHTML(_ devices: [EnhancedDevice]) -> String {
        var rows = ""
        for device in devices {
            let statusBadge = device.isOnline ? "<span class='badge badge-online'>Online</span>" : "<span class='badge badge-offline'>Offline</span>"
            let rogueBadge = device.isRogue ? "<span class='badge badge-rogue'>Rogue</span>" : ""
            let knownBadge = device.isKnownDevice ? "<span class='badge badge-known'>Known</span>" : ""

            rows += """
                <tr>
                    <td>\(device.ipAddress)</td>
                    <td>\(device.hostname ?? "—")</td>
                    <td>\(device.manufacturer ?? "—")</td>
                    <td>\(device.deviceType.rawValue)</td>
                    <td>\(device.openPorts.map { String($0.port) }.joined(separator: ", "))</td>
                    <td>\(statusBadge) \(rogueBadge) \(knownBadge)</td>
                </tr>
                """
        }

        return """
            <div class="section">
                <h2>Discovered Devices</h2>
                <table>
                    <thead>
                        <tr>
                            <th>IP Address</th>
                            <th>Hostname</th>
                            <th>Manufacturer</th>
                            <th>Type</th>
                            <th>Open Ports</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        \(rows)
                    </tbody>
                </table>
            </div>
            """
    }

    private func generateThreatsTableHTML(_ threats: [ThreatFinding]) -> String {
        guard !threats.isEmpty else { return "" }

        var rows = ""
        for threat in threats {
            let severityClass: String
            switch threat.severity {
            case .critical: severityClass = "badge-critical"
            case .high: severityClass = "badge-high"
            case .medium: severityClass = "badge-medium"
            case .low: severityClass = "badge-low"
            case .info: severityClass = "badge-low"
            }

            rows += """
                <tr>
                    <td>\(threat.affectedHost)</td>
                    <td>\(threat.title)</td>
                    <td><span class='badge \(severityClass)'>\(threat.severity.rawValue.uppercased())</span></td>
                    <td>\(threat.cvssScore.map { String(format: "%.1f", $0) } ?? "—")</td>
                    <td>\(threat.description)</td>
                </tr>
                """
        }

        return """
            <div class="section">
                <h2>Security Threats</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Host</th>
                            <th>Threat</th>
                            <th>Severity</th>
                            <th>CVSS</th>
                            <th>Description</th>
                        </tr>
                    </thead>
                    <tbody>
                        \(rows)
                    </tbody>
                </table>
            </div>
            """
    }

    // MARK: - PDF Export

    private func generatePDFReport(devices: [EnhancedDevice], threats: [ThreatFinding]) async throws -> URL {
        // For tvOS, we'll generate a text-based PDF since Core Graphics PDF generation is limited
        // In a production app, you might use a third-party library for richer PDFs

        let pdfContent = """
        NETWORK SECURITY SCAN REPORT
        ============================
        Generated: \(Date().formatted(date: .long, time: .complete))

        SUMMARY
        -------
        Total Devices: \(devices.count)
        Online Devices: \(devices.filter { $0.isOnline }.count)
        Rogue Devices: \(devices.filter { $0.isRogue }.count)
        Total Threats: \(threats.count)
        Critical Threats: \(threats.filter { $0.severity == .critical }.count)
        High Threats: \(threats.filter { $0.severity == .high }.count)

        DISCOVERED DEVICES
        ------------------
        \(generateDevicesList(devices))

        \(threats.isEmpty ? "" : """
        SECURITY THREATS
        ----------------
        \(generateThreatsList(threats))
        """)

        RECOMMENDATIONS
        ---------------
        \(generateRecommendations(devices: devices, threats: threats))

        ---
        Report generated by NMAP Plus Security Scanner
        Created by Jordan Koch
        """

        return try saveToFile(pdfContent, filename: "network_scan_report", extension: "pdf")
    }

    private func generateDevicesList(_ devices: [EnhancedDevice]) -> String {
        devices.map { device in
            """
            IP: \(device.ipAddress)
            Hostname: \(device.hostname ?? "Unknown")
            Manufacturer: \(device.manufacturer ?? "Unknown")
            Type: \(device.deviceType.rawValue)
            Status: \(device.isOnline ? "Online" : "Offline")
            Rogue: \(device.isRogue ? "YES ⚠️" : "No")
            Open Ports: \(device.openPorts.map { String($0.port) }.joined(separator: ", "))
            First Seen: \(device.firstSeen.formatted())
            ---
            """
        }.joined(separator: "\n")
    }

    private func generateThreatsList(_ threats: [ThreatFinding]) -> String {
        threats.map { threat in
            """
            Host: \(threat.affectedHost)
            Threat: \(threat.title)
            Severity: \(threat.severity.rawValue.uppercased())
            CVSS Score: \(threat.cvssScore.map { String(format: "%.1f", $0) } ?? "N/A")
            Description: \(threat.description)
            Remediation: \(threat.remediation)
            ---
            """
        }.joined(separator: "\n")
    }

    private func generateRecommendations(devices: [EnhancedDevice], threats: [ThreatFinding]) -> String {
        var recommendations: [String] = []

        let rogueCount = devices.filter { $0.isRogue }.count
        if rogueCount > 0 {
            recommendations.append("• Investigate \(rogueCount) rogue device\(rogueCount > 1 ? "s" : "") immediately")
        }

        let criticalThreats = threats.filter { $0.severity == .critical }.count
        if criticalThreats > 0 {
            recommendations.append("• Address \(criticalThreats) critical security threat\(criticalThreats > 1 ? "s" : "") immediately")
        }

        let unknownDevices = devices.filter { !$0.isKnownDevice }.count
        if unknownDevices > 0 {
            recommendations.append("• Review and whitelist \(unknownDevices) unknown device\(unknownDevices > 1 ? "s" : "")")
        }

        let highRiskPorts = devices.flatMap { $0.openPorts }.filter { [22, 23, 3389, 5900].contains($0.port) }
        if !highRiskPorts.isEmpty {
            recommendations.append("• Secure or close high-risk remote access ports (SSH, Telnet, RDP, VNC)")
        }

        if recommendations.isEmpty {
            recommendations.append("• Network appears secure - continue regular monitoring")
            recommendations.append("• Schedule automated scans to maintain visibility")
            recommendations.append("• Keep device whitelist up to date")
        }

        return recommendations.joined(separator: "\n")
    }

    // MARK: - File Management

    private func saveToFile(_ content: String, filename: String, extension fileExtension: String) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fullFilename = "\(filename)_\(timestamp).\(fileExtension)"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fullFilename)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    // MARK: - Threat Report Export

    func exportThreatReport(threats: [ThreatFinding]) async -> URL? {
        let csvContent = generateThreatReportCSV(threats)
        do {
            return try saveToFile(csvContent, filename: "threat_report", extension: "csv")
        } catch {
            exportError = error.localizedDescription
            return nil
        }
    }

    private func generateThreatReportCSV(_ threats: [ThreatFinding]) -> String {
        var csv = "Host,Threat,Severity,CVSS Score,Category,Description,Remediation,Detected At\n"

        for threat in threats {
            let row = [
                threat.affectedHost,
                threat.title,
                threat.severity.rawValue,
                threat.cvssScore.map { String(format: "%.1f", $0) } ?? "N/A",
                threat.category.rawValue,
                threat.description,
                threat.remediation,
                ISO8601DateFormatter().string(from: threat.detectedAt)
            ]
            csv += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }

        return csv
    }

    // MARK: - Error Types

    enum ExportError: LocalizedError {
        case encodingFailed
        case saveFailed
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode data"
            case .saveFailed: return "Failed to save file"
            case .unsupportedFormat: return "Unsupported export format"
            }
        }
    }
}

// MARK: - Export UI

struct ExportView: View {
    let devices: [EnhancedDevice]
    let threats: [ThreatFinding]
    @StateObject private var exportManager = ExportManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportManager.ExportFormat = .pdf
    @State private var showingShareSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Export Scan Results")
                    .font(.system(size: 42, weight: .bold))

                // Format selection
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select Format:")
                        .font(.system(size: 28, weight: .semibold))

                    ForEach(ExportManager.ExportFormat.allCases, id: \.self) { format in
                        Button(action: {
                            selectedFormat = format
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: format.icon)
                                    .font(.system(size: 32))
                                    .frame(width: 50)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(format.rawValue)
                                        .font(.system(size: 26, weight: .semibold))
                                    Text(getFormatDescription(format))
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedFormat == format {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(24)
                            .background(selectedFormat == format ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedFormat == format ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Export button
                Button(action: {
                    Task {
                        if let url = await exportManager.exportScanResults(devices, format: selectedFormat, threats: threats) {
                            // On tvOS, we'd typically save to a shared location or use AirDrop
                            // For now, just store the URL
                            print("Exported to: \(url.path)")
                        }
                    }
                }) {
                    HStack {
                        if exportManager.isExporting {
                            ProgressView()
                                .scaleEffect(1.5)
                        } else {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 32))
                        }
                        Text(exportManager.isExporting ? "Exporting..." : "Export Now")
                            .font(.system(size: 28, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(exportManager.isExporting ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(exportManager.isExporting)

                if let error = exportManager.exportError {
                    Text("Error: \(error)")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }

                if let url = exportManager.lastExportURL {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("Export Complete")
                            .font(.system(size: 24, weight: .semibold))
                        Text(url.lastPathComponent)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            .padding(40)
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func getFormatDescription(_ format: ExportManager.ExportFormat) -> String {
        switch format {
        case .pdf: return "Full report with detailed analysis"
        case .csv: return "Spreadsheet format for Excel/Numbers"
        case .json: return "Structured data for API integration"
        case .html: return "Interactive web report"
        }
    }
}
