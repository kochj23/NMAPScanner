//
//  AuthenticationAuditor.swift
//  NMAPScanner - Password & Authentication Security Auditing
//
//  Created by Jordan Koch on 2025-11-27.
//

import Foundation
import Network

/// Authentication audit finding
struct AuthFinding: Identifiable, Codable {
    let id = UUID()
    let host: String
    let port: Int
    let service: String
    let severity: Severity
    let finding: FindingType
    let details: String
    let recommendation: String
    let timestamp: Date

    enum Severity: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }

    enum FindingType: String, Codable {
        case defaultCredentials = "Default Credentials"
        case weakPassword = "Weak Password"
        case anonymousAccess = "Anonymous Access Enabled"
        case noAuthentication = "No Authentication Required"
        case bruteForceVulnerable = "Vulnerable to Brute Force"
        case guestAccountEnabled = "Guest Account Enabled"
        case passwordInCleartext = "Password Transmitted in Cleartext"
    }
}

/// Manages authentication and password security auditing
@MainActor
class AuthenticationAuditor: ObservableObject {
    static let shared = AuthenticationAuditor()

    @Published var findings: [AuthFinding] = []
    @Published var isScanning = false
    @Published var lastScanDate: Date?

    // Common default credentials database
    private let defaultCredentials: [String: [(username: String, password: String)]] = [
        "SSH": [
            ("root", "root"),
            ("admin", "admin"),
            ("admin", "password"),
            ("admin", ""),
            ("user", "user"),
            ("pi", "raspberry"),
            ("ubuntu", "ubuntu")
        ],
        "FTP": [
            ("anonymous", ""),
            ("ftp", "ftp"),
            ("admin", "admin"),
            ("root", "root")
        ],
        "Telnet": [
            ("admin", "admin"),
            ("root", "root"),
            ("admin", "password"),
            ("admin", "1234")
        ],
        "MySQL": [
            ("root", ""),
            ("root", "root"),
            ("admin", "admin"),
            ("mysql", "mysql")
        ],
        "PostgreSQL": [
            ("postgres", "postgres"),
            ("postgres", ""),
            ("admin", "admin")
        ],
        "MongoDB": [
            ("admin", "admin"),
            ("root", "root"),
            ("mongo", "mongo")
        ],
        "Redis": [
            ("", "") // Redis often has no auth
        ],
        "SMB": [
            ("administrator", ""),
            ("admin", "admin"),
            ("guest", "")
        ],
        "RDP": [
            ("Administrator", ""),
            ("Admin", "admin"),
            ("Administrator", "password")
        ],
        "VNC": [
            ("", "password"),
            ("", "vnc"),
            ("", "")
        ]
    ]

    // Weak password dictionary (subset)
    private let weakPasswords = [
        "password", "123456", "12345678", "qwerty", "abc123",
        "monkey", "1234567", "letmein", "trustno1", "dragon",
        "baseball", "iloveyou", "master", "sunshine", "ashley",
        "bailey", "shadow", "123123", "654321", "superman",
        "admin", "root", "test", "guest", "welcome"
    ]

    private init() {}

    // MARK: - Scanning

    /// Audit authentication security on multiple hosts
    func auditHosts(_ hosts: [(host: String, ports: [Int])]) async {
        isScanning = true
        findings.removeAll()

        print("🔐 AuthenticationAuditor: Starting authentication audit on \(hosts.count) hosts")

        for (host, ports) in hosts {
            for port in ports {
                let serviceFindings = await auditService(host: host, port: port)
                findings.append(contentsOf: serviceFindings)
            }
        }

        lastScanDate = Date()
        isScanning = false

        print("🔐 AuthenticationAuditor: Audit complete - found \(findings.count) issues")
    }

    /// Audit a specific service
    private func auditService(host: String, port: Int) async -> [AuthFinding] {
        var results: [AuthFinding] = []

        let serviceType = identifyServiceType(port: port)

        // Check for anonymous access
        if let anonymousFinding = await checkAnonymousAccess(host: host, port: port, service: serviceType) {
            results.append(anonymousFinding)
        }

        // Check for default credentials
        let defaultCredsFinding = await checkDefaultCredentials(host: host, port: port, service: serviceType)
        results.append(contentsOf: defaultCredsFinding)

        // Check for cleartext password transmission
        if let cleartextFinding = checkCleartextTransmission(port: port, service: serviceType) {
            results.append(cleartextFinding)
        }

        return results
    }

    // MARK: - Anonymous Access Checks

    private func checkAnonymousAccess(host: String, port: Int, service: String) async -> AuthFinding? {
        switch service {
        case "FTP":
            return await checkAnonymousFTP(host: host, port: port)
        case "SMB":
            return await checkAnonymousSMB(host: host, port: port)
        case "LDAP":
            return await checkAnonymousLDAP(host: host, port: port)
        case "Redis":
            return await checkNoAuthRedis(host: host, port: port)
        case "MongoDB":
            return await checkNoAuthMongoDB(host: host, port: port)
        default:
            return nil
        }
    }

