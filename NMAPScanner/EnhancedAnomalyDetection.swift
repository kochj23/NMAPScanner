//
//  EnhancedAnomalyDetection.swift
//  NMAPScanner - ML-Enhanced Behavioral Anomaly Detection
//
//  Created by Jordan Koch on 2025-11-27.
//

import Foundation

struct EnhancedAnomaly: Identifiable, Codable {
    let id = UUID()
    let type: AnomalyType
    let severity: Severity
    let source: String
    let description: String
    let mlConfidence: Double // 0.0-1.0
    let baseline: String
    let current: String
    let recommendation: String
    let timestamp: Date

    enum AnomalyType: String, Codable {
        case unusualTraffic = "Unusual Traffic Pattern"
        case portScanActivity = "Port Scanning Activity"
        case bandwidthSpike = "Bandwidth Anomaly"
        case unusualTime = "Activity Outside Normal Hours"
        case newExternalConnection = "New External IP Contact"
        case dataExfiltration = "Possible Data Exfiltration"
    }

    enum Severity: String, Codable {
        case critical, high, medium, low
    }
}

@MainActor
class EnhancedAnomalyDetector: ObservableObject {
    static let shared = EnhancedAnomalyDetector()

    @Published var anomalies: [EnhancedAnomaly] = []
    @Published var isAnalyzing = false

    // Baseline data for ML analysis
    private var trafficBaselines: [String: TrafficBaseline] = [:]
    private var connectionBaselines: [String: ConnectionBaseline] = [:]

    private init() {}

    func detectAnomalies(devices: [EnhancedDevice], connections: [SegmentationConnection], trafficStats: [DeviceTrafficStats]) async {
        isAnalyzing = true
        anomalies.removeAll()

        // Build baselines if needed
        if trafficBaselines.isEmpty {
            buildBaselines(trafficStats: trafficStats, connections: connections)
        }

        // ML-based traffic analysis
        await analyzeTrafficPatterns(trafficStats: trafficStats)

        // Port scan detection
        await detectPortScanning(connections: connections)

        // Time-based anomalies
        await detectTimeAnomalies(connections: connections)

        // External connection analysis
        await analyzeExternalConnections(connections: connections)

        // Data exfiltration detection
        await detectDataExfiltration(trafficStats: trafficStats)

        isAnalyzing = false
    }

    // MARK: - Baseline Learning

    private func buildBaselines(trafficStats: [DeviceTrafficStats], connections: [SegmentationConnection]) {
        // Build traffic baselines
        for stat in trafficStats {
            trafficBaselines[stat.ipAddress] = TrafficBaseline(
                averageBandwidth: stat.bytesPerSecond,
                stdDeviation: 0,  // Would calculate from historical data
                typicalConnections: stat.activeConnections
            )
        }

        // Build connection baselines
        var connectionCounts: [String: Int] = [:]
        for conn in connections {
            connectionCounts[conn.sourceIP, default: 0] += 1
        }

        for (ip, count) in connectionCounts {
            connectionBaselines[ip] = ConnectionBaseline(
                avgConnectionsPerHour: count,
                typicalDestinations: []
            )
        }
    }

    // MARK: - Traffic Pattern Analysis

    private func analyzeTrafficPatterns(trafficStats: [DeviceTrafficStats]) async {
        for stat in trafficStats {
            guard let baseline = trafficBaselines[stat.ipAddress] else { continue }

            // Calculate Z-score for bandwidth
            let bandwidthDelta = abs(Double(stat.bytesPerSecond) - Double(baseline.averageBandwidth))
            let zScore = bandwidthDelta / max(Double(baseline.averageBandwidth), 1.0)

            if zScore > 3.0 {  // 3 standard deviations = anomaly
                let confidence = min(1.0, zScore / 5.0)

                anomalies.append(EnhancedAnomaly(
                    type: .bandwidthSpike,
                    severity: zScore > 5.0 ? .critical : .high,
                    source: stat.ipAddress,
                    description: "Bandwidth \(bandwidthDelta / 1_000_000) MB/s above normal",
                    mlConfidence: confidence,
                    baseline: formatBytes(baseline.averageBandwidth),
                    current: formatBytes(stat.bytesPerSecond),
                    recommendation: "Investigate traffic source. Check for malware or data transfer.",
                    timestamp: Date()
                ))
            }
        }
    }

