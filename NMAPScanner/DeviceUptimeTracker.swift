//
//  DeviceUptimeTracker.swift
//  NMAPScanner - Device Uptime and Availability Tracking
//
//  Tracks device online/offline history and calculates uptime percentages
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation

// MARK: - Uptime Record

struct UptimeRecord: Codable {
    let deviceID: String  // IP address or MAC
    var observations: [UptimeObservation]
    var firstSeen: Date
    var lastSeen: Date

    var totalObservations: Int {
        observations.count
    }

    var onlineObservations: Int {
        observations.filter { $0.wasOnline }.count
    }

    var uptimePercentage: Double {
        guard totalObservations > 0 else { return 0.0 }
        return Double(onlineObservations) / Double(totalObservations) * 100.0
    }

    var reliability: ReliabilityRating {
        let uptime = uptimePercentage
        if uptime >= 99.0 {
            return .excellent
        } else if uptime >= 95.0 {
            return .good
        } else if uptime >= 85.0 {
            return .fair
        } else if uptime >= 70.0 {
            return .poor
        } else {
            return .unstable
        }
    }

    var averageResponseTime: TimeInterval? {
        let responseTimes = observations.compactMap { $0.responseTime }
        guard !responseTimes.isEmpty else { return nil }
        return responseTimes.reduce(0.0, +) / Double(responseTimes.count)
    }

    var downtimeEvents: [DowntimeEvent] {
        var events: [DowntimeEvent] = []
        var currentDowntime: Date?

        for observation in observations.sorted(by: { $0.timestamp < $1.timestamp }) {
            if !observation.wasOnline && currentDowntime == nil {
                currentDowntime = observation.timestamp
            } else if observation.wasOnline && currentDowntime != nil {
                let duration = observation.timestamp.timeIntervalSince(currentDowntime!)
                events.append(DowntimeEvent(
                    start: currentDowntime!,
                    end: observation.timestamp,
                    duration: duration
                ))
                currentDowntime = nil
            }
        }

        // Still offline?
        if let start = currentDowntime {
            events.append(DowntimeEvent(
                start: start,
                end: Date(),
                duration: Date().timeIntervalSince(start)
            ))
        }

        return events
    }
}

struct UptimeObservation: Codable {
    let timestamp: Date
    let wasOnline: Bool
    let responseTime: TimeInterval?  // In milliseconds
}

struct DowntimeEvent: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let duration: TimeInterval

    var durationString: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

enum ReliabilityRating: String {
    case excellent = "Excellent"  // 99%+
    case good = "Good"            // 95-99%
    case fair = "Fair"            // 85-95%
    case poor = "Poor"            // 70-85%
    case unstable = "Unstable"    // <70%

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .unstable: return "red"
        }
    }

    var emoji: String {
        switch self {
        case .excellent: return "✅"
        case .good: return "✓"
        case .fair: return "⚠️"
        case .poor: return "⚠️"
        case .unstable: return "❌"
        }
    }
}

// MARK: - Uptime Tracker

@MainActor
class DeviceUptimeTracker: ObservableObject {
    static let shared = DeviceUptimeTracker()

    @Published var uptimeRecords: [String: UptimeRecord] = [:]

    private let storageKey = "NMAPScanner-UptimeRecords"
    private let maxObservationsPerDevice = 1000  // Keep last 1000 observations

    private init() {
        loadRecords()
    }

    // MARK: - Recording

    /// Record device observation (online or offline)
    func recordObservation(deviceID: String, isOnline: Bool, responseTime: TimeInterval? = nil) {
        let observation = UptimeObservation(
            timestamp: Date(),
            wasOnline: isOnline,
            responseTime: responseTime
        )

        if var record = uptimeRecords[deviceID] {
            // Update existing record
            record.observations.append(observation)
            record.lastSeen = Date()

            // Limit observations
            if record.observations.count > maxObservationsPerDevice {
                record.observations = Array(record.observations.suffix(maxObservationsPerDevice))
            }

            uptimeRecords[deviceID] = record
        } else {
            // Create new record
            uptimeRecords[deviceID] = UptimeRecord(
                deviceID: deviceID,
                observations: [observation],
                firstSeen: Date(),
                lastSeen: Date()
            )
        }

        saveRecords()
    }

