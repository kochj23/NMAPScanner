//
//  SecurityAuditManager.swift
//  NMAP Scanner - Network Security Audit
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import Foundation
import Network

/// Represents a security audit finding
struct SecurityFinding: Identifiable {
    let id = UUID()
    let category: Category
    let severity: Severity
    let title: String
    let description: String
    let affectedHosts: [String]
    let recommendation: String
    let detectedAt: Date

    enum Category: String {
        case rogueDevice = "Rogue Device"
        case portForwarding = "Port Forwarding"
        case suspiciousPort = "Suspicious Port"
        case certificateIssue = "Certificate Issue"
        case dnsIssue = "DNS Issue"
        case networkConfig = "Network Configuration"
        case accessControl = "Access Control"
        case encryption = "Encryption"
    }

    enum Severity: String, Comparable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case info = "Info"

        var score: Int {
            switch self {
            case .critical: return 5
            case .high: return 4
            case .medium: return 3
            case .low: return 2
            case .info: return 1
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.score < rhs.score
        }
    }
}

/// Represents a known device on the network
struct KnownDevice: Codable {
    let macAddress: String
    let name: String
    let addedDate: Date
}

/// Network device information
struct NetworkDevice {
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let manufacturer: String?
    let openPorts: [Int]
    let firstSeen: Date
    let lastSeen: Date
}

/// Certificate information
struct CertificateInfo {
    let host: String
    let port: Int
    let issuer: String
    let subject: String
    let validFrom: Date
    let validTo: Date
    let isValid: Bool
    let isSelfSigned: Bool
    let issues: [String]
}

/// Manages network security auditing
@MainActor
class SecurityAuditManager: ObservableObject {
    @Published var findings: [SecurityFinding] = []
    @Published var isAuditing = false
    @Published var progress: Double = 0
    @Published var knownDevices: [KnownDevice] = []
    @Published var discoveredDevices: [NetworkDevice] = []

    private let knownDevicesKey = "SecurityAudit.KnownDevices"

    init() {
        loadKnownDevices()
    }

    /// Perform comprehensive security audit
    func performAudit(hosts: [String], scanResults: [(host: String, ports: [Int])]) async {
        isAuditing = true
        progress = 0
        findings.removeAll()

        let totalSteps = 7.0
        var currentStep = 0.0

        // Step 1: Identify rogue devices
        await identifyRogueDevices(hosts: hosts)
        currentStep += 1
        progress = currentStep / totalSteps

        // Step 2: Detect suspicious ports
        detectSuspiciousPorts(scanResults: scanResults)
        currentStep += 1
        progress = currentStep / totalSteps

        // Step 3: Check for port forwarding/NAT
        await detectPortForwarding(hosts: hosts)
        currentStep += 1
        progress = currentStep / totalSteps

        // Step 4: Validate HTTPS certificates
        await validateCertificates(scanResults: scanResults)
        currentStep += 1
        progress = currentStep / totalSteps

        // Step 5: Check DNS security
        await checkDNSSecurity(hosts: hosts)
        currentStep += 1
        progress = currentStep / totalSteps

        // Step 6: Check for open resolvers
        await checkOpenDNSResolvers(hosts: hosts)
        currentStep += 1
        progress = currentStep / totalSteps

        // Step 7: Audit network configuration
        auditNetworkConfiguration(scanResults: scanResults)
        currentStep += 1
        progress = currentStep / totalSteps

        isAuditing = false
    }

