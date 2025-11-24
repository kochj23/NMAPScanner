//
//  ThreatModel.swift
//  NMAP Scanner - Comprehensive Threat Analysis Model
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import Foundation

// MARK: - Threat Severity

enum ThreatSeverity: String, Comparable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case info = "Info"

    static func < (lhs: ThreatSeverity, rhs: ThreatSeverity) -> Bool {
        let order: [ThreatSeverity] = [.critical, .high, .medium, .low, .info]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .info: return 4
        }
    }
}

// MARK: - Threat Category

enum ThreatCategory: String, CaseIterable {
    case backdoor = "Backdoor/Remote Access"
    case exposedService = "Exposed Service"
    case weakSecurity = "Weak Security"
    case misconfiguration = "Misconfiguration"
    case rogueDevice = "Rogue Device"
    case suspiciousActivity = "Suspicious Activity"
    case dataExposure = "Data Exposure"
    case denial = "Denial of Service Risk"
}

// MARK: - Threat Finding

struct ThreatFinding: Identifiable, Hashable {
    let id = UUID()
    let severity: ThreatSeverity
    let category: ThreatCategory
    let title: String
    let description: String
    let affectedHost: String
    let affectedPort: Int?
    let detectedAt: Date
    let cvssScore: Double? // Common Vulnerability Scoring System
    let cveReferences: [String] // CVE identifiers
    let remediation: String
    let technicalDetails: String
    let impactAssessment: String

    // For rogue device detection
    var isRogueDevice: Bool {
        category == .rogueDevice
    }

    // For backdoor detection
    var isBackdoor: Bool {
        category == .backdoor
    }
}

// MARK: - Device Threat Summary

struct DeviceThreatSummary: Identifiable {
    let id = UUID()
    let device: EnhancedDevice
    let criticalThreats: [ThreatFinding]
    let highThreats: [ThreatFinding]
    let mediumThreats: [ThreatFinding]
    let lowThreats: [ThreatFinding]
    let infoItems: [ThreatFinding]

    var totalThreats: Int {
        criticalThreats.count + highThreats.count + mediumThreats.count + lowThreats.count
    }

    var hasThreats: Bool {
        totalThreats > 0
    }

    var overallSeverity: ThreatSeverity {
        if !criticalThreats.isEmpty { return .critical }
        if !highThreats.isEmpty { return .high }
        if !mediumThreats.isEmpty { return .medium }
        if !lowThreats.isEmpty { return .low }
        return .info
    }

    var allThreats: [ThreatFinding] {
        criticalThreats + highThreats + mediumThreats + lowThreats + infoItems
    }
}

// MARK: - Network Threat Summary

struct NetworkThreatSummary: Identifiable {
    let id = UUID()
    let scanDate: Date
    let totalDevices: Int
    let threatenedDevices: Int
    let criticalThreats: [ThreatFinding]
    let highThreats: [ThreatFinding]
    let mediumThreats: [ThreatFinding]
    let lowThreats: [ThreatFinding]
    let rogueDevices: [EnhancedDevice]
    let backdoorDevices: [EnhancedDevice]
    let exposedServices: [ThreatFinding]

    var totalThreats: Int {
        criticalThreats.count + highThreats.count + mediumThreats.count + lowThreats.count
    }

    var overallRiskScore: Int {
        let criticalWeight = criticalThreats.count * 10
        let highWeight = highThreats.count * 5
        let mediumWeight = mediumThreats.count * 2
        let lowWeight = lowThreats.count * 1

        let totalRisk = criticalWeight + highWeight + mediumWeight + lowWeight
        let maxRisk = totalDevices * 50 // Assume max 5 critical issues per device

        return max(0, 100 - Int((Double(totalRisk) / Double(max(maxRisk, 1))) * 100))
    }

    var riskLevel: String {
        switch overallRiskScore {
        case 90...100: return "Low Risk"
        case 70..<90: return "Moderate Risk"
        case 40..<70: return "High Risk"
        default: return "Critical Risk"
        }
    }
}

// MARK: - Enhanced Device

struct EnhancedDevice: Identifiable, Hashable {
    let id = UUID()
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let manufacturer: String?
    let deviceType: DeviceType
    let openPorts: [PortInfo]
    let isOnline: Bool
    let firstSeen: Date
    let lastSeen: Date
    let isKnownDevice: Bool // For rogue device detection
    let operatingSystem: String?
    let deviceName: String? // User-friendly name

    enum DeviceType: String {
        case router = "Router"
        case server = "Server"
        case computer = "Computer"
        case mobile = "Mobile Device"
        case iot = "IoT Device"
        case printer = "Printer"
        case unknown = "Unknown"
    }

    // Display name
    var displayName: String {
        if let name = deviceName {
            return name
        }
        if let hostname = hostname {
            return hostname
        }
        return ipAddress
    }

