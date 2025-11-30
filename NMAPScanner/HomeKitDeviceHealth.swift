//
//  HomeKitDeviceHealth.swift
//  NMAP Plus Security Scanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Monitors health and connectivity of HomeKit devices:
//  - Connection quality assessment
//  - Response time measurement
//  - Signal strength tracking
//  - Availability monitoring
//

import Foundation
import Network

/// Health status for a HomeKit device
struct DeviceHealth: Identifiable {
    let id: String  // device ID
    let timestamp: Date
    let quality: ConnectionQuality
    let responseTime: TimeInterval?  // milliseconds
    let isReachable: Bool
    let lastSeen: Date

    enum ConnectionQuality: String, Comparable {
        case excellent = "Excellent"  // <50ms, always reachable
        case good = "Good"             // <100ms, reliable
        case fair = "Fair"             // <300ms, occasional issues
        case poor = "Poor"             // >300ms or intermittent
        case offline = "Offline"       // Not reachable

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "orange"
            case .offline: return "red"
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "antenna.radiowaves.left.and.right"
            case .good: return "wifi"
            case .fair: return "wifi.slash"
            case .poor: return "exclamationmark.triangle"
            case .offline: return "xmark.circle"
            }
        }

        static func < (lhs: ConnectionQuality, rhs: ConnectionQuality) -> Bool {
            let order: [ConnectionQuality] = [.offline, .poor, .fair, .good, .excellent]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
}

/// Manages health monitoring for HomeKit devices
@MainActor
class HomeKitDeviceHealthMonitor: ObservableObject {

    static let shared = HomeKitDeviceHealthMonitor()

    // MARK: - Published Properties

    @Published var deviceHealth: [String: DeviceHealth] = [:]

    // MARK: - Private Properties

    private var monitoringTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Public Methods

    /// Start monitoring a device
    func startMonitoring(device: HomeKitDevice) {
        // Cancel existing monitoring task
        monitoringTasks[device.id]?.cancel()

        // Start new monitoring task
        let task = Task {
            await monitorDevice(device)
        }
        monitoringTasks[device.id] = task
    }

    /// Stop monitoring a device
    func stopMonitoring(deviceID: String) {
        monitoringTasks[deviceID]?.cancel()
        monitoringTasks.removeValue(forKey: deviceID)
    }

    /// Stop all monitoring
    func stopAllMonitoring() {
        for task in monitoringTasks.values {
            task.cancel()
        }
        monitoringTasks.removeAll()
    }

    /// Get health for device
    func health(for deviceID: String) -> DeviceHealth? {
        return deviceHealth[deviceID]
    }

    /// Perform quick health check
    func quickHealthCheck(for device: HomeKitDevice) async -> DeviceHealth {
        guard let ipAddress = device.ipAddress else {
            return DeviceHealth(
                id: device.id,
                timestamp: Date(),
                quality: .offline,
                responseTime: nil,
                isReachable: false,
                lastSeen: device.discoveredAt
            )
        }

        // Measure response time with TCP connection test
        let startTime = Date()
        let isReachable = await testConnection(to: ipAddress, port: 80, timeout: 3.0)
        let responseTime = Date().timeIntervalSince(startTime) * 1000  // Convert to ms

        let quality = assessQuality(responseTime: responseTime, isReachable: isReachable)

        let health = DeviceHealth(
            id: device.id,
            timestamp: Date(),
            quality: quality,
            responseTime: isReachable ? responseTime : nil,
            isReachable: isReachable,
            lastSeen: isReachable ? Date() : device.discoveredAt
        )

        await MainActor.run {
            deviceHealth[device.id] = health
        }

        return health
    }

    // MARK: - Private Methods

    private func monitorDevice(_ device: HomeKitDevice) async {
        print("📊 Health Monitor: Started monitoring \(device.displayName)")

        // Perform initial health check
        _ = await quickHealthCheck(for: device)

        // Continue monitoring every 30 seconds
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds

            if Task.isCancelled { break }

            _ = await quickHealthCheck(for: device)
        }

        print("📊 Health Monitor: Stopped monitoring \(device.displayName)")
    }

    private func testConnection(to host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            var hasResumed = false
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !hasResumed {
                        hasResumed = true
                        timeoutTimer.invalidate()
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed:
                    if !hasResumed {
                        hasResumed = true
                        timeoutTimer.invalidate()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    private func assessQuality(responseTime: TimeInterval, isReachable: Bool) -> DeviceHealth.ConnectionQuality {
        guard isReachable else { return .offline }

        if responseTime < 50 {
            return .excellent
        } else if responseTime < 100 {
            return .good
        } else if responseTime < 300 {
            return .fair
        } else {
            return .poor
        }
    }
}