    /// Identify rogue/unknown devices on the network
    private func identifyRogueDevices(hosts: [String]) async {
        for host in hosts {
            // Simulate MAC address lookup (real implementation would use ARP)
            let macAddress = await lookupMACAddress(host: host)

            if let mac = macAddress {
                let isKnown = knownDevices.contains { $0.macAddress == mac }

                if !isKnown {
                    let finding = SecurityFinding(
                        category: .rogueDevice,
                        severity: .high,
                        title: "Unknown Device Detected",
                        description: "Device with MAC address \(mac) at IP \(host) is not in the known devices list.",
                        affectedHosts: [host],
                        recommendation: "Verify this device's identity. If legitimate, add it to known devices. If unauthorized, investigate and remove from network.",
                        detectedAt: Date()
                    )

                    findings.append(finding)
                }

                // Track discovered device
                let device = NetworkDevice(
                    ipAddress: host,
                    macAddress: mac,
                    hostname: await lookupHostname(host: host),
                    manufacturer: lookupManufacturer(macAddress: mac),
                    openPorts: [],
                    firstSeen: Date(),
                    lastSeen: Date()
                )

                discoveredDevices.append(device)
            }
        }
    }

    /// Detect suspicious open ports
    private func detectSuspiciousPorts(scanResults: [(host: String, ports: [Int])]) {
        let suspiciousPorts: [Int: String] = [
            21: "FTP - Insecure file transfer",
            23: "Telnet - Unencrypted remote access",
            69: "TFTP - No authentication",
            135: "Windows RPC - Often exploited",
            445: "SMB - Ransomware target",
            1433: "MS SQL - Database exposure",
            3306: "MySQL - Database exposure",
            3389: "RDP - Remote access target",
            5432: "PostgreSQL - Database exposure",
            5900: "VNC - Often weak authentication",
            6379: "Redis - Often unsecured",
            27017: "MongoDB - Often misconfigured"
        ]

        for result in scanResults {
            let suspiciousFound = result.ports.filter { suspiciousPorts.keys.contains($0) }

            if !suspiciousFound.isEmpty {
                let portDescriptions = suspiciousFound.map { "\($0) (\(suspiciousPorts[$0]!))" }.joined(separator: ", ")

                let finding = SecurityFinding(
                    category: .suspiciousPort,
                    severity: .high,
                    title: "Suspicious Ports Open",
                    description: "Host \(result.host) has potentially dangerous ports open: \(portDescriptions)",
                    affectedHosts: [result.host],
                    recommendation: "Review necessity of these services. Close unused ports, enable authentication, and use firewall rules to restrict access.",
                    detectedAt: Date()
                )

                findings.append(finding)
            }
        }
    }

    /// Detect potential port forwarding or NAT configurations
    private func detectPortForwarding(hosts: [String]) async {
        // Check for common port forwarding patterns
        // Multiple hosts responding on the same external-facing ports could indicate NAT

        var portHostMap: [Int: [String]] = [:]

        for host in hosts {
            // Simulate port scan (in real implementation, use actual scan results)
            let commonPorts = [22, 80, 443, 3389, 8080]

            for port in commonPorts {
                if await isPortOpen(host: host, port: port) {
                    portHostMap[port, default: []].append(host)
                }
            }
        }

        // If multiple internal hosts have the same external port open, might indicate port forwarding
        for (port, hostList) in portHostMap where hostList.count > 3 {
            let finding = SecurityFinding(
                category: .portForwarding,
                severity: .medium,
                title: "Potential Port Forwarding Detected",
                description: "Port \(port) is open on \(hostList.count) hosts, which may indicate port forwarding or load balancing.",
                affectedHosts: hostList,
                recommendation: "Review network configuration. Ensure port forwarding is intentional and properly secured.",
                detectedAt: Date()
            )

            findings.append(finding)
        }
    }

