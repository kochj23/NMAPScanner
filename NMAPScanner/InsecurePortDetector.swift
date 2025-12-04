//
//  InsecurePortDetector.swift
//  NMAP Scanner - Insecure Port Detection & Flagging
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import SwiftUI

/// Detects and flags insecure/legacy ports
@MainActor
class InsecurePortDetector: ObservableObject {
    static let shared = InsecurePortDetector()

    @Published var insecureFindings: [InsecureFinding] = []

    /// Insecure ports database
    private let insecurePorts: [Int: InsecurePortInfo] = [
        // FTP - Unencrypted file transfer
        20: InsecurePortInfo(
            port: 20,
            service: "FTP Data",
            reason: "Unencrypted file transfer protocol - credentials and data transmitted in cleartext",
            severity: .critical,
            recommendation: "Replace with SFTP (port 22) or FTPS (port 990)",
            cve: ["CVE-2019-12815", "CVE-2015-3306"]
        ),
        21: InsecurePortInfo(
            port: 21,
            service: "FTP Control",
            reason: "Unencrypted authentication and control channel - easily intercepted",
            severity: .critical,
            recommendation: "Replace with SFTP (port 22) or FTPS (port 990)",
            cve: ["CVE-2019-12815", "CVE-2015-3306"]
        ),

        // Telnet - Unencrypted remote access
        23: InsecurePortInfo(
            port: 23,
            service: "Telnet",
            reason: "Completely unencrypted remote access - passwords visible in plaintext",
            severity: .critical,
            recommendation: "Replace with SSH (port 22) immediately",
            cve: ["CVE-2020-10188"]
        ),

        // TFTP - Trivial FTP
        69: InsecurePortInfo(
            port: 69,
            service: "TFTP",
            reason: "No authentication, no encryption - anyone can read/write files",
            severity: .critical,
            recommendation: "Disable TFTP or restrict to trusted networks only",
            cve: []
        ),

        // Finger - Information disclosure
        79: InsecurePortInfo(
            port: 79,
            service: "Finger",
            reason: "Discloses user information - used for reconnaissance attacks",
            severity: .high,
            recommendation: "Disable Finger service - it's obsolete",
            cve: []
        ),

        // HTTP - Unencrypted web
        80: InsecurePortInfo(
            port: 80,
            service: "HTTP",
            reason: "Unencrypted web traffic - credentials and data visible",
            severity: .medium,
            recommendation: "Use HTTPS (port 443) with TLS 1.3+",
            cve: []
        ),

        // POP3 - Unencrypted email
        110: InsecurePortInfo(
            port: 110,
            service: "POP3",
            reason: "Unencrypted email retrieval - passwords transmitted in cleartext",
            severity: .high,
            recommendation: "Use POP3S (port 995) or IMAP over SSL (port 993)",
            cve: []
        ),

        // NNTP - Unencrypted news
        119: InsecurePortInfo(
            port: 119,
            service: "NNTP",
            reason: "Unencrypted network news transfer",
            severity: .medium,
            recommendation: "Use NNTPS (port 563) if still needed",
            cve: []
        ),

        // NetBIOS
        137: InsecurePortInfo(
            port: 137,
            service: "NetBIOS Name Service",
            reason: "Legacy Windows protocol - vulnerable to spoofing and amplification attacks",
            severity: .high,
            recommendation: "Disable NetBIOS over TCP/IP in network settings",
            cve: ["CVE-2017-0144", "CVE-2017-0145"]
        ),
        138: InsecurePortInfo(
            port: 138,
            service: "NetBIOS Datagram",
            reason: "Legacy Windows protocol - information disclosure",
            severity: .high,
            recommendation: "Disable NetBIOS over TCP/IP in network settings",
            cve: []
        ),
        139: InsecurePortInfo(
            port: 139,
            service: "NetBIOS Session / SMBv1",
            reason: "Legacy SMBv1 protocol - vulnerable to ransomware (WannaCry, NotPetya)",
            severity: .critical,
            recommendation: "Disable SMBv1, use SMBv3 (port 445) with encryption",
            cve: ["CVE-2017-0144", "CVE-2017-0145", "CVE-2017-0146"]
        ),

        // IMAP - Unencrypted email
        143: InsecurePortInfo(
            port: 143,
            service: "IMAP",
            reason: "Unencrypted email access - credentials visible",
            severity: .high,
            recommendation: "Use IMAPS (port 993)",
            cve: []
        ),

        // SNMP v1/v2c
        161: InsecurePortInfo(
            port: 161,
            service: "SNMP",
            reason: "SNMPv1/v2c use community strings (cleartext passwords)",
            severity: .high,
            recommendation: "Upgrade to SNMPv3 with authentication and encryption",
            cve: []
        ),

        // LDAP - Unencrypted directory
        389: InsecurePortInfo(
            port: 389,
            service: "LDAP",
            reason: "Unencrypted directory access - credentials transmitted in cleartext",
            severity: .high,
            recommendation: "Use LDAPS (port 636) or LDAP with STARTTLS",
            cve: []
        ),

        // SMB (without encryption)
        445: InsecurePortInfo(
            port: 445,
            service: "SMB/CIFS",
            reason: "If using SMBv1 or unencrypted SMBv2/v3 - vulnerable to attacks",
            severity: .high,
            recommendation: "Disable SMBv1, enable SMB encryption, use SMBv3+",
            cve: ["CVE-2017-0144", "CVE-2020-0796"]
        ),

        // rexec
        512: InsecurePortInfo(
            port: 512,
            service: "rexec",
            reason: "Unencrypted remote execution - trivial to intercept",
            severity: .critical,
            recommendation: "Replace with SSH",
            cve: []
        ),

        // rlogin
        513: InsecurePortInfo(
            port: 513,
            service: "rlogin",
            reason: "Unencrypted remote login - no modern security",
            severity: .critical,
            recommendation: "Replace with SSH",
            cve: []
        ),

        // rsh
        514: InsecurePortInfo(
            port: 514,
            service: "rsh",
            reason: "Unencrypted remote shell - host-based authentication only",
            severity: .critical,
            recommendation: "Replace with SSH",
            cve: []
        ),

        // LPD
        515: InsecurePortInfo(
            port: 515,
            service: "LPD",
            reason: "Line Printer Daemon - unencrypted, no authentication",
            severity: .medium,
            recommendation: "Use IPP over HTTPS (port 631) or disable",
            cve: []
        ),

        // VNC (unencrypted)
        5900: InsecurePortInfo(
            port: 5900,
            service: "VNC",
            reason: "Often configured without encryption or with weak passwords",
            severity: .high,
            recommendation: "Use VNC over SSH tunnel or with strong encryption",
            cve: ["CVE-2019-8258", "CVE-2020-14396"]
        ),

        // X11
        6000: InsecurePortInfo(
            port: 6000,
            service: "X11",
            reason: "X Window System - unencrypted, allows keylogging",
            severity: .high,
            recommendation: "Use X11 forwarding over SSH, never expose directly",
            cve: []
        ),

        // MySQL (default)
        3306: InsecurePortInfo(
            port: 3306,
            service: "MySQL",
            reason: "Database exposed to network - should only be accessible locally",
            severity: .high,
            recommendation: "Bind to localhost or use SSH tunnel, enable SSL/TLS",
            cve: ["CVE-2021-2146", "CVE-2021-2471"]
        ),

        // PostgreSQL (default)
        5432: InsecurePortInfo(
            port: 5432,
            service: "PostgreSQL",
            reason: "Database exposed to network - authentication bypass risks",
            severity: .high,
            recommendation: "Bind to localhost or use SSL/TLS, configure pg_hba.conf properly",
            cve: ["CVE-2021-32027", "CVE-2021-32028"]
        ),

        // MongoDB (default)
        27017: InsecurePortInfo(
            port: 27017,
            service: "MongoDB",
            reason: "Database exposed - often misconfigured without authentication",
            severity: .high,
            recommendation: "Enable authentication, bind to localhost, use TLS",
            cve: ["CVE-2021-20329"]
        ),

        // Redis (default)
        6379: InsecurePortInfo(
            port: 6379,
            service: "Redis",
            reason: "No authentication by default - full database access",
            severity: .critical,
            recommendation: "Enable authentication, bind to localhost, use TLS",
            cve: ["CVE-2021-32625", "CVE-2021-32627"]
        ),

        // Memcached
        11211: InsecurePortInfo(
            port: 11211,
            service: "Memcached",
            reason: "No authentication - used in DDoS amplification attacks",
            severity: .high,
            recommendation: "Bind to localhost only, use firewall rules",
            cve: ["CVE-2018-1000115"]
        ),

        // Elasticsearch
        9200: InsecurePortInfo(
            port: 9200,
            service: "Elasticsearch",
            reason: "HTTP API often exposed without authentication",
            severity: .high,
            recommendation: "Enable security features, use TLS, require authentication",
            cve: ["CVE-2015-1427", "CVE-2014-3120"]
        )
    ]

