//
//  AnomalyDetectionManager.swift
//  NMAP Scanner - Network Anomaly Detection
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import SwiftUI
import Combine

/// Detects and reports network anomalies
@MainActor
class AnomalyDetectionManager: ObservableObject {
    static let shared = AnomalyDetectionManager()

    @Published var anomalies: [NetworkAnomaly] = []
    @Published var newDevices: [EnhancedDevice] = []
    @Published var missingDevices: [EnhancedDevice] = []
    @Published var changedDevices: [DeviceChange] = []
    @Published var isEnabled = true

    private let persistenceManager = DevicePersistenceManager.shared
    private var lastKnownDevices: [String: EnhancedDevice] = [:] // IP -> Device

    private init() {
        loadKnownDevices()
    }

    /// Load known devices from persistence
    private func loadKnownDevices() {
        let devices = persistenceManager.getAllDevices()
        lastKnownDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.ipAddress, $0) })
        print("🔍 AnomalyDetectionManager: Loaded \(lastKnownDevices.count) known devices")
    }

    /// Analyze new scan results for anomalies
    func analyzeScanResults(_ currentDevices: [EnhancedDevice]) {
        guard isEnabled else { return }

        print("🔍 AnomalyDetectionManager: Analyzing \(currentDevices.count) devices for anomalies...")

        var detectedAnomalies: [NetworkAnomaly] = []
        var newDevicesList: [EnhancedDevice] = []
        var missingDevicesList: [EnhancedDevice] = []
        var changedDevicesList: [DeviceChange] = []

        let currentIPs = Set(currentDevices.map { $0.ipAddress })
        let knownIPs = Set(lastKnownDevices.keys)

        // 1. Detect new devices
        let newIPs = currentIPs.subtracting(knownIPs)
        for ip in newIPs {
            if let device = currentDevices.first(where: { $0.ipAddress == ip }) {
                newDevicesList.append(device)

                let anomaly = NetworkAnomaly(
                    type: .newDevice,
                    severity: .medium,
                    device: device,
                    description: "New device detected: \(device.hostname ?? device.ipAddress)",
                    timestamp: Date()
                )
                detectedAnomalies.append(anomaly)
            }
        }

        // 2. Detect missing devices
        let missingIPs = knownIPs.subtracting(currentIPs)
        for ip in missingIPs {
            if let device = lastKnownDevices[ip] {
                missingDevicesList.append(device)

                let anomaly = NetworkAnomaly(
                    type: .deviceOffline,
                    severity: .low,
                    device: device,
                    description: "Device went offline: \(device.hostname ?? device.ipAddress)",
                    timestamp: Date()
                )
                detectedAnomalies.append(anomaly)
            }
        }

        // 3. Detect changed devices
        for device in currentDevices {
            if let oldDevice = lastKnownDevices[device.ipAddress] {
                var changes: [String] = []

                // Check for MAC address change (possible spoofing)
                if oldDevice.macAddress != device.macAddress {
                    changes.append("MAC address changed from \(oldDevice.macAddress ?? "unknown") to \(device.macAddress ?? "unknown")")

                    let anomaly = NetworkAnomaly(
                        type: .macAddressChanged,
                        severity: .high,
                        device: device,
                        description: "⚠️ MAC address changed for \(device.ipAddress) - Possible spoofing!",
                        timestamp: Date()
                    )
                    detectedAnomalies.append(anomaly)
                }

                // Check for new open ports (potential security issue)
                let oldPorts = Set(oldDevice.openPorts.map { $0.port })
                let newPorts = Set(device.openPorts.map { $0.port })
                let addedPorts = newPorts.subtracting(oldPorts)

                if !addedPorts.isEmpty {
                    changes.append("New open ports: \(addedPorts.sorted().map(String.init).joined(separator: ", "))")

                    let anomaly = NetworkAnomaly(
                        type: .newOpenPorts,
                        severity: .medium,
                        device: device,
                        description: "New open ports detected on \(device.hostname ?? device.ipAddress): \(addedPorts.sorted().map(String.init).joined(separator: ", "))",
                        timestamp: Date()
                    )
                    detectedAnomalies.append(anomaly)
                }

                // Check for closed ports
                let closedPorts = oldPorts.subtracting(newPorts)
                if !closedPorts.isEmpty {
                    changes.append("Closed ports: \(closedPorts.sorted().map(String.init).joined(separator: ", "))")
                }

                // Check for manufacturer change (suspicious)
                if oldDevice.manufacturer != device.manufacturer {
                    changes.append("Manufacturer changed from \(oldDevice.manufacturer ?? "unknown") to \(device.manufacturer ?? "unknown")")
                }

                if !changes.isEmpty {
                    let change = DeviceChange(
                        device: device,
                        changes: changes,
                        timestamp: Date()
                    )
                    changedDevicesList.append(change)
                }
            }
        }

        // Update state
        self.anomalies = detectedAnomalies
        self.newDevices = newDevicesList
        self.missingDevices = missingDevicesList
        self.changedDevices = changedDevicesList

        // Update known devices (handle duplicate IPs by keeping the most recent)
        lastKnownDevices = Dictionary(currentDevices.map { ($0.ipAddress, $0) }, uniquingKeysWith: { _, new in new })

        // Send notifications for high-severity anomalies
        for anomaly in detectedAnomalies where anomaly.severity == .high {
            NotificationManager.shared.notifyAnomaly(anomaly)
        }

        print("🔍 AnomalyDetectionManager: Found \(detectedAnomalies.count) anomalies")
        print("   - New devices: \(newDevicesList.count)")
        print("   - Missing devices: \(missingDevicesList.count)")
        print("   - Changed devices: \(changedDevicesList.count)")
    }

    /// Clear all anomalies
    func clearAnomalies() {
        anomalies.removeAll()
        newDevices.removeAll()
        missingDevices.removeAll()
        changedDevices.removeAll()
    }

    /// Dismiss a specific anomaly
    func dismissAnomaly(_ anomaly: NetworkAnomaly) {
        anomalies.removeAll { $0.id == anomaly.id }
    }
}

