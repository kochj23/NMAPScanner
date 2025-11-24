//
//  NetworkTrafficManager.swift
//  NMAP Scanner - Network Traffic Monitoring
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import Foundation
import Network
import Combine

/// Represents a monitored network connection
struct NetworkConnection: Identifiable {
    let id = UUID()
    let localEndpoint: String
    let remoteEndpoint: String
    let protocolType: String
    let state: NWConnection.State
    var bytesIn: Int64
    var bytesOut: Int64
    let startTime: Date
    var lastActivity: Date

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var stateDescription: String {
        switch state {
        case .setup: return "Setup"
        case .waiting: return "Waiting"
        case .preparing: return "Preparing"
        case .ready: return "Connected"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        @unknown default: return "Unknown"
        }
    }
}

/// Network traffic statistics
struct TrafficStatistics {
    var totalBytesIn: Int64 = 0
    var totalBytesOut: Int64 = 0
    var connectionCount: Int = 0
    var activeConnections: Int = 0
    var failedConnections: Int = 0
    var protocolBreakdown: [String: Int] = [:]

    var totalBytes: Int64 {
        totalBytesIn + totalBytesOut
    }

    func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Monitors network traffic and connection attempts
@MainActor
class NetworkTrafficManager: ObservableObject {
    @Published var activeConnections: [NetworkConnection] = []
    @Published var statistics = TrafficStatistics()
    @Published var isMonitoring = false
    @Published var recentActivity: [(timestamp: Date, description: String)] = []

    private var connectionMonitors: [UUID: NWPathMonitor] = [:]
    private let maxRecentActivity = 100
    private var updateTimer: Timer?

    // Connection tracking
    private var trackedConnections: [UUID: NetworkConnection] = [:]

    /// Start monitoring network traffic
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Start path monitoring
        startPathMonitoring()

        // Start periodic statistics update
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatistics()
            }
        }

        logActivity("Network monitoring started")
    }

    /// Stop monitoring network traffic
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        // Stop all monitors
        connectionMonitors.values.forEach { $0.cancel() }
        connectionMonitors.removeAll()

        updateTimer?.invalidate()
        updateTimer = nil

        logActivity("Network monitoring stopped")
    }

    /// Monitor network path changes
    private func startPathMonitoring() {
        let monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }

        let queue = DispatchQueue(label: "NetworkTrafficMonitor")
        monitor.start(queue: queue)

        let monitorId = UUID()
        connectionMonitors[monitorId] = monitor
    }

    /// Handle network path updates
    private func handlePathUpdate(_ path: NWPath) {
        let status = path.status == .satisfied ? "Connected" : "Disconnected"
        logActivity("Network status: \(status)")

        if path.status == .satisfied {
            // Log available interfaces
            path.availableInterfaces.forEach { interface in
                let type = interfaceType(interface.type)
                logActivity("Interface: \(interface.name) (\(type))")
            }
        }
    }

    /// Test connection to a specific endpoint
    func testConnection(host: String, port: Int, protocolParams: NWParameters) async -> NetworkConnection? {
        guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: portNumber,
            using: protocolParams
        )

        let connectionId = UUID()
        let startTime = Date()

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "connection-test-\(connectionId)")
            var hasResumed = false
            let lock = NSLock()

            connection.stateUpdateHandler = { [weak self] state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                Task { @MainActor in
                    // Determine protocol type
                    let protocolName = "TCP" // Simplified for now

                    switch state {
                    case .ready:
                        hasResumed = true

                        let conn = NetworkConnection(
                            localEndpoint: "Apple TV",
                            remoteEndpoint: "\(host):\(port)",
                            protocolType: protocolName,
                            state: state,
                            bytesIn: 0,
                            bytesOut: 0,
                            startTime: startTime,
                            lastActivity: Date()
                        )

                        self?.trackConnection(conn)
                        self?.logActivity("Connection established: \(host):\(port) (\(protocolName))")

                        connection.cancel()
                        continuation.resume(returning: conn)

                    case .failed(let error):
                        hasResumed = true

                        self?.logActivity("Connection failed: \(host):\(port) - \(error.localizedDescription)")
                        self?.statistics.failedConnections += 1

                        connection.cancel()
                        continuation.resume(returning: nil)

                    case .cancelled:
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: nil)
                        }

                    default:
                        break
                    }
                }
            }

            connection.start(queue: queue)

            // Timeout after 3 seconds
            queue.asyncAfter(deadline: .now() + 3) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Track a new connection
    private func trackConnection(_ connection: NetworkConnection) {
        trackedConnections[connection.id] = connection
        activeConnections.append(connection)

        statistics.connectionCount += 1
        statistics.activeConnections += 1

        let protocolName = connection.protocolType
        statistics.protocolBreakdown[protocolName, default: 0] += 1
    }

    /// Update connection with bandwidth data
    func updateConnection(id: UUID, bytesIn: Int64, bytesOut: Int64) {
        guard var connection = trackedConnections[id] else { return }

        let oldBytesIn = connection.bytesIn
        let oldBytesOut = connection.bytesOut

        connection.bytesIn = bytesIn
        connection.bytesOut = bytesOut
        connection.lastActivity = Date()

        trackedConnections[id] = connection

        // Update statistics
        statistics.totalBytesIn += (bytesIn - oldBytesIn)
        statistics.totalBytesOut += (bytesOut - oldBytesOut)

        // Update active connections list
        if let index = activeConnections.firstIndex(where: { $0.id == id }) {
            activeConnections[index] = connection
        }
    }

    /// Remove a connection
    func removeConnection(id: UUID) {
        trackedConnections.removeValue(forKey: id)
        activeConnections.removeAll { $0.id == id }
        statistics.activeConnections = max(0, statistics.activeConnections - 1)
    }

    /// Update statistics
    private func updateStatistics() {
        // Remove stale connections (no activity for 30 seconds)
        let staleThreshold = Date().addingTimeInterval(-30)
        let staleConnections = activeConnections.filter { $0.lastActivity < staleThreshold }

        staleConnections.forEach { removeConnection(id: $0.id) }
    }

    /// Log activity
    private func logActivity(_ description: String) {
        let entry = (timestamp: Date(), description: description)
        recentActivity.insert(entry, at: 0)

        if recentActivity.count > maxRecentActivity {
            recentActivity.removeLast()
        }
    }

    /// Clear all statistics
    func clearStatistics() {
        statistics = TrafficStatistics()
        recentActivity.removeAll()
        logActivity("Statistics cleared")
    }

    /// Get interface type name
    private func interfaceType(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
