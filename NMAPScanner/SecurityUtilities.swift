//
//  SecurityUtilities.swift
//  NMAPScanner - Security Utilities and Validation
//
//  Comprehensive security utilities for input validation, logging, and rate limiting
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation
import CommonCrypto

// MARK: - IP Address Validator

enum IPValidationError: Error, LocalizedError {
    case invalidFormat
    case privateAddressNotAllowed
    case loopbackNotAllowed
    case multicastNotAllowed
    case emptyInput
    case subnetTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid IP address format"
        case .privateAddressNotAllowed: return "Private IP addresses not allowed"
        case .loopbackNotAllowed: return "Loopback addresses not allowed"
        case .multicastNotAllowed: return "Multicast addresses not allowed"
        case .emptyInput: return "IP address cannot be empty"
        case .subnetTooLarge: return "Subnet too large (max /24)"
        }
    }
}

struct IPValidator {
    /// Validate IP address format and type
    static func validateIPAddress(_ ip: String, allowPrivate: Bool = true, allowLoopback: Bool = false) throws {
        // Check for empty
        guard !ip.isEmpty else {
            throw IPValidationError.emptyInput
        }

        // Remove whitespace
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)

        // Split into octets
        let octets = trimmed.split(separator: ".")
        guard octets.count == 4 else {
            throw IPValidationError.invalidFormat
        }

        // Validate each octet
        var octetValues: [Int] = []
        for octet in octets {
            // Only allow digits
            guard octet.allSatisfy({ $0.isNumber }) else {
                throw IPValidationError.invalidFormat
            }

            guard let value = Int(octet), value >= 0 && value <= 255 else {
                throw IPValidationError.invalidFormat
            }
            octetValues.append(value)
        }

        // Check for loopback (127.0.0.0/8)
        if !allowLoopback && octetValues[0] == 127 {
            throw IPValidationError.loopbackNotAllowed
        }

        // Check for multicast (224.0.0.0/4)
        if octetValues[0] >= 224 && octetValues[0] <= 239 {
            throw IPValidationError.multicastNotAllowed
        }

        // Check for private addresses if not allowed
        if !allowPrivate {
            // 10.0.0.0/8
            if octetValues[0] == 10 {
                throw IPValidationError.privateAddressNotAllowed
            }
            // 172.16.0.0/12
            if octetValues[0] == 172 && octetValues[1] >= 16 && octetValues[1] <= 31 {
                throw IPValidationError.privateAddressNotAllowed
            }
            // 192.168.0.0/16
            if octetValues[0] == 192 && octetValues[1] == 168 {
                throw IPValidationError.privateAddressNotAllowed
            }
        }
    }

    /// Validate subnet (e.g., "192.168.1")
    static func validateSubnet(_ subnet: String) throws {
        let octets = subnet.split(separator: ".")
        guard octets.count >= 1 && octets.count <= 3 else {
            throw IPValidationError.invalidFormat
        }

        // Prevent /8 or /16 scans (too large)
        guard octets.count >= 3 else {
            throw IPValidationError.subnetTooLarge
        }

        for octet in octets {
            guard octet.allSatisfy({ $0.isNumber }) else {
                throw IPValidationError.invalidFormat
            }

            guard let value = Int(octet), value >= 0 && value <= 255 else {
                throw IPValidationError.invalidFormat
            }
        }
    }

    /// Check if IP is valid without throwing
    static func isValidIP(_ ip: String) -> Bool {
        do {
            try validateIPAddress(ip)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - URL Validator

enum URLValidationError: Error, LocalizedError {
    case invalidURL
    case unsupportedScheme
    case blockedHost
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL format"
        case .unsupportedScheme: return "Only HTTP and HTTPS URLs are allowed"
        case .blockedHost: return "Access to this host is not allowed"
        case .emptyInput: return "URL cannot be empty"
        }
    }
}

struct URLValidator {
    private static let blockedHosts: Set<String> = [
        "169.254.169.254",  // AWS metadata service
        "127.0.0.1",         // Localhost
        "localhost",         // Localhost
        "0.0.0.0",          // All interfaces
        "metadata.google.internal",  // GCP metadata
        "169.254.169.254"    // Azure metadata
    ]

