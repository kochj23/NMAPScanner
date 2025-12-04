//
//  EnhancedDeviceExtensions.swift
//  NMAP Plus Security Scanner
//
//  Created by Jordan Koch on 2025-11-30.
//
//  Extensions and computed properties for EnhancedDevice
//

import Foundation

extension EnhancedDevice {
    /// Threat level computed property
    var threatLevel: ThreatLevel {
        let criticalPorts = openPorts.filter { $0.port == 23 || $0.port == 21 || $0.port == 445 }

        if !criticalPorts.isEmpty {
            return .high
        }

        if isRogue {
            return .medium
        }

        if openPorts.count > 10 {
            return .medium
        }

        if openPorts.isEmpty {
            return .low
        }

        return .low
    }

    /// Whether device is whitelisted (default false for compatibility)
    var isWhitelisted: Bool {
        return isKnownDevice
    }

    /// Service type for HomeKit devices
    var serviceType: String? {
        return homeKitMDNSInfo?.serviceType
    }

    /// Device name alias
    var name: String {
        return displayName
    }

    /// Category for HomeKit devices
    var category: String {
        return deviceType.rawValue
    }

    /// Discovery timestamp
    var discoveredAt: Date {
        return firstSeen
    }

    /// Vulnerabilities list (empty by default)
    var vulnerabilities: [String] {
        var vulns: [String] = []
        for port in openPorts where port.isInsecurePort {
            vulns.append("Insecure port \(port.port) open")
        }
        return vulns
    }

    /// Device type for Apple devices
    func detectAppleDeviceType() -> String? {
        if let manufacturer = manufacturer, manufacturer.lowercased().contains("apple") {
            if deviceType == .mobile {
                return "iPhone/iPad"
            } else if deviceType == .computer {
                return "Mac"
            } else if deviceType == .iot {
                return "Apple TV/HomePod"
            }
        }
        return nil
    }
}

extension EnhancedDevice.DeviceType {
    /// Network device type
    static let networkDevice = EnhancedDevice.DeviceType.router
}

extension PortInfo {
    /// Check if port is considered insecure
    var isInsecurePort: Bool {
        let insecurePorts: Set<Int> = [21, 23, 69, 80, 110, 143, 445, 1433, 3306, 5432]
        return insecurePorts.contains(port)
    }
}

enum ThreatLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}