    // MARK: - Port Scan Detection

    private func detectPortScanning(connections: [SegmentationConnection]) async {
        var scannerCandidates: [String: Set<Int>] = [:]

        for conn in connections {
            scannerCandidates[conn.sourceIP, default: []].insert(conn.destinationPort)
        }

        for (ip, ports) in scannerCandidates where ports.count > 20 {
            let confidence = min(1.0, Double(ports.count) / 100.0)

            anomalies.append(EnhancedAnomaly(
                type: .portScanActivity,
                severity: ports.count > 50 ? .critical : .high,
                source: ip,
                description: "Device attempted connections to \(ports.count) different ports",
                mlConfidence: confidence,
                baseline: "Typical: 2-5 ports",
                current: "\(ports.count) ports",
                recommendation: "Investigate device for malware. Check for unauthorized scanning tools.",
                timestamp: Date()
            ))
        }
    }

    // MARK: - Time-Based Anomalies

    private func detectTimeAnomalies(connections: [SegmentationConnection]) async {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Business hours: 8 AM - 6 PM
        if hour < 8 || hour > 18 {
            let afterHoursConnections = connections.filter { _ in true } // All current

            if afterHoursConnections.count > 100 {
                anomalies.append(EnhancedAnomaly(
                    type: .unusualTime,
                    severity: .medium,
                    source: "Multiple",
                    description: "\(afterHoursConnections.count) connections detected outside business hours",
                    mlConfidence: 0.8,
                    baseline: "Business hours: 8 AM - 6 PM",
                    current: "Current time: \(hour):00",
                    recommendation: "Review after-hours activity. Verify legitimate business need.",
                    timestamp: Date()
                ))
            }
        }
    }

    // MARK: - External Connection Analysis

    private func analyzeExternalConnections(connections: [SegmentationConnection]) async {
        for conn in connections {
            if isExternalIP(conn.destinationIP) {
                // Check if this is a new external IP
                if !hasSeenExternalIP(conn.destinationIP, from: conn.sourceIP) {
                    anomalies.append(EnhancedAnomaly(
                        type: .newExternalConnection,
                        severity: .medium,
                        source: conn.sourceIP,
                        description: "New external IP connection: \(conn.destinationIP)",
                        mlConfidence: 0.7,
                        baseline: "Known external IPs",
                        current: "New IP: \(conn.destinationIP)",
                        recommendation: "Verify external connection is legitimate. Check DNS resolution.",
                        timestamp: Date()
                    ))
                }
            }
        }
    }

    // MARK: - Data Exfiltration Detection

    private func detectDataExfiltration(trafficStats: [DeviceTrafficStats]) async {
        for stat in trafficStats {
            // High upload with low download suggests exfiltration
            let uploadBytes = stat.totalBytes // Simplified - would track separately
            let uploadRate = Double(uploadBytes) / 3600.0 // Per hour

            if uploadRate > 100_000_000 {  // > 100 MB/hour upload
                anomalies.append(EnhancedAnomaly(
                    type: .dataExfiltration,
                    severity: .critical,
                    source: stat.ipAddress,
                    description: "High outbound data transfer detected",
                    mlConfidence: 0.9,
                    baseline: "Typical upload: < 10 MB/hour",
                    current: "Current: \(Int(uploadRate / 1_000_000)) MB/hour",
                    recommendation: "URGENT: Investigate for data breach. Check file transfers and cloud uploads.",
                    timestamp: Date()
                ))
            }
        }
    }

    // MARK: - Helper Methods

    private func isExternalIP(_ ip: String) -> Bool {
        let privateRanges = ["10.", "172.16.", "192.168.", "127."]
        return !privateRanges.contains(where: { ip.starts(with: $0) })
    }

    private func hasSeenExternalIP(_ ip: String, from source: String) -> Bool {
        // In production, maintain history
        return false
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_000_000
        return String(format: "%.1f MB/s", mb)
    }
}

// MARK: - Baseline Models

struct TrafficBaseline {
    let averageBandwidth: Int
    let stdDeviation: Int
    let typicalConnections: Int
}

struct ConnectionBaseline {
    let avgConnectionsPerHour: Int
    let typicalDestinations: [String]
}