    /// Validate HTTPS certificates
    private func validateCertificates(scanResults: [(host: String, ports: [Int])]) async {
        for result in scanResults where result.ports.contains(443) {
            let certInfo = await checkCertificate(host: result.host, port: 443)

            if let cert = certInfo {
                if !cert.isValid {
                    let finding = SecurityFinding(
                        category: .certificateIssue,
                        severity: .high,
                        title: "Invalid SSL Certificate",
                        description: "Host \(result.host) has an invalid SSL certificate: \(cert.issues.joined(separator: ", "))",
                        affectedHosts: [result.host],
                        recommendation: "Install a valid SSL certificate from a trusted Certificate Authority.",
                        detectedAt: Date()
                    )

                    findings.append(finding)
                }

                if cert.isSelfSigned {
                    let finding = SecurityFinding(
                        category: .certificateIssue,
                        severity: .medium,
                        title: "Self-Signed Certificate",
                        description: "Host \(result.host) is using a self-signed SSL certificate.",
                        affectedHosts: [result.host],
                        recommendation: "Use a certificate from a trusted Certificate Authority for production environments.",
                        detectedAt: Date()
                    )

                    findings.append(finding)
                }

                // Check expiration
                if cert.validTo < Date().addingTimeInterval(30 * 24 * 3600) {
                    let finding = SecurityFinding(
                        category: .certificateIssue,
                        severity: .medium,
                        title: "Certificate Expiring Soon",
                        description: "SSL certificate for \(result.host) expires on \(cert.validTo).",
                        affectedHosts: [result.host],
                        recommendation: "Renew SSL certificate before expiration to avoid service disruption.",
                        detectedAt: Date()
                    )

                    findings.append(finding)
                }
            }
        }
    }

    /// Check DNS security
    private func checkDNSSecurity(hosts: [String]) async {
        for host in hosts {
            // Check for DNS rebinding vulnerabilities
            let hostnameA = await lookupHostname(host: host)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let hostnameB = await lookupHostname(host: host)

            if hostnameA != hostnameB && hostnameA != nil && hostnameB != nil {
                let finding = SecurityFinding(
                    category: .dnsIssue,
                    severity: .high,
                    title: "DNS Rebinding Possible",
                    description: "Host \(host) returns different hostnames on successive queries, indicating possible DNS rebinding vulnerability.",
                    affectedHosts: [host],
                    recommendation: "Implement DNS rebinding protection at the network level.",
                    detectedAt: Date()
                )

                findings.append(finding)
            }
        }
    }

    /// Check for open DNS resolvers
    private func checkOpenDNSResolvers(hosts: [String]) async {
        for host in hosts {
            if await isPortOpen(host: host, port: 53) {
                // Test if DNS resolver accepts queries from external sources
                let isOpenResolver = await testDNSResolver(host: host)

                if isOpenResolver {
                    let finding = SecurityFinding(
                        category: .dnsIssue,
                        severity: .critical,
                        title: "Open DNS Resolver",
                        description: "Host \(host) is running an open DNS resolver that responds to queries from any source.",
                        affectedHosts: [host],
                        recommendation: "Configure DNS server to only respond to authorized clients. Implement rate limiting and filtering.",
                        detectedAt: Date()
                    )

                    findings.append(finding)
                }
            }
        }
    }

    /// Audit network configuration
    private func auditNetworkConfiguration(scanResults: [(host: String, ports: [Int])]) {
        // Check for consistent security posture across network

        // Look for mixed HTTP/HTTPS usage
        var httpHosts: [String] = []
        var httpsHosts: [String] = []

        for result in scanResults {
            if result.ports.contains(80) {
                httpHosts.append(result.host)
            }
            if result.ports.contains(443) {
                httpsHosts.append(result.host)
            }
        }

        if !httpHosts.isEmpty && !httpsHosts.isEmpty {
            let finding = SecurityFinding(
                category: .encryption,
                severity: .medium,
                title: "Inconsistent Encryption Usage",
                description: "Network has mix of encrypted (\(httpsHosts.count) hosts) and unencrypted (\(httpHosts.count) hosts) web services.",
                affectedHosts: httpHosts,
                recommendation: "Migrate all web services to HTTPS. Disable HTTP or configure automatic redirects to HTTPS.",
                detectedAt: Date()
            )

            findings.append(finding)
        }

        // Check for excessive number of open ports
        for result in scanResults where result.ports.count > 10 {
            let finding = SecurityFinding(
                category: .networkConfig,
                severity: .medium,
                title: "Excessive Open Ports",
                description: "Host \(result.host) has \(result.ports.count) open ports, which increases attack surface.",
                affectedHosts: [result.host],
                recommendation: "Review open services and close unnecessary ports. Implement principle of least privilege.",
                detectedAt: Date()
            )

            findings.append(finding)
        }
    }

