//
//  ComplianceChecker.swift
//  NMAPScanner - Security Compliance Checking (CIS, NIST, PCI-DSS)
//
//  Created by Jordan Koch on 2025-11-27.
//

import Foundation

struct ComplianceCheck: Identifiable, Codable {
    let id = UUID()
    let standard: ComplianceStandard
    let checkID: String
    let name: String
    let passed: Bool
    let severity: Severity
    let finding: String
    let recommendation: String
    let affectedHosts: [String]
    let timestamp: Date

    enum ComplianceStandard: String, Codable {
        case cis = "CIS Benchmarks"
        case nist = "NIST Cybersecurity Framework"
        case pciDSS = "PCI-DSS"
        case hipaa = "HIPAA"
        case custom = "Custom Policy"
    }

    enum Severity: String, Codable {
        case critical, high, medium, low
    }
}

@MainActor
class ComplianceChecker: ObservableObject {
    static let shared = ComplianceChecker()

    @Published var checks: [ComplianceCheck] = []
    @Published var isChecking = false
    @Published var lastCheckDate: Date?

    private init() {}

    func runComplianceChecks(devices: [EnhancedDevice], banners: [ServiceBanner]) async {
        isChecking = true
        checks.removeAll()

        print("📋 ComplianceChecker: Running compliance checks")

        // CIS Benchmarks
        checks.append(contentsOf: await checkCIS(devices: devices, banners: banners))

        // NIST Framework
        checks.append(contentsOf: await checkNIST(devices: devices))

        // PCI-DSS
        checks.append(contentsOf: await checkPCIDSS(devices: devices, banners: banners))

        lastCheckDate = Date()
        isChecking = false

        print("📋 ComplianceChecker: Complete - \(checks.filter { !$0.passed }.count) failures")
    }

    private func checkCIS(devices: [EnhancedDevice], banners: [ServiceBanner]) async -> [ComplianceCheck] {
        var results: [ComplianceCheck] = []

        // CIS 1.1 - No Telnet
        let telnetHosts = devices.filter { $0.openPorts.contains(where: { $0.port == 23 }) }
        results.append(ComplianceCheck(
            standard: .cis,
            checkID: "CIS-1.1",
            name: "Telnet Service Disabled",
            passed: telnetHosts.isEmpty,
            severity: .critical,
            finding: telnetHosts.isEmpty ? "No Telnet services found" : "Telnet enabled on \(telnetHosts.count) hosts",
            recommendation: "Disable Telnet. Use SSH for secure remote access.",
            affectedHosts: telnetHosts.map { $0.ipAddress },
            timestamp: Date()
        ))

        // CIS 1.2 - No FTP
        let ftpHosts = devices.filter { $0.openPorts.contains(where: { $0.port == 21 }) }
        results.append(ComplianceCheck(
            standard: .cis,
            checkID: "CIS-1.2",
            name: "Insecure FTP Disabled",
            passed: ftpHosts.isEmpty,
            severity: .high,
            finding: ftpHosts.isEmpty ? "No FTP services found" : "FTP enabled on \(ftpHosts.count) hosts",
            recommendation: "Use SFTP or FTPS instead of plain FTP.",
            affectedHosts: ftpHosts.map { $0.ipAddress },
            timestamp: Date()
        ))

        // CIS 2.1 - SSH version check
        let oldSSH = banners.filter { $0.service == "SSH" && $0.detectedVersion?.starts(with: "7.") == true }
        results.append(ComplianceCheck(
            standard: .cis,
            checkID: "CIS-2.1",
            name: "SSH Version Current",
            passed: oldSSH.isEmpty,
            severity: .medium,
            finding: oldSSH.isEmpty ? "All SSH versions current" : "Outdated SSH on \(oldSSH.count) hosts",
            recommendation: "Upgrade OpenSSH to version 8.0 or later.",
            affectedHosts: oldSSH.map { $0.host },
            timestamp: Date()
        ))

        return results
    }

    private func checkNIST(devices: [EnhancedDevice]) async -> [ComplianceCheck] {
        var results: [ComplianceCheck] = []

        // NIST AC-3 - Access Control
        let publicServices = devices.filter { !$0.openPorts.isEmpty }
        results.append(ComplianceCheck(
            standard: .nist,
            checkID: "NIST-AC-3",
            name: "Access Control Enforcement",
            passed: publicServices.count < devices.count * 3 / 4,
            severity: .medium,
            finding: "\(publicServices.count) devices with open ports",
            recommendation: "Review and minimize exposed services. Implement principle of least privilege.",
            affectedHosts: [],
            timestamp: Date()
        ))

        return results
    }

    private func checkPCIDSS(devices: [EnhancedDevice], banners: [ServiceBanner]) async -> [ComplianceCheck] {
        var results: [ComplianceCheck] = []

        // PCI-DSS 2.2.3 - Encrypt non-console administrative access
        let adminPorts = devices.filter { device in
            device.openPorts.contains(where: { port in
                [23, 80, 8080].contains(port.port) // Telnet, HTTP
            })
        }
        results.append(ComplianceCheck(
            standard: .pciDSS,
            checkID: "PCI-2.2.3",
            name: "Administrative Access Encrypted",
            passed: adminPorts.isEmpty,
            severity: .critical,
            finding: adminPorts.isEmpty ? "All admin access encrypted" : "Unencrypted admin access on \(adminPorts.count) hosts",
            recommendation: "Use SSH, HTTPS, or VPN for all administrative access.",
            affectedHosts: adminPorts.map { $0.ipAddress },
            timestamp: Date()
        ))

        return results
    }

    var stats: ComplianceStats {
        let total = checks.count
        let passed = checks.filter { $0.passed }.count
        let failed = total - passed
        let critical = checks.filter { !$0.passed && $0.severity == .critical }.count

        return ComplianceStats(
            totalChecks: total,
            passed: passed,
            failed: failed,
            criticalFailures: critical,
            complianceScore: total > 0 ? (passed * 100) / total : 0
        )
    }
}

struct ComplianceStats {
    let totalChecks: Int
    let passed: Int
    let failed: Int
    let criticalFailures: Int
    let complianceScore: Int // 0-100%
}
