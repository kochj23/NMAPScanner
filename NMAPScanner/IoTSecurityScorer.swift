//
//  IoTSecurityScorer.swift
//  NMAPScanner - IoT Device Security Scoring
//
//  Created by Jordan Koch & Claude Code on 2025-11-27.
//

import Foundation

struct IoTSecurityScore: Identifiable {
    let id = UUID()
    let device: EnhancedDevice
    let score: Int // 0-100
    let grade: String
    let issues: [SecurityIssue]
    let strengths: [String]
    let timestamp: Date

    struct SecurityIssue: Codable {
        let category: String
        let description: String
        let impact: Int // Points deducted
    }
}

@MainActor
class IoTSecurityScorer: ObservableObject {
    static let shared = IoTSecurityScorer()

    @Published var scores: [IoTSecurityScore] = []
    @Published var isScoring = false

    private init() {}

    func scoreIoTDevices(devices: [EnhancedDevice], banners: [ServiceBanner], authFindings: [AuthFinding]) async {
        isScoring = true
        scores.removeAll()

        let iotDevices = devices.filter { $0.deviceType == .iot }

        for device in iotDevices {
            let score = await calculateScore(device: device, banners: banners, authFindings: authFindings)
            scores.append(score)
        }

        isScoring = false
    }

    private func calculateScore(device: EnhancedDevice, banners: [ServiceBanner], authFindings: [AuthFinding]) async -> IoTSecurityScore {
        var score = 100
        var issues: [IoTSecurityScore.SecurityIssue] = []
        var strengths: [String] = []

        // Check open ports
        if device.openPorts.count > 5 {
            let impact = 15
            score -= impact
            issues.append(IoTSecurityScore.SecurityIssue(
                category: "Exposed Services",
                description: "\(device.openPorts.count) open ports - IoT should minimize exposure",
                impact: impact
            ))
        } else if device.openPorts.count <= 2 {
            strengths.append("Minimal port exposure")
        }

        // Check for insecure protocols
        let insecurePorts = [21, 23, 80] // FTP, Telnet, HTTP
        let hasInsecure = device.openPorts.contains(where: { insecurePorts.contains($0.port) })
        if hasInsecure {
            let impact = 25
            score -= impact
            issues.append(IoTSecurityScore.SecurityIssue(
                category: "Insecure Protocols",
                description: "Using unencrypted protocols (FTP/Telnet/HTTP)",
                impact: impact
            ))
        } else {
            strengths.append("Uses encrypted protocols")
        }

        // Check firmware age (from banners)
        if let banner = banners.first(where: { $0.host == device.ipAddress }),
           let version = banner.detectedVersion,
           version.contains("2018") || version.contains("2019") {
            let impact = 20
            score -= impact
            issues.append(IoTSecurityScore.SecurityIssue(
                category: "Outdated Firmware",
                description: "Firmware version appears outdated",
                impact: impact
            ))
        }

        // Check for default credentials
        let hasDefaultCreds = authFindings.contains(where: {
            $0.host == device.ipAddress && $0.finding == .defaultCredentials
        })
        if hasDefaultCreds {
            let impact = 30
            score -= impact
            issues.append(IoTSecurityScore.SecurityIssue(
                category: "Default Credentials",
                description: "Using default username/password",
                impact: impact
            ))
        } else {
            strengths.append("No default credentials")
        }

        // Check encryption
        let hasHTTPS = device.openPorts.contains(where: { $0.port == 443 })
        if hasHTTPS {
            strengths.append("Uses HTTPS")
        }

        // Grade calculation
        let grade: String
        switch score {
        case 90...100: grade = "A"
        case 80..<90: grade = "B"
        case 70..<80: grade = "C"
        case 60..<70: grade = "D"
        default: grade = "F"
        }

        return IoTSecurityScore(
            device: device,
            score: max(0, score),
            grade: grade,
            issues: issues,
            strengths: strengths,
            timestamp: Date()
        )
    }

    var stats: IoTSecurityStats {
        let avgScore = scores.isEmpty ? 0 : scores.map { $0.score }.reduce(0, +) / scores.count
        let failing = scores.filter { $0.score < 60 }.count

        return IoTSecurityStats(
            totalDevices: scores.count,
            averageScore: avgScore,
            failingDevices: failing
        )
    }
}

struct IoTSecurityStats {
    let totalDevices: Int
    let averageScore: Int
    let failingDevices: Int
}
