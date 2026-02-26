//
//  ServiceVersionScanner.swift
//  NMAP Scanner - Service Version Detection
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation
import Network

/// Detects service versions by analyzing banners and responses
class ServiceVersionScanner {
    static let shared = ServiceVersionScanner()

    private init() {}

    /// Scan a port and attempt to detect service version
    func detectServiceVersion(host: String, port: Int) async -> ServiceVersionInfo? {
        // Try to get banner
        if let banner = await getBanner(host: host, port: port) {
            return parseServiceVersion(port: port, banner: banner)
        }

        return nil
    }

    /// Get banner from service
    private func getBanner(host: String, port: Int) async -> String? {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.nmapscanner.banner")

            queue.async {
                var banner: String?

                // Create socket
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM

                var result: UnsafeMutablePointer<addrinfo>?
                guard getaddrinfo(host, "\(port)", &hints, &result) == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                defer {
                    if let result = result {
                        freeaddrinfo(result)
                    }
                }

                guard let addr = result else {
                    continuation.resume(returning: nil)
                    return
                }

                let sockfd = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
                guard sockfd >= 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                defer {
                    close(sockfd)
                }

                // Set timeout
                var timeout = timeval(tv_sec: 2, tv_usec: 0)
                setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

                // Connect
                guard connect(sockfd, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                // Send probes for specific services
                if let probe = self.getProbeForPort(port) {
                    let bytesSent = send(sockfd, probe, probe.count, 0)
                    if bytesSent < 0 {
                        continuation.resume(returning: nil)
                        return
                    }
                }

                // Read response
                var buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = recv(sockfd, &buffer, buffer.count, 0)

                if bytesRead > 0 {
                    if let bannerString = String(bytes: buffer[..<bytesRead], encoding: .utf8) {
                        banner = bannerString
                    } else if let bannerString = String(bytes: buffer[..<bytesRead], encoding: .ascii) {
                        banner = bannerString
                    }
                }

                continuation.resume(returning: banner)
            }
        }
    }

    /// Get probe data for specific port
    private func getProbeForPort(_ port: Int) -> [UInt8]? {
        switch port {
        case 80, 8080, 443, 8443:
            // HTTP probe
            let httpProbe = "GET / HTTP/1.0\r\n\r\n"
            return Array(httpProbe.utf8)

        case 21:
            // FTP doesn't need probe, server sends banner on connect
            return nil

        case 22:
            // SSH doesn't need probe, server sends version on connect
            return nil

        case 25, 587:
            // SMTP probe
            let smtpProbe = "EHLO scanner\r\n"
            return Array(smtpProbe.utf8)

        case 110:
            // POP3 doesn't need probe
            return nil

        case 143:
            // IMAP doesn't need probe
            return nil

        default:
            return nil
        }
    }

