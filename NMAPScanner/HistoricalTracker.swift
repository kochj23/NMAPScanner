//
//  HistoricalTracker.swift
//  NMAPScanner
//
//  Historical device tracking and change detection system
//  Monitors device state changes, new devices, and network evolution over time
//  Created by Jordan Koch & Claude Code on 11/23/2025.
//

import Foundation
import SwiftUI

/// Historical device tracking and change detection
@MainActor
class HistoricalTracker: ObservableObject {
    static let shared = HistoricalTracker()

    // MARK: - Published Properties

    @Published var snapshots: [String: [DeviceSnapshot]] = [:] // IP -> [Snapshots]
    @Published var changes: [ChangeEvent] = []
    @Published var deviceTimelines: [String: DeviceTimeline] = [:] // IP -> Timeline

    private let userDefaults = UserDefaults.standard
    private let snapshotsKey = "device_snapshots"
    private let changesKey = "change_events"
    private let maxSnapshotsPerDevice = 100 // Limit history to prevent storage bloat
    private let maxChanges = 500 // Keep last 500 change events

    // MARK: - Data Models

    /// Snapshot of a device at a specific point in time
    struct DeviceSnapshot: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let ipAddress: String
        let macAddress: String?
        let hostname: String?
        let manufacturer: String?
        let deviceType: String
        let openPorts: [Int]
        let isOnline: Bool
        let threatLevel: String?

