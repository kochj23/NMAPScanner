//
//  DeviceReputationScorer.swift
//  NMAPScanner - Device Security and Reputation Scoring
//
//  Calculate trust/reputation scores for network devices
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation

// MARK: - Device Reputation

struct DeviceReputation: Codable {
    let deviceID: String
    let score: Int  // 0-100
    let rating: ReputationRating
    let factors: [ReputationFactor]
    let lastCalculated: Date

    var colorCode: String {
        rating.color
    }

    var emoji: String {
        rating.emoji
    }
}

enum ReputationRating: String, Codable {
    case trusted = "Trusted"           // 90-100
    case reliable = "Reliable"         // 75-89
    case acceptable = "Acceptable"     // 60-74
    case questionable = "Questionable" // 40-59
    case untrusted = "Untrusted"       // 0-39

    var color: String {
        switch self {
        case .trusted: return "green"
        case .reliable: return "blue"
        case .acceptable: return "yellow"
        case .questionable: return "orange"
        case .untrusted: return "red"
        }
    }

    var emoji: String {
        switch self {
        case .trusted: return "✅"
        case .reliable: return "✓"
        case .acceptable: return "⚠️"
        case .questionable: return "⚠️"
        case .untrusted: return "❌"
        }
    }

    static func from(score: Int) -> ReputationRating {
        if score >= 90 {
            return .trusted
        } else if score >= 75 {
            return .reliable
        } else if score >= 60 {
            return .acceptable
        } else if score >= 40 {
            return .questionable
        } else {
            return .untrusted
        }
    }
}

struct ReputationFactor: Codable {
    let category: String
    let impact: Int  // -50 to +50
    let reason: String

    var impactDescription: String {
        if impact > 0 {
            return "+\(impact) points"
        } else {
            return "\(impact) points"
        }
    }
}

// MARK: - Reputation Scorer

@MainActor
class DeviceReputationScorer: ObservableObject {
    static let shared = DeviceReputationScorer()

    @Published var reputations: [String: DeviceReputation] = [:]

    private let storageKey = "NMAPScanner-DeviceReputations"

    private init() {
        loadReputations()
    }

    // MARK: - Scoring

    /// Calculate reputation score for device
    func calculateReputation(for device: EnhancedDevice, uptimeRecord: UptimeRecord? = nil, historicalIncidents: Int = 0) -> DeviceReputation {
        var score = 50  // Start at neutral
        var factors: [ReputationFactor] = []

        // 1. Device Type Factor (trusted types score higher)
        let typeScore = scoreDeviceType(device.deviceType.rawValue)
        score += typeScore
        if typeScore != 0 {
            factors.append(ReputationFactor(
                category: "Device Type",
                impact: typeScore,
                reason: "Device type: \(device.deviceType.rawValue)"
            ))
        }

        // 2. Manufacturer Reputation
        if let manufacturer = device.manufacturer {
            let mfgScore = scoreManufacturer(manufacturer)
            score += mfgScore
            if mfgScore != 0 {
                factors.append(ReputationFactor(
                    category: "Manufacturer",
                    impact: mfgScore,
                    reason: "Manufacturer: \(manufacturer)"
                ))
            }
        } else {
            score -= 5
            factors.append(ReputationFactor(
                category: "Manufacturer",
                impact: -5,
                reason: "Unknown manufacturer"
            ))
        }

        // 3. Port Security
        let portScore = scoreOpenPorts(device.openPorts)
        score += portScore.score
        factors.append(contentsOf: portScore.factors)

        // 4. Rogue Status
        if device.isRogue {
            score -= 30
            factors.append(ReputationFactor(
                category: "Trust Status",
                impact: -30,
                reason: "Flagged as rogue/unknown device"
            ))
        } else if device.isKnownDevice {
            score += 15
            factors.append(ReputationFactor(
                category: "Trust Status",
                impact: 15,
                reason: "Known and whitelisted device"
            ))
        }

        // 5. Uptime/Reliability
        if let uptime = uptimeRecord {
            let uptimeScore = scoreUptime(uptime.uptimePercentage)
            score += uptimeScore
            if uptimeScore != 0 {
                factors.append(ReputationFactor(
                    category: "Reliability",
                    impact: uptimeScore,
                    reason: "Uptime: \(String(format: "%.1f", uptime.uptimePercentage))%"
                ))
            }
        }

        // 6. Security Incidents
        if historicalIncidents > 0 {
            let incidentPenalty = min(40, historicalIncidents * 10)
            score -= incidentPenalty
            factors.append(ReputationFactor(
                category: "Security History",
                impact: -incidentPenalty,
                reason: "\(historicalIncidents) security incidents recorded"
            ))
        }

        // 7. Online Status
        if !device.isOnline {
            score -= 10
            factors.append(ReputationFactor(
                category: "Availability",
                impact: -10,
                reason: "Device currently offline"
            ))
        }

        // Clamp score to 0-100
        score = max(0, min(100, score))

        let reputation = DeviceReputation(
            deviceID: device.ipAddress,
            score: score,
            rating: ReputationRating.from(score: score),
            factors: factors,
            lastCalculated: Date()
        )

        reputations[device.ipAddress] = reputation
        return reputation
    }