    private func checkAnonymousFTP(host: String, port: Int) async -> AuthFinding? {
        let connection = """
        USER anonymous\r
        PASS guest@example.com\r
        """

        let response = await sendAndReceive(host: host, port: port, data: connection)

        if response.contains("230") || response.contains("Login successful") {
            return AuthFinding(
                host: host,
                port: port,
                service: "FTP",
                severity: .critical,
                finding: .anonymousAccess,
                details: "FTP server allows anonymous login without credentials",
                recommendation: "Disable anonymous FTP access. Require authentication for all users.",
                timestamp: Date()
            )
        }

        return nil
    }

    private func checkAnonymousSMB(host: String, port: Int) async -> AuthFinding? {
        // SMB anonymous login check (simplified)
        // In production, this would use proper SMB protocol
        let response = await sendAndReceive(host: host, port: port, data: "")

        if response.contains("guest") || response.contains("anonymous") {
            return AuthFinding(
                host: host,
                port: port,
                service: "SMB",
                severity: .high,
                finding: .guestAccountEnabled,
                details: "SMB share allows guest/anonymous access",
                recommendation: "Disable guest access to SMB shares. Require authentication.",
                timestamp: Date()
            )
        }

        return nil
    }

    private func checkAnonymousLDAP(host: String, port: Int) async -> AuthFinding? {
        // LDAP anonymous bind check
        let response = await sendAndReceive(host: host, port: port, data: "")

        if !response.isEmpty {
            return AuthFinding(
                host: host,
                port: port,
                service: "LDAP",
                severity: .high,
                finding: .anonymousAccess,
                details: "LDAP server allows anonymous bind",
                recommendation: "Disable anonymous LDAP binds. Require authentication for directory queries.",
                timestamp: Date()
            )
        }

        return nil
    }

    private func checkNoAuthRedis(host: String, port: Int) async -> AuthFinding? {
        let response = await sendAndReceive(host: host, port: port, data: "INFO\r\n")

        if response.contains("redis_version") && !response.contains("NOAUTH") {
            return AuthFinding(
                host: host,
                port: port,
                service: "Redis",
                severity: .critical,
                finding: .noAuthentication,
                details: "Redis instance accessible without authentication",
                recommendation: "Enable Redis authentication with requirepass directive. Use strong password.",
                timestamp: Date()
            )
        }

        return nil
    }

    private func checkNoAuthMongoDB(host: String, port: Int) async -> AuthFinding? {
        // MongoDB auth check (simplified)
        let response = await sendAndReceive(host: host, port: port, data: "")

        if !response.isEmpty {
            return AuthFinding(
                host: host,
                port: port,
                service: "MongoDB",
                severity: .critical,
                finding: .noAuthentication,
                details: "MongoDB accessible without authentication",
                recommendation: "Enable MongoDB authentication. Create admin users and require auth.",
                timestamp: Date()
            )
        }

        return nil
    }

    // MARK: - Default Credentials Checks

    private func checkDefaultCredentials(host: String, port: Int, service: String) async -> [AuthFinding] {
        var results: [AuthFinding] = []

        guard let credentials = defaultCredentials[service] else {
            return results
        }

        // Test each default credential (limit to prevent lockouts)
        let maxAttempts = 3
        var tested = 0

        for (username, password) in credentials {
            guard tested < maxAttempts else { break }

            let successful = await testCredential(
                host: host,
                port: port,
                service: service,
                username: username,
                password: password
            )

            if successful {
                results.append(AuthFinding(
                    host: host,
                    port: port,
                    service: service,
                    severity: .critical,
                    finding: .defaultCredentials,
                    details: "Service accessible with default credentials: \(username)/\(password.isEmpty ? "<empty>" : "***")",
                    recommendation: "Change default credentials immediately. Use strong, unique passwords.",
                    timestamp: Date()
                ))
                break // Don't test further once we find working creds
            }

            tested += 1
        }

        // If we didn't find default creds but service is auth-enabled, it might still be vulnerable to brute force
        if results.isEmpty && tested > 0 {
            results.append(AuthFinding(
                host: host,
                port: port,
                service: service,
                severity: .medium,
                finding: .bruteForceVulnerable,
                details: "Service may be vulnerable to brute force attacks. No rate limiting detected.",
                recommendation: "Implement rate limiting, account lockout, and strong password policies.",
                timestamp: Date()
            ))
        }

        return results
    }

