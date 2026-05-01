//
//  ScanProfileTests.swift
//  NMAPScannerTests
//
//  Tests for scan profile configuration, nmap argument generation, and scan presets.
//  Validates that each profile produces the correct nmap flags, port lists, and timing.
//
//  Created by Jordan Koch on 2026-04-21.
//

import XCTest
@testable import NMAPScanner

final class ScanProfileTests: XCTestCase {

    // MARK: - AdvancedPortScanner.ScanProfile nmap Arguments

    func testQuickScanProfileGeneratesCorrectFlags() {
        let profile = AdvancedPortScanner.ScanProfile.quick
        let args = profile.nmapArgs

        XCTAssertTrue(args.contains("-T4"), "Quick scan should use aggressive timing (-T4)")
        XCTAssertTrue(args.contains("-F"), "Quick scan should use fast mode (-F) for top 100 ports")
        XCTAssertEqual(args.count, 2, "Quick scan should have exactly 2 arguments")
    }

    func testStandardScanProfileGeneratesCorrectFlags() {
        let profile = AdvancedPortScanner.ScanProfile.standard
        let args = profile.nmapArgs

        XCTAssertTrue(args.contains("-sV"), "Standard scan should include service detection (-sV)")
        XCTAssertTrue(args.contains("-sC"), "Standard scan should include default scripts (-sC)")
        XCTAssertTrue(args.contains("-T3"), "Standard scan should use normal timing (-T3)")
        XCTAssertEqual(args.count, 3)
    }

    func testComprehensiveScanProfileGeneratesCorrectFlags() {
        let profile = AdvancedPortScanner.ScanProfile.comprehensive
        let args = profile.nmapArgs

        XCTAssertTrue(args.contains("-sS"), "Comprehensive scan should use TCP SYN scan (-sS)")
        XCTAssertTrue(args.contains("-sU"), "Comprehensive scan should include UDP scanning (-sU)")
        XCTAssertTrue(args.contains("-O"), "Comprehensive scan should include OS detection (-O)")
        XCTAssertTrue(args.contains("-sV"), "Comprehensive scan should include service version detection (-sV)")
        XCTAssertTrue(args.contains("-T4"), "Comprehensive scan should use aggressive timing (-T4)")
        XCTAssertTrue(args.contains("-p-"), "Comprehensive scan should scan all ports (-p-)")
        XCTAssertEqual(args.count, 6)
    }

    func testAggressiveScanProfileGeneratesCorrectFlags() {
        let profile = AdvancedPortScanner.ScanProfile.aggressive
        let args = profile.nmapArgs

        XCTAssertTrue(args.contains("-A"), "Aggressive scan should use -A flag (OS, version, script, traceroute)")
        XCTAssertTrue(args.contains("-T4"), "Aggressive scan should use aggressive timing (-T4)")
        XCTAssertEqual(args.count, 2)
    }

    func testStealthScanProfileGeneratesCorrectFlags() {
        let profile = AdvancedPortScanner.ScanProfile.stealth
        let args = profile.nmapArgs

        XCTAssertTrue(args.contains("-sS"), "Stealth scan should use SYN scan (-sS)")
        XCTAssertTrue(args.contains("-T2"), "Stealth scan should use slow timing (-T2)")
        XCTAssertTrue(args.contains("-f"), "Stealth scan should fragment packets (-f)")
        XCTAssertEqual(args.count, 3)
    }

    func testCustomScanProfileReturnsEmptyArgs() {
        let profile = AdvancedPortScanner.ScanProfile.custom
        let args = profile.nmapArgs

        XCTAssertTrue(args.isEmpty, "Custom scan should return empty args (user configures)")
    }

    // MARK: - ScanProfile Properties

