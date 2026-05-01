//
//  DeviceModelTests.swift
//  NMAPScannerTests
//
//  Tests for EnhancedDevice, PortInfo, DeviceType, and device-related
//  data models used throughout the scanning and threat analysis pipeline.
//
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import NMAPScanner

final class DeviceModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeDevice(
        ip: String = "192.168.1.100",
        mac: String? = "AA:BB:CC:DD:EE:FF",
        hostname: String? = "test-device",
        deviceType: EnhancedDevice.DeviceType = .unknown,
        openPorts: [PortInfo] = [],
        isKnownDevice: Bool = true,
        firstSeen: Date = Date().addingTimeInterval(-86400),
        deviceName: String? = nil,
        os: String? = nil
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
            operatingSystem: os,
            deviceName: deviceName
        )
    }

    private func makePort(
        port: Int,
        service: String = "unknown",
        state: PortInfo.PortState = .open,
        protocolType: String = "TCP"
    ) -> PortInfo {
        return PortInfo(port: port, service: service, version: nil, state: state, protocolType: protocolType, banner: nil)
    }

    // MARK: - EnhancedDevice Properties

    func testDeviceIdentity() {
        let device1 = makeDevice(ip: "192.168.1.1")
        let device2 = makeDevice(ip: "192.168.1.1")
        // Each device gets a unique UUID
        XCTAssertNotEqual(device1.id, device2.id)
    }

    func testDeviceDisplayNamePriority() {
        // deviceName > hostname > ipAddress
        let named = makeDevice(hostname: "host", deviceName: "My Router")
        XCTAssertEqual(named.displayName, "My Router")

        let hostOnly = makeDevice(hostname: "host", deviceName: nil)
        XCTAssertEqual(hostOnly.displayName, "host")

        let ipOnly = makeDevice(ip: "10.0.0.1", hostname: nil, deviceName: nil)
        XCTAssertEqual(ipOnly.displayName, "10.0.0.1")
    }

    func testDeviceTypeRawValues() {
        XCTAssertEqual(EnhancedDevice.DeviceType.router.rawValue, "Router")
        XCTAssertEqual(EnhancedDevice.DeviceType.server.rawValue, "Server")
        XCTAssertEqual(EnhancedDevice.DeviceType.computer.rawValue, "Computer")
        XCTAssertEqual(EnhancedDevice.DeviceType.mobile.rawValue, "Mobile Device")
        XCTAssertEqual(EnhancedDevice.DeviceType.iot.rawValue, "IoT Device")
        XCTAssertEqual(EnhancedDevice.DeviceType.printer.rawValue, "Printer")
        XCTAssertEqual(EnhancedDevice.DeviceType.unknown.rawValue, "Unknown")
    }

    // MARK: - Rogue Device Detection

    func testKnownDeviceNeverRogue() {
        let device = makeDevice(isKnownDevice: true, firstSeen: Date())
        XCTAssertFalse(device.isRogue)
        XCTAssertFalse(device.isRogue(timeWindowSeconds: 86400))
    }

    func testUnknownDeviceRecentlySeenIsRogue() {
        let device = makeDevice(isKnownDevice: false, firstSeen: Date().addingTimeInterval(-60))
        XCTAssertTrue(device.isRogue, "Unknown device seen 60s ago with default 1hr window")
    }

    func testUnknownDeviceOldNotRogue() {
        let device = makeDevice(isKnownDevice: false, firstSeen: Date().addingTimeInterval(-7200))
        XCTAssertFalse(device.isRogue, "Unknown device seen 2hr ago with default 1hr window")
    }

    func testRogueDetectionCustomWindow() {
        let device = makeDevice(isKnownDevice: false, firstSeen: Date().addingTimeInterval(-120))

        XCTAssertTrue(device.isRogue(timeWindowSeconds: 300), "Within 5-min window")
        XCTAssertFalse(device.isRogue(timeWindowSeconds: 60), "Outside 1-min window")
    }

    func testRogueDetectionEdgeCaseExactBoundary() {
        let now = Date()
        let device = makeDevice(isKnownDevice: false, firstSeen: now.addingTimeInterval(-3600))
        // At exactly 3600 seconds, the condition is firstSeen.timeIntervalSinceNow > -3600
        // timeIntervalSinceNow for 3600s ago = -3600, so -3600 > -3600 is false
        XCTAssertFalse(device.isRogue(timeWindowSeconds: 3600),
            "Device at exact boundary should NOT be rogue")
    }

    // MARK: - PortInfo Classification

    func testPortStateRawValues() {
        XCTAssertEqual(PortInfo.PortState.open.rawValue, "Open")
        XCTAssertEqual(PortInfo.PortState.filtered.rawValue, "Filtered")
        XCTAssertEqual(PortInfo.PortState.closed.rawValue, "Closed")
    }

    func testBackdoorPortSet() {
        let knownBackdoors: [Int] = [31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374, 2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002]
        for port in knownBackdoors {
            XCTAssertTrue(PortInfo.backdoorPorts.contains(port), "Port \(port) should be in backdoor set")
        }
    }

    func testRemoteAccessPortSet() {
        let remotePorts: [Int] = [22, 23, 3389, 5900, 5901, 5902, 5800, 5801, 5802]
        for port in remotePorts {
            XCTAssertTrue(PortInfo.remoteAccessPorts.contains(port), "Port \(port) should be in remote access set")
        }
    }

    func testDatabasePortSet() {
        let dbPorts: [Int] = [3306, 5432, 1433, 1434, 27017, 27018, 27019, 6379, 9042, 7000, 7001, 8086]
        for port in dbPorts {
            XCTAssertTrue(PortInfo.databasePorts.contains(port), "Port \(port) should be in database set")
        }
    }

    func testPortSuspiciousLogic() {
        // Backdoor port is always suspicious
        let backdoor = makePort(port: 31337)
        XCTAssertTrue(backdoor.isSuspicious)

        // SSH on 22 is common, not suspicious
        let ssh = PortInfo(port: 22, service: "ssh", version: nil, state: .open, protocolType: "TCP", banner: nil)
        XCTAssertFalse(ssh.isSuspicious, "SSH on port 22 is a common service and should not be suspicious")

        // Telnet is remote access but NOT common service => suspicious
        let telnet = makePort(port: 23, service: "telnet")
        XCTAssertTrue(telnet.isRemoteAccessPort)
        XCTAssertFalse(telnet.isCommonService)
        XCTAssertTrue(telnet.isSuspicious)

        // Database on non-common port is suspicious
        let cassandra = makePort(port: 9042, service: "cassandra")
        XCTAssertTrue(cassandra.isDatabasePort)
        XCTAssertTrue(cassandra.isSuspicious)

        // MySQL and PostgreSQL are excluded from db suspicion
        let mysql = makePort(port: 3306, service: "mysql")
        XCTAssertTrue(mysql.isDatabasePort)
        XCTAssertFalse(mysql.isSuspicious, "MySQL on 3306 should not be suspicious (common)")

        let postgres = makePort(port: 5432, service: "postgresql")
        XCTAssertTrue(postgres.isDatabasePort)
        XCTAssertFalse(postgres.isSuspicious, "PostgreSQL on 5432 should not be suspicious (common)")
    }

    func testCommonServiceDetection() {
        let ssh = makePort(port: 22, service: "ssh")
        XCTAssertTrue(ssh.isCommonService)

        let rdp = PortInfo(port: 3389, service: "RDP", version: nil, state: .open, protocolType: "TCP", banner: nil)
        XCTAssertTrue(rdp.isCommonService)

        let telnet = makePort(port: 23, service: "telnet")
        XCTAssertFalse(telnet.isCommonService)

        let http = makePort(port: 80, service: "http")
        XCTAssertFalse(http.isCommonService, "HTTP on 80 is NOT in the isCommonService list")
    }

    // MARK: - PortScanConfiguration Service Names

    func testServiceNameMappingCoversStandardPorts() {
        let expectedMappings: [Int: String] = [
            20: "FTP Data", 21: "FTP Control", 22: "SSH", 23: "Telnet",
            25: "SMTP", 53: "DNS", 80: "HTTP", 110: "POP3", 143: "IMAP",
            443: "HTTPS", 445: "SMB", 587: "SMTP Submission", 993: "IMAPS",
            995: "POP3S", 3306: "MySQL", 3389: "RDP", 5432: "PostgreSQL",
            5900: "VNC", 6379: "Redis", 8080: "HTTP Proxy", 27017: "MongoDB",
        ]

        for (port, expectedName) in expectedMappings {
            XCTAssertEqual(PortScanConfiguration.serviceName(for: port), expectedName,
                "Port \(port) should map to '\(expectedName)'")
        }
    }

    func testServiceNameForAIServices() {
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 11434), "Ollama")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 7860), "Gradio")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 8188), "ComfyUI")
    }

    func testServiceNameForUnknownPort() {
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 59999), "Port 59999")
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 1), "TCPMUX")
    }

    // MARK: - PortRiskLevel Classification

    func testPortRiskLevelHighPorts() {
        let highRisk = [21, 23, 25, 53, 80, 110, 143, 443, 445, 3389, 5900]
        for port in highRisk {
            XCTAssertEqual(PortScanConfiguration.riskLevel(for: port), .high,
                "Port \(port) should be high risk")
        }
    }

    func testPortRiskLevelMediumPorts() {
        let medRisk = [22, 135, 139, 161, 389, 636, 1433, 3306, 5432, 8080]
        for port in medRisk {
            XCTAssertEqual(PortScanConfiguration.riskLevel(for: port), .medium,
                "Port \(port) should be medium risk")
        }
    }

    func testPortRiskLevelLowPorts() {
        // Port < 1024, not in high or medium lists
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 500), .low)
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 999), .low)
    }

    func testPortRiskLevelMinimalPorts() {
        // Port >= 1024, not in any special list
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 50000), .minimal)
        XCTAssertEqual(PortScanConfiguration.riskLevel(for: 65535), .minimal)
    }

    // MARK: - PortScanMode

    func testPortScanModePortCounts() {
        XCTAssertEqual(PortScanMode.standard.getPorts().count, 1024)
        XCTAssertEqual(PortScanMode.comprehensive.getPorts().count, 65535)
        XCTAssertGreaterThan(PortScanMode.current.getPorts().count, 50)
    }

    func testPortScanModeCurrentContainsCommonServices() {
        let common = PortScanMode.current.getPorts()
        XCTAssertTrue(common.contains(22), "Common ports should include SSH")
        XCTAssertTrue(common.contains(80), "Common ports should include HTTP")
        XCTAssertTrue(common.contains(443), "Common ports should include HTTPS")
    }

    func testPortScanModeCodableRoundTrip() throws {
        for mode in PortScanMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PortScanMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - HomeKitMDNSInfo

    func testHomeKitMDNSInfoIcons() {
        let airplay = HomeKitMDNSInfo(deviceName: "Apple TV", serviceType: "_airplay._tcp", category: "Media", isHomeKitAccessory: false, discoveredAt: Date())
        XCTAssertEqual(airplay.icon, "airplayvideo")

        let homekit = HomeKitMDNSInfo(deviceName: "Smart Plug", serviceType: "_hap._tcp", category: "Switch", isHomeKitAccessory: true, discoveredAt: Date())
        XCTAssertEqual(homekit.icon, "homekit")

        let companion = HomeKitMDNSInfo(deviceName: "MacBook", serviceType: "_companion-link._tcp", category: "Computer", isHomeKitAccessory: false, discoveredAt: Date())
        XCTAssertEqual(companion.icon, "applelogo")

        let other = HomeKitMDNSInfo(deviceName: "IoT Sensor", serviceType: "_http._tcp", category: "Sensor", isHomeKitAccessory: false, discoveredAt: Date())
        XCTAssertEqual(other.icon, "sensor")
    }

    // MARK: - ExportManager Formats

    @MainActor
    func testExportFormatProperties() {
        XCTAssertEqual(ExportManager.ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportManager.ExportFormat.csv.fileExtension, "csv")
        XCTAssertEqual(ExportManager.ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportManager.ExportFormat.html.fileExtension, "html")

        for format in ExportManager.ExportFormat.allCases {
            XCTAssertFalse(format.icon.isEmpty, "Format \(format.rawValue) should have an icon")
            XCTAssertFalse(format.fileExtension.isEmpty, "Format \(format.rawValue) should have an extension")
        }
    }

    @MainActor
    func testExportFormatCount() {
        XCTAssertEqual(ExportManager.ExportFormat.allCases.count, 4,
            "Should have 4 export formats: PDF, CSV, JSON, HTML")
    }
}