        init(from device: EnhancedDevice) {
            self.id = UUID()
            self.timestamp = Date()
            self.ipAddress = device.ipAddress
            self.macAddress = device.macAddress
            self.hostname = device.hostname
            self.manufacturer = device.manufacturer
            self.deviceType = device.deviceType.rawValue
            self.openPorts = device.openPorts.map { $0.port }
            self.isOnline = device.isOnline
            self.threatLevel = nil // Could integrate with ThreatAnalyzer
        }
    }

    /// Change event representing a detected difference
    struct ChangeEvent: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let ipAddress: String
        let macAddress: String?
        let hostname: String?
        let changeType: ChangeType
        let details: String
        let severity: ChangeSeverity

        enum ChangeType: String, Codable {
            case newDevice = "New Device"
            case deviceLeft = "Device Left"
            case deviceReturned = "Device Returned"
            case portsAdded = "Ports Opened"
            case portsRemoved = "Ports Closed"
            case hostnameChanged = "Hostname Changed"
            case deviceTypeChanged = "Device Type Changed"
            case statusChanged = "Status Changed"
        }

        enum ChangeSeverity: String, Codable {
            case info = "Info"
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
        }

        var icon: String {
            switch changeType {
            case .newDevice: return "plus.circle.fill"
            case .deviceLeft: return "minus.circle.fill"
            case .deviceReturned: return "arrow.clockwise.circle.fill"
            case .portsAdded: return "lock.open.fill"
            case .portsRemoved: return "lock.fill"
            case .hostnameChanged: return "network"
            case .deviceTypeChanged: return "wrench.fill"
            case .statusChanged: return "power"
            }
        }

        var color: Color {
            switch severity {
            case .info: return .blue
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }

    /// Timeline of a device's history
    struct DeviceTimeline: Identifiable {
        let id: UUID
        let ipAddress: String
        var firstSeen: Date
        var lastSeen: Date
        var totalAppearances: Int
        var snapshots: [DeviceSnapshot]
        var changes: [ChangeEvent]

        var uptimePercentage: Double {
            let totalTime = Date().timeIntervalSince(firstSeen)
            guard totalTime > 0 else { return 0 }
            let onlineTime = snapshots.filter { $0.isOnline }.count
            return Double(onlineTime) / Double(snapshots.count) * 100
        }
    }

    // MARK: - Initialization

    init() {
        loadHistory()
    }

    // MARK: - Snapshot Management

    /// Record a snapshot of the current device state
    func recordSnapshot(_ device: EnhancedDevice) {
        let snapshot = DeviceSnapshot(from: device)

        if snapshots[device.ipAddress] == nil {
            snapshots[device.ipAddress] = []
        }

        snapshots[device.ipAddress]?.append(snapshot)

        // Limit snapshots per device
        if let count = snapshots[device.ipAddress]?.count, count > maxSnapshotsPerDevice {
            snapshots[device.ipAddress]?.removeFirst(count - maxSnapshotsPerDevice)
        }

        updateTimeline(for: device.ipAddress)
        saveHistory()
    }

    /// Record snapshots for multiple devices
    func recordSnapshots(_ devices: [EnhancedDevice]) {
        for device in devices {
            recordSnapshot(device)
        }
    }

    /// Get all snapshots for a specific device
    func getDeviceHistory(for ipAddress: String) -> [DeviceSnapshot] {
        return snapshots[ipAddress] ?? []
    }

    /// Get the most recent snapshot for a device
    func getLatestSnapshot(for ipAddress: String) -> DeviceSnapshot? {
        return snapshots[ipAddress]?.last
    }

    // MARK: - Change Detection

    /// Detect changes between current scan and previous snapshots
    func detectChanges(current: [EnhancedDevice], previous: [String: DeviceSnapshot]) -> [ChangeEvent] {
        var detectedChanges: [ChangeEvent] = []

        let currentIPs = Set(current.map { $0.ipAddress })
        let previousIPs = Set(previous.keys)

        // Detect new devices
        let newIPs = currentIPs.subtracting(previousIPs)
        for ip in newIPs {
            if let device = current.first(where: { $0.ipAddress == ip }) {
                let change = ChangeEvent(
                    id: UUID(),
                    timestamp: Date(),
                    ipAddress: ip,
                    macAddress: device.macAddress,
                    hostname: device.hostname,
                    changeType: .newDevice,
                    details: "New device discovered: \(device.hostname ?? ip)",
                    severity: .medium
                )
                detectedChanges.append(change)
            }
        }

        // Detect devices that left
        let leftIPs = previousIPs.subtracting(currentIPs)
        for ip in leftIPs {
            if let previousSnapshot = previous[ip] {
                let change = ChangeEvent(
                    id: UUID(),
                    timestamp: Date(),
                    ipAddress: ip,
                    macAddress: previousSnapshot.macAddress,
                    hostname: previousSnapshot.hostname,
                    changeType: .deviceLeft,
                    details: "Device went offline: \(previousSnapshot.hostname ?? ip)",
                    severity: .low
                )
                detectedChanges.append(change)
            }
        }

        // Detect changes in existing devices
        for device in current {
            guard let previousSnapshot = previous[device.ipAddress] else { continue }

            let currentPorts = Set(device.openPorts.map { $0.port })
            let previousPorts = Set(previousSnapshot.openPorts)

            // Detect new open ports
            let newPorts = currentPorts.subtracting(previousPorts)
            if !newPorts.isEmpty {
                let severity: ChangeEvent.ChangeSeverity = newPorts.contains(where: { isHighRiskPort($0) }) ? .high : .medium
                let change = ChangeEvent(
                    id: UUID(),
                    timestamp: Date(),
                    ipAddress: device.ipAddress,
                    macAddress: device.macAddress,
                    hostname: device.hostname,
                    changeType: .portsAdded,
                    details: "New ports opened: \(newPorts.sorted().map(String.init).joined(separator: ", "))",
                    severity: severity
                )
                detectedChanges.append(change)
            }

            // Detect closed ports
            let closedPorts = previousPorts.subtracting(currentPorts)
            if !closedPorts.isEmpty {
                let change = ChangeEvent(
                    id: UUID(),
                    timestamp: Date(),
                    ipAddress: device.ipAddress,
                    macAddress: device.macAddress,
                    hostname: device.hostname,
                    changeType: .portsRemoved,
                    details: "Ports closed: \(closedPorts.sorted().map(String.init).joined(separator: ", "))",
                    severity: .low
                )
                detectedChanges.append(change)
            }

            // Detect hostname changes
            if let currentHostname = device.hostname,
               let previousHostname = previousSnapshot.hostname,
               currentHostname != previousHostname {
                let change = ChangeEvent(
                    id: UUID(),
                    timestamp: Date(),
                    ipAddress: device.ipAddress,
                    macAddress: device.macAddress,
                    hostname: currentHostname,
                    changeType: .hostnameChanged,
                    details: "Hostname changed: \(previousHostname) → \(currentHostname)",
                    severity: .info
                )
                detectedChanges.append(change)
            }

            // Detect device type changes
            if device.deviceType.rawValue != previousSnapshot.deviceType {
                let change = ChangeEvent(
                    id: UUID(),
                    timestamp: Date(),
                    ipAddress: device.ipAddress,
                    macAddress: device.macAddress,
                    hostname: device.hostname,
                    changeType: .deviceTypeChanged,
                    details: "Device type changed: \(previousSnapshot.deviceType) → \(device.deviceType.rawValue)",
                    severity: .medium
                )
                detectedChanges.append(change)
            }
        }

        return detectedChanges
    }

    /// Analyze a scan and detect all changes
    func analyzeAndRecordChanges(devices: [EnhancedDevice]) {
        // Get latest snapshots for comparison
        var previousSnapshots: [String: DeviceSnapshot] = [:]
        for (ip, snapshotArray) in snapshots {
            if let latest = snapshotArray.last {
                previousSnapshots[ip] = latest
            }
        }

        // Detect changes
        let newChanges = detectChanges(current: devices, previous: previousSnapshots)

        // Record changes
        changes.append(contentsOf: newChanges)

        // Limit total changes stored
        if changes.count > maxChanges {
            changes.removeFirst(changes.count - maxChanges)
        }

        // Record new snapshots
        recordSnapshots(devices)

        saveHistory()
    }

    // MARK: - Timeline Management

    private func updateTimeline(for ipAddress: String) {
        guard let deviceSnapshots = snapshots[ipAddress], !deviceSnapshots.isEmpty else { return }

        let firstSnapshot = deviceSnapshots.first!
        let lastSnapshot = deviceSnapshots.last!
        let deviceChanges = changes.filter { $0.ipAddress == ipAddress }

        let timeline = DeviceTimeline(
            id: UUID(),
            ipAddress: ipAddress,
            firstSeen: firstSnapshot.timestamp,
            lastSeen: lastSnapshot.timestamp,
            totalAppearances: deviceSnapshots.count,
            snapshots: deviceSnapshots,
            changes: deviceChanges
        )

        deviceTimelines[ipAddress] = timeline
    }

    func getTimeline(for ipAddress: String) -> DeviceTimeline? {
        return deviceTimelines[ipAddress]
    }

    // MARK: - Query Methods

    /// Get changes since a specific date
    func getChanges(since date: Date) -> [ChangeEvent] {
        return changes.filter { $0.timestamp >= date }
    }

    /// Get changes of a specific type
    func getChanges(ofType type: ChangeEvent.ChangeType) -> [ChangeEvent] {
        return changes.filter { $0.changeType == type }
    }

    /// Get changes with minimum severity
    func getChanges(minSeverity: ChangeEvent.ChangeSeverity) -> [ChangeEvent] {
        let severityOrder: [ChangeEvent.ChangeSeverity] = [.info, .low, .medium, .high, .critical]
        guard let minIndex = severityOrder.firstIndex(of: minSeverity) else { return [] }

        return changes.filter { change in
            if let changeIndex = severityOrder.firstIndex(of: change.severity) {
                return changeIndex >= minIndex
            }
            return false
        }
    }

    /// Get all devices that have appeared on the network
    func getAllKnownDevices() -> [String] {
        return Array(snapshots.keys)
    }

    /// Get devices seen within a time period
    func getDevicesSeen(since date: Date) -> [String] {
        return snapshots.filter { _, snapshots in
            snapshots.contains { $0.timestamp >= date }
        }.map { $0.key }
    }

    /// Get statistics for a device
    func getDeviceStatistics(for ipAddress: String) -> DeviceStatistics? {
        guard let deviceSnapshots = snapshots[ipAddress], !deviceSnapshots.isEmpty else { return nil }

        let onlineCount = deviceSnapshots.filter { $0.isOnline }.count
        let offlineCount = deviceSnapshots.count - onlineCount
        let uptimePercentage = Double(onlineCount) / Double(deviceSnapshots.count) * 100

        let allPorts = Set(deviceSnapshots.flatMap { $0.openPorts })
        let deviceChanges = changes.filter { $0.ipAddress == ipAddress }

        return DeviceStatistics(
            ipAddress: ipAddress,
            firstSeen: deviceSnapshots.first!.timestamp,
            lastSeen: deviceSnapshots.last!.timestamp,
            totalScans: deviceSnapshots.count,
            onlineScans: onlineCount,
            offlineScans: offlineCount,
            uptimePercentage: uptimePercentage,
            uniquePortsSeen: allPorts.count,
            totalChanges: deviceChanges.count
        )
    }

    struct DeviceStatistics {
        let ipAddress: String
        let firstSeen: Date
        let lastSeen: Date
        let totalScans: Int
        let onlineScans: Int
        let offlineScans: Int
        let uptimePercentage: Double
        let uniquePortsSeen: Int
        let totalChanges: Int
    }

    // MARK: - Helper Methods

    private func isHighRiskPort(_ port: Int) -> Bool {
        // Common high-risk ports
        let highRiskPorts = [
            21, 22, 23, 25, 53, 135, 139, 445, 1433, 1434, 3306, 3389, 5432, 5900, 6379, 8080, 8888, 27017
        ]
        return highRiskPorts.contains(port)
    }

    // MARK: - Persistence

    private func loadHistory() {
        // Load snapshots
        if let data = userDefaults.data(forKey: snapshotsKey),
           let decoded = try? JSONDecoder().decode([String: [DeviceSnapshot]].self, from: data) {
            snapshots = decoded
        }

        // Load changes
        if let data = userDefaults.data(forKey: changesKey),
           let decoded = try? JSONDecoder().decode([ChangeEvent].self, from: data) {
            changes = decoded
        }

        // Rebuild timelines
        for ip in snapshots.keys {
            updateTimeline(for: ip)
        }
    }

    private func saveHistory() {
        // Save snapshots
        if let data = try? JSONEncoder().encode(snapshots) {
            userDefaults.set(data, forKey: snapshotsKey)
        }

        // Save changes
        if let data = try? JSONEncoder().encode(changes) {
            userDefaults.set(data, forKey: changesKey)
        }
    }

    /// Clear all historical data
    func clearHistory() {
        snapshots.removeAll()
        changes.removeAll()
        deviceTimelines.removeAll()
        saveHistory()
    }

    /// Clear history older than specified date
    func clearHistory(olderThan date: Date) {
        // Remove old snapshots
        for (ip, deviceSnapshots) in snapshots {
            snapshots[ip] = deviceSnapshots.filter { $0.timestamp >= date }
        }

        // Remove empty entries
        snapshots = snapshots.filter { !$0.value.isEmpty }

        // Remove old changes
        changes = changes.filter { $0.timestamp >= date }

        saveHistory()
    }
}

