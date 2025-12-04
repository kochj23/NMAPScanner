//
//  NetworkSegmentationAnalyzer.swift
//  NMAPScanner - Network Segmentation & Isolation Analysis
//
//  Created by Jordan Koch & Claude Code on 2025-11-27.
//

import Foundation

/// Network segment definition
struct NetworkSegment: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let cidr: String
    let securityLevel: SecurityLevel
    let purpose: String
    let allowedDestinations: [String] // CIDRs this segment can reach

    enum SecurityLevel: String, Codable {
        case high = "High Security"
        case medium = "Medium Security"
        case low = "Low Security"
        case dmz = "DMZ"
        case iot = "IoT Isolated"
    }
}

/// Segmentation violation
struct SegmentationViolation: Identifiable, Codable {
    let id = UUID()
    let severity: Severity
    let sourceIP: String
    let sourceSegment: String
    let destinationIP: String
    let destinationSegment: String
    let description: String
    let recommendation: String
    let timestamp: Date

    enum Severity: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

/// Manages network segmentation analysis
@MainActor
class NetworkSegmentationAnalyzer: ObservableObject {
    static let shared = NetworkSegmentationAnalyzer()

    @Published var segments: [NetworkSegment] = []
    @Published var violations: [SegmentationViolation] = []
    @Published var isAnalyzing = false
    @Published var lastAnalysisDate: Date?

    private init() {
        loadDefaultSegments()
    }

    // MARK: - Configuration

    private func loadDefaultSegments() {
        segments = [
            NetworkSegment(
                name: "Management Network",
                cidr: "10.0.0.0/24",
                securityLevel: .high,
                purpose: "Network management and administration",
                allowedDestinations: []
            ),
            NetworkSegment(
                name: "Corporate Network",
                cidr: "192.168.1.0/24",
                securityLevel: .medium,
                purpose: "Employee workstations and office devices",
                allowedDestinations: ["10.100.0.0/16"] // Can access servers
            ),
            NetworkSegment(
                name: "Server Network",
                cidr: "10.100.0.0/16",
                securityLevel: .high,
                purpose: "Application and database servers",
                allowedDestinations: []
            ),
            NetworkSegment(
                name: "DMZ",
                cidr: "172.16.0.0/24",
                securityLevel: .dmz,
                purpose: "Internet-facing services",
                allowedDestinations: []
            ),
            NetworkSegment(
                name: "IoT Network",
                cidr: "10.200.0.0/16",
                securityLevel: .iot,
                purpose: "IoT and smart devices",
                allowedDestinations: [] // Should be isolated
            )
        ]
    }

    // MARK: - Analysis

    /// Analyze network traffic for segmentation violations
    func analyzeSegmentation(devices: [EnhancedDevice], connections: [SegmentationConnection]) async {
        isAnalyzing = true
        violations.removeAll()

        print("🔍 NetworkSegmentationAnalyzer: Analyzing segmentation on \(connections.count) connections")

        for connection in connections {
            if let violation = detectViolation(connection: connection, devices: devices) {
                violations.append(violation)
            }
        }

        // Additional checks
        await checkIoTIsolation(devices: devices, connections: connections)
        await checkInternetAccess(devices: devices, connections: connections)
        await checkLateralMovement(connections: connections)

        lastAnalysisDate = Date()
        isAnalyzing = false

        print("🔍 NetworkSegmentationAnalyzer: Analysis complete - found \(violations.count) violations")
    }

    private func detectViolation(connection: SegmentationConnection, devices: [EnhancedDevice]) -> SegmentationViolation? {
        guard let sourceSegment = identifySegment(ip: connection.sourceIP),
              let destSegment = identifySegment(ip: connection.destinationIP) else {
            return nil
        }

        // Check if this connection violates segmentation policy
        if sourceSegment.id != destSegment.id {
            // Different segments - check if allowed
            if !sourceSegment.allowedDestinations.contains(destSegment.cidr) {
                let severity = calculateSeverity(
                    sourceLevel: sourceSegment.securityLevel,
                    destLevel: destSegment.securityLevel
                )

                return SegmentationViolation(
                    severity: severity,
                    sourceIP: connection.sourceIP,
                    sourceSegment: sourceSegment.name,
                    destinationIP: connection.destinationIP,
                    destinationSegment: destSegment.name,
                    description: "Unauthorized traffic from \(sourceSegment.name) to \(destSegment.name)",
                    recommendation: "Implement firewall rules to block traffic between these segments. Review VLAN configuration.",
                    timestamp: Date()
                )
            }
        }

        return nil
    }

    // MARK: - IoT Isolation Checks