    // Rogue device indicator with configurable time window
    func isRogue(timeWindowSeconds: TimeInterval) -> Bool {
        !isKnownDevice && firstSeen.timeIntervalSinceNow > -timeWindowSeconds
    }

    // Legacy support - uses default 1 hour
    var isRogue: Bool {
        isRogue(timeWindowSeconds: 3600)
    }
}

// MARK: - Port Information

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let service: String
    let version: String?
    let state: PortState
    let protocolType: String // TCP, UDP
    let banner: String? // Service banner

    enum PortState: String {
        case open = "Open"
        case filtered = "Filtered"
        case closed = "Closed"
    }

    // Well-known suspicious/backdoor ports
    static let backdoorPorts: Set<Int> = [
        31337, // Back Orifice
        12345, 12346, // NetBus
        1243, // SubSeven
        6667, 6668, 6669, // IRC (often used for botnets)
        27374, // SubSeven
        2001, // Trojan.Latinus
        1999, // BackDoor
        30100, 30101, 30102, // NetSphere
        5000, 5001, 5002, // Back Door Setup, Sockets de Troie
    ]

    // Remote access ports (can be legitimate or backdoors)
    static let remoteAccessPorts: Set<Int> = [
        22, // SSH
        23, // Telnet
        3389, // RDP
        5900, 5901, 5902, // VNC
        5800, 5801, 5802, // VNC HTTP
    ]

    // Exposed database ports
    static let databasePorts: Set<Int> = [
        3306, // MySQL
        5432, // PostgreSQL
        1433, 1434, // MSSQL
        27017, 27018, 27019, // MongoDB
        6379, // Redis
        9042, // Cassandra
        7000, 7001, // Cassandra
        8086, // InfluxDB
    ]

    var isBackdoorPort: Bool {
        PortInfo.backdoorPorts.contains(port)
    }

    var isRemoteAccessPort: Bool {
        PortInfo.remoteAccessPorts.contains(port)
    }

    var isDatabasePort: Bool {
        PortInfo.databasePorts.contains(port)
    }

    var isSuspicious: Bool {
        isBackdoorPort || (isRemoteAccessPort && !isCommonService) || (isDatabasePort && port != 3306 && port != 5432)
    }

    var isCommonService: Bool {
        // SSH on standard port is common, telnet is not
        (port == 22) || (port == 3389 && service.contains("RDP"))
    }
}

// MARK: - Threat Analyzer

@MainActor
class ThreatAnalyzer: ObservableObject {
    @Published var networkSummary: NetworkThreatSummary?
    @Published var deviceSummaries: [DeviceThreatSummary] = []
    @Published var allThreats: [ThreatFinding] = []

    func analyzeNetwork(devices: [EnhancedDevice]) {
        var allFindings: [ThreatFinding] = []
        var deviceSummaries: [DeviceThreatSummary] = []

        for device in devices {
            let findings = analyzeDevice(device)
            allFindings.append(contentsOf: findings)

            let summary = DeviceThreatSummary(
                device: device,
                criticalThreats: findings.filter { $0.severity == .critical },
                highThreats: findings.filter { $0.severity == .high },
                mediumThreats: findings.filter { $0.severity == .medium },
                lowThreats: findings.filter { $0.severity == .low },
                infoItems: findings.filter { $0.severity == .info }
            )

            deviceSummaries.append(summary)
        }

        self.deviceSummaries = deviceSummaries.sorted { $0.overallSeverity < $1.overallSeverity }
        self.allThreats = allFindings.sorted { $0.severity < $1.severity }

        // Create network summary
        let rogueDevices = devices.filter { $0.isRogue }
        let backdoorDevices = devices.filter { device in
            device.openPorts.contains { $0.isBackdoorPort }
        }
        let exposedServices = allFindings.filter { $0.category == .exposedService }

        self.networkSummary = NetworkThreatSummary(
            scanDate: Date(),
            totalDevices: devices.count,
            threatenedDevices: deviceSummaries.filter { $0.hasThreats }.count,
            criticalThreats: allFindings.filter { $0.severity == .critical },
            highThreats: allFindings.filter { $0.severity == .high },
            mediumThreats: allFindings.filter { $0.severity == .medium },
            lowThreats: allFindings.filter { $0.severity == .low },
            rogueDevices: rogueDevices,
            backdoorDevices: backdoorDevices,
            exposedServices: exposedServices
        )
    }

