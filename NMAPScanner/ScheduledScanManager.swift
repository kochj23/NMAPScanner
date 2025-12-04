//
//  ScheduledScanManager.swift
//  NMAP Scanner - Scheduled Automatic Scanning
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import SwiftUI

/// Manages scheduled automatic network scans
@MainActor
class ScheduledScanManager: ObservableObject {
    static let shared = ScheduledScanManager()

    @Published var isEnabled = false
    @Published var scanInterval: ScanInterval = .hourly
    @Published var lastScanTime: Date?
    @Published var nextScanTime: Date?
    @Published var scanHistory: [ScheduledScanResult] = []

    private var timer: Timer?
    private let userDefaults = UserDefaults.standard

    // UserDefaults keys
    private let enabledKey = "ScheduledScanEnabled"
    private let intervalKey = "ScheduledScanInterval"
    private let lastScanKey = "ScheduledScanLastTime"

    private init() {
        loadSettings()
        if isEnabled {
            startScheduledScans()
        }
    }

    /// Scan intervals
    enum ScanInterval: String, CaseIterable, Codable {
        case fifteenMinutes = "Every 15 Minutes"
        case thirtyMinutes = "Every 30 Minutes"
        case hourly = "Every Hour"
        case everyTwoHours = "Every 2 Hours"
        case everySixHours = "Every 6 Hours"
        case daily = "Daily"

        var seconds: TimeInterval {
            switch self {
            case .fifteenMinutes: return 15 * 60
            case .thirtyMinutes: return 30 * 60
            case .hourly: return 60 * 60
            case .everyTwoHours: return 2 * 60 * 60
            case .everySixHours: return 6 * 60 * 60
            case .daily: return 24 * 60 * 60
            }
        }
    }

    /// Load settings from UserDefaults
    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: enabledKey)
        if let intervalString = userDefaults.string(forKey: intervalKey),
           let interval = ScanInterval(rawValue: intervalString) {
            scanInterval = interval
        }
        lastScanTime = userDefaults.object(forKey: lastScanKey) as? Date
        updateNextScanTime()
    }

    /// Save settings to UserDefaults
    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: enabledKey)
        userDefaults.set(scanInterval.rawValue, forKey: intervalKey)
        if let lastScanTime = lastScanTime {
            userDefaults.set(lastScanTime, forKey: lastScanKey)
        }
    }

    /// Enable scheduled scanning
    func enable(with interval: ScanInterval) {
        isEnabled = true
        scanInterval = interval
        saveSettings()
        startScheduledScans()
        print("📅 ScheduledScanManager: Enabled with interval \(interval.rawValue)")
    }

    /// Disable scheduled scanning
    func disable() {
        isEnabled = false
        saveSettings()
        stopScheduledScans()
        print("📅 ScheduledScanManager: Disabled")
    }

    /// Start scheduled scans
    private func startScheduledScans() {
        stopScheduledScans() // Stop any existing timer

        let interval = scanInterval.seconds
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performScheduledScan()
            }
        }

        updateNextScanTime()
        print("📅 ScheduledScanManager: Started timer with interval \(scanInterval.rawValue)")
    }

    /// Stop scheduled scans
    private func stopScheduledScans() {
        timer?.invalidate()
        timer = nil
        nextScanTime = nil
    }

    /// Update next scan time
    private func updateNextScanTime() {
        if isEnabled, let lastScan = lastScanTime {
            nextScanTime = lastScan.addingTimeInterval(scanInterval.seconds)
        } else if isEnabled {
            nextScanTime = Date().addingTimeInterval(scanInterval.seconds)
        } else {
            nextScanTime = nil
        }
    }

    /// Perform a scheduled scan
    func performScheduledScan() async {
        print("📅 ScheduledScanManager: Starting scheduled scan...")

        lastScanTime = Date()
        saveSettings()
        updateNextScanTime()

        // Perform the scan via IntegratedScannerV3
        // This will be called from the dashboard view
        NotificationCenter.default.post(name: .performScheduledScan, object: nil)

        print("📅 ScheduledScanManager: Scheduled scan initiated")
    }

    /// Record scan result
    func recordScanResult(deviceCount: Int, duration: TimeInterval, anomaliesFound: Int) {
        let result = ScheduledScanResult(
            timestamp: Date(),
            deviceCount: deviceCount,
            duration: duration,
            anomaliesFound: anomaliesFound
        )

        scanHistory.append(result)

        // Keep only last 100 scans
        if scanHistory.count > 100 {
            scanHistory.removeFirst(scanHistory.count - 100)
        }
    }

    /// Get time until next scan
    var timeUntilNextScan: String? {
        guard let nextScan = nextScanTime else { return nil }

        let now = Date()
        let interval = nextScan.timeIntervalSince(now)

        if interval < 0 {
            return "Scanning soon..."
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Scan Result Model

struct ScheduledScanResult: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let deviceCount: Int
    let duration: TimeInterval
    let anomaliesFound: Int
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let performScheduledScan = Notification.Name("performScheduledScan")
}
