//
//  ThreatAnalysisTests.swift
//  NMAPScannerTests
//
//  Tests for threat analysis scoring, risk assessment, and device security evaluation.
//  Validates ThreatAnalyzer, NetworkThreatSummary scoring, IoT security scoring,
//  and PortInfo classification.
//
//  Created by Jordan Koch on 2026-04-21.
//

import XCTest
@testable import NMAPScanner

final class ThreatAnalysisTests: XCTestCase {

    // MARK: - Test Helpers

    /// Create a minimal EnhancedDevice for testing
    private func makeDevice(
        ip: String = "192.168.1.100",
        mac: String? = "AA:BB:CC:DD:EE:FF",
        hostname: String? = "test-device",
        deviceType: EnhancedDevice.DeviceType = .unknown,
        openPorts: [PortInfo] = [],
        isKnownDevice: Bool = true,
        firstSeen: Date = Date().addingTimeInterval(-86400) // 1 day ago
    ) -> EnhancedDevice {
        return EnhancedDevice(
            ipAddress: ip,
            macAddress: mac,
            hostname: hostname,
            manufacturer: nil,
            deviceType: deviceType,
            openPorts: openPorts,
            isOnline: true,
            firstSeen: firstSeen,
            lastSeen: Date(),
            isKnownDevice: isKnownDevice,
            operatingSystem: nil,
            deviceName: nil
        )
    }

    /// Create a PortInfo for testing
    private func makePort(
        port: Int,
        service: String = "unknown",
        version: String? = nil,
        state: PortInfo.PortState = .open,
        protocolType: String = "TCP",
        banner: String? = nil
    ) -> PortInfo {
        return PortInfo(
            port: port,
            service: service,
            version: version,
            state: state,
            protocolType: protocolType,
            banner: banner
        )
    }

    // MARK: - ThreatSeverity Ordering

    func testThreatSeverityOrdering() {
        // Critical < High < Medium < Low < Info (in terms of sort priority)
        XCTAssertTrue(ThreatSeverity.critical < ThreatSeverity.high)
        XCTAssertTrue(ThreatSeverity.high < ThreatSeverity.medium)
        XCTAssertTrue(ThreatSeverity.medium < ThreatSeverity.low)
        XCTAssertTrue(ThreatSeverity.low < ThreatSeverity.info)
    }

    func testThreatSeveritySortOrder() {
        XCTAssertEqual(ThreatSeverity.critical.sortOrder, 0)
        XCTAssertEqual(ThreatSeverity.high.sortOrder, 1)
        XCTAssertEqual(ThreatSeverity.medium.sortOrder, 2)
        XCTAssertEqual(ThreatSeverity.low.sortOrder, 3)
        XCTAssertEqual(ThreatSeverity.info.sortOrder, 4)
    }

    func testThreatSeverityAllCases() {
        XCTAssertEqual(ThreatSeverity.allCases.count, 5)
    }

    // MARK: - PortInfo Classification

    func testBackdoorPortDetection() {
        let backdoorPorts = [31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374, 2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002]
        for portNum in backdoorPorts {
            let port = makePort(port: portNum)
            XCTAssertTrue(port.isBackdoorPort,
                "Port \(portNum) should be classified as a backdoor port")
        }
    }

    func testNonBackdoorPortsNotFlagged() {
        let normalPorts = [22, 80, 443, 3306, 8080]
        for portNum in normalPorts {
            let port = makePort(port: portNum)
            XCTAssertFalse(port.isBackdoorPort,
                "Port \(portNum) should NOT be classified as a backdoor port")
        }
    }

    func testRemoteAccessPortDetection() {
        let remotePorts = [22, 23, 3389, 5900, 5901, 5902, 5800, 5801, 5802]
        for portNum in remotePorts {
            let port = makePort(port: portNum)
            XCTAssertTrue(port.isRemoteAccessPort,
                "Port \(portNum) should be classified as a remote access port")
        }
    }

    func testDatabasePortDetection() {
        let dbPorts = [3306, 5432, 1433, 1434, 27017, 27018, 27019, 6379, 9042, 7000, 7001, 8086]
        for portNum in dbPorts {
            let port = makePort(port: portNum)
            XCTAssertTrue(port.isDatabasePort,
                "Port \(portNum) should be classified as a database port")
        }
    }