    // MARK: - Scoring Functions

    private func scoreDeviceType(_ typeString: String) -> Int {
        let lower = typeString.lowercased()

        if lower.contains("router") || lower.contains("gateway") {
            return 10  // Critical infrastructure
        } else if lower.contains("switch") || lower.contains("hub") {
            return 10  // Critical infrastructure
        } else if lower.contains("access") && lower.contains("point") {
            return 8  // Network infrastructure
        } else if lower.contains("server") {
            return 5  // Servers
        } else if lower.contains("nas") || lower.contains("storage") {
            return 5  // Storage
        } else if lower.contains("workstation") || lower.contains("pc") || lower.contains("laptop") {
            return 0  // Neutral
        } else if lower.contains("phone") || lower.contains("mobile") {
            return 0  // Neutral
        } else if lower.contains("tablet") || lower.contains("ipad") {
            return 0  // Neutral
        } else if lower.contains("tv") || lower.contains("television") {
            return -2  // IoT
        } else if lower.contains("camera") || lower.contains("cam") {
            return -8  // Often vulnerable
        } else if lower.contains("printer") || lower.contains("print") {
            return -3  // Often outdated
        } else if lower.contains("iot") || lower.contains("smart") {
            return -5  // IoT devices
        } else if lower.contains("unknown") {
            return -10  // Suspicious
        }

        return 0  // Default neutral
    }

    private func scoreManufacturer(_ manufacturer: String) -> Int {
        let trusted = ["Apple", "Cisco", "Ubiquiti", "UniFi", "Netgear", "ASUS", "Synology", "QNAP"]
        let reliable = ["TP-Link", "D-Link", "Linksys", "HP", "Dell", "Lenovo", "Samsung"]
        let questionable = ["Hikvision", "Dahua", "Unknown", "Generic"]

        let lower = manufacturer.lowercased()

        if trusted.contains(where: { lower.contains($0.lowercased()) }) {
            return 10
        } else if reliable.contains(where: { lower.contains($0.lowercased()) }) {
            return 5
        } else if questionable.contains(where: { lower.contains($0.lowercased()) }) {
            return -15
        }

        return 0
    }

