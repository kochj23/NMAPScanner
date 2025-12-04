//
//  DNSSecurityAnalyzer.swift
//  NMAPScanner - DNS Security Analysis
//
//  Created by Jordan Koch & Claude Code on 2025-11-27.
//

import Foundation

struct DNSSecurityFinding: Identifiable, Codable {
    let id = UUID()
    let severity: Severity
    let type: FindingType
    let domain: String
    let ipAddress: String
    let description: String
    let recommendation: String
    let timestamp: Date

    enum Severity: String, Codable {
        case critical, high, medium, low
    }

    enum FindingType: String, Codable {
        case dnsTunneling = "DNS Tunneling"
        case dgaDomain = "DGA Domain"
        case suspiciousTLD = "Suspicious TLD"
        case openResolver = "Open DNS Resolver"
        case dnssecFailure = "DNSSEC Validation Failure"
    }
}

@MainActor
class DNSSecurityAnalyzer: ObservableObject {
    static let shared = DNSSecurityAnalyzer()

    @Published var findings: [DNSSecurityFinding] = []
    @Published var isScanning = false

    private let suspiciousTLDs = ["tk", "ml", "ga", "cf", "gq", "pw", "cc", "ws"]
    private let knownC2Domains = ["badactor.com", "malware.xyz"] // Simplified list

    private init() {}

    func analyzeDNSTraffic(queries: [(domain: String, ip: String)]) async {
        isScanning = true
        findings.removeAll()

        for (domain, ip) in queries {
            // Check for DNS tunneling
            if domain.count > 50 || domain.components(separatedBy: ".").count > 5 {
                findings.append(DNSSecurityFinding(
                    severity: .high,
                    type: .dnsTunneling,
                    domain: domain,
                    ipAddress: ip,
                    description: "Suspicious long/complex DNS query - possible data exfiltration",
                    recommendation: "Investigate this host for malware. Monitor DNS query patterns.",
                    timestamp: Date()
                ))
            }

            // Check for DGA patterns
            if isDGADomain(domain) {
                findings.append(DNSSecurityFinding(
                    severity: .critical,
                    type: .dgaDomain,
                    domain: domain,
                    ipAddress: ip,
                    description: "Domain matches DGA pattern - likely malware C2 communication",
                    recommendation: "Isolate this device immediately. Run malware scan.",
                    timestamp: Date()
                ))
            }

            // Check TLD
            if let tld = domain.components(separatedBy: ".").last,
               suspiciousTLDs.contains(tld) {
                findings.append(DNSSecurityFinding(
                    severity: .medium,
                    type: .suspiciousTLD,
                    domain: domain,
                    ipAddress: ip,
                    description: "Query to suspicious TLD often used by malware",
                    recommendation: "Review connection purpose. Block TLD if not business-critical.",
                    timestamp: Date()
                ))
            }
        }

        isScanning = false
    }

    private func isDGADomain(_ domain: String) -> Bool {
        let domainName = domain.components(separatedBy: ".").first ?? ""
        let vowels = "aeiou"
        let vowelCount = domainName.filter { vowels.contains($0.lowercased()) }.count
        let consonantRatio = Double(domainName.count - vowelCount) / max(Double(domainName.count), 1.0)

        // DGA domains typically have high consonant ratio and random appearance
        return consonantRatio > 0.7 && domainName.count > 12
    }
}