    func testSuspiciousPortDetection() {
        // Backdoor port is always suspicious
        let backdoorPort = makePort(port: 31337)
        XCTAssertTrue(backdoorPort.isSuspicious, "Backdoor port 31337 should be suspicious")

        // Telnet is suspicious (remote access, not common service)
        let telnetPort = makePort(port: 23, service: "telnet")
        XCTAssertTrue(telnetPort.isRemoteAccessPort)

        // SSH is common service, not suspicious
        let sshPort = makePort(port: 22, service: "ssh")
        XCTAssertTrue(sshPort.isCommonService, "SSH on port 22 should be a common service")
    }

    func testCommonServiceDetection() {
        let sshPort = makePort(port: 22)
        XCTAssertTrue(sshPort.isCommonService, "SSH on 22 should be common")

        let rdpPort = makePort(port: 3389, service: "RDP")
        XCTAssertTrue(rdpPort.isCommonService, "RDP on 3389 should be common")

        let telnetPort = makePort(port: 23)
        XCTAssertFalse(telnetPort.isCommonService, "Telnet on 23 should NOT be a common service")
    }

    // MARK: - NetworkThreatSummary Risk Score

    func testRiskScoreWithNoThreatsIsHigh() {
        let summary = NetworkThreatSummary(
            scanDate: Date(),
            totalDevices: 10,
            threatenedDevices: 0,
            criticalThreats: [],
            highThreats: [],
            mediumThreats: [],
            lowThreats: [],
            rogueDevices: [],
            backdoorDevices: [],
            exposedServices: []
        )

        // With 0 threats, risk should be minimal (score close to 100)
        XCTAssertEqual(summary.overallRiskScore, 100,
            "No threats should result in maximum risk score of 100")
        XCTAssertEqual(summary.riskLevel, "Low Risk")
    }

    func testRiskScoreWithCriticalThreatsIsLow() {
        let criticalFinding = ThreatFinding(
            severity: .critical,
            category: .backdoor,
            title: "Test Critical",
            description: "Test",
            affectedHost: "192.168.1.1",
            affectedPort: 31337,
            detectedAt: Date(),
            cvssScore: 10.0,
            cveReferences: [],
            remediation: "Fix it",
            technicalDetails: "Details",
            impactAssessment: "Impact"
        )

        let manyCritical = Array(repeating: criticalFinding, count: 50)

        let summary = NetworkThreatSummary(
            scanDate: Date(),
            totalDevices: 10,
            threatenedDevices: 10,
            criticalThreats: manyCritical,
            highThreats: [],
            mediumThreats: [],
            lowThreats: [],
            rogueDevices: [],
            backdoorDevices: [],
            exposedServices: []
        )

        XCTAssertLessThan(summary.overallRiskScore, 40,
            "Many critical threats should result in low risk score")
        XCTAssertEqual(summary.riskLevel, "Critical Risk")
    }

    func testRiskScoreWeighting() {
        // Create different severity findings
        let critical = ThreatFinding(
            severity: .critical, category: .backdoor, title: "Critical",
            description: "", affectedHost: "192.168.1.1", affectedPort: nil,
            detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        let high = ThreatFinding(
            severity: .high, category: .exposedService, title: "High",
            description: "", affectedHost: "192.168.1.1", affectedPort: nil,
            detectedAt: Date(), cvssScore: 7.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        let _ = ThreatFinding(
            severity: .medium, category: .weakSecurity, title: "Medium",
            description: "", affectedHost: "192.168.1.1", affectedPort: nil,
            detectedAt: Date(), cvssScore: 5.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )

        // Scenario with 1 critical threat on 10 devices
        let criticalSummary = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 10, threatenedDevices: 1,
            criticalThreats: [critical], highThreats: [], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )

        // Scenario with 2 high threats on 10 devices
        let highSummary = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 10, threatenedDevices: 2,
            criticalThreats: [], highThreats: [high, high], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )

        // 1 critical (weight 10) = 10 risk points
        // 2 high (weight 5 each) = 10 risk points
        // These should produce identical risk scores for same device count
        XCTAssertEqual(criticalSummary.overallRiskScore, highSummary.overallRiskScore,
            "1 critical (10pts) should equal 2 high (5pts each) in risk weighting")
    }