// MARK: - Historical Views

/// View showing device change history timeline
struct HistoricalTimelineView: View {
    @StateObject private var tracker = HistoricalTracker.shared
    @State private var filterType: ChangeFilterType = .all
    @State private var showingFilters = false

    enum ChangeFilterType: String, CaseIterable {
        case all = "All Changes"
        case critical = "Critical"
        case high = "High Priority"
        case today = "Today"
        case week = "This Week"
    }

    var filteredChanges: [HistoricalTracker.ChangeEvent] {
        switch filterType {
        case .all:
            return tracker.changes
        case .critical:
            return tracker.getChanges(minSeverity: .critical)
        case .high:
            return tracker.getChanges(minSeverity: .high)
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return tracker.getChanges(since: today)
        case .week:
            let week = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return tracker.getChanges(since: week)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter bar
                HStack {
                    Text("Filter:")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)

                    Picker("Filter", selection: $filterType) {
                        ForEach(ChangeFilterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                if filteredChanges.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                        Text("No Changes Detected")
                            .font(.system(size: 32, weight: .semibold))
                        Text("Start scanning to track device changes over time")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List {
                        ForEach(filteredChanges.reversed()) { change in
                            ChangeEventRow(change: change)
                        }
                    }
                }
            }
            .navigationTitle("Network History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear Old") {
                        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
                        tracker.clearHistory(olderThan: twoWeeksAgo)
                    }
                }
            }
        }
    }
}