// MARK: - Network Anomaly Model

struct NetworkAnomaly: Identifiable, Hashable {
    let id = UUID()
    let type: AnomalyType
    let severity: AnomalySeverity
    let device: EnhancedDevice
    let description: String
    let timestamp: Date

    enum AnomalyType: String, Codable {
        case newDevice = "New Device"
        case deviceOffline = "Device Offline"
        case macAddressChanged = "MAC Address Changed"
        case newOpenPorts = "New Open Ports"
        case suspiciousActivity = "Suspicious Activity"

        var icon: String {
            switch self {
            case .newDevice: return "plus.circle.fill"
            case .deviceOffline: return "xmark.circle.fill"
            case .macAddressChanged: return "arrow.triangle.2.circlepath"
            case .newOpenPorts: return "network.badge.shield.half.filled"
            case .suspiciousActivity: return "exclamationmark.triangle.fill"
            }
        }

        var displayName: String {
            return self.rawValue
        }
    }

    enum AnomalySeverity: String, Codable, Comparable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"

        static func < (lhs: AnomalySeverity, rhs: AnomalySeverity) -> Bool {
            let order: [AnomalySeverity] = [.low, .medium, .high, .critical]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }

        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .orange
            case .high: return .red
            case .critical: return .purple
            }
        }
    }
}

// MARK: - Device Change Model

struct DeviceChange: Identifiable, Hashable {
    let id = UUID()
    let device: EnhancedDevice
    let changes: [String]
    let timestamp: Date
}

// MARK: - NotificationManager Extension

extension NotificationManager {
    func notifyAnomaly(_ anomaly: NetworkAnomaly) {
        let title = "⚠️ Network Anomaly Detected"
        let message = "\(anomaly.type.rawValue): \(anomaly.description)"

        // macOS notification
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)

        print("🔔 NotificationManager: Anomaly notification sent - \(anomaly.type.rawValue)")
    }
}