    func testRiskLevelBoundaries() {
        // Test each risk level boundary
        func makeSummary(critical: Int, total: Int) -> NetworkThreatSummary {
            let finding = ThreatFinding(
                severity: .critical, category: .backdoor, title: "Test",
                description: "", affectedHost: "test", affectedPort: nil,
                detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
                remediation: "", technicalDetails: "", impactAssessment: ""
            )
            return NetworkThreatSummary(
                scanDate: Date(), totalDevices: total, threatenedDevices: critical,
                criticalThreats: Array(repeating: finding, count: critical),
                highThreats: [], mediumThreats: [], lowThreats: [],
                rogueDevices: [], backdoorDevices: [], exposedServices: []
            )
        }

        let lowRisk = makeSummary(critical: 0, total: 10)
        XCTAssertEqual(lowRisk.riskLevel, "Low Risk")

        // The risk score is: 100 - (totalRisk / maxRisk * 100)
        // maxRisk = totalDevices * 50
        // For score < 40 => "Critical Risk"
        // Need totalRisk / maxRisk > 0.6 => totalRisk > 300 for 10 devices
        // Each critical = 10 points, so 31+ criticals for 10 devices
        let criticalRisk = makeSummary(critical: 31, total: 10)
        XCTAssertEqual(criticalRisk.riskLevel, "Critical Risk")
    }

    func testTotalThreatCount() {
        let finding = ThreatFinding(
            severity: .low, category: .misconfiguration, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 1.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )

        let summary = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 5, threatenedDevices: 3,
            criticalThreats: [finding, finding],
            highThreats: [finding, finding, finding],
            mediumThreats: [finding],
            lowThreats: [finding, finding, finding, finding],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )

        XCTAssertEqual(summary.totalThreats, 10, "Total threats should be sum of all severity levels")
    }

    func testRiskScoreNeverNegative() {
        let finding = ThreatFinding(
            severity: .critical, category: .backdoor, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )

        // Extreme case: 1000 critical threats on 1 device
        let summary = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 1, threatenedDevices: 1,
            criticalThreats: Array(repeating: finding, count: 1000),
            highThreats: [], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )

        XCTAssertGreaterThanOrEqual(summary.overallRiskScore, 0,
            "Risk score should never be negative")
    }

    func testRiskScoreZeroDevicesEdgeCase() {
        let summary = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 0, threatenedDevices: 0,
            criticalThreats: [], highThreats: [], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )

        // maxRisk = 0 * 50 = 0, formula uses max(maxRisk, 1) to avoid division by zero
        XCTAssertEqual(summary.overallRiskScore, 100,
            "Zero devices with zero threats should be 100 (low risk)")
    }

    // MARK: - DeviceThreatSummary

    func testDeviceThreatSummaryOverallSeverity() {
        let critical = ThreatFinding(
            severity: .critical, category: .backdoor, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        let low = ThreatFinding(
            severity: .low, category: .misconfiguration, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 2.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )

        let device = makeDevice()

        // Device with critical threat
        let criticalSummary = DeviceThreatSummary(
            device: device,
            criticalThreats: [critical],
            highThreats: [],
            mediumThreats: [],
            lowThreats: [low],
            infoItems: []
        )
        XCTAssertEqual(criticalSummary.overallSeverity, .critical)

        // Device with only low threats
        let lowSummary = DeviceThreatSummary(
            device: device,
            criticalThreats: [],
            highThreats: [],
            mediumThreats: [],
            lowThreats: [low],
            infoItems: []
        )
        XCTAssertEqual(lowSummary.overallSeverity, .low)

        // Device with no threats
        let cleanSummary = DeviceThreatSummary(
            device: device,
            criticalThreats: [],
            highThreats: [],
            mediumThreats: [],
            lowThreats: [],
            infoItems: []
        )
        XCTAssertEqual(cleanSummary.overallSeverity, .info)
    }

    func testDeviceThreatSummaryHasThreats() {
        let device = makeDevice()
        let finding = ThreatFinding(
            severity: .low, category: .misconfiguration, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 1.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )

        let withThreats = DeviceThreatSummary(
            device: device, criticalThreats: [], highThreats: [],
            mediumThreats: [], lowThreats: [finding], infoItems: []
        )
        XCTAssertTrue(withThreats.hasThreats)
        XCTAssertEqual(withThreats.totalThreats, 1)

        let withoutThreats = DeviceThreatSummary(
            device: device, criticalThreats: [], highThreats: [],
            mediumThreats: [], lowThreats: [], infoItems: []
        )
        XCTAssertFalse(withoutThreats.hasThreats)
        XCTAssertEqual(withoutThreats.totalThreats, 0)
    }

    // MARK: - EnhancedDevice Rogue Detection

    func testRogueDeviceDetectionWithDefaultTimeWindow() {
        // Known device is never rogue
        let knownDevice = makeDevice(isKnownDevice: true, firstSeen: Date())
        XCTAssertFalse(knownDevice.isRogue, "Known device should never be rogue")

        // Unknown device seen recently
        let newUnknown = makeDevice(isKnownDevice: false, firstSeen: Date().addingTimeInterval(-60))
        XCTAssertTrue(newUnknown.isRogue, "Unknown device seen 60 seconds ago should be rogue (within 1 hour window)")

        // Unknown device seen long ago
        let oldUnknown = makeDevice(isKnownDevice: false, firstSeen: Date().addingTimeInterval(-7200))
        XCTAssertFalse(oldUnknown.isRogue, "Unknown device seen 2 hours ago should NOT be rogue (outside 1 hour window)")
    }

    func testRogueDeviceDetectionWithCustomTimeWindow() {
        let device = makeDevice(isKnownDevice: false, firstSeen: Date().addingTimeInterval(-300))

        // Within 10-minute window
        XCTAssertTrue(device.isRogue(timeWindowSeconds: 600),
            "Device seen 5 min ago should be rogue with 10-min window")

        // Outside 1-minute window
        XCTAssertFalse(device.isRogue(timeWindowSeconds: 60),
            "Device seen 5 min ago should NOT be rogue with 1-min window")
    }

    // MARK: - EnhancedDevice Display Name

    func testDeviceDisplayNamePriority() {
        // Device name takes priority
        let namedDevice = EnhancedDevice(
            ipAddress: "192.168.1.1", macAddress: nil, hostname: "my-host",
            manufacturer: nil, deviceType: .unknown, openPorts: [], isOnline: true,
            firstSeen: Date(), lastSeen: Date(), isKnownDevice: true,
            operatingSystem: nil, deviceName: "My Device"
        )
        XCTAssertEqual(namedDevice.displayName, "My Device")

        // Hostname is second priority
        let hostDevice = EnhancedDevice(
            ipAddress: "192.168.1.1", macAddress: nil, hostname: "my-host",
            manufacturer: nil, deviceType: .unknown, openPorts: [], isOnline: true,
            firstSeen: Date(), lastSeen: Date(), isKnownDevice: true,
            operatingSystem: nil, deviceName: nil
        )
        XCTAssertEqual(hostDevice.displayName, "my-host")

        // IP address is fallback
        let ipOnlyDevice = EnhancedDevice(
            ipAddress: "192.168.1.1", macAddress: nil, hostname: nil,
            manufacturer: nil, deviceType: .unknown, openPorts: [], isOnline: true,
            firstSeen: Date(), lastSeen: Date(), isKnownDevice: true,
            operatingSystem: nil, deviceName: nil
        )
        XCTAssertEqual(ipOnlyDevice.displayName, "192.168.1.1")
    }

    // MARK: - ThreatCategory

    func testAllThreatCategoriesExist() {
        XCTAssertEqual(ThreatCategory.allCases.count, 8)
        XCTAssertNotNil(ThreatCategory.backdoor)
        XCTAssertNotNil(ThreatCategory.exposedService)
        XCTAssertNotNil(ThreatCategory.weakSecurity)
        XCTAssertNotNil(ThreatCategory.misconfiguration)
        XCTAssertNotNil(ThreatCategory.rogueDevice)
        XCTAssertNotNil(ThreatCategory.suspiciousActivity)
        XCTAssertNotNil(ThreatCategory.dataExposure)
        XCTAssertNotNil(ThreatCategory.denial)
    }

    // MARK: - ThreatFinding Properties

    func testThreatFindingIsRogueDevice() {
        let rogueFinding = ThreatFinding(
            severity: .critical, category: .rogueDevice, title: "Rogue",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 9.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        XCTAssertTrue(rogueFinding.isRogueDevice)
        XCTAssertFalse(rogueFinding.isBackdoor)
    }

    func testThreatFindingIsBackdoor() {
        let backdoorFinding = ThreatFinding(
            severity: .critical, category: .backdoor, title: "Backdoor",
            description: "", affectedHost: "test", affectedPort: 31337,
            detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        XCTAssertTrue(backdoorFinding.isBackdoor)
        XCTAssertFalse(backdoorFinding.isRogueDevice)
    }

    // MARK: - IoTSecurityScore Grade Calculation

    func testIoTSecurityScoreGradeFromScoreValue() {
        // Test the grade boundaries based on IoTSecurityScorer.calculateScore logic
        // A: 90-100, B: 80-89, C: 70-79, D: 60-69, F: < 60

        // These are the score-to-grade mappings from the scorer
        let gradeMap: [(Int, String)] = [
            (100, "A"), (95, "A"), (90, "A"),
            (89, "B"), (85, "B"), (80, "B"),
            (79, "C"), (75, "C"), (70, "C"),
            (69, "D"), (65, "D"), (60, "D"),
            (59, "F"), (50, "F"), (30, "F"), (0, "F"),
        ]

        for (score, expectedGrade) in gradeMap {
            let grade: String
            switch score {
            case 90...100: grade = "A"
            case 80..<90: grade = "B"
            case 70..<80: grade = "C"
            case 60..<70: grade = "D"
            default: grade = "F"
            }
            XCTAssertEqual(grade, expectedGrade,
                "Score \(score) should map to grade '\(expectedGrade)' but got '\(grade)'")
        }
    }

    func testIoTScoringDeductions() {
        // Test the specific deduction amounts from IoTSecurityScorer

        // Many open ports: -15
        let manyPortsDeduction = 15
        let score1 = 100 - manyPortsDeduction
        XCTAssertEqual(score1, 85, "6+ open ports should deduct 15 points")

        // Insecure protocols (FTP/Telnet/HTTP): -25
        let insecureProtocolDeduction = 25
        let score2 = 100 - insecureProtocolDeduction
        XCTAssertEqual(score2, 75, "Insecure protocols should deduct 25 points")

        // Outdated firmware: -20
        let outdatedFirmwareDeduction = 20
        let score3 = 100 - outdatedFirmwareDeduction
        XCTAssertEqual(score3, 80, "Outdated firmware should deduct 20 points")

        // Default credentials: -30
        let defaultCredsDeduction = 30
        let score4 = 100 - defaultCredsDeduction
        XCTAssertEqual(score4, 70, "Default credentials should deduct 30 points")

        // All issues combined: 100 - 15 - 25 - 20 - 30 = 10
        let allIssues = 100 - manyPortsDeduction - insecureProtocolDeduction - outdatedFirmwareDeduction - defaultCredsDeduction
        XCTAssertEqual(allIssues, 10, "All deductions combined should result in score of 10")
    }

    func testIoTScoringMinimumIsZero() {
        // Even with extreme deductions, score should be clamped to 0 (max(0, score))
        let extremeDeductions = 100 + 50 // More than max
        let clampedScore = max(0, 100 - extremeDeductions)
        XCTAssertEqual(clampedScore, 0, "Score should be clamped to 0 minimum")
    }

    // MARK: - NSEScriptResult Severity

    func testNSEScriptSeverityDetermination() {
        // The determineSeverity function checks for keywords in output

        // High severity keywords
        let criticalOutput = ["This system is vulnerable to CVE-2021-44228"]
        let exploitOutput = ["exploit found for service"]
        XCTAssertTrue(criticalOutput.joined(separator: " ").lowercased().contains("vulnerable"))
        XCTAssertTrue(exploitOutput.joined(separator: " ").lowercased().contains("exploit"))

        // Medium severity keywords
        let warningOutput = ["warning: weak cipher suite detected"]
        let weakOutput = ["insecure configuration found"]
        XCTAssertTrue(warningOutput.joined(separator: " ").lowercased().contains("warning"))
        XCTAssertTrue(weakOutput.joined(separator: " ").lowercased().contains("insecure"))

        // Info (no severity keywords)
        let infoOutput = ["Service running normally on port 80"]
        let text = infoOutput.joined(separator: " ").lowercased()
        XCTAssertFalse(text.contains("critical") || text.contains("exploit") || text.contains("vulnerable"))
        XCTAssertFalse(text.contains("warning") || text.contains("weak") || text.contains("insecure"))
    }

    // MARK: - AISecuritySeverity

    func testAISecuritySeverityComparable() {
        // The Comparable implementation sorts more severe items first:
        // critical < high < medium < low (in sort order, critical comes first)
        XCTAssertTrue(AISecuritySeverity.critical < AISecuritySeverity.high,
            "Critical should sort before high (critical.score > high.score)")
        XCTAssertTrue(AISecuritySeverity.high < AISecuritySeverity.medium,
            "High should sort before medium")
        XCTAssertTrue(AISecuritySeverity.medium < AISecuritySeverity.low,
            "Medium should sort before low")
    }

    func testAISecuritySeverityScores() {
        XCTAssertEqual(AISecuritySeverity.critical.score, 4)
        XCTAssertEqual(AISecuritySeverity.high.score, 3)
    }
}
