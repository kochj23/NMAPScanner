//
//  SSLCertificateAnalyzer.swift
//  NMAPScanner - SSL/TLS Certificate Security Analysis
//
//  Created by Jordan Koch on 2025-11-27.
//

import Foundation
import Network
import Security

/// SSL/TLS Certificate Analysis Results
struct SSLFindings: Identifiable, Codable {
    let id = UUID()
    let host: String
    let port: Int
    let isSecure: Bool
    let issues: [SSLIssue]
    let certificateInfo: CertificateInfo?
    let tlsVersion: String?
    let cipherSuite: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case host, port, isSecure, issues, certificateInfo, tlsVersion, cipherSuite, timestamp
    }
}

struct SSLIssue: Identifiable, Codable {
    let id = UUID()
    let severity: Severity
    let type: IssueType
    let description: String
    let recommendation: String

    enum Severity: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case info = "Info"
    }

    enum IssueType: String, Codable {
        case expiredCertificate = "Expired Certificate"
        case selfSigned = "Self-Signed Certificate"
        case weakCipher = "Weak Cipher Suite"
        case invalidChain = "Invalid Certificate Chain"
        case hostnameM = "Hostname Mismatch"
        case weakTLS = "Weak TLS Version"
        case untrustedCA = "Untrusted Certificate Authority"
        case certificateRevoked = "Certificate Revoked"
        case weakSignature = "Weak Signature Algorithm"
        case shortKeyLength = "Insufficient Key Length"
    }

    enum CodingKeys: String, CodingKey {
        case severity, type, description, recommendation
    }
}

struct CertificateInfo: Codable {
    let subject: String
    let issuer: String
    let validFrom: Date
    let validTo: Date
    let serialNumber: String
    let signatureAlgorithm: String
    let publicKeyAlgorithm: String
    let keySize: Int
    let isExpired: Bool
    let isSelfSigned: Bool
    let subjectAltNames: [String]
}

/// Manages SSL/TLS certificate analysis and security checks
@MainActor
class SSLCertificateAnalyzer: ObservableObject {
    static let shared = SSLCertificateAnalyzer()

    @Published var findings: [SSLFindings] = []
    @Published var isScanning = false
    @Published var lastScanDate: Date?

    private init() {}

    // MARK: - Scanning

    /// Scan multiple hosts for SSL/TLS vulnerabilities
    func scanHosts(_ hosts: [(host: String, port: Int)]) async {
        isScanning = true
        findings.removeAll()

        print("🔒 SSLCertificateAnalyzer: Starting SSL scan on \(hosts.count) hosts")

        for (host, port) in hosts {
            if let finding = await analyzeSSL(host: host, port: port) {
                findings.append(finding)
            }
        }

        lastScanDate = Date()
        isScanning = false

        print("🔒 SSLCertificateAnalyzer: SSL scan complete - found \(findings.count) hosts with SSL")
    }

    /// Analyze SSL/TLS configuration for a specific host
    func analyzeSSL(host: String, port: Int) async -> SSLFindings? {
        var issues: [SSLIssue] = []
        var certificateInfo: CertificateInfo?
        var tlsVersion: String?
        var cipherSuite: String?

        // Create TLS connection
        let tlsOptions = NWProtocolTLS.Options()

        // Configure to get detailed info
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { (metadata, trust, complete) in
                // We'll analyze the certificate in detail
                complete(true) // Accept all for analysis purposes
            },
            DispatchQueue.global()
        )