    /// Validate and sanitize URL for UniFi controller
    static func validateControllerURL(_ urlString: String) throws -> String {
        guard !urlString.isEmpty else {
            throw URLValidationError.emptyInput
        }

        var sanitized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add https:// if no scheme
        if !sanitized.hasPrefix("http://") && !sanitized.hasPrefix("https://") {
            sanitized = "https://\(sanitized)"
        }

        // Parse URL
        guard let url = URL(string: sanitized),
              let scheme = url.scheme,
              let host = url.host else {
            throw URLValidationError.invalidURL
        }

        // Validate scheme
        guard scheme == "https" || scheme == "http" else {
            throw URLValidationError.unsupportedScheme
        }

        // Check blocked hosts
        if blockedHosts.contains(host.lowercased()) {
            throw URLValidationError.blockedHost
        }

        return sanitized
    }
}

// MARK: - Secure Logger

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case security = "SECURITY"
}

struct SecureLogger {
    /// Log message with automatic sensitive data masking
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if DEBUG
        // Development: Show all logs with masking
        let masked = maskSensitiveData(message)
        print("[\(level.rawValue)] [\(timestamp)] [\(filename):\(line)] \(masked)")
        #else
        // Production: Only warnings, errors, and security events
        if level == .warning || level == .error || level == .security {
            let masked = maskSensitiveData(message)
            print("[\(level.rawValue)] [\(timestamp)] \(masked)")
        }
        #endif
    }

    /// Mask sensitive data patterns in log messages
    private static func maskSensitiveData(_ text: String) -> String {
        var masked = text

        // Mask password fields in JSON
        masked = maskPattern(masked, pattern: #""password"\s*:\s*"[^"]*""#, replacement: "\"password\":\"***\"")
        masked = maskPattern(masked, pattern: #""passwd"\s*:\s*"[^"]*""#, replacement: "\"passwd\":\"***\"")

        // Mask token fields
        masked = maskPattern(masked, pattern: #""token"\s*:\s*"[^"]*""#, replacement: "\"token\":\"***\"")
        masked = maskPattern(masked, pattern: #""apikey"\s*:\s*"[^"]*""#, replacement: "\"apikey\":\"***\"")
        masked = maskPattern(masked, pattern: #""api_key"\s*:\s*"[^"]*""#, replacement: "\"api_key\":\"***\"")

        // Mask cookie values
        masked = maskPattern(masked, pattern: #""cookie"\s*:\s*"[^"]*""#, replacement: "\"cookie\":\"***\"")
        masked = maskPattern(masked, pattern: #"Cookie:\s*[^\s]+"#, replacement: "Cookie:***")

        // Mask session IDs
        masked = maskPattern(masked, pattern: #""session"\s*:\s*"[^"]*""#, replacement: "\"session\":\"***\"")
        masked = maskPattern(masked, pattern: #"unifises=[A-Za-z0-9]+"#, replacement: "unifises=***")

        // Mask bearer tokens
        masked = maskPattern(masked, pattern: #"Bearer\s+[A-Za-z0-9+/=]+"#, replacement: "Bearer ***")

        // Mask basic auth
        masked = maskPattern(masked, pattern: #"Basic\s+[A-Za-z0-9+/=]+"#, replacement: "Basic ***")

        return masked
    }

    private static func maskPattern(_ text: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

// MARK: - Rate Limiter

/// Actor-based rate limiter for network operations
actor RateLimiter {
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval
    private var requestCount: Int = 0
    private var windowStart: Date = Date()

    init(requestsPerSecond: Double) {
        self.minimumInterval = 1.0 / requestsPerSecond
    }

    /// Wait if rate limit would be exceeded
    func waitIfNeeded() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                let waitTime = minimumInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
        requestCount += 1
    }

    /// Reset rate limiter
    func reset() {
        lastRequestTime = nil
        requestCount = 0
        windowStart = Date()
    }

    /// Get current request count
    func getCurrentCount() -> Int {
        return requestCount
    }
}

// MARK: - Security Audit Log

enum SecurityAuditEvent: String, Codable {
    case loginAttempt = "Login Attempt"
    case loginSuccess = "Login Success"
    case loginFailure = "Login Failure"
    case mfaRequired = "MFA Required"
    case mfaSuccess = "MFA Success"
    case mfaFailure = "MFA Failure"
    case configurationChange = "Configuration Changed"
    case credentialsCleared = "Credentials Cleared"
    case certificateRejected = "Certificate Rejected"
    case certificateTrusted = "Certificate Trusted"
    case sessionExpired = "Session Expired"
    case suspiciousActivity = "Suspicious Activity Detected"
    case validationError = "Validation Error"
    case scanStarted = "Network Scan Started"
    case scanCompleted = "Network Scan Completed"
}

struct AuditEntry: Codable {
    let timestamp: Date
    let event: SecurityAuditEvent
    let details: String
    let level: String

    init(timestamp: Date = Date(), event: SecurityAuditEvent, details: String, level: LogLevel = .info) {
        self.timestamp = timestamp
        self.event = event
        self.details = details
        self.level = level.rawValue
    }
}

struct SecurityAuditLog {
    private static let maxEntries = 1000
    private static let auditLogKey = "SecurityAuditLog"

    /// Log security event to audit trail
    static func log(event: SecurityAuditEvent, details: String, level: LogLevel = .info) {
        let entry = AuditEntry(event: event, details: details, level: level)

        // Get existing log
        var entries = loadAuditLog()
        entries.append(entry)

        // Keep only last N entries
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }

        // Save back
        saveAuditLog(entries)

        // Also log to console
        SecureLogger.log("AUDIT: [\(event.rawValue)] \(details)", level: level)
    }

    /// Get recent audit entries
    static func getRecentEntries(count: Int = 100) -> [AuditEntry] {
        let all = loadAuditLog()
        return Array(all.suffix(count))
    }

    /// Clear audit log (with confirmation)
    static func clearLog() {
        UserDefaults.standard.removeObject(forKey: auditLogKey)
        SecureLogger.log("Audit log cleared", level: .warning)
    }

    private static func loadAuditLog() -> [AuditEntry] {
        guard let data = UserDefaults.standard.data(forKey: auditLogKey),
              let entries = try? JSONDecoder().decode([AuditEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private static func saveAuditLog(_ entries: [AuditEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: auditLogKey)
    }
}

// MARK: - Generic Error Messages

struct UserFacingErrors {
    /// Convert technical error to user-friendly message
    static func genericMessage(for error: Error) -> String {
        // Log detailed error internally
        SecureLogger.log("Error occurred: \(error)", level: .error)

        // Return generic message to user
        if let urlError = error as? URLError {
            return urlErrorMessage(urlError)
        } else if let validationError = error as? IPValidationError {
            return validationError.localizedDescription
        } else if let urlValidationError = error as? URLValidationError {
            return urlValidationError.localizedDescription
        } else {
            return "An error occurred. Please try again."
        }
    }

    private static func urlErrorMessage(_ error: URLError) -> String {
        switch error.code {
        case .timedOut:
            return "Connection timed out. Please check your network connection."
        case .cannotConnectToHost:
            return "Cannot reach server. Please check the IP address."
        case .networkConnectionLost:
            return "Network connection lost. Please try again."
        case .notConnectedToInternet:
            return "No internet connection. Please connect to a network."
        case .secureConnectionFailed:
            return "Secure connection failed. Certificate may be invalid."
        case .serverCertificateHasBadDate:
            return "Server certificate has expired or is not yet valid."
        case .serverCertificateUntrusted:
            return "Server certificate is not trusted."
        case .cannotFindHost:
            return "Server not found. Please check the address."
        default:
            return "Connection failed. Please try again."
        }
    }
}

// MARK: - Certificate Fingerprint Utility

struct CertificateFingerprint {
    /// Calculate SHA-256 fingerprint of certificate
    static func calculate(for certificate: SecCertificate) -> String? {
        let certData = SecCertificateCopyData(certificate) as Data

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        certData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(certData.count), &hash)
        }

        return hash.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Format fingerprint for display (AA:BB:CC:DD:...)
    static func formatForDisplay(_ fingerprint: String) -> String {
        var formatted = ""
        for (index, char) in fingerprint.enumerated() {
            if index > 0 && index % 2 == 0 {
                formatted += ":"
            }
            formatted.append(char)
        }
        return formatted.uppercased()
    }

    /// Extract certificate subject (Common Name)
    static func getCommonName(for certificate: SecCertificate) -> String? {
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(certificate, &commonName)

        guard status == errSecSuccess,
              let name = commonName as String? else {
            return nil
        }

        return name
    }
}
