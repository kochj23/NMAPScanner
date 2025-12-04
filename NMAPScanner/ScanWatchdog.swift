//
//  ScanWatchdog.swift
//  NMAP Plus Security Scanner - Scan Timeout Watchdog
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation

/// Watchdog that monitors scanning operations and terminates hung scans
@MainActor
class ScanWatchdog: ObservableObject {
    static let shared = ScanWatchdog()

    @Published var isMonitoring = false
    @Published var lastProgressUpdate: Date?
    @Published var timeoutWarning: String?

    private var watchdogTask: Task<Void, Never>?
    private let maxStallTime: TimeInterval = 30.0 // 30 seconds without progress = hung

    private init() {}

    /// Start monitoring a scan operation
    func startMonitoring(operation: String) {
        print("🐕 ScanWatchdog: Starting monitoring for \(operation)")
        isMonitoring = true
        lastProgressUpdate = Date()
        timeoutWarning = nil

        // Cancel any existing watchdog
        watchdogTask?.cancel()

        // Start new watchdog task
        watchdogTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5 seconds

                guard let lastUpdate = lastProgressUpdate else {
                    continue
                }

                let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

                if timeSinceLastUpdate > maxStallTime {
                    print("⚠️ ScanWatchdog: Scan appears to be hung! No progress for \(Int(timeSinceLastUpdate))s")
                    timeoutWarning = "⚠️ Scan may be hung (no progress for \(Int(timeSinceLastUpdate))s)"

                    // After 60 seconds with no progress, force terminate
                    if timeSinceLastUpdate > 60.0 {
                        print("🚨 ScanWatchdog: FORCE TERMINATING hung scan operation!")
                        timeoutWarning = "🚨 Scan hung - force terminated"
                        self.forceTerminate()
                        break
                    }
                }
            }
        }
    }

    /// Update progress (resets the watchdog timer)
    func updateProgress() {
        lastProgressUpdate = Date()
        timeoutWarning = nil
    }

    /// Stop monitoring
    func stopMonitoring() {
        print("🐕 ScanWatchdog: Stopping monitoring")
        watchdogTask?.cancel()
        watchdogTask = nil
        isMonitoring = false
        lastProgressUpdate = nil
        timeoutWarning = nil
    }

    /// Force terminate the current scan
    private func forceTerminate() {
        print("🚨 ScanWatchdog: Force terminating scan operation")
        // Cancel all active scanning tasks by posting a notification
        NotificationCenter.default.post(name: .scanWatchdogTimeout, object: nil)
        stopMonitoring()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let scanWatchdogTimeout = Notification.Name("ScanWatchdogTimeout")
}