        let parameters = NWParameters(tls: tlsOptions)
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: parameters
        )

        let result = await testTLSConnection(connection)

        guard result.connected else {
            return nil // Not an SSL/TLS service
        }

        // Extract certificate information
        if let metadata = result.metadata {
            certificateInfo = extractCertificateInfo(from: metadata, host: host)
            tlsVersion = extractTLSVersion(from: metadata)
            cipherSuite = extractCipherSuite(from: metadata)

            // Analyze for vulnerabilities
            issues.append(contentsOf: analyzeCertificate(certificateInfo, host: host))
            issues.append(contentsOf: analyzeTLSVersion(tlsVersion))
            issues.append(contentsOf: analyzeCipherSuite(cipherSuite))
        }

        let isSecure = issues.filter { $0.severity == .critical || $0.severity == .high }.isEmpty

        return SSLFindings(
            host: host,
            port: port,
            isSecure: isSecure,
            issues: issues,
            certificateInfo: certificateInfo,
            tlsVersion: tlsVersion,
            cipherSuite: cipherSuite,
            timestamp: Date()
        )
    }

    // MARK: - Connection Testing

    private func testTLSConnection(_ connection: NWConnection) async -> (connected: Bool, metadata: NWProtocolMetadata?) {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "tls-test")
            var hasResumed = false
            let lock = NSLock()
            var capturedMetadata: NWProtocolMetadata?

            connection.stateUpdateHandler = { state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    // Capture TLS metadata
                    capturedMetadata = connection.metadata(definition: NWProtocolTLS.definition)
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: (true, capturedMetadata))

                case .failed, .cancelled:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: (false, nil))

                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Timeout after 5 seconds
            queue.asyncAfter(deadline: .now() + 5) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: (false, nil))
                }
            }
        }
    }

    // MARK: - Certificate Analysis

    private func extractCertificateInfo(from metadata: NWProtocolMetadata, host: String) -> CertificateInfo? {
        guard let tlsMetadata = metadata as? NWProtocolTLS.Metadata else {
            return nil
        }

        var certificateInfo: CertificateInfo?

        let secMetadata = sec_protocol_metadata_copy_peer_public_key(tlsMetadata.securityProtocolMetadata)

        // Extract certificate chain
        sec_protocol_metadata_access_peer_certificate_chain(tlsMetadata.securityProtocolMetadata) { chain in
            // Convert sec_certificate_t to SecCertificate
            let certificate = sec_certificate_copy_ref(chain).takeRetainedValue() as SecCertificate

            // Extract certificate details
            if let subject = SecCertificateCopySubjectSummary(certificate) as String?,
               let data = SecCertificateCopyData(certificate) as Data? {

                var validFrom = Date()
                var validTo = Date()
                var serialNumber = "Unknown"
                var signatureAlgorithm = "Unknown"
                var publicKeyAlgorithm = "RSA"
                var keySize = 2048
                var issuer = "Unknown"
                var subjectAltNames: [String] = []

                // Parse certificate data
                if let values = SecCertificateCopyValues(certificate, nil, nil) as? [String: Any] {
                    // Extract dates
                    if let notBefore = values[kSecOIDX509V1ValidityNotBefore as String] as? [String: Any],
                       let notBeforeValue = notBefore[kSecPropertyKeyValue as String] as? NSNumber {
                        validFrom = Date(timeIntervalSinceReferenceDate: notBeforeValue.doubleValue)
                    }

                    if let notAfter = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
                       let notAfterValue = notAfter[kSecPropertyKeyValue as String] as? NSNumber {
                        validTo = Date(timeIntervalSinceReferenceDate: notAfterValue.doubleValue)
                    }

                    // Extract issuer
                    if let issuerInfo = values[kSecOIDX509V1IssuerName as String] as? [String: Any],
                       let issuerValue = issuerInfo[kSecPropertyKeyValue as String] as? [[String: Any]] {
                        issuer = issuerValue.compactMap { dict in
                            if let label = dict[kSecPropertyKeyLabel as String] as? String,
                               let value = dict[kSecPropertyKeyValue as String] as? String {
                                return "\(label)=\(value)"
                            }
                            return nil
                        }.joined(separator: ", ")
                    }

                    // Extract serial number
                    if let serialInfo = values[kSecOIDX509V1SerialNumber as String] as? [String: Any],
                       let serialData = serialInfo[kSecPropertyKeyValue as String] as? Data {
                        serialNumber = serialData.map { String(format: "%02x", $0) }.joined()
                    }

                    // Extract signature algorithm
                    if let sigInfo = values[kSecOIDX509V1SignatureAlgorithm as String] as? [String: Any],
                       let sigValue = sigInfo[kSecPropertyKeyValue as String] as? String {
                        signatureAlgorithm = sigValue
                    }

                    // Extract public key info
                    if let pubKeyInfo = values[kSecOIDX509V1SubjectPublicKey as String] as? [String: Any],
                       let pubKeyAlg = pubKeyInfo[kSecPropertyKeyLabel as String] as? String {
                        publicKeyAlgorithm = pubKeyAlg
                    }

                    // Estimate key size from public key data
                    // Safely verify the object is actually a SecKey before using it,
                    // since secMetadata is typed as Any and may not be a SecKey.
                    let cfObject = secMetadata as CFTypeRef
                    if CFGetTypeID(cfObject) == SecKeyGetTypeID(),
                       let pubKeyData = SecKeyCopyExternalRepresentation(cfObject as! SecKey, nil) as Data? {
                        keySize = pubKeyData.count * 8
                    }

                    // Extract Subject Alternative Names
                    if let sanInfo = values[kSecOIDSubjectAltName as String] as? [String: Any],
                       let sanArray = sanInfo[kSecPropertyKeyValue as String] as? [[String: Any]] {
                        subjectAltNames = sanArray.compactMap { dict in
                            dict[kSecPropertyKeyValue as String] as? String
                        }
                    }
                }

                let isExpired = validTo < Date()
                let isSelfSigned = subject.lowercased().contains(issuer.lowercased()) || issuer.contains("self")

                certificateInfo = CertificateInfo(
                    subject: subject,
                    issuer: issuer,
                    validFrom: validFrom,
                    validTo: validTo,
                    serialNumber: serialNumber,
                    signatureAlgorithm: signatureAlgorithm,
                    publicKeyAlgorithm: publicKeyAlgorithm,
                    keySize: keySize,
                    isExpired: isExpired,
                    isSelfSigned: isSelfSigned,
                    subjectAltNames: subjectAltNames
                )
            }
        }

        return certificateInfo
    }

    private func extractTLSVersion(from metadata: NWProtocolMetadata) -> String? {
        guard let tlsMetadata = metadata as? NWProtocolTLS.Metadata else {
            return nil
        }

        let version = sec_protocol_metadata_get_negotiated_tls_protocol_version(
            tlsMetadata.securityProtocolMetadata
        )

        switch version {
        case .TLSv10: return "TLS 1.0"
        case .TLSv11: return "TLS 1.1"
        case .TLSv12: return "TLS 1.2"
        case .TLSv13: return "TLS 1.3"
        case .DTLSv10: return "DTLS 1.0"
        case .DTLSv12: return "DTLS 1.2"
        default: return "Unknown"
        }
    }

    private func extractCipherSuite(from metadata: NWProtocolMetadata) -> String? {
        guard let tlsMetadata = metadata as? NWProtocolTLS.Metadata else {
            return nil
        }

        let cipherSuite = sec_protocol_metadata_get_negotiated_tls_ciphersuite(
            tlsMetadata.securityProtocolMetadata
        )

        return cipherSuiteToString(cipherSuite)
    }

    // MARK: - Vulnerability Analysis

    private func analyzeCertificate(_ info: CertificateInfo?, host: String) -> [SSLIssue] {
        var issues: [SSLIssue] = []

        guard let info = info else {
            return issues
        }

        // Check if expired
        if info.isExpired {
            issues.append(SSLIssue(
                severity: .critical,
                type: .expiredCertificate,
                description: "Certificate expired on \(formatDate(info.validTo))",
                recommendation: "Renew the SSL certificate immediately. Expired certificates cause browser warnings and connection failures."
            ))
        }

        // Check if expiring soon (within 30 days)
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: info.validTo).day ?? 0
        if daysUntilExpiry > 0 && daysUntilExpiry <= 30 {
            issues.append(SSLIssue(
                severity: .high,
                type: .expiredCertificate,
                description: "Certificate expires in \(daysUntilExpiry) days",
                recommendation: "Renew the SSL certificate soon to avoid service interruption."
            ))
        }

        // Check if self-signed
        if info.isSelfSigned {
            issues.append(SSLIssue(
                severity: .high,
                type: .selfSigned,
                description: "Certificate is self-signed and not trusted by browsers",
                recommendation: "Use a certificate from a trusted Certificate Authority (Let's Encrypt, DigiCert, etc.)."
            ))
        }

        // Check weak signature algorithms
        let weakSignatures = ["sha1", "md5", "md2"]
        if weakSignatures.contains(where: { info.signatureAlgorithm.lowercased().contains($0) }) {
            issues.append(SSLIssue(
                severity: .high,
                type: .weakSignature,
                description: "Certificate uses weak signature algorithm: \(info.signatureAlgorithm)",
                recommendation: "Use SHA-256 or stronger signature algorithm. SHA-1 and MD5 are cryptographically broken."
            ))
        }

        // Check key size
        if info.publicKeyAlgorithm.lowercased().contains("rsa") && info.keySize < 2048 {
            issues.append(SSLIssue(
                severity: .high,
                type: .shortKeyLength,
                description: "RSA key size (\(info.keySize) bits) is too short",
                recommendation: "Use at least 2048-bit RSA keys. 4096-bit keys recommended for long-term security."
            ))
        } else if info.publicKeyAlgorithm.lowercased().contains("ec") && info.keySize < 256 {
            issues.append(SSLIssue(
                severity: .high,
                type: .shortKeyLength,
                description: "ECC key size (\(info.keySize) bits) is too short",
                recommendation: "Use at least 256-bit ECC keys (equivalent to 3072-bit RSA)."
            ))
        }

        // Check hostname match
        let hostnameMatches = info.subject.lowercased().contains(host.lowercased()) ||
                             info.subjectAltNames.contains { $0.lowercased().contains(host.lowercased()) }

        if !hostnameMatches && !info.subjectAltNames.isEmpty {
            issues.append(SSLIssue(
                severity: .high,
                type: .hostnameM,
                description: "Certificate hostname doesn't match '\(host)'",
                recommendation: "Ensure certificate is issued for the correct hostname. Subject: \(info.subject)"
            ))
        }

        return issues
    }

    private func analyzeTLSVersion(_ version: String?) -> [SSLIssue] {
        var issues: [SSLIssue] = []

        guard let version = version else {
            return issues
        }

        // Check for weak TLS versions
        if version.contains("1.0") || version.contains("1.1") || version.contains("SSL") {
            issues.append(SSLIssue(
                severity: .critical,
                type: .weakTLS,
                description: "Using deprecated TLS version: \(version)",
                recommendation: "Disable TLS 1.0 and 1.1. Use TLS 1.2 or TLS 1.3 only. Older versions have known vulnerabilities."
            ))
        }

        return issues
    }

    private func analyzeCipherSuite(_ cipherSuite: String?) -> [SSLIssue] {
        var issues: [SSLIssue] = []

        guard let cipherSuite = cipherSuite else {
            return issues
        }

        let weakCiphers = ["RC4", "DES", "3DES", "NULL", "EXPORT", "anon", "MD5"]

        for weakCipher in weakCiphers {
            if cipherSuite.contains(weakCipher) {
                issues.append(SSLIssue(
                    severity: .critical,
                    type: .weakCipher,
                    description: "Weak cipher suite in use: \(cipherSuite)",
                    recommendation: "Disable weak ciphers. Use AES-GCM, ChaCha20-Poly1305, or AES-CBC with strong modes."
                ))
                break
            }
        }

        return issues
    }

    // MARK: - Helper Methods

    private func cipherSuiteToString(_ suite: tls_ciphersuite_t) -> String {
        // Map common cipher suites
        switch suite.rawValue {
        case 0x002F: return "TLS_RSA_WITH_AES_128_CBC_SHA"
        case 0x0035: return "TLS_RSA_WITH_AES_256_CBC_SHA"
        case 0x009C: return "TLS_RSA_WITH_AES_128_GCM_SHA256"
        case 0x009D: return "TLS_RSA_WITH_AES_256_GCM_SHA384"
        case 0xC02F: return "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        case 0xC030: return "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        case 0xCCA8: return "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
        case 0x1301: return "TLS_AES_128_GCM_SHA256"
        case 0x1302: return "TLS_AES_256_GCM_SHA384"
        case 0x1303: return "TLS_CHACHA20_POLY1305_SHA256"
        default: return "Unknown (0x\(String(format: "%04X", suite.rawValue)))"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Statistics

    var stats: SSLStats {
        let critical = findings.flatMap { $0.issues }.filter { $0.severity == .critical }.count
        let high = findings.flatMap { $0.issues }.filter { $0.severity == .high }.count
        let medium = findings.flatMap { $0.issues }.filter { $0.severity == .medium }.count
        let secure = findings.filter { $0.isSecure }.count
        let insecure = findings.filter { !$0.isSecure }.count

        return SSLStats(
            totalHosts: findings.count,
            secureHosts: secure,
            insecureHosts: insecure,
            criticalIssues: critical,
            highIssues: high,
            mediumIssues: medium
        )
    }
}

struct SSLStats {
    let totalHosts: Int
    let secureHosts: Int
    let insecureHosts: Int
    let criticalIssues: Int
    let highIssues: Int
    let mediumIssues: Int
}
