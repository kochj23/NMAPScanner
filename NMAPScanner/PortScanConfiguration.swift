//
//  PortScanConfiguration.swift
//  NMAPScanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-29.
//  Port scanning configuration and presets
//

import Foundation
import SwiftUI

/// Port scanning modes with different coverage levels
enum PortScanMode: String, CaseIterable, Codable {
    case standard = "Standard Ports"
    case current = "Common Ports"
    case comprehensive = "All Ports"

    /// Description of what this mode scans
    var description: String {
        switch self {
        case .standard:
            return "Scans ports 1-1024 (well-known ports)"
        case .current:
            return "Scans most common ports (~100 ports)"
        case .comprehensive:
            return "Scans all ports 1-65536 (complete scan)"
        }
    }

    /// Icon for this scan mode
    var icon: String {
        switch self {
        case .standard:
            return "bolt.fill"
        case .current:
            return "bolt.horizontal.fill"
        case .comprehensive:
            return "bolt.circle.fill"
        }
    }

    /// Color for this scan mode
    var color: Color {
        switch self {
        case .standard:
            return .green
        case .current:
            return .blue
        case .comprehensive:
            return .orange
        }
    }

    /// Estimated scan time per host
    var estimatedTimePerHost: String {
        switch self {
        case .standard:
            return "~10-30 seconds"
        case .current:
            return "~2-5 seconds"
        case .comprehensive:
            return "~10-30 minutes"
        }
    }

    /// Get the port array for this scan mode
    func getPorts() -> [Int] {
        switch self {
        case .standard:
            return PortScanConfiguration.standardPorts
        case .current:
            return CommonPorts.standard
        case .comprehensive:
            return PortScanConfiguration.allPorts
        }
    }

    /// Port count
    var portCount: Int {
        switch self {
        case .standard:
            return 1024
        case .current:
            return CommonPorts.standard.count
        case .comprehensive:
            return 65536
        }
    }
}

/// Port scanning configuration manager
class PortScanConfiguration {

    /// Standard ports (1-1024) - Well-known ports
    static let standardPorts: [Int] = Array(1...1024)

    /// All possible ports (1-65536) - Complete scan
    static let allPorts: [Int] = Array(1...65535)

    /// Get port name/service for a given port number
    static func serviceName(for port: Int) -> String {
        // Extended service name mapping
        let services: [Int: String] = [
            // Standard ports (1-1024)
            1: "TCPMUX",
            7: "Echo",
            9: "Discard",
            13: "Daytime",
            17: "QOTD",
            19: "CharGen",
            20: "FTP Data",
            21: "FTP Control",
            22: "SSH",
            23: "Telnet",
            25: "SMTP",
            37: "Time",
            42: "WINS",
            43: "WHOIS",
            49: "TACACS",
            53: "DNS",
            67: "DHCP Server",
            68: "DHCP Client",
            69: "TFTP",
            70: "Gopher",
            79: "Finger",
            80: "HTTP",
            81: "HTTP Alt",
            88: "Kerberos",
            102: "MS Exchange",
            110: "POP3",
            111: "RPC",
            113: "Ident",
            119: "NNTP",
            123: "NTP",
            135: "MS RPC",
            137: "NetBIOS Name",
            138: "NetBIOS Datagram",
            139: "NetBIOS Session",
            143: "IMAP",
            161: "SNMP",
            162: "SNMP Trap",
            179: "BGP",
            194: "IRC",
            201: "AppleTalk",
            389: "LDAP",
            443: "HTTPS",
            445: "SMB",
            464: "Kerberos",
            465: "SMTPS",
            514: "Syslog",
            515: "LPD",
            520: "RIP",
            521: "RIPng",
            540: "UUCP",
            543: "Klogin",
            544: "Kshell",
            548: "AFP",
            554: "RTSP",
            587: "SMTP Submission",
            631: "IPP",
            636: "LDAPS",
            646: "LDP",
            873: "rsync",
            989: "FTPS Data",
            990: "FTPS Control",
            992: "Telnet SSL",
            993: "IMAPS",
            995: "POP3S",
            1080: "SOCKS Proxy",
            // Common higher ports
            1433: "MS SQL",
            1434: "MS SQL Monitor",
            1521: "Oracle",
            1723: "PPTP",
            3306: "MySQL",
            3389: "RDP",
            5000: "UPnP",
            5060: "SIP",
            5432: "PostgreSQL",
            5900: "VNC",
            5938: "TeamViewer",
            6379: "Redis",
            8080: "HTTP Proxy",
            8443: "HTTPS Alt",
            8888: "HTTP Alt",
            9000: "HTTP Alt",
            9090: "WebSM",
            27017: "MongoDB",
            // HomeKit/Apple
            7000: "AirPlay",
            49152: "HomeKit",
            32498: "HomeKit Alt",
            62078: "AirPlay"
        ]

        return services[port] ?? "Port \(port)"
    }

    /// Get port risk level
    static func riskLevel(for port: Int) -> PortRiskLevel {
        let highRiskPorts = [21, 23, 25, 53, 80, 110, 143, 443, 445, 3389, 5900]
        let mediumRiskPorts = [22, 135, 139, 161, 389, 636, 1433, 3306, 5432, 8080]

        if highRiskPorts.contains(port) {
            return .high
        } else if mediumRiskPorts.contains(port) {
            return .medium
        } else if port < 1024 {
            return .low
        } else {
            return .minimal
        }
    }
}

/// Port risk level
enum PortRiskLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case minimal = "Minimal"

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        case .minimal: return .green
        }
    }
}

/// User defaults key for storing scan mode preference
extension UserDefaults {
    private static let scanModeKey = "selectedPortScanMode"

    var selectedPortScanMode: PortScanMode {
        get {
            if let rawValue = string(forKey: UserDefaults.scanModeKey),
               let mode = PortScanMode(rawValue: rawValue) {
                return mode
            }
            return .current // Default to current mode
        }
        set {
            set(newValue.rawValue, forKey: UserDefaults.scanModeKey)
        }
    }
}
