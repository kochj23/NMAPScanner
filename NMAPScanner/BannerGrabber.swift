//
//  BannerGrabber.swift
//  NMAPScanner - Banner Grabbing & Service Fingerprinting
//
//  Created by Jordan Koch & Claude Code on 2025-11-27.
//

import Foundation
import Network

/// Service banner information
struct ServiceBanner: Identifiable, Codable {
    let id = UUID()
    let host: String
    let port: Int
    let service: String
    let banner: String
    let detectedVersion: String?
    let serverSoftware: String?
    let operatingSystem: String?
    let confidence: Int // 0-100
    let timestamp: Date
    let vulnerabilityNotes: [String]

    enum CodingKeys: String, CodingKey {
        case host, port, service, banner, detectedVersion, serverSoftware
        case operatingSystem, confidence, timestamp, vulnerabilityNotes
    }
}

/// OS fingerprinting result
struct OSFingerprint: Identifiable, Codable {
    let id = UUID()
    let host: String
    let detectedOS: String
    let confidence: Int
    let details: String
    let timestamp: Date
}

/// Manages banner grabbing and service fingerprinting
@MainActor
class BannerGrabber: ObservableObject {
    static let shared = BannerGrabber()

    @Published var banners: [ServiceBanner] = []
    @Published var osFingerprints: [OSFingerprint] = []
    @Published var isScanning = false
    @Published var lastScanDate: Date?

    private init() {}

    // MARK: - Scanning

    /// Scan multiple hosts and grab service banners
    func scanHosts(_ hosts: [(host: String, ports: [Int])]) async {
        isScanning = true
        banners.removeAll()

        print("🔍 BannerGrabber: Starting banner grab on \(hosts.count) hosts")

        for (host, ports) in hosts {
            for port in ports {
                if let banner = await grabBanner(host: host, port: port) {
                    banners.append(banner)
                }
            }

            // Also perform OS fingerprinting per host
            if let osprint = await performOSFingerprinting(host: host, ports: ports) {
                osFingerprints.append(osprint)
            }
        }

        lastScanDate = Date()
        isScanning = false

        print("🔍 BannerGrabber: Banner grab complete - captured \(banners.count) banners")
    }

    /// Grab banner from a specific service
    func grabBanner(host: String, port: Int) async -> ServiceBanner? {
        // Determine service type and appropriate banner grabbing technique
        let serviceType = identifyServiceType(port: port)

        var banner = ""
        var detectedVersion: String?
        var serverSoftware: String?

        switch serviceType {
        case "HTTP", "HTTPS":
            banner = await grabHTTPBanner(host: host, port: port)
            (detectedVersion, serverSoftware) = parseHTTPBanner(banner)

        case "FTP":
            banner = await grabFTPBanner(host: host, port: port)
            detectedVersion = parseFTPBanner(banner)

        case "SSH":
            banner = await grabSSHBanner(host: host, port: port)
            detectedVersion = parseSSHBanner(banner)

        case "SMTP":
            banner = await grabSMTPBanner(host: host, port: port)
            detectedVersion = parseSMTPBanner(banner)

        case "MySQL":
            banner = await grabMySQLBanner(host: host, port: port)
            detectedVersion = parseMySQLBanner(banner)

        case "PostgreSQL":
            banner = await grabPostgreSQLBanner(host: host, port: port)
            detectedVersion = parsePostgreSQLBanner(banner)

        case "Redis":
            banner = await grabRedisBanner(host: host, port: port)
            detectedVersion = parseRedisBanner(banner)

        case "MongoDB":
            banner = await grabMongoDBBanner(host: host, port: port)
            detectedVersion = parseMongoDBBanner(banner)

        case "SMB":
            banner = await grabSMBBanner(host: host, port: port)
            detectedVersion = parseSMBBanner(banner)

        default:
            banner = await grabGenericBanner(host: host, port: port)
            detectedVersion = parseGenericBanner(banner)
        }

        guard !banner.isEmpty else {
            return nil
        }

        // Detect OS from banner
        let os = detectOSFromBanner(banner)

        // Check for known vulnerabilities
        let vulnerabilities = checkKnownVulnerabilities(
            service: serviceType,
            version: detectedVersion,
            banner: banner
        )

        return ServiceBanner(
            host: host,
            port: port,
            service: serviceType,
            banner: banner,
            detectedVersion: detectedVersion,
            serverSoftware: serverSoftware,
            operatingSystem: os,
            confidence: calculateConfidence(banner: banner, version: detectedVersion),
            timestamp: Date(),
            vulnerabilityNotes: vulnerabilities
        )
    }