    private func scoreOpenPorts(_ ports: [PortInfo]) -> (score: Int, factors: [ReputationFactor]) {
        var score = 0
        var factors: [ReputationFactor] = []

        // Dangerous ports (significant penalty)
        let dangerousPorts = [23, 21, 69, 135, 139, 445, 1433, 3306, 5432, 6379, 27017]
        let openDangerousPorts = ports.filter { dangerousPorts.contains($0.port) }

        if !openDangerousPorts.isEmpty {
            let penalty = openDangerousPorts.count * -8
            score += penalty
            factors.append(ReputationFactor(
                category: "Port Security",
                impact: penalty,
                reason: "\(openDangerousPorts.count) dangerous ports open (Telnet, FTP, databases)"
            ))
        }

        // Backdoor ports
        let backdoorPorts = [31337, 12345, 54321, 1337, 6667, 6666]
        let openBackdoorPorts = ports.filter { backdoorPorts.contains($0.port) }

        if !openBackdoorPorts.isEmpty {
            score -= 40  // Huge penalty
            factors.append(ReputationFactor(
                category: "Malware Indicators",
                impact: -40,
                reason: "Backdoor/trojan ports detected"
            ))
        }

        // Too many open ports (suspicious)
        if ports.count > 20 {
            score -= 10
            factors.append(ReputationFactor(
                category: "Attack Surface",
                impact: -10,
                reason: "Too many open ports (\(ports.count))"
            ))
        } else if ports.count > 10 {
            score -= 5
            factors.append(ReputationFactor(
                category: "Attack Surface",
                impact: -5,
                reason: "Many open ports (\(ports.count))"
            ))
        }

        // Secure ports (bonus)
        let securePorts = [443, 22]  // HTTPS, SSH
        let hasSecurePorts = ports.contains { securePorts.contains($0.port) }

        if hasSecurePorts {
            score += 5
            factors.append(ReputationFactor(
                category: "Security",
                impact: 5,
                reason: "Uses secure protocols (HTTPS/SSH)"
            ))
        }

        return (score, factors)
    }

    private func scoreUptime(_ uptimePercentage: Double) -> Int {
        if uptimePercentage >= 99.0 {
            return 10
        } else if uptimePercentage >= 95.0 {
            return 5
        } else if uptimePercentage >= 85.0 {
            return 0
        } else if uptimePercentage >= 70.0 {
            return -5
        } else {
            return -10
        }
    }

    // MARK: - Batch Operations

    /// Calculate reputation for all devices
    func calculateAllReputations(devices: [EnhancedDevice], uptimeRecords: [String: UptimeRecord] = [:]) {
        for device in devices {
            let uptime = uptimeRecords[device.ipAddress]
            _ = calculateReputation(for: device, uptimeRecord: uptime)
        }

        saveReputations()
        SecureLogger.log("Calculated reputations for \(devices.count) devices", level: .info)
    }

    /// Get devices by reputation rating
    func getDevicesByRating(_ rating: ReputationRating) -> [DeviceReputation] {
        return reputations.values.filter { $0.rating == rating }
    }

    /// Get low-reputation devices (score < 50)
    func getLowReputationDevices() -> [DeviceReputation] {
        return reputations.values.filter { $0.score < 50 }
            .sorted { $0.score < $1.score }
    }

    /// Get statistics
    func getStatistics() -> ReputationStatistics {
        let scores = reputations.values.map { $0.score }

        return ReputationStatistics(
            totalDevices: reputations.count,
            averageScore: scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count,
            trustedCount: getDevicesByRating(.trusted).count,
            reliableCount: getDevicesByRating(.reliable).count,
            acceptableCount: getDevicesByRating(.acceptable).count,
            questionableCount: getDevicesByRating(.questionable).count,
            untrustedCount: getDevicesByRating(.untrusted).count
        )
    }

    // MARK: - Persistence

    private func saveReputations() {
        do {
            let data = try JSONEncoder().encode(reputations)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            SecureLogger.log("Failed to save reputations: \(error)", level: .error)
        }
    }

    private func loadReputations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([String: DeviceReputation].self, from: data) else {
            return
        }

        reputations = saved
        SecureLogger.log("Loaded reputations for \(saved.count) devices", level: .info)
    }

    /// Clear all reputation data
    func clearAllReputations() {
        reputations.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        SecureLogger.log("Cleared all reputation data", level: .warning)
    }
}

// MARK: - Statistics

struct ReputationStatistics {
    let totalDevices: Int
    let averageScore: Int
    let trustedCount: Int
    let reliableCount: Int
    let acceptableCount: Int
    let questionableCount: Int
    let untrustedCount: Int

    var distribution: String {
        """
        Trusted: \(trustedCount)
        Reliable: \(reliableCount)
        Acceptable: \(acceptableCount)
        Questionable: \(questionableCount)
        Untrusted: \(untrustedCount)
        """
    }
}