    private func analyzeDevice(_ device: EnhancedDevice) -> [ThreatFinding] {
        var findings: [ThreatFinding] = []

        // Check for rogue device
        if device.isRogue {
            findings.append(ThreatFinding(
                severity: .critical,
                category: .rogueDevice,
                title: "Rogue Device Detected",
                description: "Unknown device detected on network for the first time",
                affectedHost: device.ipAddress,
                affectedPort: nil,
                detectedAt: Date(),
                cvssScore: 9.0,
                cveReferences: [],
                remediation: "Investigate device immediately. If unauthorized, isolate from network and identify source. Update MAC whitelist if legitimate.",
                technicalDetails: "Device MAC: \(device.macAddress ?? "Unknown"), First seen: \(device.firstSeen), Not in known devices list",
                impactAssessment: "Potential unauthorized access to network. Could be attacker device, compromised host, or legitimate new device."
            ))
        }

        // Check each port
        for portInfo in device.openPorts {
            findings.append(contentsOf: analyzePort(portInfo, device: device))
        }

        // Check for multiple remote access ports
        let remoteAccessCount = device.openPorts.filter { $0.isRemoteAccessPort }.count
        if remoteAccessCount > 2 {
            findings.append(ThreatFinding(
                severity: .high,
                category: .suspiciousActivity,
                title: "Multiple Remote Access Ports Open",
                description: "\(remoteAccessCount) remote access services detected",
                affectedHost: device.ipAddress,
                affectedPort: nil,
                detectedAt: Date(),
                cvssScore: 7.5,
                cveReferences: [],
                remediation: "Disable unnecessary remote access services. Use VPN for remote access. Implement strong authentication.",
                technicalDetails: "Open remote access ports: \(device.openPorts.filter { $0.isRemoteAccessPort }.map { "\($0.port)/\($0.service)" }.joined(separator: ", "))",
                impactAssessment: "Increased attack surface. Multiple entry points for attackers. Higher risk of brute-force attacks."
            ))
        }

        // Check for exposed databases
        let exposedDatabases = device.openPorts.filter { $0.isDatabasePort }
        if !exposedDatabases.isEmpty {
            for db in exposedDatabases {
                findings.append(ThreatFinding(
                    severity: .critical,
                    category: .dataExposure,
                    title: "Exposed Database Service",
                    description: "\(db.service) database accessible from network",
                    affectedHost: device.ipAddress,
                    affectedPort: db.port,
                    detectedAt: Date(),
                    cvssScore: 9.8,
                    cveReferences: [],
                    remediation: "Bind database to localhost only. Use firewall to restrict access. Implement authentication and encryption. Place behind application tier.",
                    technicalDetails: "Service: \(db.service), Port: \(db.port), Protocol: \(db.protocolType)",
                    impactAssessment: "Direct database access from network. Risk of data breach, SQL injection, unauthorized data access, or data destruction."
                ))
            }
        }

        return findings
    }