struct ChangeEventRow: View {
    let change: HistoricalTracker.ChangeEvent

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: change.icon)
                .font(.system(size: 32))
                .foregroundColor(change.color)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 8) {
                Text(change.changeType.rawValue)
                    .font(.system(size: 24, weight: .semibold))

                Text(change.details)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                HStack {
                    Text(change.ipAddress)
                        .font(.system(size: 18))
                        .foregroundColor(.blue)

                    if let hostname = change.hostname {
                        Text("• \(hostname)")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(change.timestamp, style: .relative)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// What's New dashboard widget showing recent changes
struct WhatsNewWidget: View {
    @StateObject private var tracker = HistoricalTracker.shared

    var recentChanges: [HistoricalTracker.ChangeEvent] {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return tracker.getChanges(since: oneDayAgo).suffix(5).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text("What's New")
                    .font(.system(size: 36, weight: .bold))
            }

            if recentChanges.isEmpty {
                Text("No recent changes detected")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentChanges) { change in
                    HStack(spacing: 12) {
                        Image(systemName: change.icon)
                            .font(.system(size: 24))
                            .foregroundColor(change.color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(change.changeType.rawValue)
                                .font(.system(size: 20, weight: .semibold))
                            Text(change.details)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(change.timestamp, style: .relative)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(30)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}

/// Device timeline detail view
struct DeviceTimelineView: View {
    let ipAddress: String
    @StateObject private var tracker = HistoricalTracker.shared

    var timeline: HistoricalTracker.DeviceTimeline? {
        tracker.getTimeline(for: ipAddress)
    }

    var statistics: HistoricalTracker.DeviceStatistics? {
        tracker.getDeviceStatistics(for: ipAddress)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Statistics summary
                if let stats = statistics {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Statistics")
                            .font(.system(size: 36, weight: .bold))

                        HStack(spacing: 40) {
                            StatItem(label: "Uptime", value: String(format: "%.1f%%", stats.uptimePercentage))
                            StatItem(label: "Total Scans", value: "\(stats.totalScans)")
                            StatItem(label: "Unique Ports", value: "\(stats.uniquePortsSeen)")
                            StatItem(label: "Changes", value: "\(stats.totalChanges)")
                        }

                        HStack(spacing: 40) {
                            VStack(spacing: 8) {
                                Text("First Seen")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                                Text(stats.firstSeen, style: .date)
                                    .font(.system(size: 20, weight: .semibold))
                            }

                            VStack(spacing: 8) {
                                Text("Last Seen")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                                Text(stats.lastSeen, style: .date)
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                    }
                    .padding(30)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }

                // Change history
                if let timeline = timeline, !timeline.changes.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Change History")
                            .font(.system(size: 36, weight: .bold))

                        ForEach(timeline.changes.reversed()) { change in
                            ChangeEventRow(change: change)
                        }
                    }
                }
            }
            .padding(40)
        }
        .navigationTitle("Device History")
    }
}