    private func checkIoTIsolation(devices: [EnhancedDevice], connections: [SegmentationConnection]) async {
        let iotDevices = devices.filter { $0.deviceType == .iot }

        for device in iotDevices {
            // Check if IoT device is communicating with non-IoT segments
            let deviceConnections = connections.filter {
                $0.sourceIP == device.ipAddress || $0.destinationIP == device.ipAddress
            }

            for connection in deviceConnections {
                let otherIP = connection.sourceIP == device.ipAddress ? connection.destinationIP : connection.sourceIP

                if let otherSegment = identifySegment(ip: otherIP),
                   otherSegment.securityLevel != NetworkSegment.SecurityLevel.iot {
                    violations.append(SegmentationViolation(
                        severity: .high,
                        sourceIP: device.ipAddress,
                        sourceSegment: "IoT Network",
                        destinationIP: otherIP,
                        destinationSegment: otherSegment.name,
                        description: "IoT device '\(device.hostname ?? device.ipAddress)' communicating outside isolated network",
                        recommendation: "Isolate IoT devices on separate VLAN. Block all traffic except to IoT controller/gateway.",
                        timestamp: Date()
                    ))
                }
            }
        }
    }

    // MARK: - Internet Access Checks

    private func checkInternetAccess(devices: [EnhancedDevice], connections: [SegmentationConnection]) async {
        for connection in connections {
            if isInternetIP(connection.destinationIP) {
                // Check if source should have internet access
                if let sourceSegment = identifySegment(ip: connection.sourceIP) {
                    if sourceSegment.securityLevel == .high {
                        // High security segments shouldn't directly access internet
                        violations.append(SegmentationViolation(
                            severity: .high,
                            sourceIP: connection.sourceIP,
                            sourceSegment: sourceSegment.name,
                            destinationIP: connection.destinationIP,
                            destinationSegment: "Internet",
                            description: "High security device accessing internet directly",
                            recommendation: "Route traffic through proxy/firewall. Implement egress filtering.",
                            timestamp: Date()
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Lateral Movement Detection

    private func checkLateralMovement(connections: [SegmentationConnection]) async {
        // Detect suspicious lateral movement patterns
        var sourceConnectionCounts: [String: Set<String>] = [:]

        for connection in connections {
            sourceConnectionCounts[connection.sourceIP, default: []].insert(connection.destinationIP)
        }

        // Flag sources connecting to many destinations (potential scanning/lateral movement)
        for (sourceIP, destinations) in sourceConnectionCounts {
            if destinations.count > 10 {
                if let segment = identifySegment(ip: sourceIP) {
                    violations.append(SegmentationViolation(
                        severity: .medium,
                        sourceIP: sourceIP,
                        sourceSegment: segment.name,
                        destinationIP: "Multiple (\(destinations.count))",
                        destinationSegment: "Various",
                        description: "Device showing lateral movement pattern - connecting to \(destinations.count) different hosts",
                        recommendation: "Investigate this device for potential compromise. Review connection logs.",
                        timestamp: Date()
                    ))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func identifySegment(ip: String) -> NetworkSegment? {
        for segment in segments {
            if ipInCIDR(ip: ip, cidr: segment.cidr) {
                return segment
            }
        }
        return nil
    }

    private func ipInCIDR(ip: String, cidr: String) -> Bool {
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let networkIP = components.first,
              let prefixLength = Int(components.last!) else {
            return false
        }

        let ipInt = ipToInt(String(ip))
        let networkInt = ipToInt(String(networkIP))
        let mask: UInt32 = ~((1 << (32 - prefixLength)) - 1)

        return (ipInt & mask) == (networkInt & mask)
    }

    private func ipToInt(_ ip: String) -> UInt32 {
        let octets = ip.split(separator: ".").compactMap { UInt32($0) }
        guard octets.count == 4 else { return 0 }

        return (octets[0] << 24) + (octets[1] << 16) + (octets[2] << 8) + octets[3]
    }

    private func isInternetIP(_ ip: String) -> Bool {
        // Check if IP is public (not RFC1918 private)
        let privateRanges = [
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
            "127.0.0.0/8",
            "169.254.0.0/16"
        ]

        for range in privateRanges {
            if ipInCIDR(ip: ip, cidr: range) {
                return false
            }
        }

        return true
    }

    private func calculateSeverity(sourceLevel: NetworkSegment.SecurityLevel, destLevel: NetworkSegment.SecurityLevel) -> SegmentationViolation.Severity {
        switch (sourceLevel, destLevel) {
        case (.iot, _):
            return .critical // IoT should never cross boundaries
        case (.low, .high), (.dmz, .high):
            return .critical // Low/DMZ accessing high security
        case (.medium, .high):
            return .high
        default:
            return .medium
        }
    }

    // MARK: - Statistics

    var stats: SegmentationStats {
        let critical = violations.filter { $0.severity == .critical }.count
        let high = violations.filter { $0.severity == .high }.count
        let iotViolations = violations.filter { $0.sourceSegment.contains("IoT") }.count
        let internetViolations = violations.filter { $0.destinationSegment == "Internet" }.count

        return SegmentationStats(
            totalViolations: violations.count,
            criticalViolations: critical,
            highViolations: high,
            iotViolations: iotViolations,
            internetViolations: internetViolations,
            segmentsMonitored: segments.count
        )
    }
}

struct SegmentationStats {
    let totalViolations: Int
    let criticalViolations: Int
    let highViolations: Int
    let iotViolations: Int
    let internetViolations: Int
    let segmentsMonitored: Int
}

// Helper struct for network connections
struct SegmentationConnection: Codable {
    let sourceIP: String
    let destinationIP: String
    let sourcePort: Int
    let destinationPort: Int
    let protocolType: String
}
