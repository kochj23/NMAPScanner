//
//  NMAPXMLParsingTests.swift
//  NMAPScannerTests
//
//  Tests for nmap output parsing: port lines, OS detection, service versions,
//  NSE script output, and ARP table parsing.
//
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import NMAPScanner

final class NMAPXMLParsingTests: XCTestCase {

    // MARK: - Port Line Parsing (parseNmapPorts pattern)

    /// The AdvancedPortScanner.parseNmapPorts method extracts open ports from nmap text output.
    /// We replicate the same logic here to validate the parsing pattern.

    private func parseNmapPorts(_ output: String) -> [Int] {
        var ports: [Int] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 && components[0].contains("/") && components[1] == "open" {
                if let port = Int(components[0].components(separatedBy: "/")[0]) {
                    ports.append(port)
                }
            }
        }
        return ports
    }

    func testParseStandardNmapPortOutput() {
        let output = """
        Starting Nmap 7.94 ( https://nmap.org ) at 2026-05-01 12:00 PDT
        Nmap scan report for 192.168.1.1
        Host is up (0.0035s latency).

        PORT     STATE  SERVICE
        22/tcp   open   ssh
        80/tcp   open   http
        443/tcp  open   https
        3306/tcp closed mysql
        8080/tcp open   http-proxy

        Nmap done: 1 IP address (1 host up) scanned in 1.23 seconds
        """

        let ports = parseNmapPorts(output)
        XCTAssertEqual(ports.count, 4, "Should find 4 open ports (22, 80, 443, 8080)")
        XCTAssertTrue(ports.contains(22))
        XCTAssertTrue(ports.contains(80))
        XCTAssertTrue(ports.contains(443))
        XCTAssertTrue(ports.contains(8080))
        XCTAssertFalse(ports.contains(3306), "Closed ports should not be included")
    }

    func testParseFilteredPortsExcluded() {
        let output = """
        PORT     STATE    SERVICE
        22/tcp   open     ssh
        80/tcp   filtered http
        443/tcp  open     https
        """

        let ports = parseNmapPorts(output)
        XCTAssertEqual(ports.count, 2, "Should find only 2 open ports, not filtered")
        XCTAssertTrue(ports.contains(22))
        XCTAssertTrue(ports.contains(443))
        XCTAssertFalse(ports.contains(80), "Filtered port should not be included")
    }

    func testParseEmptyNmapOutput() {
        let ports = parseNmapPorts("")
        XCTAssertTrue(ports.isEmpty)
    }

    func testParseNmapOutputWithNoOpenPorts() {
        let output = """
        Starting Nmap 7.94
        Nmap scan report for 192.168.1.50
        Host is up (0.010s latency).
        All 1000 scanned ports on 192.168.1.50 are closed

        Nmap done: 1 IP address (1 host up) scanned in 2.00 seconds
        """

        let ports = parseNmapPorts(output)
        XCTAssertTrue(ports.isEmpty, "Should find no open ports when all are closed")
    }

    func testParseNmapHighPortNumbers() {
        let output = """
        PORT      STATE SERVICE
        11434/tcp open  unknown
        32400/tcp open  plex
        49152/tcp open  unknown
        """

        let ports = parseNmapPorts(output)
        XCTAssertEqual(ports.count, 3)
        XCTAssertTrue(ports.contains(11434))
        XCTAssertTrue(ports.contains(32400))
        XCTAssertTrue(ports.contains(49152))
    }

    func testParseNmapUDPPorts() {
        let output = """
        PORT     STATE         SERVICE
        53/udp   open          domain
        67/udp   open|filtered dhcps
        123/udp  open          ntp
        161/udp  open          snmp
        """

        let ports = parseNmapPorts(output)
        // Only "open" state, not "open|filtered"
        XCTAssertTrue(ports.contains(53))
        XCTAssertTrue(ports.contains(123))
        XCTAssertTrue(ports.contains(161))
        XCTAssertFalse(ports.contains(67), "open|filtered should not match 'open' exactly")
    }

    // MARK: - OS Detection Parsing

    private func parseOSDetection(_ output: String) -> (String?, String?, Int) {
        let lines = output.components(separatedBy: "\n")
        var osName: String?
        var osFamily: String?
        var accuracy: Int = 0

        for line in lines {
            if line.contains("Running:") {
                osFamily = line.replacingOccurrences(of: "Running:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("OS details:") {
                osName = line.replacingOccurrences(of: "OS details:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("Aggressive OS guesses:") {
                let parts = line.components(separatedBy: "(")
                if parts.count > 1 {
                    let accuracyStr = parts[1].components(separatedBy: "%")[0]
                    accuracy = Int(accuracyStr) ?? 0
                    osName = parts[0].replacingOccurrences(of: "Aggressive OS guesses:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return (osName, osFamily, accuracy)
    }

    func testParseOSDetectionWithFullMatch() {
        let output = """
        Nmap scan report for 192.168.1.1
        Running: Linux 5.X
        OS details: Linux 5.4 - 5.15
        """

        let (osName, osFamily, _) = parseOSDetection(output)
        XCTAssertEqual(osName, "Linux 5.4 - 5.15")
        XCTAssertEqual(osFamily, "Linux 5.X")
    }

    func testParseOSDetectionWithAggressiveGuess() {
        // nmap format: "Aggressive OS guesses: Linux 5.4 (95%), Linux 5.15 (90%)"
        // The parser splits on "(" and takes the first number before "%"
        let output = """
        Nmap scan report for 192.168.1.33
        Aggressive OS guesses: Apple macOS 14 Sonoma (95%), Apple macOS 13 Ventura (90%)
        """

        let (osName, _, accuracy) = parseOSDetection(output)
        XCTAssertEqual(accuracy, 95)
        XCTAssertNotNil(osName)
        XCTAssertTrue(osName?.contains("Apple macOS") ?? false)
    }

    func testParseOSDetectionWithNoMatch() {
        let output = """
        Nmap scan report for 192.168.1.200
        No OS matches for host
        """

        let (osName, osFamily, accuracy) = parseOSDetection(output)
        XCTAssertNil(osName)
        XCTAssertNil(osFamily)
        XCTAssertEqual(accuracy, 0)
    }

    // MARK: - Service Version Parsing

    private func parseServiceVersions(_ output: String) -> [Int: String] {
        var versions: [Int: String] = [:]
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 3 && components[0].contains("/") {
                if let port = Int(components[0].components(separatedBy: "/")[0]) {
                    let version = components[2...].joined(separator: " ")
                    versions[port] = version
                }
            }
        }
        return versions
    }

    func testParseServiceVersionsStandard() {
        let output = """
        PORT     STATE SERVICE     VERSION
        22/tcp   open  ssh         OpenSSH 8.9p1 Ubuntu 3ubuntu0.4
        80/tcp   open  http        nginx 1.18.0
        443/tcp  open  ssl/https   nginx 1.18.0
        3306/tcp open  mysql       MySQL 8.0.35
        """

        let versions = parseServiceVersions(output)
        XCTAssertEqual(versions.count, 4)
        XCTAssertTrue(versions[22]?.contains("OpenSSH") ?? false)
        XCTAssertTrue(versions[80]?.contains("nginx") ?? false)
        XCTAssertTrue(versions[3306]?.contains("MySQL") ?? false)
    }

    func testParseServiceVersionsEmpty() {
        let versions = parseServiceVersions("")
        XCTAssertTrue(versions.isEmpty)
    }

    // MARK: - ARP Output Parsing

    private func parseARPOutput(_ output: String) -> [String] {
        var ips: [String] = []
        let lines = output.split(separator: "\n")
        for line in lines {
            if let startIndex = line.firstIndex(of: "("),
               let endIndex = line.firstIndex(of: ")"),
               startIndex < endIndex {
                let ipString = String(line[line.index(after: startIndex)..<endIndex])
                let parts = ipString.split(separator: ".")
                if parts.count == 4 {
                    let allValid = parts.allSatisfy { if let n = Int($0) { return n >= 0 && n <= 255 } else { return false } }
                    if allValid { ips.append(ipString) }
                }
            }
        }
        return ips
    }

    func testParseARPTableStandard() {
        let output = """
        ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
        ? (192.168.1.33) at 11:22:33:44:55:66 on en0 ifscope [ethernet]
        ? (192.168.1.100) at ab:cd:ef:01:23:45 on en0 ifscope [ethernet]
        """

        let ips = parseARPOutput(output)
        XCTAssertEqual(ips.count, 3)
        XCTAssertTrue(ips.contains("192.168.1.1"))
        XCTAssertTrue(ips.contains("192.168.1.33"))
        XCTAssertTrue(ips.contains("192.168.1.100"))
    }

    func testParseARPTableWithIncomplete() {
        let output = """
        ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
        ? (192.168.1.2) at (incomplete) on en0 ifscope [ethernet]
        """

        let ips = parseARPOutput(output)
        XCTAssertEqual(ips.count, 2, "Should still extract IP from incomplete ARP entry")
    }

    func testParseARPTableRejectsInvalidIPs() {
        let output = """
        ? (999.999.999.999) at aa:bb:cc:dd:ee:ff on en0
        ? (not.an.ip.address) at bb:cc:dd:ee:ff:00 on en0
        """

        let ips = parseARPOutput(output)
        XCTAssertTrue(ips.isEmpty, "Invalid IPs should be rejected")
    }

    // MARK: - NSE Script Output Parsing

    func testNSESeverityDetermination() {
        // Replicate the determineSeverity logic from AdvancedPortScanner
        func determineSeverity(_ output: [String]) -> NSEScriptResult.Severity {
            let text = output.joined(separator: " ").lowercased()
            if text.contains("critical") || text.contains("exploit") || text.contains("vulnerable") {
                return .high
            } else if text.contains("warning") || text.contains("weak") || text.contains("insecure") {
                return .medium
            } else {
                return .info
            }
        }

        XCTAssertEqual(determineSeverity(["VULNERABLE: CVE-2021-44228"]), .high)
        XCTAssertEqual(determineSeverity(["exploit found"]), .high)
        XCTAssertEqual(determineSeverity(["critical issue detected"]), .high)
        XCTAssertEqual(determineSeverity(["warning: weak cipher"]), .medium)
        XCTAssertEqual(determineSeverity(["insecure protocol"]), .medium)
        XCTAssertEqual(determineSeverity(["service running normally"]), .info)
    }

    // MARK: - OSDetectionResult Model

    func testOSDetectionResultDefaults() {
        let result = OSDetectionResult()
        XCTAssertNil(result.osName)
        XCTAssertNil(result.osFamily)
        XCTAssertEqual(result.accuracy, 0)
    }

    func testOSDetectionResultWithValues() {
        let result = OSDetectionResult(osName: "Linux 5.15", osFamily: "Linux", accuracy: 95)
        XCTAssertEqual(result.osName, "Linux 5.15")
        XCTAssertEqual(result.osFamily, "Linux")
        XCTAssertEqual(result.accuracy, 95)
    }

    // MARK: - AdvancedScanResult Report Export

    @MainActor
    func testAdvancedScanResultExportContainsAllSections() {
        var result = AdvancedScanResult(
            ipAddress: "192.168.1.1",
            hostname: "router.local",
            scanProfile: .aggressive
        )
        result.tcpPorts = [22, 80, 443]
        result.udpPorts = [53, 123]
        result.osDetection = OSDetectionResult(osName: "Linux 5.15", osFamily: "Linux", accuracy: 95)
        result.serviceVersions = [22: "OpenSSH 8.9", 80: "nginx 1.18"]
        result.completionDate = Date()

        let report = AdvancedPortScanner.shared.exportResults(result)

        XCTAssertTrue(report.contains("192.168.1.1"))
        XCTAssertTrue(report.contains("router.local"))
        XCTAssertTrue(report.contains("Aggressive Scan"))
        XCTAssertTrue(report.contains("TCP Ports"))
        XCTAssertTrue(report.contains("UDP Ports"))
        XCTAssertTrue(report.contains("OS Detection"))
        XCTAssertTrue(report.contains("Linux 5.15"))
        XCTAssertTrue(report.contains("Service Versions"))
        XCTAssertTrue(report.contains("OpenSSH"))
    }

    @MainActor
    func testAdvancedScanResultExportMinimal() {
        let result = AdvancedScanResult(
            ipAddress: "10.0.0.1",
            hostname: nil,
            scanProfile: .quick
        )

        let report = AdvancedPortScanner.shared.exportResults(result)
        XCTAssertTrue(report.contains("10.0.0.1"))
        XCTAssertTrue(report.contains("Quick Scan"))
        XCTAssertFalse(report.contains("Hostname:"), "No hostname should omit hostname line")
    }
}