    private init() {}

    /// Scan device for insecure ports
    func scanDevice(_ device: EnhancedDevice) {
        for port in device.openPorts {
            if let insecureInfo = insecurePorts[port.port] {
                let finding = InsecureFinding(
                    id: UUID(),
                    ipAddress: device.ipAddress,
                    hostname: device.hostname,
                    port: port.port,
                    service: insecureInfo.service,
                    reason: insecureInfo.reason,
                    severity: insecureInfo.severity,
                    recommendation: insecureInfo.recommendation,
                    cve: insecureInfo.cve,
                    detectedAt: Date()
                )

                // Avoid duplicates
                if !insecureFindings.contains(where: {
                    $0.ipAddress == finding.ipAddress && $0.port == finding.port
                }) {
                    insecureFindings.append(finding)
                }
            }
        }
    }

    /// Scan all devices
    func scanAllDevices(_ devices: [EnhancedDevice]) {
        insecureFindings.removeAll()

        for device in devices {
            scanDevice(device)
        }

        // Send notification if critical findings
        let criticalCount = insecureFindings.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            NotificationManager.shared.showNotification(
                .criticalThreat,
                title: "Critical Insecure Ports Detected",
                message: "Found \(criticalCount) critical insecure ports (FTP, Telnet, SMBv1, etc.)",
                severity: .critical
            )
        }
    }

    /// Get findings for specific device
    func getFindings(for ipAddress: String) -> [InsecureFinding] {
        return insecureFindings.filter { $0.ipAddress == ipAddress }
    }

    /// Get statistics
    var stats: InsecureStats {
        let critical = insecureFindings.filter { $0.severity == .critical }.count
        let high = insecureFindings.filter { $0.severity == .high }.count
        let medium = insecureFindings.filter { $0.severity == .medium }.count

        return InsecureStats(total: insecureFindings.count, critical: critical, high: high, medium: medium)
    }
}

// MARK: - Data Models

struct InsecurePortInfo {
    let port: Int
    let service: String
    let reason: String
    let severity: InsecureSeverity
    let recommendation: String
    let cve: [String]
}

struct InsecureFinding: Identifiable, Codable {
    let id: UUID
    let ipAddress: String
    let hostname: String?
    let port: Int
    let service: String
    let reason: String
    let severity: InsecureSeverity
    let recommendation: String
    let cve: [String]
    let detectedAt: Date
}

enum InsecureSeverity: String, Codable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"

    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        }
    }

    var score: Int {
        switch self {
        case .critical: return 3
        case .high: return 2
        case .medium: return 1
        }
    }
}

struct InsecureStats {
    let total: Int
    let critical: Int
    let high: Int
    let medium: Int
}