    private func analyzePort(_ port: PortInfo, device: EnhancedDevice) -> [ThreatFinding] {
        var findings: [ThreatFinding] = []

        // Check for known backdoor ports
        if port.isBackdoorPort {
            findings.append(ThreatFinding(
                severity: .critical,
                category: .backdoor,
                title: "Known Backdoor Port Detected",
                description: "Port \(port.port) is associated with known backdoor trojans/malware",
                affectedHost: device.ipAddress,
                affectedPort: port.port,
                detectedAt: Date(),
                cvssScore: 10.0,
                cveReferences: [],
                remediation: "IMMEDIATE ACTION REQUIRED: Isolate device from network. Run full malware scan. Reimage system if compromised. Investigate source of infection.",
                technicalDetails: "Port \(port.port) is commonly used by: \(getBackdoorInfo(port.port)). Service banner: \(port.banner ?? "none")",
                impactAssessment: "System likely compromised. Attacker may have full control. Risk of data theft, lateral movement, and persistent access."
            ))
        }

        // Check for Telnet
        if port.port == 23 {
            findings.append(ThreatFinding(
                severity: .critical,
                category: .weakSecurity,
                title: "Telnet Service Enabled",
                description: "Unencrypted remote access protocol detected",
                affectedHost: device.ipAddress,
                affectedPort: 23,
                detectedAt: Date(),
                cvssScore: 9.0,
                cveReferences: ["CVE-2020-15778", "CVE-2019-19521"],
                remediation: "Disable Telnet immediately. Use SSH instead. If SSH is not available, use encrypted VPN tunnel.",
                technicalDetails: "Telnet transmits all data including passwords in clear text. Vulnerable to man-in-the-middle attacks and eavesdropping.",
                impactAssessment: "Credentials can be intercepted. System can be compromised. Complete lack of confidentiality and integrity protection."
            ))
        }

        // Check for anonymous FTP
        if port.port == 21 {
            findings.append(ThreatFinding(
                severity: .high,
                category: .weakSecurity,
                title: "FTP Service Detected",
                description: "Potentially insecure file transfer protocol",
                affectedHost: device.ipAddress,
                affectedPort: 21,
                detectedAt: Date(),
                cvssScore: 7.5,
                cveReferences: ["CVE-2021-41773"],
                remediation: "Replace with SFTP or FTPS. Disable anonymous access. Use strong authentication. Consider using SCP instead.",
                technicalDetails: "FTP transmits credentials in clear text. Check if anonymous access is enabled. Version: \(port.version ?? "unknown")",
                impactAssessment: "Credentials may be intercepted. Possible anonymous file access. Risk of unauthorized data access or modification."
            ))
        }

        // Check for HTTP without HTTPS
        if port.port == 80 && !device.openPorts.contains(where: { $0.port == 443 }) {
            findings.append(ThreatFinding(
                severity: .medium,
                category: .weakSecurity,
                title: "HTTP Without HTTPS",
                description: "Web server accessible over unencrypted HTTP only",
                affectedHost: device.ipAddress,
                affectedPort: 80,
                detectedAt: Date(),
                cvssScore: 5.3,
                cveReferences: [],
                remediation: "Enable HTTPS with valid SSL/TLS certificate. Redirect HTTP to HTTPS. Disable HTTP if possible.",
                technicalDetails: "HTTP port 80 open, no HTTPS port 443 detected. All traffic sent in clear text.",
                impactAssessment: "Data transmitted in clear text. Risk of eavesdropping, session hijacking, and man-in-the-middle attacks."
            ))
        }

        // Check for VNC
        if port.port >= 5900 && port.port <= 5910 {
            findings.append(ThreatFinding(
                severity: .high,
                category: .backdoor,
                title: "VNC Remote Desktop Exposed",
                description: "VNC service accessible from network",
                affectedHost: device.ipAddress,
                affectedPort: port.port,
                detectedAt: Date(),
                cvssScore: 8.0,
                cveReferences: ["CVE-2020-14404", "CVE-2019-15681"],
                remediation: "Place VNC behind VPN or SSH tunnel. Use strong password. Enable encryption. Consider using more secure alternative like RDP with NLA.",
                technicalDetails: "VNC uses weak encryption by default. Often targeted by automated scanners. Display number: \(port.port - 5900)",
                impactAssessment: "Remote desktop access available to attackers. Risk of unauthorized screen capture, keyboard monitoring, and system control."
            ))
        }

        // Check for RDP
        if port.port == 3389 {
            findings.append(ThreatFinding(
                severity: .high,
                category: .backdoor,
                title: "RDP Service Exposed to Network",
                description: "Remote Desktop Protocol accessible from network",
                affectedHost: device.ipAddress,
                affectedPort: 3389,
                detectedAt: Date(),
                cvssScore: 8.0,
                cveReferences: ["CVE-2019-0708", "CVE-2020-0609", "CVE-2020-0610"],
                remediation: "Place RDP behind VPN. Enable Network Level Authentication (NLA). Use strong passwords or certificate-based auth. Enable account lockout policies.",
                technicalDetails: "RDP is frequently targeted by ransomware and automated attacks. BlueKeep and other critical vulnerabilities affect unpatched systems.",
                impactAssessment: "High-value target for attackers. Risk of brute-force attacks, ransomware deployment, and complete system compromise."
            ))
        }

        // Check for SMB
        if port.port == 445 || port.port == 139 {
            findings.append(ThreatFinding(
                severity: .high,
                category: .exposedService,
                title: "SMB File Sharing Exposed",
                description: "Windows file sharing accessible from network",
                affectedHost: device.ipAddress,
                affectedPort: port.port,
                detectedAt: Date(),
                cvssScore: 7.5,
                cveReferences: ["CVE-2017-0144", "CVE-2020-0796"],
                remediation: "Disable SMBv1. Restrict SMB access to specific subnets. Use firewall rules. Enable SMB signing. Apply latest patches.",
                technicalDetails: "SMB port \(port.port) exposed. EternalBlue (MS17-010) and SMBGhost vulnerabilities affect unpatched systems.",
                impactAssessment: "Risk of ransomware (WannaCry), lateral movement, credential theft, and unauthorized file access."
            ))
        }

        return findings
    }

    private func getBackdoorInfo(_ port: Int) -> String {
        switch port {
        case 31337: return "Back Orifice trojan"
        case 12345, 12346: return "NetBus trojan"
        case 1243: return "SubSeven trojan"
        case 6667, 6668, 6669: return "IRC botnet command & control"
        case 27374: return "SubSeven trojan"
        case 2001: return "Trojan.Latinus"
        case 1999: return "BackDoor trojan"
        case 30100, 30101, 30102: return "NetSphere trojan"
        case 5000, 5001, 5002: return "Back Door Setup/Sockets de Troie"
        default: return "Unknown backdoor/trojan"
        }
    }
}