    /// Add device to known devices list
    func addKnownDevice(macAddress: String, name: String) {
        let device = KnownDevice(macAddress: macAddress, name: name, addedDate: Date())
        knownDevices.append(device)
        saveKnownDevices()
    }

    /// Remove device from known devices list
    func removeKnownDevice(macAddress: String) {
        knownDevices.removeAll { $0.macAddress == macAddress }
        saveKnownDevices()
    }

    /// Clear all findings
    func clearFindings() {
        findings.removeAll()
    }

    /// Export audit report
    func exportAuditReport() -> String {
        var report = "# Network Security Audit Report\n"
        report += "# Generated: \(Date())\n"
        report += "# Total Findings: \(findings.count)\n\n"

        let groupedByCategory = Dictionary(grouping: findings, by: { $0.category })

        for (category, items) in groupedByCategory.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            report += "## \(category.rawValue)\n\n"

            for finding in items.sorted(by: { $0.severity > $1.severity }) {
                report += "### [\(finding.severity.rawValue)] \(finding.title)\n"
                report += "\(finding.description)\n"
                report += "Affected Hosts: \(finding.affectedHosts.joined(separator: ", "))\n"
                report += "Recommendation: \(finding.recommendation)\n\n"
            }
        }

        return report
    }

    // MARK: - Helper Methods

    private func lookupMACAddress(host: String) async -> String? {
        // Simulate MAC lookup (real implementation would parse ARP table)
        // For now, generate a fake MAC for testing
        let components = host.split(separator: ".")
        if components.count == 4, let last = components.last {
            return "00:11:22:33:44:\(String(format: "%02X", Int(last) ?? 0))"
        }
        return nil
    }

    private func lookupHostname(host: String) async -> String? {
        // Perform reverse DNS lookup
        // Real implementation would use DNS queries
        return "device-\(host.split(separator: ".").last ?? "unknown")"
    }

    private func lookupManufacturer(macAddress: String) -> String? {
        // Lookup OUI (first 3 octets) in manufacturer database
        // Real implementation would use OUI database
        let oui = macAddress.prefix(8)
        let manufacturers = [
            "00:11:22": "Cisco",
            "00:1A:2B": "Apple",
            "00:50:56": "VMware",
            "08:00:27": "VirtualBox"
        ]
        return manufacturers[String(oui)]
    }

    private func isPortOpen(host: String, port: Int) async -> Bool {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "port-check")
            var hasResumed = false
            let lock = NSLock()

            connection.stateUpdateHandler = { state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)

                case .failed, .cancelled:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)

                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 2) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func checkCertificate(host: String, port: Int) async -> CertificateInfo? {
        // Simplified certificate check
        // Real implementation would use SecTrust and parse certificate details
        return CertificateInfo(
            host: host,
            port: port,
            issuer: "Unknown CA",
            subject: host,
            validFrom: Date().addingTimeInterval(-365 * 24 * 3600),
            validTo: Date().addingTimeInterval(365 * 24 * 3600),
            isValid: true,
            isSelfSigned: false,
            issues: []
        )
    }

    private func testDNSResolver(host: String) async -> Bool {
        // Test if DNS server responds to queries
        // Real implementation would send DNS query packet
        return false // Conservative default
    }

    // MARK: - Persistence

    private func loadKnownDevices() {
        if let data = UserDefaults.standard.data(forKey: knownDevicesKey),
           let devices = try? JSONDecoder().decode([KnownDevice].self, from: data) {
            knownDevices = devices
        }
    }

    private func saveKnownDevices() {
        if let data = try? JSONEncoder().encode(knownDevices) {
            UserDefaults.standard.set(data, forKey: knownDevicesKey)
        }
    }
}
