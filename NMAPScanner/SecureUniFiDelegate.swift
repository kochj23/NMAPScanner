//
//  SecureUniFiDelegate.swift
//  NMAPScanner - Secure Certificate Validation for UniFi Controllers
//
//  Replaces insecure certificate bypass with proper validation
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation
import Security
import SwiftUI

/// Secure URLSession delegate with certificate pinning and user confirmation
class SecureUniFiDelegate: NSObject, URLSessionDelegate {
    // Store trusted certificate fingerprints
    private var trustedCertificates: Set<String> = []
    private let trustStoreKey = "NMAPScanner-TrustedCertificates"

    // Callback for user confirmation
    var onCertificateChallenge: ((String, String, String) async -> Bool)?

    override init() {
        super.init()
        loadTrustedCertificates()
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Get certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        guard certificateCount > 0,
              let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            SecureLogger.log("No certificate in chain", level: .error)
            SecurityAuditLog.log(event: .certificateRejected, details: "No certificate in chain", level: .error)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Calculate certificate fingerprint
        guard let fingerprint = CertificateFingerprint.calculate(for: certificate) else {
            SecureLogger.log("Failed to calculate certificate fingerprint", level: .error)
            SecurityAuditLog.log(event: .certificateRejected, details: "Fingerprint calculation failed", level: .error)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get certificate details
        let commonName = CertificateFingerprint.getCommonName(for: certificate) ?? "Unknown"
        let host = challenge.protectionSpace.host
        let formattedFingerprint = CertificateFingerprint.formatForDisplay(fingerprint)

        // Check if certificate is already trusted
        if trustedCertificates.contains(fingerprint) {
            SecureLogger.log("Certificate trusted (previously accepted): \(commonName)", level: .info)
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }

        // New certificate - evaluate trust
        var trustResult: SecTrustResultType = .invalid
        SecTrustEvaluate(serverTrust, &trustResult)

        let isTrustedBySystem = (trustResult == .unspecified || trustResult == .proceed)

        if isTrustedBySystem {
            // Certificate is trusted by system (valid CA chain)
            SecureLogger.log("Certificate trusted by system: \(commonName)", level: .info)
            SecurityAuditLog.log(event: .certificateTrusted, details: "System-trusted cert for \(host)", level: .info)

            // Auto-trust system-validated certificates
            trustedCertificates.insert(fingerprint)
            saveTrustedCertificates()

            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }

        // Self-signed or untrusted certificate - ask user
        SecureLogger.log("Untrusted certificate detected for \(host)", level: .warning)
        SecurityAuditLog.log(event: .certificateRejected, details: "Untrusted cert for \(host), awaiting user decision", level: .warning)

        Task { @MainActor [weak self] in
            guard let self = self else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            // Call the callback to ask user
            let shouldTrust = await self.onCertificateChallenge?(host, commonName, formattedFingerprint) ?? false

            if shouldTrust {
                // User accepted - add to trusted list
                self.trustedCertificates.insert(fingerprint)
                self.saveTrustedCertificates()

                SecurityAuditLog.log(event: .certificateTrusted, details: "User trusted cert for \(host): \(formattedFingerprint)", level: .security)
                SecureLogger.log("User trusted certificate for \(host)", level: .info)

                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                // User rejected
                SecurityAuditLog.log(event: .certificateRejected, details: "User rejected cert for \(host)", level: .security)
                SecureLogger.log("User rejected certificate for \(host)", level: .warning)
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }

    // MARK: - Trusted Certificates Management

    private func loadTrustedCertificates() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustStoreKey,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            if status != errSecItemNotFound {
                SecureLogger.log("Failed to load trusted certificates from Keychain, status: \(status)", level: .error)
            }
            return
        }

        do {
            let fingerprints = try JSONDecoder().decode([String].self, from: data)
            trustedCertificates = Set(fingerprints)
            SecureLogger.log("Loaded \(trustedCertificates.count) trusted certificates", level: .info)
        } catch {
            SecureLogger.log("Failed to decode trusted certificates: \(error.localizedDescription)", level: .error)
        }
    }

    private func saveTrustedCertificates() {
        let fingerprints = Array(trustedCertificates)

        let data: Data
        do {
            data = try JSONEncoder().encode(fingerprints)
        } catch {
            SecureLogger.log("Failed to encode trusted certificates: \(error.localizedDescription)", level: .error)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustStoreKey,
            kSecValueData as String: data
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            SecureLogger.log("Failed to save trusted certificates: \(status)", level: .error)
        } else {
            SecureLogger.log("Saved \(trustedCertificates.count) trusted certificates", level: .info)
        }
    }

    /// Clear all trusted certificates (user action)
    func clearTrustedCertificates() {
        trustedCertificates.removeAll()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustStoreKey
        ]
        SecItemDelete(query as CFDictionary)

        SecurityAuditLog.log(event: .configurationChange, details: "Cleared all trusted certificates", level: .security)
        SecureLogger.log("Cleared all trusted certificates", level: .warning)
    }

    /// Remove specific certificate from trust store
    func removeTrustedCertificate(_ fingerprint: String) {
        trustedCertificates.remove(fingerprint)
        saveTrustedCertificates()

        SecurityAuditLog.log(event: .configurationChange, details: "Removed trusted certificate: \(fingerprint)", level: .security)
        SecureLogger.log("Removed trusted certificate", level: .info)
    }
}

// MARK: - Certificate Trust UI

struct CertificateTrustAlert {
    let host: String
    let commonName: String
    let fingerprint: String

    var title: String {
        "Untrusted Certificate Detected"
    }

    var message: String {
        """
        The server \(host) presented a certificate that is not trusted by your system.

        Common Name: \(commonName)
        Fingerprint: \(fingerprint)

        This may be normal for UniFi controllers (they use self-signed certificates), but could also indicate a Man-in-the-Middle attack.

        Only proceed if you recognize this server and trust this network.
        """
    }
}
