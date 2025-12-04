//
//  DeviceGroupingManager.swift
//  NMAP Scanner - Device Grouping and Organization
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation
import SwiftUI

/// Manages device grouping and organization
@MainActor
class DeviceGroupingManager: ObservableObject {
    static let shared = DeviceGroupingManager()

    @Published var groupingMode: GroupingMode = .none
    @Published var groups: [DeviceGroup] = []

    private init() {}

    enum GroupingMode: String, CaseIterable {
        case none = "No Grouping"
        case role = "By Role"
        case manufacturer = "By Manufacturer"
        case subnet = "By Subnet"
        case status = "By Status"
        case custom = "Custom Groups"
    }

    /// Group devices based on current mode
    func groupDevices(_ devices: [EnhancedDevice]) -> [DeviceGroup] {
        switch groupingMode {
        case .none:
            return [DeviceGroup(name: "All Devices", devices: devices, icon: "network", color: .blue)]

        case .role:
            return groupByRole(devices)

        case .manufacturer:
            return groupByManufacturer(devices)

        case .subnet:
            return groupBySubnet(devices)

        case .status:
            return groupByStatus(devices)

        case .custom:
            return groups.isEmpty ? [DeviceGroup(name: "All Devices", devices: devices, icon: "network", color: .blue)] : groups
        }
    }

    /// Group devices by role
    private func groupByRole(_ devices: [EnhancedDevice]) -> [DeviceGroup] {
        var grouped: [String: [EnhancedDevice]] = [:]

        for device in devices {
            let role = detectRole(device) ?? "Unknown"
            grouped[role, default: []].append(device)
        }

        return grouped.map { role, devices in
            DeviceGroup(
                name: role,
                devices: devices.sorted { $0.ipAddress < $1.ipAddress },
                icon: roleIcon(role),
                color: roleColor(role)
            )
        }.sorted { $0.name < $1.name }
    }

    /// Group devices by manufacturer
    private func groupByManufacturer(_ devices: [EnhancedDevice]) -> [DeviceGroup] {
        var grouped: [String: [EnhancedDevice]] = [:]

        for device in devices {
            let manufacturer = device.manufacturer ?? "Unknown"
            grouped[manufacturer, default: []].append(device)
        }

        return grouped.map { manufacturer, devices in
            DeviceGroup(
                name: manufacturer,
                devices: devices.sorted { $0.ipAddress < $1.ipAddress },
                icon: "building.2",
                color: .orange
            )
        }.sorted { $0.name < $1.name }
    }

    /// Group devices by subnet
    private func groupBySubnet(_ devices: [EnhancedDevice]) -> [DeviceGroup] {
        var grouped: [String: [EnhancedDevice]] = [:]

        for device in devices {
            let parts = device.ipAddress.split(separator: ".")
            if parts.count >= 3 {
                let subnet = "\(parts[0]).\(parts[1]).\(parts[2]).0/24"
                grouped[subnet, default: []].append(device)
            }
        }

        return grouped.map { subnet, devices in
            DeviceGroup(
                name: subnet,
                devices: devices.sorted { $0.ipAddress < $1.ipAddress },
                icon: "network",
                color: .blue
            )
        }.sorted { $0.name < $1.name }
    }

    /// Group devices by status
    private func groupByStatus(_ devices: [EnhancedDevice]) -> [DeviceGroup] {
        let online = devices.filter { $0.isOnline }
        let offline = devices.filter { !$0.isOnline }

        return [
            DeviceGroup(name: "Online", devices: online, icon: "checkmark.circle.fill", color: .green),
            DeviceGroup(name: "Offline", devices: offline, icon: "xmark.circle.fill", color: .gray)
        ]
    }

    /// Detect device role
    private func detectRole(_ device: EnhancedDevice) -> String? {
        // Check if it's a HomeKit device first

        let ports = Set(device.openPorts.map { $0.port })

        if ports.contains(53) || ports.contains(67) || ports.contains(68) {
            return "Gateway"
        }
        if ports.contains(80) || ports.contains(443) || ports.contains(8080) {
            return "Web Server"
        }
        if ports.intersection([3306, 5432, 1433, 27017, 6379]).count > 0 {
            return "Database"
        }
        if ports.intersection([445, 139, 548, 2049]).count > 0 {
            return "File Server"
        }
        if ports.intersection([631, 9100]).count > 0 {
            return "Printer"
        }
        if ports.intersection([25, 465, 587, 143, 993, 110, 995]).count > 0 {
            return "Mail Server"
        }
        if ports.contains(22) || ports.contains(3389) || ports.contains(5900) {
            return "Remote Access"
        }
        if ports.intersection([1883, 8883, 8123, 1400]).count > 0 {
            return "Smart Home"
        }
        if ports.intersection([32400, 8096, 8920, 9091]).count > 0 {
            return "Media Server"
        }
        if ports.intersection([5000, 5001]).count > 0 {
            return "NAS"
        }

        return device.openPorts.isEmpty ? "Unknown" : "Workstation"
    }

    /// Get icon for role
    private func roleIcon(_ role: String) -> String {
        switch role {
        case "Gateway": return "wifi.router"
        case "Web Server": return "server.rack"
        case "Database": return "cylinder.split.1x2"
        case "File Server": return "folder.fill"
        case "Printer": return "printer"
        case "Mail Server": return "envelope.fill"
        case "Remote Access": return "terminal"
        case "Smart Home": return "house.fill"
        case "Media Server": return "play.rectangle.fill"
        case "NAS": return "externaldrive.fill"
        case "Workstation": return "desktopcomputer"
        default: return "questionmark.circle"
        }
    }

    /// Get color for role
    private func roleColor(_ role: String) -> Color {
        switch role {
        case "Gateway": return .blue
        case "Web Server": return .green
        case "Database": return .purple
        case "File Server": return .orange
        case "Printer": return .pink
        case "Mail Server": return .cyan
        case "Remote Access": return .red
        case "Smart Home": return .mint
        case "Media Server": return .indigo
        case "NAS": return .teal
        case "Workstation": return .brown
        default: return .gray
        }
    }

    /// Create a custom group
    func createCustomGroup(name: String, devices: [EnhancedDevice], icon: String = "folder", color: Color = .blue) {
        let group = DeviceGroup(name: name, devices: devices, icon: icon, color: color)
        groups.append(group)
    }

    /// Remove a custom group
    func removeCustomGroup(_ group: DeviceGroup) {
        groups.removeAll { $0.id == group.id }
    }
}

// MARK: - Device Group Model

struct DeviceGroup: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var devices: [EnhancedDevice]
    let icon: String
    let color: Color

    var deviceCount: Int {
        devices.count
    }

    var onlineCount: Int {
        devices.filter { $0.isOnline }.count
    }

    var totalOpenPorts: Int {
        devices.reduce(0) { $0 + $1.openPorts.count }
    }

    static func == (lhs: DeviceGroup, rhs: DeviceGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
