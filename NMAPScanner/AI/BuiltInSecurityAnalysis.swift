//
//  BuiltInSecurityAnalysis.swift
//  NMAPScanner
//
//  The rule-based results every AI feature falls back to when AI is off, unreachable, or its reply is rejected.
//  Built on the app's own ThreatAnalyzer (backdoor / remote-access / database port rules, rogue devices).
//  Deterministic and network-free.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

@MainActor
enum BuiltInSecurityAnalysis {
    static let label = "Built-in rule-based analysis"

    /// The app's rule-based findings for `devices`, most severe first.
    static func findings(_ devices: [EnhancedDevice]) -> [ThreatFinding] {
        let analyzer = ThreatAnalyzer()
        analyzer.analyzeNetwork(devices: devices)
        return analyzer.allThreats
    }

    // MARK: Threat analysis

    static func threatAnalysis(devices: [EnhancedDevice]) -> ThreatAnalysisResult {
        let all = findings(devices)
        let actionable = all.filter { $0.severity != .info }
        let threats = actionable.map { ThreatItem(description: "\($0.affectedHost): \($0.title)", severity: $0.severity) }
        let counts = ThreatSeverity.allCases.filter { $0 != .info }.map { sev in
            "\(actionable.filter { $0.severity == sev }.count) \(sev.rawValue.lowercased())"
        }.joined(separator: ", ")
        let rogue = devices.filter { $0.isRogue }.count
        var summary = "\(label) of \(devices.count) device(s): \(counts) finding(s)."
        if rogue > 0 { summary += " \(rogue) unrecognised (rogue) device(s) on the network." }
        if actionable.isEmpty { summary += " No risky open ports were found." }
        let recommendations = unique(actionable.map(\.remediation)).prefix(10)
        let full = actionable.map { "- [\($0.severity.rawValue)] \($0.affectedHost): \($0.title) — \($0.remediation)" }
            .joined(separator: "\n")
        return ThreatAnalysisResult(summary: summary, threats: threats,
                                    recommendations: recommendations.isEmpty ? ["Keep scanning regularly and review new devices."] : Array(recommendations),
                                    analyzedDeviceCount: devices.count, analysisDate: Date(), fullResponse: full)
    }

    static func deviceAnalysis(_ device: EnhancedDevice) -> DeviceThreatAnalysis {
        let f = findings([device]).filter { $0.severity != .info }
        let risk: DeviceRiskLevel
        switch f.map(\.severity).min() {
        case .critical?: risk = .critical
        case .high?: risk = .high
        case .medium?: risk = .medium
        case .low?: risk = .low
        default: risk = .safe
        }
        let text = f.isEmpty
            ? "\(label): no risky open ports on \(device.displayName) (\(device.openPorts.count) open port(s))."
            : "\(label) for \(device.displayName):\n" + f.map { "- [\($0.severity.rawValue)] \($0.title): \($0.remediation)" }.joined(separator: "\n")
        return DeviceThreatAnalysis(device: device, riskLevel: risk, analysis: text, analyzedDate: Date())
    }

    // MARK: Recommendations

    static func priority(_ s: ThreatSeverity) -> SecurityPriority {
        switch s {
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low, .info: return .low
        }
    }

    static func recommendations(for found: [ThreatFinding]) -> [SecurityRecommendation] {
        let grouped = Dictionary(grouping: found.filter { $0.severity != .info }, by: \.title)
        return grouped.values.compactMap { group -> SecurityRecommendation? in
            guard let first = group.min(by: { $0.severity < $1.severity }) else { return nil }
            let hosts = unique(group.map(\.affectedHost))
            return SecurityRecommendation(
                title: first.title,
                priority: priority(first.severity),
                reason: first.description,
                steps: [first.remediation],
                impact: "Affects \(hosts.count) device(s): \(hosts.prefix(5).joined(separator: ", "))\(hosts.count > 5 ? "…" : "")"
            )
        }.sorted { $0.title < $1.title }
    }