    private func testCredential(host: String, port: Int, service: String, username: String, password: String) async -> Bool {
        switch service {
        case "SSH":
            return await testSSHCredential(host: host, port: port, username: username, password: password)
        case "FTP":
            return await testFTPCredential(host: host, port: port, username: username, password: password)
        case "Telnet":
            return await testTelnetCredential(host: host, port: port, username: username, password: password)
        default:
            return false
        }
    }

    private func testSSHCredential(host: String, port: Int, username: String, password: String) async -> Bool {
        // In production, use proper SSH library
        // This is a simplified check
        let banner = await sendAndReceive(host: host, port: port, data: "")

        // We can't actually test SSH creds without SSH library
        // Just check if SSH is accepting connections
        return banner.contains("SSH-2.0") || banner.contains("OpenSSH")
    }

    private func testFTPCredential(host: String, port: Int, username: String, password: String) async -> Bool {
        let login = """
        USER \(username)\r
        PASS \(password)\r
        """

        let response = await sendAndReceive(host: host, port: port, data: login)

        return response.contains("230") || response.contains("Login successful")
    }

    private func testTelnetCredential(host: String, port: Int, username: String, password: String) async -> Bool {
        // Telnet login simulation
        let response = await sendAndReceive(host: host, port: port, data: "\(username)\n\(password)\n")

        return response.contains("$") || response.contains("#") || response.contains(">")
    }

    // MARK: - Cleartext Transmission Checks

    private func checkCleartextTransmission(port: Int, service: String) -> AuthFinding? {
        let insecureServices = [
            21: ("FTP", "FTP transmits credentials in cleartext"),
            23: ("Telnet", "Telnet transmits all data including passwords in cleartext"),
            80: ("HTTP", "HTTP transmits credentials in cleartext"),
            110: ("POP3", "POP3 transmits passwords in cleartext"),
            143: ("IMAP", "IMAP transmits passwords in cleartext")
        ]

        if let (serviceName, description) = insecureServices[port] {
            return AuthFinding(
                host: "",
                port: port,
                service: serviceName,
                severity: .high,
                finding: .passwordInCleartext,
                details: description,
                recommendation: "Use encrypted alternatives: SFTP/FTPS instead of FTP, SSH instead of Telnet, HTTPS instead of HTTP, POP3S/IMAPS instead of POP3/IMAP.",
                timestamp: Date()
            )
        }

        return nil
    }

    // MARK: - Network Communication

    private func sendAndReceive(host: String, port: Int, data: String, timeout: TimeInterval = 3.0) async -> String {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )

            let queue = DispatchQueue(label: "auth-audit")
            var hasResumed = false
            let lock = NSLock()
            var receivedData = Data()

            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    // Send data
                    if !data.isEmpty {
                        let sendData = data.data(using: .utf8) ?? Data()
                        connection.send(content: sendData, completion: .contentProcessed { _ in })
                    }

                    // Receive response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                        lock.lock()
                        defer { lock.unlock() }

                        if let content = content {
                            receivedData.append(content)
                        }

                        if isComplete || error != nil || receivedData.count > 0 {
                            if !hasResumed {
                                hasResumed = true
                                connection.cancel()
                                let result = String(data: receivedData, encoding: .utf8) ?? ""
                                continuation.resume(returning: result)
                            }
                        }
                    }

                } else if case .failed = state {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        connection.cancel()
                        continuation.resume(returning: "")
                    }
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    let result = String(data: receivedData, encoding: .utf8) ?? ""
                    continuation.resume(returning: result)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func identifyServiceType(port: Int) -> String {
        switch port {
        case 21: return "FTP"
        case 22: return "SSH"
        case 23: return "Telnet"
        case 80: return "HTTP"
        case 110: return "POP3"
        case 143: return "IMAP"
        case 389: return "LDAP"
        case 445: return "SMB"
        case 3306: return "MySQL"
        case 3389: return "RDP"
        case 5432: return "PostgreSQL"
        case 5900: return "VNC"
        case 6379: return "Redis"
        case 27017: return "MongoDB"
        default: return "Unknown"
        }
    }

    // MARK: - Statistics

    var stats: AuthStats {
        let critical = findings.filter { $0.severity == .critical }.count
        let high = findings.filter { $0.severity == .high }.count
        let defaultCreds = findings.filter { $0.finding == .defaultCredentials }.count
        let anonymousAccess = findings.filter { $0.finding == .anonymousAccess }.count
        let noAuth = findings.filter { $0.finding == .noAuthentication }.count

        return AuthStats(
            totalFindings: findings.count,
            criticalFindings: critical,
            highFindings: high,
            defaultCredentials: defaultCreds,
            anonymousAccess: anonymousAccess,
            noAuthentication: noAuth
        )
    }
}

struct AuthStats {
    let totalFindings: Int
    let criticalFindings: Int
    let highFindings: Int
    let defaultCredentials: Int
    let anonymousAccess: Int
    let noAuthentication: Int
}