    /// Record multiple observations (batch processing after scan)
    func recordScanResults(onlineDevices: [String: TimeInterval], allKnownDevices: [String]) {
        let timestamp = Date()

        // Record online devices with response times
        for (deviceID, responseTime) in onlineDevices {
            recordObservation(deviceID: deviceID, isOnline: true, responseTime: responseTime)
        }

        // Record offline devices (devices we've seen before but not in this scan)
        let offlineDevices = Set(allKnownDevices).subtracting(Set(onlineDevices.keys))
        for deviceID in offlineDevices {
            recordObservation(deviceID: deviceID, isOnline: false)
        }

        SecureLogger.log("Recorded uptime for \(onlineDevices.count) online, \(offlineDevices.count) offline devices", level: .info)
    }

    // MARK: - Queries

    /// Get uptime record for device
    func getUptimeRecord(for deviceID: String) -> UptimeRecord? {
        return uptimeRecords[deviceID]
    }

    /// Get all devices with low uptime (< 90%)
    func getUnreliableDevices(threshold: Double = 90.0) -> [UptimeRecord] {
        return uptimeRecords.values.filter { $0.uptimePercentage < threshold }
            .sorted { $0.uptimePercentage < $1.uptimePercentage }
    }

    /// Get devices by reliability rating
    func getDevicesByReliability(_ rating: ReliabilityRating) -> [UptimeRecord] {
        return uptimeRecords.values.filter { $0.reliability == rating }
    }

    /// Get devices with recent downtime
    func getRecentlyDownDevices(since: Date) -> [UptimeRecord] {
        return uptimeRecords.values.filter { record in
            record.downtimeEvents.contains { $0.start >= since }
        }
    }

    /// Get statistics
    func getStatistics() -> UptimeStatistics {
        let records = Array(uptimeRecords.values)

        let avgUptime = records.isEmpty ? 0.0 : records.map { $0.uptimePercentage }.reduce(0.0, +) / Double(records.count)

        let reliabilityCounts = [
            ReliabilityRating.excellent: records.filter { $0.reliability == .excellent }.count,
            .good: records.filter { $0.reliability == .good }.count,
            .fair: records.filter { $0.reliability == .fair }.count,
            .poor: records.filter { $0.reliability == .poor }.count,
            .unstable: records.filter { $0.reliability == .unstable }.count
        ]

        return UptimeStatistics(
            totalDevices: records.count,
            averageUptime: avgUptime,
            reliabilityCounts: reliabilityCounts,
            mostReliable: records.max { $0.uptimePercentage < $1.uptimePercentage },
            leastReliable: records.min { $0.uptimePercentage < $1.uptimePercentage }
        )
    }

    // MARK: - Persistence

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(uptimeRecords)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            SecureLogger.log("Failed to save uptime records: \(error)", level: .error)
        }
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([String: UptimeRecord].self, from: data) else {
            return
        }

        uptimeRecords = records
        SecureLogger.log("Loaded uptime records for \(records.count) devices", level: .info)
    }

    /// Clear all uptime data
    func clearAllRecords() {
        uptimeRecords.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        SecureLogger.log("Cleared all uptime records", level: .warning)
    }

    /// Clear old records (older than retention period)
    func clearOldRecords(olderThan days: Int) {
        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))

        uptimeRecords = uptimeRecords.filter { $0.value.lastSeen >= cutoffDate }
        saveRecords()

        SecureLogger.log("Cleared uptime records older than \(days) days", level: .info)
    }
}

// MARK: - Statistics

struct UptimeStatistics {
    let totalDevices: Int
    let averageUptime: Double
    let reliabilityCounts: [ReliabilityRating: Int]
    let mostReliable: UptimeRecord?
    let leastReliable: UptimeRecord?
}