    static func recommendationSet(devices: [EnhancedDevice]) -> SecurityRecommendationSet {
        var recs = recommendations(for: findings(devices))
        recs.append(SecurityRecommendation(
            title: "Review unknown devices after every scan",
            priority: .low,
            reason: "New or unrecognised devices are the most common sign of an intrusion.",
            steps: ["Name or whitelist each known device", "Investigate anything flagged as rogue"],
            impact: "Faster detection of unauthorised devices"))
        func of(_ p: SecurityPriority) -> [SecurityRecommendation] { recs.filter { $0.priority == p } }
        return SecurityRecommendationSet(critical: of(.critical), high: of(.high), medium: of(.medium), low: of(.low),
                                         generatedDate: Date(), networkSize: devices.count,
                                         fullResponse: "\(label): \(recs.count) recommendation(s) from the scan's open ports.")
    }

    static func deviceRecommendations(_ device: EnhancedDevice) -> [SecurityRecommendation] {
        recommendations(for: findings([device]))
    }

    // MARK: Natural-language query (keyword search)

    /// Keyword search over name, IP, MAC, vendor, type, OS, services and port numbers. Every word must match.
    static func query(_ text: String, devices: [EnhancedDevice]) -> QueryResult {
        let stop: Set<String> = ["show", "me", "all", "the", "with", "which", "what", "devices", "device", "are", "is",
                                 "find", "list", "that", "have", "has", "a", "an", "on", "my", "of", "open", "port", "ports"]
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != ":" })
            .map(String.init).filter { !stop.contains($0) }
        let wantsRogue = words.contains { $0.hasPrefix("rogue") || $0 == "unknown" || $0 == "new" }
        let matches = devices.filter { d in
            let hay = haystack(d)
            return words.allSatisfy { w in
                hay.contains(w) || ((w.hasPrefix("rogue") || w == "unknown" || w == "new") && d.isRogue)
                    || (w == "risky" && d.openPorts.contains { $0.isSuspicious })
                    || (w == "online" && d.isOnline) || (w == "offline" && !d.isOnline)
            }
        }
        let explanation = words.isEmpty
            ? "\(label): no search words in the query, so every device is listed."
            : "\(label): devices whose name, address, vendor, type, OS or services contain “\(words.joined(separator: "”, “"))”"
              + (wantsRogue ? " (rogue = not yet known)." : ".")
        return QueryResult(query: text, matchingDevices: words.isEmpty ? devices : matches, explanation: explanation,
                           summary: "Found \(words.isEmpty ? devices.count : matches.count) matching device(s)", timestamp: Date())
    }

    private static func haystack(_ d: EnhancedDevice) -> String {
        ([d.displayName, d.ipAddress, d.macAddress ?? "", d.hostname ?? "", d.manufacturer ?? "", d.deviceType.rawValue,
          d.operatingSystem ?? ""] + d.openPorts.flatMap { [String($0.port), $0.service] })
            .joined(separator: " ").lowercased()
    }

    // MARK: Documentation

    static func documentation(devices: [EnhancedDevice], includeSecurityAnalysis: Bool, includeTopology: Bool,
                              includeRecommendations: Bool) -> NetworkDocumentation {
        var md = "# Network Documentation\n\n_Generated by NMAPScanner’s \(label.lowercased()) on \(Date().formatted(date: .long, time: .shortened))._\n\n"
        md += "## Executive Summary\n\n- Devices: \(devices.count) (\(devices.filter(\.isOnline).count) online)\n"
        md += "- Devices with open ports: \(devices.filter { !$0.openPorts.isEmpty }.count)\n"
        md += "- Rogue devices: \(devices.filter(\.isRogue).count)\n\n"
        if includeTopology {
            md += "## Network Topology\n\n"
            let byType = Dictionary(grouping: devices, by: \.deviceType).sorted { $0.value.count > $1.value.count }
            md += byType.map { "- \($0.key.rawValue): \($0.value.count)" }.joined(separator: "\n") + "\n\n"
        }
        md += "## Device Inventory\n\n| Name | IP | MAC | Type | Vendor | Open ports |\n|---|---|---|---|---|---|\n"
        for d in devices {
            let ports = d.openPorts.prefix(8).map { "\($0.port)/\($0.service)" }.joined(separator: ", ")
            md += "| \(d.displayName) | \(d.ipAddress) | \(d.macAddress ?? "—") | \(d.deviceType.rawValue) | \(d.manufacturer ?? "—") | \(ports.isEmpty ? "—" : ports) |\n"
        }
        let result = threatAnalysis(devices: devices)
        if includeSecurityAnalysis {
            md += "\n## Security Analysis\n\n\(result.summary)\n\n"
            md += result.fullResponse.isEmpty ? "" : result.fullResponse + "\n"
        }
        if includeRecommendations {
            md += "\n## Recommendations\n\n" + result.recommendations.map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        return NetworkDocumentation(title: "Network Documentation - \(Date().formatted(date: .long, time: .omitted))",
                                    content: md, generatedDate: Date(), deviceCount: devices.count,
                                    includesSecurityAnalysis: includeSecurityAnalysis, includesTopology: includeTopology,
                                    includesRecommendations: includeRecommendations)
    }

    static func deviceDocumentation(_ d: EnhancedDevice) -> String {
        var md = "# \(d.displayName)\n\n- IP: \(d.ipAddress)\n- MAC: \(d.macAddress ?? "—")\n- Type: \(d.deviceType.rawValue)\n"
        md += "- Vendor: \(d.manufacturer ?? "—")\n- OS: \(d.operatingSystem ?? "—")\n- Status: \(d.isOnline ? "Online" : "Offline")\n\n"
        md += "## Open ports\n\n" + (d.openPorts.isEmpty ? "None\n" : d.openPorts.map { "- \($0.port)/\($0.protocolType) \($0.service)\($0.version.map { " (\($0))" } ?? "")" }.joined(separator: "\n") + "\n")
        md += "\n## Security assessment\n\n" + deviceAnalysis(d).analysis + "\n"
        return md
    }

    // MARK: Anomalies (used when the AI can't judge a heuristic hit)

    static func newDeviceAnomaly(_ d: EnhancedDevice) -> MLXNetworkAnomaly {
        let backdoor = d.openPorts.contains { $0.isBackdoorPort }
        return MLXNetworkAnomaly(type: .newDevice, severity: backdoor ? .critical : (d.openPorts.contains { $0.isSuspicious } ? .high : .medium),
                                 description: "New device \(d.displayName) (\(d.ipAddress)) was not in the baseline"
                                    + (backdoor ? " and has a known backdoor port open." : "."),
                                 recommendation: "Confirm who owns this device; block it if it is not recognised.",
                                 affectedDevice: d, detectedDate: Date())
    }

    static func portAnomaly(_ d: EnhancedDevice, baselineAverage: Int) -> MLXNetworkAnomaly {
        MLXNetworkAnomaly(type: .unusualPorts, severity: d.openPorts.contains { $0.isSuspicious } ? .high : .medium,
                          description: "\(d.displayName) has \(d.openPorts.count) open ports (network average \(baselineAverage)).",
                          recommendation: "Close services that are not needed and firewall the rest.",
                          affectedDevice: d, detectedDate: Date())
    }

    static func missingDevicesAnomaly(count: Int, known: Int) -> MLXNetworkAnomaly {
        MLXNetworkAnomaly(type: .missingDevices, severity: count * 2 > known ? .high : .medium,
                          description: "\(count) of \(known) baseline devices are missing from this scan.",
                          recommendation: "Check for a network outage, DHCP change or a switch/AP failure.",
                          affectedDevice: nil, detectedDate: Date())
    }

    // MARK: Report sections (raw data when AI is unavailable)

    static func reportSection(_ title: String, data: String) -> String {
        "_\(label) — AI was off or unavailable, so this section lists the underlying scan data._\n\n\(data)"
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}
