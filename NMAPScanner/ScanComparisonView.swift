//
//  ScanComparisonView.swift
//  NMAPScanner - Compare Two Network Scans Side-by-Side
//
//  Visualize network changes between scans
//  Created by Jordan Koch on 2025-12-11.
//

import SwiftUI

// MARK: - Scan Snapshot

struct ScanSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let devices: [DeviceSnapshot]
    let totalDevices: Int
    let onlineDevices: Int
    let totalPorts: Int
    let scanDuration: TimeInterval

    init(from devices: [EnhancedDevice], duration: TimeInterval = 0) {
        self.id = UUID()
        self.timestamp = Date()
        self.devices = devices.map { DeviceSnapshot(from: $0) }
        self.totalDevices = devices.count
        self.onlineDevices = devices.filter { $0.isOnline }.count
        self.totalPorts = devices.reduce(0) { $0 + $1.openPorts.count }
        self.scanDuration = duration
    }
}

struct DeviceSnapshot: Identifiable, Codable {
    let id: String  // IP address
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let manufacturer: String?
    let deviceType: String
    let openPorts: [Int]
    let isOnline: Bool
    let isRogue: Bool

    init(from device: EnhancedDevice) {
        self.id = device.ipAddress
        self.ipAddress = device.ipAddress
        self.macAddress = device.macAddress
        self.hostname = device.hostname
        self.manufacturer = device.manufacturer
        self.deviceType = device.deviceType.rawValue
        self.openPorts = device.openPorts.map { $0.port }
        self.isOnline = device.isOnline
        self.isRogue = device.isRogue
    }
}

// MARK: - Comparison Result

struct ScanComparison {
    let scan1: ScanSnapshot
    let scan2: ScanSnapshot
    let changes: [DeviceChange]

    var newDevices: [DeviceSnapshot] {
        let scan1IPs = Set(scan1.devices.map { $0.ipAddress })
        return scan2.devices.filter { !scan1IPs.contains($0.ipAddress) }
    }

    var removedDevices: [DeviceSnapshot] {
        let scan2IPs = Set(scan2.devices.map { $0.ipAddress })
        return scan1.devices.filter { !scan2IPs.contains($0.ipAddress) }
    }

    var modifiedDevices: [DeviceSnapshot] {
        changes.filter { $0.changeType != .added && $0.changeType != .removed }
            .compactMap { change in
                scan2.devices.first { $0.ipAddress == change.deviceIP }
            }
    }

    var unchangedDevices: [DeviceSnapshot] {
        let changedIPs = Set(changes.map { $0.deviceIP })
        return scan2.devices.filter { !changedIPs.contains($0.ipAddress) }
    }

