//
//  SecurityViews.swift
//  NMAP Scanner - Security & Vulnerability Views
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI

// MARK: - Vulnerability Scanner View

struct VulnerabilityView: View {
    @StateObject private var scanner = VulnerabilityScanner()
    @State private var targetHost: String = "192.168.1.1"
    @State private var selectedVuln: Vulnerability?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Vulnerability Scanner")
                    .font(.system(size: 50, weight: .bold))

                // Scan controls
                HStack(spacing: 20) {
                    TextField("Target Host", text: $targetHost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24))
                        .padding(15)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .frame(maxWidth: 400)

                    Button("Scan") {
                        Task {
                            // Simulate port scan results
                            let ports = [21, 22, 23, 80, 443, 3306, 3389]
                            _ = await scanner.scanHost(host: targetHost, openPorts: ports)
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(scanner.isScanning)

                    Button("Clear") {
                        scanner.clearVulnerabilities()
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)

                    Button("Export") {
                        let report = scanner.exportReport()
                        print(report) // In real app, would share/save file
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(10)
                }

                if scanner.isScanning {
                    HStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning \(scanner.currentHost)...")
                            .font(.system(size: 24))
                    }
                    .padding(20)
                }

                // Security scores
                if !scanner.securityScores.isEmpty {
                    Text("Security Scores")
                        .font(.system(size: 36, weight: .semibold))

                    ForEach(Array(scanner.securityScores.keys.sorted()), id: \.self) { host in
                        if let score = scanner.securityScores[host] {
                            SecurityScoreCard(score: score)
                        }
                    }
                }

                // Vulnerabilities list
                if !scanner.vulnerabilities.isEmpty {
                    Text("Vulnerabilities Found (\(scanner.vulnerabilities.count))")
                        .font(.system(size: 36, weight: .semibold))

                    let groupedVulns = Dictionary(grouping: scanner.vulnerabilities, by: { $0.severity })

                    ForEach([Vulnerability.Severity.critical, .high, .medium, .low, .info], id: \.self) { severity in
                        if let vulns = groupedVulns[severity], !vulns.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("\(severity.rawValue) (\(vulns.count))")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(severityColor(severity))

                                ForEach(vulns) { vuln in
                                    VulnerabilityCard(vulnerability: vuln)
                                        .onTapGesture {
                                            selectedVuln = vuln
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedVuln) { vuln in
            VulnerabilityDetailView(vulnerability: vuln)
        }
    }

    private func severityColor(_ severity: Vulnerability.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

struct SecurityScoreCard: View {
    let score: SecurityScore

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(score.host)
                        .font(.system(size: 28, weight: .bold))
                    Text("Score: \(score.score)/100")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Checks: \(score.checksPassed)/\(score.checksTotal) passed")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text(score.grade)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(gradeColor(score.grade))
                    Text(score.rating)
                        .font(.system(size: 20))
                        .foregroundColor(gradeColor(score.grade))
                }
                .padding(20)
                .background(gradeColor(score.grade).opacity(0.2))
                .cornerRadius(12)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 20)
                        .cornerRadius(10)

                    Rectangle()
                        .fill(gradeColor(score.grade))
                        .frame(width: geometry.size.width * CGFloat(score.score) / 100, height: 20)
                        .cornerRadius(10)
                }
            }
            .frame(height: 20)
        }
        .padding(24)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .yellow
        case "D": return .orange
        default: return .red
        }
    }
}

struct VulnerabilityCard: View {
    let vulnerability: Vulnerability

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(vulnerability.type.rawValue)
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Text(vulnerability.severity.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor(vulnerability.severity))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            Text(vulnerability.host + (vulnerability.port.map { ":\($0)" } ?? ""))
                .font(.system(size: 20, design: .monospaced))
                .foregroundColor(.gray)

            Text(vulnerability.description)
                .font(.system(size: 20))
                .lineLimit(2)

