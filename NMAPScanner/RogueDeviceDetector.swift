//
//  RogueDeviceDetector.swift
//  NMAPScanner - Rogue & Unauthorized Device Detection
//
//  Created by Jordan Koch & Claude Code on 2025-11-27.
//

import Foundation

struct RogueDevice: Identifiable, Codable {
    let id = UUID()
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let reason: DetectionReason
    let severity: Severity
    let recommendation: String
    let timestamp: Date

    enum DetectionReason: String, Codable {
        case unauthorizedDHCP = "Unauthorized DHCP Server"
        case rogueAP = "Rogue WiFi Access Point"
        case unknownVendor = "Unknown MAC Vendor"
        case notInInventory = "Not in Asset Inventory"
        case unauthorizedRouter = "Unauthorized Router/Gateway"
    }

    enum Severity: String, Codable {
        case critical, high, medium
    }
}

@MainActor
class RogueDeviceDetector: ObservableObject {
    static let shared = RogueDeviceDetector()

    @Published var rogueDevices: [RogueDevice] = []
    @Published var authorizedDevices: Set<String> = [] // MAC addresses
    @Published var isScanning = false

    private init() {}

    func detectRogueDevices(devices: [EnhancedDevice]) async {
        isScanning = true
        rogueDevices.removeAll()

        for device in devices {
            // Check for unauthorized DHCP servers
            if device.openPorts.contains(where: { $0.port == 67 }) && !isAuthorizedDHCPServer(device.ipAddress) {
                rogueDevices.append(RogueDevice(
                    ipAddress: device.ipAddress,
                    macAddress: device.macAddress,
                    hostname: device.hostname,
                    reason: .unauthorizedDHCP,
                    severity: .critical,
                    recommendation: "Investigate and remove unauthorized DHCP server. This can cause network outages.",
                    timestamp: Date()
                ))
            }

            // Check for rogue WiFi APs
            if device.deviceType == .router && device.openPorts.contains(where: { $0.port == 80 || $0.port == 443 }) {
                if !isAuthorizedRouter(device.ipAddress) {
                    rogueDevices.append(RogueDevice(
                        ipAddress: device.ipAddress,
                        macAddress: device.macAddress,
                        hostname: device.hostname,
                        reason: .rogueAP,
                        severity: .critical,
                        recommendation: "Possible rogue access point. Locate and remove physical device.",
                        timestamp: Date()
                    ))
                }
            }

            // Check asset inventory
            if let mac = device.macAddress, !authorizedDevices.contains(mac) {
                rogueDevices.append(RogueDevice(
                    ipAddress: device.ipAddress,
                    macAddress: mac,
                    hostname: device.hostname,
                    reason: .notInInventory,
                    severity: .medium,
                    recommendation: "Device not in authorized inventory. Verify and add or remove from network.",
                    timestamp: Date()
                ))
            }
        }

        isScanning = false
    }

    private func isAuthorizedDHCPServer(_ ip: String) -> Bool {
        // In production, maintain list of authorized DHCP servers
        return ip.starts(with: "192.168.1.1") || ip.starts(with: "10.0.0.1")
    }

    private func isAuthorizedRouter(_ ip: String) -> Bool {
        // In production, maintain list of authorized routers/APs
        return ip.starts(with: "192.168.1.1") || ip.starts(with: "10.0.0.1")
    }
}