    /// Parse service version from banner
    private func parseServiceVersion(port: Int, banner: String) -> ServiceVersionInfo {
        let bannerLower = banner.lowercased()

        // HTTP/HTTPS
        if port == 80 || port == 443 || port == 8080 || port == 8443 {
            if let serverMatch = banner.range(of: "Server: ([^\r\n]+)", options: .regularExpression) {
                let server = String(banner[serverMatch]).replacingOccurrences(of: "Server: ", with: "")
                return ServiceVersionInfo(
                    service: "HTTP",
                    version: parseHTTPServerVersion(server),
                    product: parseHTTPServerProduct(server),
                    extraInfo: server
                )
            }
        }

        // SSH
        if port == 22 && bannerLower.contains("ssh") {
            if let versionMatch = banner.range(of: "SSH-[0-9.]+", options: .regularExpression) {
                let version = String(banner[versionMatch])
                return ServiceVersionInfo(
                    service: "SSH",
                    version: version,
                    product: parseSSHProduct(banner),
                    extraInfo: banner.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        // FTP
        if port == 21 && (bannerLower.contains("ftp") || banner.hasPrefix("220")) {
            return ServiceVersionInfo(
                service: "FTP",
                version: parseFTPVersion(banner),
                product: parseFTPProduct(banner),
                extraInfo: banner.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        // SMTP
        if (port == 25 || port == 587) && banner.hasPrefix("220") {
            return ServiceVersionInfo(
                service: "SMTP",
                version: parseSMTPVersion(banner),
                product: parseSMTPProduct(banner),
                extraInfo: banner.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        // POP3
        if port == 110 && bannerLower.contains("pop") {
            return ServiceVersionInfo(
                service: "POP3",
                version: nil,
                product: parsePOP3Product(banner),
                extraInfo: banner.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        // IMAP
        if port == 143 && bannerLower.contains("imap") {
            return ServiceVersionInfo(
                service: "IMAP",
                version: nil,
                product: parseIMAPProduct(banner),
                extraInfo: banner.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        // MySQL
        if port == 3306 && banner.count > 0 {
            return ServiceVersionInfo(
                service: "MySQL",
                version: parseMySQLVersion(banner),
                product: "MySQL",
                extraInfo: nil
            )
        }

        // PostgreSQL
        if port == 5432 {
            return ServiceVersionInfo(
                service: "PostgreSQL",
                version: nil,
                product: "PostgreSQL",
                extraInfo: nil
            )
        }

        // Generic
        return ServiceVersionInfo(
            service: "Unknown",
            version: nil,
            product: nil,
            extraInfo: banner.isEmpty ? nil : banner.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Version Parsers

    private func parseHTTPServerVersion(_ server: String) -> String? {
        // Extract version from Server header (e.g., "nginx/1.18.0" -> "1.18.0")
        if let range = server.range(of: "/[0-9.]+", options: .regularExpression) {
            return String(server[range]).dropFirst().description
        }
        return nil
    }

    private func parseHTTPServerProduct(_ server: String) -> String? {
        // Extract product name (e.g., "nginx/1.18.0" -> "nginx")
        if let range = server.range(of: "^[^/\\s]+", options: .regularExpression) {
            return String(server[range])
        }
        return nil
    }

    private func parseSSHProduct(_ banner: String) -> String? {
        // Parse SSH product (e.g., "SSH-2.0-OpenSSH_8.2" -> "OpenSSH")
        if let range = banner.range(of: "SSH-[0-9.]+-([^\\s]+)", options: .regularExpression) {
            let match = String(banner[range])
            if let productRange = match.range(of: "[^-]+$", options: .regularExpression) {
                let product = String(match[productRange])
                if let underscoreIndex = product.firstIndex(of: "_") {
                    return String(product[..<underscoreIndex])
                }
                return product
            }
        }
        return nil
    }

    private func parseFTPVersion(_ banner: String) -> String? {
        if let range = banner.range(of: "[0-9]+\\.[0-9]+", options: .regularExpression) {
            return String(banner[range])
        }
        return nil
    }

    private func parseFTPProduct(_ banner: String) -> String? {
        if banner.lowercased().contains("filezilla") {
            return "FileZilla"
        } else if banner.lowercased().contains("proftpd") {
            return "ProFTPD"
        } else if banner.lowercased().contains("vsftpd") {
            return "vsftpd"
        }
        return nil
    }

    private func parseSMTPVersion(_ banner: String) -> String? {
        if let range = banner.range(of: "[0-9]+\\.[0-9]+\\.[0-9]+", options: .regularExpression) {
            return String(banner[range])
        }
        return nil
    }

    private func parseSMTPProduct(_ banner: String) -> String? {
        if banner.lowercased().contains("postfix") {
            return "Postfix"
        } else if banner.lowercased().contains("sendmail") {
            return "Sendmail"
        } else if banner.lowercased().contains("exim") {
            return "Exim"
        }
        return nil
    }

    private func parsePOP3Product(_ banner: String) -> String? {
        if banner.lowercased().contains("dovecot") {
            return "Dovecot"
        }
        return nil
    }

    private func parseIMAPProduct(_ banner: String) -> String? {
        if banner.lowercased().contains("dovecot") {
            return "Dovecot"
        } else if banner.lowercased().contains("courier") {
            return "Courier"
        }
        return nil
    }

    private func parseMySQLVersion(_ banner: String) -> String? {
        // MySQL version is in binary protocol, try to extract
        if banner.count > 10 {
            let bytes = [UInt8](banner.utf8)
            if bytes.count > 10 {
                // Version string starts around byte 5
                let versionStart = 5
                if let versionEnd = bytes[versionStart...].firstIndex(of: 0) {
                    let versionBytes = bytes[versionStart..<versionEnd]
                    return String(bytes: versionBytes, encoding: .utf8)
                }
            }
        }
        return nil
    }
}

// MARK: - Service Version Info Model

struct ServiceVersionInfo: Codable, Hashable {
    let service: String
    let version: String?
    let product: String?
    let extraInfo: String?

    var displayString: String {
        var parts: [String] = []

        if let product = product {
            parts.append(product)
        } else {
            parts.append(service)
        }

        if let version = version {
            parts.append(version)
        }

        return parts.joined(separator: " ")
    }
}