            Text("Tap for details")
                .font(.system(size: 16))
                .foregroundColor(.blue)
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func severityColor(_ severity: Vulnerability.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

struct VulnerabilityDetailView: View {
    let vulnerability: Vulnerability
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Text("Vulnerability Details")
                        .font(.system(size: 40, weight: .bold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 20) {
                    SecurityInfoRow(label: "Type", value: vulnerability.type.rawValue)
                    SecurityInfoRow(label: "Severity", value: vulnerability.severity.rawValue)
                    SecurityInfoRow(label: "Host", value: vulnerability.host)
                    if let port = vulnerability.port {
                        SecurityInfoRow(label: "Port", value: "\(port)")
                    }
                    SecurityInfoRow(label: "Detected", value: formatDate(vulnerability.detectedAt))
                }

                Divider()
                    .background(Color.gray)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Description")
                        .font(.system(size: 28, weight: .semibold))
                    Text(vulnerability.description)
                        .font(.system(size: 22))
                        .padding(20)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 15) {
                    Text("Recommendation")
                        .font(.system(size: 28, weight: .semibold))
                    Text(vulnerability.recommendation)
                        .font(.system(size: 22))
                        .padding(20)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(40)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Security Audit View

struct SecurityAuditView: View {
    @StateObject private var auditManager = SecurityAuditManager()
    @State private var selectedFinding: SecurityFinding?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Security Audit")
                    .font(.system(size: 50, weight: .bold))

                // Controls
                HStack(spacing: 20) {
                    Button("Run Audit") {
                        Task {
                            // Simulate audit with sample data
                            let hosts = ["192.168.1.1", "192.168.1.10", "192.168.1.20"]
                            let results: [(host: String, ports: [Int])] = [
                                ("192.168.1.1", [22, 80, 443]),
                                ("192.168.1.10", [21, 23, 3306]),
                                ("192.168.1.20", [80, 443, 8080])
                            ]
                            await auditManager.performAudit(hosts: hosts, scanResults: results)
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(auditManager.isAuditing)

                    Button("Clear") {
                        auditManager.clearFindings()
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)

                    Button("Export") {
                        let report = auditManager.exportAuditReport()
                        print(report)
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(10)
                }

                if auditManager.isAuditing {
                    VStack(spacing: 15) {
                        ProgressView(value: auditManager.progress)
                            .scaleEffect(y: 3)
                            .padding(.horizontal, 100)
                        Text("Running security audit...")
                            .font(.system(size: 24))
                    }
                    .padding(20)
                }

                // Known devices management
                KnownDevicesSection(auditManager: auditManager)

                // Findings
                if !auditManager.findings.isEmpty {
                    Text("Findings (\(auditManager.findings.count))")
                        .font(.system(size: 36, weight: .semibold))

                    let groupedFindings = Dictionary(grouping: auditManager.findings, by: { $0.category })

                    ForEach(Array(groupedFindings.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                        if let findings = groupedFindings[category] {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("\(category.rawValue) (\(findings.count))")
                                    .font(.system(size: 30, weight: .semibold))

                                ForEach(findings.sorted(by: { $0.severity > $1.severity })) { finding in
                                    FindingCard(finding: finding)
                                        .onTapGesture {
                                            selectedFinding = finding
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedFinding) { finding in
            FindingDetailView(finding: finding)
        }
    }
}

struct KnownDevicesSection: View {
    @ObservedObject var auditManager: SecurityAuditManager
    @State private var showingAddDevice = false
    @State private var newDeviceMAC = ""
    @State private var newDeviceName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Known Devices (\(auditManager.knownDevices.count))")
                    .font(.system(size: 32, weight: .semibold))

                Spacer()

                Button("Add Device") {
                    showingAddDevice = true
                }
                .font(.system(size: 20))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(8)
            }

            if auditManager.knownDevices.isEmpty {
                Text("No known devices. Add devices to identify rogue devices on your network.")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .padding(20)
            } else {
                ForEach(auditManager.knownDevices, id: \.macAddress) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(device.name)
                                .font(.system(size: 22, weight: .semibold))
                            Text(device.macAddress)
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Button("Remove") {
                            auditManager.removeKnownDevice(macAddress: device.macAddress)
                        }
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                    }
                    .padding(15)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceView(
                macAddress: $newDeviceMAC,
                name: $newDeviceName,
                onAdd: {
                    auditManager.addKnownDevice(macAddress: newDeviceMAC, name: newDeviceName)
                    newDeviceMAC = ""
                    newDeviceName = ""
                    showingAddDevice = false
                }
            )
        }
    }
}

struct AddDeviceView: View {
    @Binding var macAddress: String
    @Binding var name: String
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 30) {
            Text("Add Known Device")
                .font(.system(size: 36, weight: .bold))

            TextField("Device Name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 24))
                .padding(15)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

            TextField("MAC Address", text: $macAddress)
                .textFieldStyle(.plain)
                .font(.system(size: 24, design: .monospaced))
                .padding(15)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 24))
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(10)

                Button("Add") {
                    onAdd()
                }
                .font(.system(size: 24, weight: .semibold))
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(name.isEmpty || macAddress.isEmpty)
            }
        }
        .padding(40)
    }
}

struct FindingCard: View {
    let finding: SecurityFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(finding.title)
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Text(finding.severity.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor(finding.severity))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            Text(finding.description)
                .font(.system(size: 20))
                .lineLimit(2)

            if !finding.affectedHosts.isEmpty {
                Text("Affected: \(finding.affectedHosts.joined(separator: ", "))")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }

            Text("Tap for details")
                .font(.system(size: 16))
                .foregroundColor(.blue)
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func severityColor(_ severity: SecurityFinding.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

struct FindingDetailView: View {
    let finding: SecurityFinding
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Text("Finding Details")
                        .font(.system(size: 40, weight: .bold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 20) {
                    SecurityInfoRow(label: "Title", value: finding.title)
                    SecurityInfoRow(label: "Category", value: finding.category.rawValue)
                    SecurityInfoRow(label: "Severity", value: finding.severity.rawValue)
                    SecurityInfoRow(label: "Affected Hosts", value: finding.affectedHosts.joined(separator: ", "))
                    SecurityInfoRow(label: "Detected", value: formatDate(finding.detectedAt))
                }

                Divider()
                    .background(Color.gray)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Description")
                        .font(.system(size: 28, weight: .semibold))
                    Text(finding.description)
                        .font(.system(size: 22))
                        .padding(20)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 15) {
                    Text("Recommendation")
                        .font(.system(size: 28, weight: .semibold))
                    Text(finding.recommendation)
                        .font(.system(size: 22))
                        .padding(20)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(40)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Simple InfoRow for SecurityViews
struct SecurityInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 200, alignment: .leading)
            Text(value)
                .font(.system(size: 20))
        }
    }
}
