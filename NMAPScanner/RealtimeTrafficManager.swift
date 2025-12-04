//
//  RealtimeTrafficManager.swift
//  NMAPScanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-29.
//  Real-time network traffic monitoring and visualization
//

import Foundation
import Network
import SwiftUI

/// Represents a network packet flow between devices
struct PacketFlow: Identifiable, Equatable {
    let id = UUID()
    let sourceIP: String
    let destinationIP: String
    let timestamp: Date
    let protocolType: ProtocolType
    let bytes: Int
    let port: Int?

    enum ProtocolType: String {
        case tcp = "TCP"
        case udp = "UDP"
        case icmp = "ICMP"
        case other = "Other"
    }

    var animationProgress: Double = 0.0

    static func == (lhs: PacketFlow, rhs: PacketFlow) -> Bool {
        lhs.id == rhs.id
    }
}

/// Device traffic statistics
struct RealtimeDeviceTrafficStats: Identifiable {
    let id: String // IP Address
    var bytesReceived: Int64 = 0
    var bytesSent: Int64 = 0
    var packetsReceived: Int64 = 0
    var packetsSent: Int64 = 0
    var lastActivity: Date = Date()
    var recentBytesPerSecond: Double = 0
    var protocolBreakdown: [String: Int] = [:] // Protocol -> packet count

    var totalBytes: Int64 { bytesReceived + bytesSent }
    var totalPackets: Int64 { packetsReceived + packetsSent }

    /// Activity level from 0.0 (idle) to 1.0 (very active)
    var activityLevel: Double {
        let maxBytesPerSecond: Double = 1_000_000 // 1 MB/s = max activity
        return min(recentBytesPerSecond / maxBytesPerSecond, 1.0)
    }

    /// Get heat map color based on activity
    var heatMapColor: Color {
        if activityLevel < 0.2 { return .green }
        if activityLevel < 0.5 { return .yellow }
        if activityLevel < 0.8 { return .orange }
        return .red
    }
}

/// Bandwidth history point for sparklines
struct BandwidthPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bytesPerSecond: Double
}

/// Real-time network traffic manager
@MainActor
class RealtimeTrafficManager: ObservableObject {
    static let shared = RealtimeTrafficManager()

    @Published var isMonitoring = false
    @Published var activeFlows: [PacketFlow] = []
    @Published var deviceStats: [String: RealtimeDeviceTrafficStats] = [:] // IP -> Stats
    @Published var totalBytesPerSecond: Double = 0
    @Published var totalPacketsPerSecond: Double = 0

    // Historical data for sparklines (keep last 60 data points = 1 minute at 1s intervals)
    @Published var bandwidthHistory: [String: [BandwidthPoint]] = [:] // IP -> history

    private var monitoringTask: Task<Void, Never>?
    private var animationTimer: Timer?
    private let maxFlowsDisplayed = 50 // Limit active flows for performance
    private let flowLifetime: TimeInterval = 3.0 // Flows disappear after 3 seconds

    private init() {}

    /// Start monitoring network traffic
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Start flow animation timer
        startFlowAnimations()