    var summary: String {
        """
        Comparing scans from \(formatShortDate(scan1.timestamp)) to \(formatShortDate(scan2.timestamp))

        Changes:
        - New devices: \(newDevices.count)
        - Removed devices: \(removedDevices.count)
        - Modified devices: \(modifiedDevices.count)
        - Unchanged devices: \(unchangedDevices.count)
        """
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum ChangeType: String, Codable {
    case added = "Added"
    case removed = "Removed"
    case portsChanged = "Ports Changed"
    case hostnameChanged = "Hostname Changed"
    case statusChanged = "Status Changed"
    case becameRogue = "Became Rogue"
    case trustedNow = "Trusted Now"
}

struct DeviceChange: Identifiable {
    let id = UUID()
    let deviceIP: String
    let changeType: ChangeType
    let details: String
    let severity: ChangeSeverity

    enum ChangeSeverity {
        case info
        case warning
        case critical
    }
}

// MARK: - Comparison Engine

class ScanComparisonEngine {

    /// Compare two scans and generate diff
    static func compare(scan1: ScanSnapshot, scan2: ScanSnapshot) -> ScanComparison {
        var changes: [DeviceChange] = []

        let scan1Devices = Dictionary(uniqueKeysWithValues: scan1.devices.map { ($0.ipAddress, $0) })
        let scan2Devices = Dictionary(uniqueKeysWithValues: scan2.devices.map { ($0.ipAddress, $0) })

        // Find new devices
        for (ip, device) in scan2Devices where scan1Devices[ip] == nil {
            changes.append(DeviceChange(
                deviceIP: ip,
                changeType: .added,
                details: "New device discovered: \(device.hostname ?? ip)",
                severity: device.isRogue ? .warning : .info
            ))
        }

        // Find removed devices
        for (ip, device) in scan1Devices where scan2Devices[ip] == nil {
            changes.append(DeviceChange(
                deviceIP: ip,
                changeType: .removed,
                details: "Device left network: \(device.hostname ?? ip)",
                severity: .info
            ))
        }

        // Find modified devices
        for (ip, device1) in scan1Devices {
            guard let device2 = scan2Devices[ip] else { continue }

            // Check for port changes
            let ports1 = Set(device1.openPorts)
            let ports2 = Set(device2.openPorts)

            if ports1 != ports2 {
                let added = ports2.subtracting(ports1)
                let removed = ports1.subtracting(ports2)

                var detail = "Ports changed: "
                if !added.isEmpty {
                    detail += "Added \(Array(added).sorted().map { String($0) }.joined(separator: ", "))"
                }
                if !removed.isEmpty {
                    if !added.isEmpty { detail += "; " }
                    detail += "Removed \(Array(removed).sorted().map { String($0) }.joined(separator: ", "))"
                }

                changes.append(DeviceChange(
                    deviceIP: ip,
                    changeType: .portsChanged,
                    details: detail,
                    severity: added.contains(where: { [22, 23, 3389, 5900].contains($0) }) ? .warning : .info
                ))
            }

            // Check for hostname changes
            if device1.hostname != device2.hostname {
                changes.append(DeviceChange(
                    deviceIP: ip,
                    changeType: .hostnameChanged,
                    details: "Hostname changed: '\(device1.hostname ?? "none")' → '\(device2.hostname ?? "none")'",
                    severity: .info
                ))
            }

            // Check for status changes
            if device1.isOnline != device2.isOnline {
                changes.append(DeviceChange(
                    deviceIP: ip,
                    changeType: .statusChanged,
                    details: device2.isOnline ? "Device came online" : "Device went offline",
                    severity: device2.isOnline ? .info : .warning
                ))
            }

            // Check for rogue status changes
            if !device1.isRogue && device2.isRogue {
                changes.append(DeviceChange(
                    deviceIP: ip,
                    changeType: .becameRogue,
                    details: "Device flagged as rogue (previously trusted)",
                    severity: .critical
                ))
            } else if device1.isRogue && !device2.isRogue {
                changes.append(DeviceChange(
                    deviceIP: ip,
                    changeType: .trustedNow,
                    details: "Device now trusted (was rogue)",
                    severity: .info
                ))
            }
        }

        return ScanComparison(scan1: scan1, scan2: scan2, changes: changes)
    }
}

// MARK: - Scan Comparison UI

struct ScanComparisonView: View {
    let comparison: ScanComparison

    @State private var selectedFilter: ChangeFilter = .all

    enum ChangeFilter: String, CaseIterable {
        case all = "All Changes"
        case added = "New Devices"
        case removed = "Removed"
        case modified = "Modified"
        case critical = "Critical"
    }

    private var filteredChanges: [DeviceChange] {
        switch selectedFilter {
        case .all:
            return comparison.changes
        case .added:
            return comparison.changes.filter { $0.changeType == .added }
        case .removed:
            return comparison.changes.filter { $0.changeType == .removed }
        case .modified:
            return comparison.changes.filter { ![ChangeType.added, .removed].contains($0.changeType) }
        case .critical:
            return comparison.changes.filter { $0.severity == .critical }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Scan Comparison")
                        .font(.system(size: 28, weight: .bold))

                    Text(comparison.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()

            Divider()

            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(ChangeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Statistics cards
            HStack(spacing: 16) {
                StatCard(title: "New", count: comparison.newDevices.count, color: .green)
                StatCard(title: "Removed", count: comparison.removedDevices.count, color: .red)
                StatCard(title: "Modified", count: comparison.modifiedDevices.count, color: .orange)
                StatCard(title: "Unchanged", count: comparison.unchangedDevices.count, color: .gray)
            }
            .padding(.horizontal)

            Divider()
                .padding(.vertical)

            // Changes list
            if filteredChanges.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No changes in this category")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredChanges) { change in
                            ChangeRow(change: change)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 900, height: 700)
    }
}

// MARK: - Change Row

struct ChangeRow: View {
    let change: DeviceChange

    private var iconName: String {
        switch change.changeType {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .portsChanged: return "network"
        case .hostnameChanged: return "textformat.abc"
        case .statusChanged: return "power"
        case .becameRogue: return "exclamationmark.triangle.fill"
        case .trustedNow: return "checkmark.shield.fill"
        }
    }

    private var color: Color {
        switch change.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(change.changeType.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)

                Text(change.details)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Text(change.deviceIP)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Scan History Manager

@MainActor
class ScanHistoryManager: ObservableObject {
    static let shared = ScanHistoryManager()

    @Published var scans: [ScanSnapshot] = []

    private let storageKey = "NMAPScanner-ScanHistory"
    private let maxScans = 50  // Keep last 50 scans

    private init() {
        loadScans()
    }

    /// Save current scan to history
    func saveScan(devices: [EnhancedDevice], duration: TimeInterval) {
        let snapshot = ScanSnapshot(from: devices, duration: duration)
        scans.append(snapshot)

        // Limit to max scans
        if scans.count > maxScans {
            scans = Array(scans.suffix(maxScans))
        }

        saveScans()
        SecureLogger.log("Saved scan to history: \(devices.count) devices", level: .info)
    }

    /// Compare two scans
    func compare(scan1: ScanSnapshot, scan2: ScanSnapshot) -> ScanComparison {
        return ScanComparisonEngine.compare(scan1: scan1, scan2: scan2)
    }

    /// Get most recent scan
    func getMostRecentScan() -> ScanSnapshot? {
        return scans.last
    }

    /// Get scans in date range
    func getScans(from startDate: Date, to endDate: Date) -> [ScanSnapshot] {
        return scans.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    // MARK: - Persistence

    private func saveScans() {
        do {
            let data = try JSONEncoder().encode(scans)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            SecureLogger.log("Failed to save scan history: \(error)", level: .error)
        }
    }

    private func loadScans() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let savedScans = try? JSONDecoder().decode([ScanSnapshot].self, from: data) else {
            return
        }

        scans = savedScans
        SecureLogger.log("Loaded \(scans.count) scans from history", level: .info)
    }

    /// Clear all scan history
    func clearHistory() {
        scans.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        SecureLogger.log("Cleared scan history", level: .warning)
    }
}

#Preview {
    let scan1 = ScanSnapshot(from: [], duration: 10)
    let scan2 = ScanSnapshot(from: [], duration: 12)
    let comparison = ScanComparisonEngine.compare(scan1: scan1, scan2: scan2)

    return ScanComparisonView(comparison: comparison)
}
