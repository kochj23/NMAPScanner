//
//  NetworkTrafficAnalyzer.swift
//  NMAP Scanner - Real-time Network Traffic Analysis
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import Network
import SwiftUI

/// Manages real-time network traffic monitoring and analysis
@MainActor
class NetworkTrafficAnalyzer: ObservableObject {
    static let shared = NetworkTrafficAnalyzer()

    @Published var isMonitoring = false
    @Published var trafficStats: [String: DeviceTrafficStats] = [:]
    @Published var topTalkers: [DeviceTrafficStats] = []
    @Published var protocolBreakdown: [String: Int] = [:]
    @Published var anomalies: [TrafficAnomaly] = []

    private var monitoringTask: Task<Void, Never>?
    private var trafficHistory: [String: [TrafficDataPoint]] = [:]
    private let maxHistoryPoints = 100

    private init() {}

    // MARK: - Traffic Monitoring

    /// Start monitoring network traffic
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        print("📊 NetworkTrafficAnalyzer: Starting traffic monitoring")

        monitoringTask = Task.detached { [weak self] in
            while await self?.isMonitoring == true {
                await self?.captureTrafficSnapshot()
                try? await Task.sleep(for: .seconds(5)) // Capture every 5 seconds
            }
        }
    }

    /// Stop monitoring network traffic
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        print("📊 NetworkTrafficAnalyzer: Stopped traffic monitoring")
    }

    /// Capture a traffic snapshot
    private func captureTrafficSnapshot() async {
        // Use netstat to capture current connections
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-an", "-p", "tcp"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                await processNetstatOutput(output)
            }
        } catch {
            print("❌ NetworkTrafficAnalyzer: Failed to capture traffic: \(error)")
        }
    }

    /// Process netstat output
    private func processNetstatOutput(_ output: String) async {
        let lines = output.components(separatedBy: "\n")
        var connectionCounts: [String: Int] = [:]
        var protocolCounts: [String: Int] = [:]

        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            guard components.count >= 4 else { continue }

            let proto = components[0]
            let localAddress = components[3]

            // Extract IP address
            if let ip = extractIPAddress(from: localAddress) {
                connectionCounts[ip, default: 0] += 1
            }

            // Count protocols
            protocolCounts[proto, default: 0] += 1
        }

        await MainActor.run {
            updateTrafficStats(connectionCounts: connectionCounts, protocolCounts: protocolCounts)
        }
    }

    /// Extract IP address from netstat address string
    private func extractIPAddress(from address: String) -> String? {
        // Format: "192.168.1.100.80" or "192.168.1.100:80"
        let components = address.components(separatedBy: CharacterSet(charactersIn: ".:"))

        // IPv4: Take first 4 components
        if components.count >= 4 {
            return components[0..<4].joined(separator: ".")
        }

        return nil
    }

    /// Update traffic statistics
    private func updateTrafficStats(connectionCounts: [String: Int], protocolCounts: [String: Int]) {
        let timestamp = Date()

        // Update per-device stats
        for (ip, count) in connectionCounts {
            var stats = trafficStats[ip] ?? DeviceTrafficStats(ipAddress: ip)
            stats.activeConnections = count
            stats.lastUpdate = timestamp

            // Estimate bandwidth (rough approximation: connections * avg packet size)
            let estimatedBytesPerSec = count * 1500 // Assume 1500 bytes per connection
            stats.bytesPerSecond = estimatedBytesPerSec
            stats.totalBytes += estimatedBytesPerSec * 5 // 5-second interval

            // Add to history
            let dataPoint = TrafficDataPoint(timestamp: timestamp, bytesPerSecond: estimatedBytesPerSec, connections: count)
            trafficHistory[ip, default: []].append(dataPoint)

            // Limit history size
            if trafficHistory[ip]!.count > maxHistoryPoints {
                trafficHistory[ip]!.removeFirst()
            }

            stats.history = trafficHistory[ip] ?? []

            trafficStats[ip] = stats
        }

        // Update protocol breakdown
        protocolBreakdown = protocolCounts

        // Update top talkers
        topTalkers = trafficStats.values
            .sorted { $0.bytesPerSecond > $1.bytesPerSecond }
            .prefix(10)
            .map { $0 }

        // Detect anomalies
        detectTrafficAnomalies()
    }

    /// Detect traffic pattern anomalies
    private func detectTrafficAnomalies() {
        var detectedAnomalies: [TrafficAnomaly] = []

        for (ip, stats) in trafficStats {
            // High connection count anomaly
            if stats.activeConnections > 100 {
                let anomaly = TrafficAnomaly(
                    id: UUID(),
                    ipAddress: ip,
                    type: .highConnectionCount,
                    severity: .high,
                    description: "Device has \(stats.activeConnections) active connections",
                    timestamp: Date(),
                    value: Double(stats.activeConnections)
                )
                detectedAnomalies.append(anomaly)
            }

            // High bandwidth usage anomaly
            if stats.bytesPerSecond > 1_000_000 { // > 1 MB/s
                let mbps = Double(stats.bytesPerSecond) / 1_000_000
                let anomaly = TrafficAnomaly(
                    id: UUID(),
                    ipAddress: ip,
                    type: .highBandwidth,
                    severity: .medium,
                    description: String(format: "Device using %.2f MB/s bandwidth", mbps),
                    timestamp: Date(),
                    value: mbps
                )
                detectedAnomalies.append(anomaly)
            }

            // Sudden traffic spike
            if stats.history.count >= 10 {
                let recentAvg = stats.history.suffix(10).map { $0.bytesPerSecond }.reduce(0, +) / 10
                let previousAvg = stats.history.prefix(stats.history.count - 10).map { $0.bytesPerSecond }.reduce(0, +) / max(1, stats.history.count - 10)

                if recentAvg > previousAvg * 3 { // 3x spike
                    let anomaly = TrafficAnomaly(
                        id: UUID(),
                        ipAddress: ip,
                        type: .trafficSpike,
                        severity: .medium,
                        description: "Sudden traffic increase detected (3x baseline)",
                        timestamp: Date(),
                        value: Double(recentAvg) / Double(previousAvg)
                    )
                    detectedAnomalies.append(anomaly)
                }
            }
        }

        // Keep only recent anomalies (last 50)
        anomalies = (detectedAnomalies + anomalies).prefix(50).map { $0 }
    }

    // MARK: - Utility Methods

    /// Get traffic stats for a specific device
    func getStats(for ipAddress: String) -> DeviceTrafficStats? {
        return trafficStats[ipAddress]
    }

    /// Get total network bandwidth
    var totalBandwidth: Int {
        return trafficStats.values.map { $0.bytesPerSecond }.reduce(0, +)
    }

    /// Get total active connections
    var totalConnections: Int {
        return trafficStats.values.map { $0.activeConnections }.reduce(0, +)
    }

    /// Format bytes to human-readable string
    static func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    /// Format bandwidth to human-readable string
    static func formatBandwidth(_ bytesPerSecond: Int) -> String {
        let kbps = Double(bytesPerSecond) * 8 / 1024
        let mbps = kbps / 1024

        if mbps >= 1 {
            return String(format: "%.2f Mbps", mbps)
        } else {
            return String(format: "%.2f Kbps", kbps)
        }
    }
}

// MARK: - Data Models

/// Traffic statistics for a single device
struct DeviceTrafficStats: Identifiable, Codable {
    let id = UUID()
    let ipAddress: String
    var activeConnections: Int = 0
    var bytesPerSecond: Int = 0
    var totalBytes: Int = 0
    var lastUpdate: Date = Date()
    var history: [TrafficDataPoint] = []

    enum CodingKeys: String, CodingKey {
        case ipAddress, activeConnections, bytesPerSecond, totalBytes, lastUpdate, history
    }
}

/// Single traffic data point for historical tracking
struct TrafficDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let bytesPerSecond: Int
    let connections: Int

    enum CodingKeys: String, CodingKey {
        case timestamp, bytesPerSecond, connections
    }
}

/// Traffic anomaly detection result
struct TrafficAnomaly: Identifiable, Codable {
    let id: UUID
    let ipAddress: String
    let type: AnomalyType
    let severity: Severity
    let description: String
    let timestamp: Date
    let value: Double

    enum AnomalyType: String, Codable {
        case highConnectionCount = "High Connection Count"
        case highBandwidth = "High Bandwidth Usage"
        case trafficSpike = "Traffic Spike"
        case unusualProtocol = "Unusual Protocol"
    }

    enum Severity: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
    }
}
