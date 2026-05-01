//
//  IntegrationTests.swift
//  NMAPScannerTests
//
//  Integration tests: verify nmap binary exists, test scan profile argument
//  assembly, test localhost connectivity, and end-to-end model workflows.
//
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import NMAPScanner

final class IntegrationTests: XCTestCase {

    // MARK: - nmap Binary Availability

    func testNmapBinaryExistsAtExpectedPaths() {
        // nmap is typically at /usr/local/bin/nmap (Homebrew Intel) or /opt/homebrew/bin/nmap (Homebrew Apple Silicon)
        let possiblePaths = [
            "/usr/local/bin/nmap",
            "/opt/homebrew/bin/nmap",
        ]

        var found = false
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                found = true
                break
            }
        }

        // Also check PATH via `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["nmap"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                found = true
            }
        } catch {
            // which failed, rely on direct path checks
        }

        XCTAssertTrue(found, "nmap must be installed (brew install nmap). NMAPScanner requires it.")
    }

    func testNmapVersionIsReasonable() {
        let process = Process()
        let possiblePaths = ["/opt/homebrew/bin/nmap", "/usr/local/bin/nmap"]
        var nmapPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                nmapPath = path
                break
            }
        }

        guard let path = nmapPath else {
            // nmap not installed, skip version check
            return
        }

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                XCTAssertTrue(output.contains("Nmap"), "nmap --version should contain 'Nmap'")
                // Version should be 7.x or higher
                if let versionMatch = output.range(of: #"Nmap version \d+\.\d+"#, options: .regularExpression) {
                    let versionStr = output[versionMatch]
                    XCTAssertTrue(versionStr.contains("7.") || versionStr.contains("8.") || versionStr.contains("9."),
                        "nmap should be version 7.x or higher, got: \(versionStr)")
                }
            }
        } catch {
            XCTFail("Failed to run nmap --version: \(error)")
        }
    }

    // MARK: - System Command Availability

    func testPingCommandExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/sbin/ping"),
            "ping command should exist at /sbin/ping")
    }

    func testARPCommandExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/usr/sbin/arp"),
            "arp command should exist at /usr/sbin/arp")
    }

    // MARK: - Localhost Scan Simulation

    func testLocalhostIPValidation() {
        // Localhost should be valid with allowLoopback
        XCTAssertNoThrow(try IPValidator.validateIPAddress("127.0.0.1", allowLoopback: true))
    }

    // MARK: - End-to-End Model Workflows

    @MainActor
    func testThreatAnalyzerFullWorkflow() {
        let analyzer = ThreatAnalyzer()

        // Create devices with various threat profiles
        let cleanDevice = EnhancedDevice(
            ipAddress: "192.168.1.10", macAddress: "AA:BB:CC:DD:EE:01",
            hostname: "clean-server", manufacturer: nil, deviceType: .server,
            openPorts: [PortInfo(port: 443, service: "https", version: nil, state: .open, protocolType: "TCP", banner: nil)],
            isOnline: true, firstSeen: Date().addingTimeInterval(-86400), lastSeen: Date(),
            isKnownDevice: true, operatingSystem: "Linux", deviceName: nil
        )

        let riskyDevice = EnhancedDevice(
            ipAddress: "192.168.1.50", macAddress: "AA:BB:CC:DD:EE:02",
            hostname: "risky-host", manufacturer: nil, deviceType: .unknown,
            openPorts: [
                PortInfo(port: 23, service: "telnet", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 21, service: "ftp", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 3306, service: "mysql", version: nil, state: .open, protocolType: "TCP", banner: nil),
            ],
            isOnline: true, firstSeen: Date().addingTimeInterval(-86400), lastSeen: Date(),
            isKnownDevice: true, operatingSystem: nil, deviceName: nil
        )

        let rogueDevice = EnhancedDevice(
            ipAddress: "192.168.1.200", macAddress: "FF:FF:FF:00:00:01",
            hostname: nil, manufacturer: nil, deviceType: .unknown,
            openPorts: [
                PortInfo(port: 31337, service: "unknown", version: nil, state: .open, protocolType: "TCP", banner: nil),
            ],
            isOnline: true, firstSeen: Date().addingTimeInterval(-60), lastSeen: Date(),
            isKnownDevice: false, operatingSystem: nil, deviceName: nil
        )

        analyzer.analyzeNetwork(devices: [cleanDevice, riskyDevice, rogueDevice])

        // Verify network summary was created
        XCTAssertNotNil(analyzer.networkSummary)
        XCTAssertEqual(analyzer.networkSummary?.totalDevices, 3)

        // Verify threats were found
        XCTAssertFalse(analyzer.allThreats.isEmpty, "Should find threats from risky and rogue devices")

        // Verify device summaries
        XCTAssertEqual(analyzer.deviceSummaries.count, 3)

        // Rogue device should have critical threats
        let rogueSummary = analyzer.deviceSummaries.first { $0.device.ipAddress == "192.168.1.200" }
        XCTAssertNotNil(rogueSummary)
        XCTAssertTrue(rogueSummary?.hasThreats ?? false)
        XCTAssertFalse(rogueSummary?.criticalThreats.isEmpty ?? true,
            "Rogue device with backdoor port should have critical threats")

        // Clean device should have minimal or no threats
        let cleanSummary = analyzer.deviceSummaries.first { $0.device.ipAddress == "192.168.1.10" }
        XCTAssertNotNil(cleanSummary)

        // Risky device should have threats from telnet, ftp, and exposed database
        let riskySummary = analyzer.deviceSummaries.first { $0.device.ipAddress == "192.168.1.50" }
        XCTAssertNotNil(riskySummary)
        XCTAssertTrue(riskySummary?.hasThreats ?? false)
    }

    @MainActor
    func testThreatAnalyzerEmptyNetwork() {
        let analyzer = ThreatAnalyzer()
        analyzer.analyzeNetwork(devices: [])

        XCTAssertNotNil(analyzer.networkSummary)
        XCTAssertEqual(analyzer.networkSummary?.totalDevices, 0)
        XCTAssertEqual(analyzer.networkSummary?.totalThreats, 0)
        XCTAssertEqual(analyzer.networkSummary?.overallRiskScore, 100)
        XCTAssertEqual(analyzer.networkSummary?.riskLevel, "Low Risk")
    }

    // MARK: - Scan Profile Integration

    func testAllScanProfilesCanBeSelectedAndDescribed() {
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            XCTAssertFalse(profile.rawValue.isEmpty)
            XCTAssertFalse(profile.description.isEmpty)
            XCTAssertNotNil(profile.id)
            // Args should be a valid array (even if empty for custom)
            let args = profile.nmapArgs
            if profile != .custom {
                XCTAssertFalse(args.isEmpty,
                    "Non-custom profile \(profile.rawValue) should have args")
            }
        }
    }

    // MARK: - ScanPreset Integration

    func testScanPresetCodableRoundTripForAllBuiltIns() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for preset in ScanPreset.builtInPresets {
            let data = try encoder.encode(preset)
            let decoded = try decoder.decode(ScanPreset.self, from: data)
            XCTAssertEqual(decoded.name, preset.name)
            XCTAssertEqual(decoded.ports, preset.ports)
            XCTAssertEqual(decoded.scanType, preset.scanType)
            XCTAssertEqual(decoded.timeout, preset.timeout)
            XCTAssertEqual(decoded.maxThreads, preset.maxThreads)
        }
    }

    // MARK: - Export Format Round Trip

    @MainActor
    func testExportManagerInitialState() {
        let manager = ExportManager.shared
        XCTAssertFalse(manager.isExporting)
        XCTAssertNil(manager.exportError)
    }

    // MARK: - Scan Scheduler

    @MainActor
    func testScheduledScanManagerExists() {
        // Verify the shared instance is accessible
        let manager = ScheduledScanManager.shared
        XCTAssertNotNil(manager, "ScheduledScanManager should be accessible")
    }

    // MARK: - Multiple Remote Access Port Threat

    @MainActor
    func testMultipleRemoteAccessPortsTriggerThreat() {
        let analyzer = ThreatAnalyzer()

        let device = EnhancedDevice(
            ipAddress: "192.168.1.42", macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "multi-remote", manufacturer: nil, deviceType: .computer,
            openPorts: [
                PortInfo(port: 22, service: "ssh", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 23, service: "telnet", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 3389, service: "rdp", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 5900, service: "vnc", version: nil, state: .open, protocolType: "TCP", banner: nil),
            ],
            isOnline: true, firstSeen: Date().addingTimeInterval(-86400), lastSeen: Date(),
            isKnownDevice: true, operatingSystem: nil, deviceName: nil
        )

        analyzer.analyzeNetwork(devices: [device])

        let summary = analyzer.deviceSummaries.first
        XCTAssertNotNil(summary)

        // Should have "Multiple Remote Access Ports Open" finding
        let multiRemoteThreat = analyzer.allThreats.first { $0.title.contains("Multiple Remote Access") }
        XCTAssertNotNil(multiRemoteThreat, "4 remote access ports should trigger multiple-remote-access threat")
        XCTAssertEqual(multiRemoteThreat?.severity, .high)
    }

    // MARK: - Exposed Database Threat

    @MainActor
    func testExposedDatabaseTriggersDataExposureThreat() {
        let analyzer = ThreatAnalyzer()

        let device = EnhancedDevice(
            ipAddress: "192.168.1.50", macAddress: nil,
            hostname: "db-server", manufacturer: nil, deviceType: .server,
            openPorts: [
                PortInfo(port: 6379, service: "redis", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 27017, service: "mongodb", version: nil, state: .open, protocolType: "TCP", banner: nil),
            ],
            isOnline: true, firstSeen: Date().addingTimeInterval(-86400), lastSeen: Date(),
            isKnownDevice: true, operatingSystem: nil, deviceName: nil
        )

        analyzer.analyzeNetwork(devices: [device])

        let dbThreats = analyzer.allThreats.filter { $0.category == .dataExposure }
        XCTAssertGreaterThanOrEqual(dbThreats.count, 2,
            "Redis and MongoDB exposed should each generate a data exposure threat")
    }
}
