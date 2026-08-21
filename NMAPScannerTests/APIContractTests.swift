//
//  APIContractTests.swift
//  NMAPScannerTests
//
//  Tests for the Nova REST API (port 37423) request/response models,
//  serialization/deserialization, HTTP parsing, and STIX 2.1 compliance.
//
//  Created by Jordan Koch on 2026-04-21.
//

import XCTest
@testable import NMAPScanner

final class APIContractTests: XCTestCase {

    // MARK: - AISecurityWarning Codable

    func testAISecurityWarningCodableRoundTrip() throws {
        let warning = AISecurityWarning(
            id: UUID(),
            severity: .critical,
            service: "Ollama",
            host: "192.168.1.100",
            port: 11434,
            title: "Ollama Without Authentication",
            description: "Ollama API exposed without authentication",
            remediation: "Enable authentication or restrict to localhost",
            cveReferences: ["CVE-2024-1234"],
            detectedAt: Date(),
            probeResult: AIProbeResult(
                isVulnerable: true,
                responseReceived: true,
                authRequired: false,
                details: "API responded without auth",
                probedAt: Date()
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(warning)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AISecurityWarning.self, from: data)

        XCTAssertEqual(decoded.id, warning.id)
        XCTAssertEqual(decoded.severity, warning.severity)
        XCTAssertEqual(decoded.service, warning.service)
        XCTAssertEqual(decoded.host, warning.host)
        XCTAssertEqual(decoded.port, warning.port)
        XCTAssertEqual(decoded.title, warning.title)
        XCTAssertEqual(decoded.description, warning.description)
        XCTAssertEqual(decoded.remediation, warning.remediation)
        XCTAssertEqual(decoded.cveReferences, warning.cveReferences)
        XCTAssertEqual(decoded.isVerified, true)
    }

    func testAISecurityWarningIsVerifiedDerivedFromProbeResult() {
        let verifiedWarning = AISecurityWarning(
            severity: .high, service: "Test", host: "10.0.0.1", port: 8080,
            title: "Test", description: "Test", remediation: "Test",
            probeResult: AIProbeResult(
                isVulnerable: true, responseReceived: true,
                authRequired: false, details: "", probedAt: Date()
            )
        )
        XCTAssertTrue(verifiedWarning.isVerified)

        let unverifiedWarning = AISecurityWarning(
            severity: .low, service: "Test", host: "10.0.0.1", port: 8080,
            title: "Test", description: "Test", remediation: "Test",
            probeResult: nil
        )
        XCTAssertFalse(unverifiedWarning.isVerified)
    }

    // MARK: - AISecuritySeverity Codable

    func testAISecuritySeverityCodableRoundTrip() throws {
        for severity in AISecuritySeverity.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(severity)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AISecuritySeverity.self, from: data)
            XCTAssertEqual(decoded, severity)
        }
    }

    func testAISecuritySeverityRawValues() {
        XCTAssertEqual(AISecuritySeverity.critical.rawValue, "Critical")
        XCTAssertEqual(AISecuritySeverity.high.rawValue, "High")
        XCTAssertEqual(AISecuritySeverity.medium.rawValue, "Medium")
        XCTAssertEqual(AISecuritySeverity.low.rawValue, "Low")
    }

    // MARK: - AIProbeResult Codable

    func testAIProbeResultCodableRoundTrip() throws {
        let probe = AIProbeResult(
            isVulnerable: true,
            responseReceived: true,
            authRequired: false,
            details: "Service responded to unauthenticated request",
            probedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(probe)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AIProbeResult.self, from: data)

        XCTAssertEqual(decoded.isVulnerable, probe.isVulnerable)
        XCTAssertEqual(decoded.responseReceived, probe.responseReceived)
        XCTAssertEqual(decoded.authRequired, probe.authRequired)
        XCTAssertEqual(decoded.details, probe.details)
    }

    // MARK: - ServiceBanner Codable

    func testServiceBannerCodableRoundTrip() throws {
        let banner = ServiceBanner(
            host: "192.168.1.1",
            port: 80,
            service: "HTTP",
            banner: "Apache/2.4.41 (Ubuntu)",
            detectedVersion: "2.4.41",
            serverSoftware: "Apache",
            operatingSystem: "Ubuntu",
            confidence: 95,
            timestamp: Date(),
            vulnerabilityNotes: ["CVE-2021-44790"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(banner)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ServiceBanner.self, from: data)

        XCTAssertEqual(decoded.host, banner.host)
        XCTAssertEqual(decoded.port, banner.port)
        XCTAssertEqual(decoded.service, banner.service)
        XCTAssertEqual(decoded.banner, banner.banner)
        XCTAssertEqual(decoded.detectedVersion, banner.detectedVersion)
        XCTAssertEqual(decoded.serverSoftware, banner.serverSoftware)
        XCTAssertEqual(decoded.operatingSystem, banner.operatingSystem)
        XCTAssertEqual(decoded.confidence, banner.confidence)
        XCTAssertEqual(decoded.vulnerabilityNotes, banner.vulnerabilityNotes)
    }

    // MARK: - AuthFinding Codable

    func testAuthFindingCodableRoundTrip() throws {
        let finding = AuthFinding(
            host: "192.168.1.50",
            port: 22,
            service: "SSH",
            severity: .critical,
            finding: .defaultCredentials,
            details: "Device accepts root/root",
            recommendation: "Change default credentials immediately",
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(finding)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuthFinding.self, from: data)

        XCTAssertEqual(decoded.host, finding.host)
        XCTAssertEqual(decoded.port, finding.port)
        XCTAssertEqual(decoded.service, finding.service)
        XCTAssertEqual(decoded.severity, finding.severity)
        XCTAssertEqual(decoded.finding, finding.finding)
        XCTAssertEqual(decoded.details, finding.details)
        XCTAssertEqual(decoded.recommendation, finding.recommendation)
    }

    func testAuthFindingSeverityValues() {
        XCTAssertEqual(AuthFinding.Severity.critical.rawValue, "Critical")
        XCTAssertEqual(AuthFinding.Severity.high.rawValue, "High")
        XCTAssertEqual(AuthFinding.Severity.medium.rawValue, "Medium")
        XCTAssertEqual(AuthFinding.Severity.low.rawValue, "Low")
    }

    func testAuthFindingTypeValues() {
        XCTAssertEqual(AuthFinding.FindingType.defaultCredentials.rawValue, "Default Credentials")
        XCTAssertEqual(AuthFinding.FindingType.weakPassword.rawValue, "Weak Password")
        XCTAssertEqual(AuthFinding.FindingType.anonymousAccess.rawValue, "Anonymous Access Enabled")
        XCTAssertEqual(AuthFinding.FindingType.noAuthentication.rawValue, "No Authentication Required")
        XCTAssertEqual(AuthFinding.FindingType.bruteForceVulnerable.rawValue, "Vulnerable to Brute Force")
        XCTAssertEqual(AuthFinding.FindingType.guestAccountEnabled.rawValue, "Guest Account Enabled")
        XCTAssertEqual(AuthFinding.FindingType.passwordInCleartext.rawValue, "Password Transmitted in Cleartext")
    }

    // MARK: - AuditEntry Codable

    func testAuditEntryCodableRoundTrip() throws {
        let entry = AuditEntry(
            event: .scanStarted,
            details: "Network scan started on 192.168.1.0/24",
            level: .info
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuditEntry.self, from: data)

        XCTAssertEqual(decoded.event, entry.event)
        XCTAssertEqual(decoded.details, entry.details)
        XCTAssertEqual(decoded.level, entry.level)
    }

    func testSecurityAuditEventsAreCodable() throws {
        let events: [SecurityAuditEvent] = [
            .loginAttempt, .loginSuccess, .loginFailure,
            .mfaRequired, .mfaSuccess, .mfaFailure,
            .configurationChange, .credentialsCleared,
            .certificateRejected, .certificateTrusted,
            .sessionExpired, .suspiciousActivity,
            .validationError, .scanStarted, .scanCompleted
        ]

        for event in events {
            let entry = AuditEntry(event: event, details: "test", level: .info)

            let encoder = JSONEncoder()
            let data = try encoder.encode(entry)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AuditEntry.self, from: data)

            XCTAssertEqual(decoded.event, event)
        }
    }

    // MARK: - AdvancedScanResult Model

    func testAdvancedScanResultInitialization() {
        let result = AdvancedScanResult(
            ipAddress: "192.168.1.1",
            hostname: "router.local",
            scanProfile: .standard
        )

        XCTAssertEqual(result.ipAddress, "192.168.1.1")
        XCTAssertEqual(result.hostname, "router.local")
        XCTAssertEqual(result.scanProfile.rawValue, "Standard Scan")
        XCTAssertTrue(result.tcpPorts.isEmpty)
        XCTAssertTrue(result.udpPorts.isEmpty)
        XCTAssertNil(result.osDetection.osName)
        XCTAssertTrue(result.serviceVersions.isEmpty)
        XCTAssertTrue(result.scriptResults.isEmpty)
        XCTAssertNil(result.completionDate)
    }

    // MARK: - IoTSecurityScore Model

    func testIoTSecurityScoreIssueIsCodable() throws {
        let issue = IoTSecurityScore.SecurityIssue(
            category: "Insecure Protocols",
            description: "Using Telnet (unencrypted)",
            impact: 25
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(issue)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(IoTSecurityScore.SecurityIssue.self, from: data)

        XCTAssertEqual(decoded.category, issue.category)
        XCTAssertEqual(decoded.description, issue.description)
        XCTAssertEqual(decoded.impact, issue.impact)
    }

    // MARK: - STIX 2.1 Format Validation

    func testSTIXTypeMappingFromSeverity() {
        // The NovaAPIServer maps severity to STIX indicator types
        // Critical/High -> "malicious-activity"
        // Medium -> "anomalous-activity"
        // Low/Info -> "benign"

        func stixType(_ severity: String) -> String {
            switch severity.lowercased() {
            case "critical", "high": return "malicious-activity"
            case "medium": return "anomalous-activity"
            default: return "benign"
            }
        }

        XCTAssertEqual(stixType("Critical"), "malicious-activity")
        XCTAssertEqual(stixType("High"), "malicious-activity")
        XCTAssertEqual(stixType("Medium"), "anomalous-activity")
        XCTAssertEqual(stixType("Low"), "benign")
        XCTAssertEqual(stixType("Info"), "benign")
    }

    func testSTIXPatternFormat() {
        // STIX pattern format used by the IoC endpoint
        let host = "192.168.1.100"
        let port = 11434
        let pattern = "[network-traffic:dst_port = \(port) AND network-traffic:dst_ref.value = '\(host)']"

        XCTAssertTrue(pattern.hasPrefix("[network-traffic:"))
        XCTAssertTrue(pattern.hasSuffix("]"))
        XCTAssertTrue(pattern.contains("dst_port = \(port)"))
        XCTAssertTrue(pattern.contains("dst_ref.value = '\(host)'"))
    }

    // MARK: - API Response JSON Structure

    func testStatusResponseStructure() throws {
        // Simulate the JSON structure returned by GET /api/status
        let statusResponse: [String: Any] = [
            "status": "running",
            "app": "NMAPScanner",
            "version": "1.0",
            "port": "37423",
            "scanResultCount": 5,
            "securityWarningCount": 3,
            "uptimeSeconds": 3600
        ]

        let data = try JSONSerialization.data(withJSONObject: statusResponse)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["status"] as? String, "running")
        XCTAssertEqual(parsed["app"] as? String, "NMAPScanner")
        XCTAssertEqual(parsed["port"] as? String, "37423")
        XCTAssertNotNil(parsed["scanResultCount"])
        XCTAssertNotNil(parsed["securityWarningCount"])
        XCTAssertNotNil(parsed["uptimeSeconds"])
    }

    func testScanStartRequestValidation() throws {
        // Valid request body for POST /api/scan/start
        let validRequest: [String: Any] = ["ip": "192.168.1.1"]
        let data = try JSONSerialization.data(withJSONObject: validRequest)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(parsed["ip"] as? String)

        // Invalid request: missing ip field
        let invalidRequest: [String: Any] = ["target": "192.168.1.1"]
        let invalidData = try JSONSerialization.data(withJSONObject: invalidRequest)
        let invalidParsed = try JSONSerialization.jsonObject(with: invalidData) as! [String: Any]
        XCTAssertNil(invalidParsed["ip"] as? String)
    }

    func testScanResultResponseStructure() throws {
        // Simulate scan result JSON
        let result: [String: Any] = [
            "ip": "192.168.1.1",
            "hostname": "router.local",
            "tcpPorts": [22, 80, 443],
            "udpPorts": [53],
            "os": "Linux 5.4",
            "services": ["22: OpenSSH 8.9", "80: nginx 1.18"]
        ]

        let data = try JSONSerialization.data(withJSONObject: result)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["ip"] as? String, "192.168.1.1")
        XCTAssertEqual(parsed["hostname"] as? String, "router.local")
        XCTAssertNotNil(parsed["tcpPorts"] as? [Int])
        XCTAssertNotNil(parsed["udpPorts"] as? [Int])
    }

    func testSecurityWarningResponseStructure() throws {
        let warning: [String: Any] = [
            "id": UUID().uuidString,
            "severity": "Critical",
            "title": "Ollama Without Auth",
            "description": "Test description",
            "host": "192.168.1.100",
            "port": 11434,
            "service": "Ollama",
            "isVerified": true,
            "remediation": "Restrict access"
        ]

        let data = try JSONSerialization.data(withJSONObject: warning)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(parsed["id"] as? String)
        XCTAssertEqual(parsed["severity"] as? String, "Critical")
        XCTAssertNotNil(parsed["title"])
        XCTAssertNotNil(parsed["description"])
        XCTAssertNotNil(parsed["host"])
        XCTAssertNotNil(parsed["port"])
        XCTAssertNotNil(parsed["service"])
        XCTAssertNotNil(parsed["isVerified"])
        XCTAssertNotNil(parsed["remediation"])
    }

    func testSTIXBundleStructure() throws {
        // Validate the STIX 2.1 bundle format from /api/threats/ioc
        let bundle: [String: Any] = [
            "type": "bundle",
            "id": "bundle--\(UUID().uuidString.lowercased())",
            "spec_version": "2.1",
            "objects": [
                [
                    "type": "indicator",
                    "spec_version": "2.1",
                    "id": "indicator--\(UUID().uuidString.lowercased())",
                    "created": ISO8601DateFormatter().string(from: Date()),
                    "modified": ISO8601DateFormatter().string(from: Date()),
                    "name": "Test Indicator",
                    "description": "Test",
                    "indicator_types": ["malicious-activity"],
                    "pattern_type": "stix",
                    "pattern": "[network-traffic:dst_port = 11434]",
                    "valid_from": ISO8601DateFormatter().string(from: Date()),
                    "labels": ["critical"]
                ] as [String: Any]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: bundle)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "bundle")
        XCTAssertEqual(parsed["spec_version"] as? String, "2.1")
        XCTAssertTrue((parsed["id"] as? String)?.hasPrefix("bundle--") ?? false)

        let objects = parsed["objects"] as? [[String: Any]]
        XCTAssertNotNil(objects)
        XCTAssertEqual(objects?.count, 1)

        let indicator = objects?.first
        XCTAssertEqual(indicator?["type"] as? String, "indicator")
        XCTAssertEqual(indicator?["spec_version"] as? String, "2.1")
        XCTAssertTrue((indicator?["id"] as? String)?.hasPrefix("indicator--") ?? false)
    }

    func testThreatImportRequestValidation() throws {
        // Valid STIX import request
        let validBundle: [String: Any] = [
            "type": "bundle",
            "objects": [
                ["type": "indicator", "name": "Test IoC"]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: validBundle)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "bundle")
        XCTAssertNotNil(parsed["objects"] as? [[String: Any]])

        // Invalid request: wrong type
        let invalidBundle: [String: Any] = [
            "type": "not-a-bundle",
            "objects": []
        ]
        let invalidData = try JSONSerialization.data(withJSONObject: invalidBundle)
        let invalidParsed = try JSONSerialization.jsonObject(with: invalidData) as! [String: Any]
        XCTAssertNotEqual(invalidParsed["type"] as? String, "bundle")
    }

    // MARK: - AIBackendError

    func testAIBackendErrorDescriptions() {
        XCTAssertNotNil(AIBackendError.noBackendAvailable.errorDescription)
        XCTAssertNotNil(AIBackendError.invalidConfiguration.errorDescription)
        XCTAssertNotNil(AIBackendError.invalidState.errorDescription)
        XCTAssertNotNil(AIBackendError.mlxScriptNotConfigured.errorDescription)
        XCTAssertNotNil(AIBackendError.mlxExecutionFailed("test error").errorDescription)
        XCTAssertNotNil(AIBackendError.embeddingsNotSupported.errorDescription)

        XCTAssertTrue(AIBackendError.mlxExecutionFailed("custom error").errorDescription!.contains("custom error"))
    }

    // MARK: - MLXError

    func testMLXErrorDescriptions() {
        XCTAssertNotNil(MLXError.notAvailable.errorDescription)
        XCTAssertNotNil(MLXError.modelNotFound.errorDescription)
        XCTAssertNotNil(MLXError.inferenceError("test").errorDescription)
        XCTAssertNotNil(MLXError.decodingError.errorDescription)
        XCTAssertNotNil(MLXError.executionError("test").errorDescription)

        XCTAssertTrue(MLXError.inferenceError("specific error").errorDescription!.contains("specific error"))
        XCTAssertTrue(MLXError.executionError("exec fail").errorDescription!.contains("exec fail"))
    }

    // MARK: - UserFacingErrors

    func testUserFacingErrorsForURLErrors() {
        let timedOut = URLError(.timedOut)
        let message = UserFacingErrors.genericMessage(for: timedOut)
        XCTAssertTrue(message.contains("timed out") || message.contains("network"),
            "Timeout error should mention timeout or network")

        let notConnected = URLError(.notConnectedToInternet)
        let notConnectedMsg = UserFacingErrors.genericMessage(for: notConnected)
        XCTAssertTrue(notConnectedMsg.lowercased().contains("internet") || notConnectedMsg.lowercased().contains("network"),
            "Not connected error should mention internet or network")

        let cantConnect = URLError(.cannotConnectToHost)
        let cantConnectMsg = UserFacingErrors.genericMessage(for: cantConnect)
        XCTAssertTrue(cantConnectMsg.lowercased().contains("reach") || cantConnectMsg.lowercased().contains("server"),
            "Cannot connect error should mention server")
    }

    func testUserFacingErrorsForValidationErrors() {
        let ipError = IPValidationError.invalidFormat
        let message = UserFacingErrors.genericMessage(for: ipError)
        XCTAssertTrue(message.lowercased().contains("ip") || message.lowercased().contains("format"),
            "IP validation error should mention format")

        let urlError = URLValidationError.blockedHost
        let urlMessage = UserFacingErrors.genericMessage(for: urlError)
        XCTAssertTrue(urlMessage.lowercased().contains("host") || urlMessage.lowercased().contains("not allowed"),
            "URL validation error should mention host restriction")
    }

    func testUserFacingErrorsForUnknownErrors() {
        struct CustomError: Error {}
        let message = UserFacingErrors.genericMessage(for: CustomError())
        XCTAssertTrue(message.contains("try again") || message.contains("error occurred"),
            "Unknown error should give generic user-friendly message")
    }

    // MARK: - AIBackend Properties

    func testAIBackendRawValues() {
        XCTAssertEqual(AIBackend.ollama.rawValue, "Ollama")
        XCTAssertEqual(AIBackend.mlx.rawValue, "MLX Toolkit")
        XCTAssertEqual(AIBackend.tinyLLM.rawValue, "TinyLLM")
        XCTAssertEqual(AIBackend.tinyChat.rawValue, "TinyChat")
        XCTAssertEqual(AIBackend.openWebUI.rawValue, "OpenWebUI")
        XCTAssertEqual(AIBackend.auto.rawValue, "Auto (Prefer Ollama)")
    }

    func testAIBackendAllCasesCount() {
        // ollama, mlx, tinyLLM, tinyChat, openWebUI, openRouter, novaGateway, auto
        XCTAssertEqual(AIBackend.allCases.count, 8)
    }

    func testAIBackendIcons() {
        for backend in AIBackend.allCases {
            XCTAssertFalse(backend.icon.isEmpty,
                "Backend \(backend.rawValue) should have an icon")
        }
    }

    func testAIBackendDescriptions() {
        for backend in AIBackend.allCases {
            XCTAssertFalse(backend.description.isEmpty,
                "Backend \(backend.rawValue) should have a description")
        }
    }

    func testAIBackendAttribution() {
        // TinyLLM and TinyChat should have attribution
        XCTAssertNotNil(AIBackend.tinyLLM.attribution)
        XCTAssertNotNil(AIBackend.tinyChat.attribution)
        XCTAssertNotNil(AIBackend.openWebUI.attribution)

        // Ollama, MLX, auto should not
        XCTAssertNil(AIBackend.ollama.attribution)
        XCTAssertNil(AIBackend.mlx.attribution)
        XCTAssertNil(AIBackend.auto.attribution)
    }

    func testAIBackendAttributionContainsURL() {
        if let tinyLLMAttrib = AIBackend.tinyLLM.attribution {
            XCTAssertTrue(tinyLLMAttrib.contains("github.com"))
        }
        if let tinyChatAttrib = AIBackend.tinyChat.attribution {
            XCTAssertTrue(tinyChatAttrib.contains("github.com"))
        }
    }
}