        // Start simulated traffic generation (for demo purposes)
        // In production, this would capture real packets
        startTrafficSimulation()
    }

    /// Stop monitoring network traffic
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }

    /// Add a packet flow to visualize
    func addPacketFlow(source: String, destination: String, protocolType: PacketFlow.ProtocolType, bytes: Int, port: Int? = nil) {
        let flow = PacketFlow(
            sourceIP: source,
            destinationIP: destination,
            timestamp: Date(),
            protocolType: protocolType,
            bytes: bytes,
            port: port
        )

        // Add to active flows
        activeFlows.append(flow)

        // Limit number of displayed flows
        if activeFlows.count > maxFlowsDisplayed {
            activeFlows.removeFirst(activeFlows.count - maxFlowsDisplayed)
        }

        // Update device stats
        updateDeviceStats(source: source, destination: destination, bytes: bytes, protocolType: protocolType)
    }

    /// Update statistics for devices
    private func updateDeviceStats(source: String, destination: String, bytes: Int, protocolType: PacketFlow.ProtocolType) {
        let now = Date()

        // Update source device (sending)
        var sourceStats = deviceStats[source] ?? RealtimeDeviceTrafficStats(id: source)
        sourceStats.bytesSent += Int64(bytes)
        sourceStats.packetsSent += 1
        sourceStats.lastActivity = now
        sourceStats.protocolBreakdown[protocolType.rawValue, default: 0] += 1
        deviceStats[source] = sourceStats

        // Update destination device (receiving)
        var destStats = deviceStats[destination] ?? RealtimeDeviceTrafficStats(id: destination)
        destStats.bytesReceived += Int64(bytes)
        destStats.packetsReceived += 1
        destStats.lastActivity = now
        destStats.protocolBreakdown[protocolType.rawValue, default: 0] += 1
        deviceStats[destination] = destStats

        // Update bandwidth calculations
        calculateBandwidth()
    }

    /// Calculate current bandwidth for all devices
    private func calculateBandwidth() {
        let oneSecondAgo = Date().addingTimeInterval(-1.0)
        var totalBytes: Double = 0
        var totalPackets: Double = 0

        for (ip, stats) in deviceStats {
            // Calculate bytes per second based on recent activity
            let recentBytes = Double(stats.totalBytes)
            deviceStats[ip]?.recentBytesPerSecond = recentBytes / 10.0 // Smoothed over 10s

            // Add to bandwidth history
            let point = BandwidthPoint(timestamp: Date(), bytesPerSecond: deviceStats[ip]?.recentBytesPerSecond ?? 0)
            var history = bandwidthHistory[ip] ?? []
            history.append(point)

            // Keep only last 60 points
            if history.count > 60 {
                history.removeFirst(history.count - 60)
            }
            bandwidthHistory[ip] = history

            totalBytes += deviceStats[ip]?.recentBytesPerSecond ?? 0
            totalPackets += Double(stats.totalPackets)
        }

        totalBytesPerSecond = totalBytes
        totalPacketsPerSecond = totalPackets / 60.0 // Average over last minute
    }

    /// Start animating packet flows
    private func startFlowAnimations() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFlowAnimations()
            }
        }
    }

    /// Update flow animations
    private func updateFlowAnimations() {
        let now = Date()

        // Update animation progress for each flow
        activeFlows = activeFlows.compactMap { flow in
            var updatedFlow = flow
            let elapsed = now.timeIntervalSince(flow.timestamp)
            updatedFlow.animationProgress = min(elapsed / flowLifetime, 1.0)

            // Remove flows that have completed animation
            return updatedFlow.animationProgress < 1.0 ? updatedFlow : nil
        }

        // Clean up old flows
        activeFlows = activeFlows.filter { flow in
            now.timeIntervalSince(flow.timestamp) < flowLifetime
        }
    }

    /// Get protocol breakdown for network
    func getProtocolBreakdown() -> [String: Int] {
        var breakdown: [String: Int] = [:]

        for stats in deviceStats.values {
            for (proto, count) in stats.protocolBreakdown {
                breakdown[proto, default: 0] += count
            }
        }

        return breakdown
    }

    /// Get most active devices (top 10)
    func getMostActiveDevices() -> [(String, Double)] {
        deviceStats
            .map { ($0.key, $0.value.recentBytesPerSecond) }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { ($0.0, $0.1) }
    }

    /// Format bytes to human readable
    func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1.0 { return String(format: "%.2f GB", gb) }
        if mb >= 1.0 { return String(format: "%.2f MB", mb) }
        if kb >= 1.0 { return String(format: "%.2f KB", kb) }
        return String(format: "%.0f B", bytes)
    }

    /// Format bandwidth rate
    func formatBandwidth(_ bytesPerSecond: Double) -> String {
        formatBytes(bytesPerSecond) + "/s"
    }

    /// Start simulated traffic (for demo/testing)
    private func startTrafficSimulation() {
        monitoringTask = Task { @MainActor in
            while !Task.isCancelled {
                // Simulate random network traffic
                let sourceIPs = ["192.168.1.1", "192.168.1.10", "192.168.1.20", "192.168.1.30"]
                let destIPs = ["192.168.1.100", "192.168.1.101", "192.168.1.102", "8.8.8.8"]
                let protocols: [PacketFlow.ProtocolType] = [.tcp, .udp, .icmp]

                let source = sourceIPs.randomElement()!
                let dest = destIPs.randomElement()!
                let proto = protocols.randomElement()!
                let bytes = Int.random(in: 64...1500)
                let port = [80, 443, 22, 53, 3389].randomElement()

                addPacketFlow(source: source, destination: dest, protocolType: proto, bytes: bytes, port: port)

                try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000)) // 0.1-0.5s
            }
        }
    }

    /// Reset all statistics
    func resetStats() {
        deviceStats.removeAll()
        bandwidthHistory.removeAll()
        activeFlows.removeAll()
        totalBytesPerSecond = 0
        totalPacketsPerSecond = 0
    }
}