    // MARK: - Protocol-Specific Banner Grabbing

    private func grabHTTPBanner(host: String, port: Int) async -> String {
        let request = """
        HEAD / HTTP/1.1\r
        Host: \(host)\r
        User-Agent: NMAPScanner/5.0\r
        Connection: close\r
        \r

        """

        return await sendDataAndReceive(host: host, port: port, data: request)
    }

    private func grabFTPBanner(host: String, port: Int) async -> String {
        // FTP sends banner immediately on connect
        return await sendDataAndReceive(host: host, port: port, data: "")
    }

    private func grabSSHBanner(host: String, port: Int) async -> String {
        // SSH sends banner immediately
        return await sendDataAndReceive(host: host, port: port, data: "")
    }

    private func grabSMTPBanner(host: String, port: Int) async -> String {
        // SMTP sends banner, then we can send EHLO
        let initialBanner = await sendDataAndReceive(host: host, port: port, data: "")

        if !initialBanner.isEmpty {
            let ehlo = await sendDataAndReceive(host: host, port: port, data: "EHLO scanner.local\r\n")
            return initialBanner + "\n" + ehlo
        }

        return initialBanner
    }

    private func grabMySQLBanner(host: String, port: Int) async -> String {
        // MySQL sends handshake packet immediately
        return await sendDataAndReceive(host: host, port: port, data: "")
    }

    private func grabPostgreSQLBanner(host: String, port: Int) async -> String {
        // PostgreSQL startup message
        var startupMessage = Data()
        startupMessage.append(contentsOf: [0x00, 0x00, 0x00, 0x08]) // Length
        startupMessage.append(contentsOf: [0x04, 0xD2, 0x16, 0x2F]) // Protocol version 196608

        return await sendRawDataAndReceive(host: host, port: port, data: startupMessage)
    }

    private func grabRedisBanner(host: String, port: Int) async -> String {
        // Send INFO command
        return await sendDataAndReceive(host: host, port: port, data: "INFO\r\n")
    }

    private func grabMongoDBBanner(host: String, port: Int) async -> String {
        // MongoDB wire protocol - send isMaster command
        // This is a simplified version
        return await sendDataAndReceive(host: host, port: port, data: "")
    }

    private func grabSMBBanner(host: String, port: Int) async -> String {
        // SMB negotiation request (simplified)
        return await sendDataAndReceive(host: host, port: port, data: "")
    }

    private func grabGenericBanner(host: String, port: Int) async -> String {
        // Try simple connect and read
        return await sendDataAndReceive(host: host, port: port, data: "")
    }

    // MARK: - Network Communication

    private func sendDataAndReceive(host: String, port: Int, data: String, timeout: TimeInterval = 5.0) async -> String {
        let rawData = data.data(using: .utf8) ?? Data()
        let response = await sendRawDataAndReceive(host: host, port: port, data: rawData, timeout: timeout)
        return String(data: Data(response.utf8), encoding: .utf8) ?? ""
    }

    private func sendRawDataAndReceive(host: String, port: Int, data: Data, timeout: TimeInterval = 5.0) async -> String {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )

            let queue = DispatchQueue(label: "banner-grab")
            var hasResumed = false
            let lock = NSLock()
            var receivedData = Data()

            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    // Send data if any
                    if !data.isEmpty {
                        connection.send(content: data, completion: .contentProcessed { error in
                            if error != nil {
                                lock.lock()
                                defer { lock.unlock() }
                                if !hasResumed {
                                    hasResumed = true
                                    connection.cancel()
                                    continuation.resume(returning: "")
                                }
                            }
                        })
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

            // Timeout
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

    // MARK: - Banner Parsing

    private func parseHTTPBanner(_ banner: String) -> (version: String?, server: String?) {
        var version: String?
        var server: String?

        let lines = banner.split(separator: "\n")
        for line in lines {
            let lower = line.lowercased()

            if lower.starts(with: "server:") {
                server = String(line.dropFirst(7).trimmingCharacters(in: .whitespaces))

                // Extract version from server string
                if let match = server?.range(of: #"[\d]+\.[\d]+\.?[\d]*"#, options: .regularExpression) {
                    version = String(server![match])
                }
            }
        }

        return (version, server)
    }

    private func parseFTPBanner(_ banner: String) -> String? {
        // FTP banners often include version info
        // Example: "220 ProFTPD 1.3.5 Server"
        let pattern = #"[\d]+\.[\d]+\.?[\d]*"#
        if let range = banner.range(of: pattern, options: .regularExpression) {
            return String(banner[range])
        }
        return nil
    }

    private func parseSSHBanner(_ banner: String) -> String? {
        // SSH banners: "SSH-2.0-OpenSSH_7.4"
        if banner.contains("OpenSSH") {
            let pattern = #"OpenSSH[_\s][\d]+\.[\d]+p?[\d]*"#
            if let range = banner.range(of: pattern, options: .regularExpression) {
                return String(banner[range])
            }
        }
        return nil
    }

    private func parseSMTPBanner(_ banner: String) -> String? {
        // SMTP banners vary greatly
        let pattern = #"[\d]+\.[\d]+\.?[\d]*"#
        if let range = banner.range(of: pattern, options: .regularExpression) {
            return String(banner[range])
        }
        return nil
    }

    private func parseMySQLBanner(_ banner: String) -> String? {
        // MySQL sends version in handshake packet
        if banner.contains("mysql") || banner.contains("MariaDB") {
            let pattern = #"[\d]+\.[\d]+\.[\d]+"#
            if let range = banner.range(of: pattern, options: .regularExpression) {
                return String(banner[range])
            }
        }
        return nil
    }

    private func parsePostgreSQLBanner(_ banner: String) -> String? {
        if banner.contains("PostgreSQL") {
            let pattern = #"[\d]+\.[\d]+"#
            if let range = banner.range(of: pattern, options: .regularExpression) {
                return String(banner[range])
            }
        }
        return nil
    }

    private func parseRedisBanner(_ banner: String) -> String? {
        // Redis INFO response contains redis_version
        if let range = banner.range(of: #"redis_version:([\d]+\.[\d]+\.[\d]+)"#, options: .regularExpression) {
            let versionLine = String(banner[range])
            if let colonIndex = versionLine.firstIndex(of: ":") {
                return String(versionLine[versionLine.index(after: colonIndex)...])
            }
        }
        return nil
    }

    private func parseMongoDBBanner(_ banner: String) -> String? {
        if banner.contains("MongoDB") {
            let pattern = #"[\d]+\.[\d]+\.[\d]+"#
            if let range = banner.range(of: pattern, options: .regularExpression) {
                return String(banner[range])
            }
        }
        return nil
    }

    private func parseSMBBanner(_ banner: String) -> String? {
        // SMB version detection is complex, return basic info
        if banner.contains("SMB") {
            return "SMBv1/v2/v3"
        }
        return nil
    }

    private func parseGenericBanner(_ banner: String) -> String? {
        // Try to extract any version number
        let pattern = #"[\d]+\.[\d]+\.?[\d]*"#
        if let range = banner.range(of: pattern, options: .regularExpression) {
            return String(banner[range])
        }
        return nil
    }

    // MARK: - OS Detection

    private func detectOSFromBanner(_ banner: String) -> String? {
        let lower = banner.lowercased()

        if lower.contains("ubuntu") { return "Ubuntu Linux" }
        if lower.contains("debian") { return "Debian Linux" }
        if lower.contains("centos") { return "CentOS Linux" }
        if lower.contains("redhat") || lower.contains("rhel") { return "Red Hat Enterprise Linux" }
        if lower.contains("fedora") { return "Fedora Linux" }
        if lower.contains("windows") || lower.contains("microsoft") { return "Windows Server" }
        if lower.contains("freebsd") { return "FreeBSD" }
        if lower.contains("openbsd") { return "OpenBSD" }
        if lower.contains("darwin") || lower.contains("macos") { return "macOS" }
        if lower.contains("linux") { return "Linux (unknown distribution)" }
        if lower.contains("unix") { return "Unix" }

        return nil
    }

    // MARK: - OS Fingerprinting

    private func performOSFingerprinting(host: String, ports: [Int]) async -> OSFingerprint? {
        var osHints: [String: Int] = [:]
        var totalConfidence = 0

        // Analyze banners for OS clues
        for port in ports {
            let banner = await grabGenericBanner(host: host, port: port)
            if !banner.isEmpty, let os = detectOSFromBanner(banner) {
                osHints[os, default: 0] += 30
                totalConfidence += 30
            }
        }

        // Additional TCP/IP stack fingerprinting would go here
        // This would involve analyzing TCP window sizes, TTL values, etc.
        // For now, we'll use banner-based detection

        guard let mostLikelyOS = osHints.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let confidence = min(100, (mostLikelyOS.value * 100) / max(totalConfidence, 1))

        return OSFingerprint(
            host: host,
            detectedOS: mostLikelyOS.key,
            confidence: confidence,
            details: "Detected from service banners on \(ports.count) ports",
            timestamp: Date()
        )
    }

    // MARK: - Vulnerability Checking

    private func checkKnownVulnerabilities(service: String, version: String?, banner: String) -> [String] {
        var vulnerabilities: [String] = []

        guard let version = version else {
            return vulnerabilities
        }

        // Check for known vulnerable versions
        switch service {
        case "OpenSSH":
            if version.contains("7.4") || version.contains("7.2") {
                vulnerabilities.append("OpenSSH \(version) has known vulnerabilities. Upgrade to 8.0+")
            }

        case "Apache":
            if version.contains("2.4.49") || version.contains("2.4.50") {
                vulnerabilities.append("Apache \(version) - CRITICAL path traversal CVE-2021-41773")
            }

        case "nginx":
            if version.contains("1.18") || version.contains("1.16") {
                vulnerabilities.append("nginx \(version) - known DNS resolver vulnerability")
            }

        case "ProFTPD":
            if version.contains("1.3.5") {
                vulnerabilities.append("ProFTPD \(version) - CRITICAL remote code execution")
            }

        case "MySQL":
            if version.starts(with: "5.6") {
                vulnerabilities.append("MySQL 5.6 - end of life, upgrade to 8.0+")
            }

        case "SMB":
            if banner.contains("SMBv1") || banner.contains("SMB 1") {
                vulnerabilities.append("SMBv1 enabled - CRITICAL WannaCry/NotPetya vulnerability")
            }

        default:
            break
        }

        return vulnerabilities
    }

    // MARK: - Helper Methods

    private func identifyServiceType(port: Int) -> String {
        switch port {
        case 21: return "FTP"
        case 22: return "SSH"
        case 23: return "Telnet"
        case 25: return "SMTP"
        case 80: return "HTTP"
        case 110: return "POP3"
        case 143: return "IMAP"
        case 443: return "HTTPS"
        case 445: return "SMB"
        case 3306: return "MySQL"
        case 5432: return "PostgreSQL"
        case 6379: return "Redis"
        case 27017: return "MongoDB"
        case 8080: return "HTTP"
        default: return "Unknown"
        }
    }

    private func calculateConfidence(banner: String, version: String?) -> Int {
        var confidence = 50 // Base confidence

        if !banner.isEmpty {
            confidence += 20
        }

        if version != nil {
            confidence += 30
        }

        return min(100, confidence)
    }

    // MARK: - Statistics

    var stats: BannerStats {
        let servicesWithVersions = banners.filter { $0.detectedVersion != nil }.count
        let vulnerableServices = banners.filter { !$0.vulnerabilityNotes.isEmpty }.count

        return BannerStats(
            totalBanners: banners.count,
            servicesWithVersions: servicesWithVersions,
            vulnerableServices: vulnerableServices,
            osDetected: osFingerprints.count
        )
    }
}

struct BannerStats {
    let totalBanners: Int
    let servicesWithVersions: Int
    let vulnerableServices: Int
    let osDetected: Int
}