    func testAllProfilesHaveDescriptions() {
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            XCTAssertFalse(profile.description.isEmpty,
                "Profile \(profile.rawValue) should have a non-empty description")
        }
    }

    func testAllProfilesHaveUniqueDescriptions() {
        let descriptions = AdvancedPortScanner.ScanProfile.allCases.map { $0.description }
        let uniqueDescriptions = Set(descriptions)
        XCTAssertEqual(descriptions.count, uniqueDescriptions.count,
            "Each scan profile should have a unique description")
    }

    func testScanProfileRawValuesAreUserFriendly() {
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.quick.rawValue, "Quick Scan")
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.standard.rawValue, "Standard Scan")
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.comprehensive.rawValue, "Comprehensive Scan")
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.aggressive.rawValue, "Aggressive Scan")
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.stealth.rawValue, "Stealth Scan")
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.custom.rawValue, "Custom Scan")
    }

    func testScanProfileCount() {
        XCTAssertEqual(AdvancedPortScanner.ScanProfile.allCases.count, 6,
            "Should have exactly 6 scan profiles")
    }

    // MARK: - ScanPreset Configuration

    func testWebServicesPresetContainsHTTPPorts() {
        let preset = ScanPreset.webServices
        XCTAssertTrue(preset.ports.contains(80), "Web services should include HTTP port 80")
        XCTAssertTrue(preset.ports.contains(443), "Web services should include HTTPS port 443")
        XCTAssertTrue(preset.ports.contains(8080), "Web services should include HTTP proxy port 8080")
        XCTAssertTrue(preset.ports.contains(8443), "Web services should include HTTPS alt port 8443")
        XCTAssertTrue(preset.isBuiltIn)
        XCTAssertEqual(preset.scanType, .fast)
    }

    func testIoTDevicesPresetContainsMQTTPorts() {
        let preset = ScanPreset.iotDevices
        XCTAssertTrue(preset.ports.contains(1883), "IoT should include MQTT port 1883")
        XCTAssertTrue(preset.ports.contains(8883), "IoT should include MQTT/TLS port 8883")
        XCTAssertTrue(preset.ports.contains(5683), "IoT should include CoAP port 5683")
        XCTAssertTrue(preset.isBuiltIn)
        XCTAssertEqual(preset.scanType, .targeted)
    }

    func testDatabasesPresetContainsAllMajorDBPorts() {
        let preset = ScanPreset.databases
        XCTAssertTrue(preset.ports.contains(3306), "Should include MySQL port 3306")
        XCTAssertTrue(preset.ports.contains(5432), "Should include PostgreSQL port 5432")
        XCTAssertTrue(preset.ports.contains(27017), "Should include MongoDB port 27017")
        XCTAssertTrue(preset.ports.contains(6379), "Should include Redis port 6379")
        XCTAssertTrue(preset.ports.contains(1433), "Should include MS SQL port 1433")
        XCTAssertTrue(preset.isBuiltIn)
    }

    func testFileServersPresetContainsSMBAndNFS() {
        let preset = ScanPreset.fileServers
        XCTAssertTrue(preset.ports.contains(445), "Should include SMB port 445")
        XCTAssertTrue(preset.ports.contains(139), "Should include NetBIOS port 139")
        XCTAssertTrue(preset.ports.contains(548), "Should include AFP port 548")
        XCTAssertTrue(preset.ports.contains(2049), "Should include NFS port 2049")
        XCTAssertTrue(preset.ports.contains(21), "Should include FTP port 21")
        XCTAssertTrue(preset.ports.contains(22), "Should include SSH/SFTP port 22")
    }

    func testMailServersPresetContainsAllEmailPorts() {
        let preset = ScanPreset.mailServers
        XCTAssertTrue(preset.ports.contains(25), "Should include SMTP port 25")
        XCTAssertTrue(preset.ports.contains(110), "Should include POP3 port 110")
        XCTAssertTrue(preset.ports.contains(143), "Should include IMAP port 143")
        XCTAssertTrue(preset.ports.contains(993), "Should include IMAPS port 993")
        XCTAssertTrue(preset.ports.contains(995), "Should include POP3S port 995")
        XCTAssertTrue(preset.ports.contains(587), "Should include SMTP submission port 587")
    }

    func testRemoteAccessPresetContainsSSHRDPVNC() {
        let preset = ScanPreset.remoteAccess
        XCTAssertTrue(preset.ports.contains(22), "Should include SSH port 22")
        XCTAssertTrue(preset.ports.contains(23), "Should include Telnet port 23")
        XCTAssertTrue(preset.ports.contains(3389), "Should include RDP port 3389")
        XCTAssertTrue(preset.ports.contains(5900), "Should include VNC port 5900")
    }

    func testSecurityAuditPresetScansFirst1024Ports() {
        let preset = ScanPreset.securityAudit
        XCTAssertEqual(preset.ports.count, 1024, "Security audit should scan 1024 ports")
        XCTAssertEqual(preset.ports.first, 1, "Should start at port 1")
        XCTAssertEqual(preset.ports.last, 1024, "Should end at port 1024")
        XCTAssertEqual(preset.scanType, .comprehensive)
        XCTAssertEqual(preset.maxThreads, 200, "Security audit should use max threads")
    }

    func testQuickScanPresetHas20Ports() {
        let preset = ScanPreset.quickScan
        XCTAssertEqual(preset.ports.count, 20, "Quick scan should have exactly 20 ports")
        XCTAssertEqual(preset.scanType, .fast)
        XCTAssertEqual(preset.timeout, 1.0, "Quick scan should have 1 second timeout")
    }

    func testBuiltInPresetsCollectionContainsAll10Presets() {
        let presets = ScanPreset.builtInPresets
        XCTAssertEqual(presets.count, 10, "Should have 10 built-in presets")

        let names = Set(presets.map { $0.name })
        XCTAssertTrue(names.contains("Quick Scan"))
        XCTAssertTrue(names.contains("Web Services"))
        XCTAssertTrue(names.contains("IoT Devices"))
        XCTAssertTrue(names.contains("Databases"))
        XCTAssertTrue(names.contains("File Servers"))
        XCTAssertTrue(names.contains("Mail Servers"))
        XCTAssertTrue(names.contains("Remote Access"))
        XCTAssertTrue(names.contains("Printers"))
        XCTAssertTrue(names.contains("Media Devices"))
        XCTAssertTrue(names.contains("Security Audit"))
    }

    func testAllBuiltInPresetsAreMarkedAsBuiltIn() {
        for preset in ScanPreset.builtInPresets {
            XCTAssertTrue(preset.isBuiltIn,
                "Preset '\(preset.name)' should be marked as built-in")
        }
    }

    func testAllPresetPortsAreInValidRange() {
        for preset in ScanPreset.builtInPresets {
            for port in preset.ports {
                XCTAssertGreaterThan(port, 0, "Port should be > 0 in preset '\(preset.name)'")
                XCTAssertLessThanOrEqual(port, 65535, "Port should be <= 65535 in preset '\(preset.name)'")
            }
        }
    }

    func testAllPresetsHavePositiveTimeout() {
        for preset in ScanPreset.builtInPresets {
            XCTAssertGreaterThan(preset.timeout, 0,
                "Preset '\(preset.name)' should have positive timeout")
        }
    }

    func testAllPresetsHavePositiveMaxThreads() {
        for preset in ScanPreset.builtInPresets {
            XCTAssertGreaterThan(preset.maxThreads, 0,
                "Preset '\(preset.name)' should have positive max threads")
        }
    }

    // MARK: - ScanPreset Codable

    func testScanPresetCodableRoundTrip() throws {
        let original = ScanPreset(
            name: "Test Preset",
            description: "A test preset",
            icon: "network",
            color: "blue",
            ports: [80, 443, 8080],
            scanType: .targeted,
            timeout: 2.5,
            maxThreads: 75
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScanPreset.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.icon, original.icon)
        XCTAssertEqual(decoded.color, original.color)
        XCTAssertEqual(decoded.ports, original.ports)
        XCTAssertEqual(decoded.scanType, original.scanType)
        XCTAssertEqual(decoded.timeout, original.timeout)
        XCTAssertEqual(decoded.maxThreads, original.maxThreads)
    }

    func testScanTypeCodableRoundTrip() throws {
        let scanTypes: [ScanPreset.ScanType] = [.targeted, .comprehensive, .fast]
        for scanType in scanTypes {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scanType)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ScanPreset.ScanType.self, from: data)

            XCTAssertEqual(decoded, scanType)
        }
    }

    // MARK: - PortScanMode

    func testPortScanModeStandardReturns1024Ports() {
        let ports = PortScanMode.standard.getPorts()
        XCTAssertEqual(ports.count, 1024)
        XCTAssertEqual(ports.first, 1)
        XCTAssertEqual(ports.last, 1024)
        XCTAssertEqual(PortScanMode.standard.portCount, 1024)
    }

    func testPortScanModeComprehensiveReturnsAllPorts() {
        let ports = PortScanMode.comprehensive.getPorts()
        XCTAssertEqual(ports.count, 65535)
        XCTAssertEqual(ports.first, 1)
        XCTAssertEqual(ports.last, 65535)
        XCTAssertEqual(PortScanMode.comprehensive.portCount, 65536)
    }

    func testPortScanModeCurrentReturnsCommonPorts() {
        let ports = PortScanMode.current.getPorts()
        XCTAssertGreaterThan(ports.count, 50, "Common ports should have at least 50 entries")
        // Should include standard services
        XCTAssertTrue(ports.contains(22), "Common ports should include SSH")
        XCTAssertTrue(ports.contains(80), "Common ports should include HTTP")
        XCTAssertTrue(ports.contains(443), "Common ports should include HTTPS")
    }

    func testPortScanModeDescriptions() {
        for mode in PortScanMode.allCases {
            XCTAssertFalse(mode.description.isEmpty,
                "Port scan mode \(mode.rawValue) should have a description")
        }
    }

    func testPortScanModeEstimatedTimes() {
        for mode in PortScanMode.allCases {
            XCTAssertFalse(mode.estimatedTimePerHost.isEmpty,
                "Port scan mode \(mode.rawValue) should have an estimated time")
        }
    }

    // MARK: - PortScanConfiguration

    func testServiceNameForKnownPorts() {
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 22), "SSH")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 80), "HTTP")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 443), "HTTPS")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 3306), "MySQL")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 5432), "PostgreSQL")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 3389), "RDP")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 445), "SMB")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 11434), "Ollama")
    }

    func testServiceNameForUnknownPortReturnsPortNumber() {
        let result = PortScanConfiguration.serviceName(for: 59999)
        XCTAssertEqual(result, "Port 59999")
    }

    func testPortRiskLevelClassification() {
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 23), .high, "Telnet should be high risk")
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 3389), .high, "RDP should be high risk")
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 22), .medium, "SSH should be medium risk")
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 3306), .medium, "MySQL should be medium risk")
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 500), .low, "Port 500 (< 1024) should be low risk")
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 50000), .minimal, "Port 50000 (>= 1024, not known) should be minimal risk")
    }

    // MARK: - PresetStatistics

    @MainActor
    func testPresetStatisticsCalculation() {
        let manager = ScanPresetManager.shared
        let stats = manager.getPresetStatistics(.quickScan)

        XCTAssertEqual(stats.portCount, 20)
        XCTAssertGreaterThan(stats.estimatedTimePerHost, 0)
        XCTAssertGreaterThan(stats.estimatedTimeFor254Hosts, 0)
        XCTAssertEqual(stats.scanType, .fast)
        XCTAssertEqual(stats.threadsUsed, 100)
    }

    @MainActor
    func testPresetStatisticsFormattedTime() {
        let manager = ScanPresetManager.shared
        let stats = manager.getPresetStatistics(.securityAudit)

        XCTAssertFalse(stats.formattedTimePerHost.isEmpty)
        XCTAssertFalse(stats.formattedTotalTime.isEmpty)
        XCTAssertTrue(stats.formattedTimePerHost.hasSuffix("s"),
            "Formatted time should end with 's' for seconds")
        XCTAssertTrue(stats.formattedTotalTime.contains("m"),
            "Formatted total time should contain 'm' for minutes")
    }
}
