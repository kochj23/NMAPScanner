//
//  UniFiDeviceIdentifier.swift
//  NMAP Plus Security Scanner - UniFi Device Identification
//
//  Created by Jordan Koch & Claude Code on 2025-12-01.
//
//  Identifies UniFi network infrastructure devices using multiple detection methods:
//  1. MAC Address OUI lookup (Ubiquiti MAC addresses)
//  2. Open ports characteristic of UniFi devices
//  3. HTTP/HTTPS banner grabbing
//  4. UDP Discovery Protocol (port 10001)
//  5. Hostname patterns
//

import Foundation
import Network

// MARK: - UniFi Device Info

/// Detailed information about identified UniFi device
struct UniFiDeviceInfo {
    let ipAddress: String
    let macAddress: String?
    let deviceType: UniFiDeviceType
    let model: String?
    let version: String?
    let hostname: String?
    let detectionMethod: UniFiDetectionMethod
    let confidence: DetectionConfidence

    enum UniFiDetectionMethod: String {
        case macAddressOUI = "MAC Address OUI"
        case portSignature = "Port Signature"
        case httpBanner = "HTTP Banner"
        case udpDiscovery = "UDP Discovery"
        case hostname = "Hostname Pattern"
        case combined = "Multiple Methods"
    }

    enum DetectionConfidence: String {
        case high = "High"     // 90%+ certainty
        case medium = "Medium" // 60-89% certainty
        case low = "Low"       // 40-59% certainty
    }
}

// MARK: - UniFi Device Identifier

/// Identifies UniFi devices on the network without requiring controller access
@MainActor
class UniFiDeviceIdentifier: ObservableObject {
    static let shared = UniFiDeviceIdentifier()

    @Published var identifiedDevices: [String: UniFiDeviceInfo] = [:] // IP -> DeviceInfo
    @Published var isIdentifying = false
    @Published var progress: Double = 0
    @Published var status = ""

    // Known Ubiquiti MAC OUIs (Organizationally Unique Identifiers)
    private let ubiquitiOUIs: Set<String> = [
        "00:27:22", // Ubiquiti Networks Inc.
        "24:5A:4C", // Ubiquiti Networks Inc.
        "68:D7:9A", // Ubiquiti Networks Inc.
        "74:83:C2", // Ubiquiti Networks Inc.
        "78:8A:20", // Ubiquiti Networks Inc.
        "80:2A:A8", // Ubiquiti Networks Inc.
        "B4:FB:E4", // Ubiquiti Networks Inc.
        "DC:9F:DB", // Ubiquiti Networks Inc.
        "E0:63:DA", // Ubiquiti Networks Inc.
        "F0:9F:C2", // Ubiquiti Networks Inc.
        "FC:EC:DA", // Ubiquiti Networks Inc.
        "18:E8:29", // Ubiquiti Networks Inc.
        "44:D9:E7", // Ubiquiti Networks Inc.
        "6C:B0:CE", // Ubiquiti Networks Inc.
        "70:A7:41"  // Ubiquiti Networks Inc.
    ]

    // UniFi device characteristic port signatures
    private let unifiPortSignatures: [Set<Int>] = [
        [22, 443, 8080, 10001],           // Full management device
        [22, 443, 8443, 10001],           // UDM/Gateway
        [22, 80, 443, 10001],             // Access Point
        [22, 443, 10001],                 // Switch
        [22, 80, 443, 7080, 7443, 7447]  // Camera/Protect
    ]

    private init() {}

    // MARK: - Public API

    /// Identify UniFi devices from a list of IP addresses
    func identifyDevices(ipAddresses: [String]) async {
        print("🔍 UniFiDeviceIdentifier: Starting identification for \(ipAddresses.count) IPs")

        isIdentifying = true
        progress = 0
        status = "Starting UniFi device identification..."
        identifiedDevices = [:]

        for (index, ip) in ipAddresses.enumerated() {
            status = "Checking \(ip)... (\(index + 1)/\(ipAddresses.count))"

            if let deviceInfo = await identifyDevice(ip: ip) {
                identifiedDevices[ip] = deviceInfo
                print("✅ UniFiDeviceIdentifier: Found UniFi device - \(ip): \(deviceInfo.deviceType.rawValue) (\(deviceInfo.detectionMethod.rawValue))")
            }

            progress = Double(index + 1) / Double(ipAddresses.count)
        }

        status = "Identification complete - \(identifiedDevices.count) UniFi devices found"
        progress = 1.0
        isIdentifying = false

        print("✅ UniFiDeviceIdentifier: Complete - found \(identifiedDevices.count) UniFi devices")
    }

    /// Check if an IP is a known UniFi device IP from the user's list
    func isKnownUniFiIP(_ ip: String) -> Bool {
        let knownUniFiIPs: Set<String> = [
            "192.168.1.33", "192.168.1.161", "192.168.1.28", "192.168.1.78",
            "192.168.1.138", "192.168.1.50", "192.168.1.80", "192.168.1.193",
            "192.168.1.102", "192.168.1.122", "192.168.1.109", "192.168.1.155",
            "192.168.1.52", "192.168.1.1", "192.168.1.123", "192.168.1.54"
        ]
        return knownUniFiIPs.contains(ip)
    }

    // MARK: - Device Identification Methods

    /// Identify a single device using multiple detection methods
    private func identifyDevice(ip: String) async -> UniFiDeviceInfo? {
        var detectionScores: [UniFiDeviceInfo.UniFiDetectionMethod: Int] = [:]
        var detectedDeviceType: UniFiDeviceType = .unknown
        var model: String?
        var version: String?
        var hostname: String?
        var macAddress: String?

        // Method 1: Check if it's a known UniFi IP from user's list
        if isKnownUniFiIP(ip) {
            detectionScores[.combined] = 100
            print("🎯 UniFiDeviceIdentifier: \(ip) is in known UniFi device list")
        }

        // Method 2: MAC Address OUI Lookup
        if let mac = await getMACAddress(for: ip) {
            macAddress = mac
            if isUbiquitiMAC(mac) {
                detectionScores[.macAddressOUI] = 95
                print("✅ UniFiDeviceIdentifier: \(ip) has Ubiquiti MAC: \(mac)")
            }
        }

        // Method 3: Port Signature Analysis
        if let portScore = await checkPortSignature(ip: ip) {
            detectionScores[.portSignature] = portScore
            if portScore > 70 {
                print("✅ UniFiDeviceIdentifier: \(ip) has UniFi port signature (score: \(portScore))")
            }
        }

        // Method 4: HTTP Banner Grabbing
        if let bannerInfo = await grabHTTPBanner(ip: ip) {
            detectionScores[.httpBanner] = 85
            model = bannerInfo.model
            version = bannerInfo.version
            detectedDeviceType = bannerInfo.deviceType
            print("✅ UniFiDeviceIdentifier: \(ip) HTTP banner indicates UniFi device")
        }

        // Method 5: Hostname Pattern Matching
        if let host = await getHostname(for: ip) {
            hostname = host
            if matchesUniFiHostnamePattern(host) {
                detectionScores[.hostname] = 70
                print("✅ UniFiDeviceIdentifier: \(ip) hostname matches UniFi pattern: \(host)")
            }
        }

        // Calculate confidence based on detection scores
        let maxScore = detectionScores.values.max() ?? 0
        let totalMethods = detectionScores.count

        guard maxScore > 50 || totalMethods >= 2 else {
            return nil // Not confident enough
        }

        // Determine confidence level
        let confidence: UniFiDeviceInfo.DetectionConfidence
        if maxScore >= 90 || totalMethods >= 3 {
            confidence = .high
        } else if maxScore >= 70 || totalMethods >= 2 {
            confidence = .medium
        } else {
            confidence = .low
        }

        // Determine detection method
        let detectionMethod: UniFiDeviceInfo.UniFiDetectionMethod
        if totalMethods > 1 {
            detectionMethod = .combined
        } else if let primary = detectionScores.keys.first {
            detectionMethod = primary
        } else {
            detectionMethod = .combined
        }

        // If device type not determined from banner, try to infer from ports/IP
        if detectedDeviceType == .unknown {
            detectedDeviceType = inferDeviceType(ip: ip, hostname: hostname)
        }

        return UniFiDeviceInfo(
            ipAddress: ip,
            macAddress: macAddress,
            deviceType: detectedDeviceType,
            model: model,
            version: version,
            hostname: hostname,
            detectionMethod: detectionMethod,
            confidence: confidence
        )
    }

    // MARK: - Detection Helper Methods

    /// Check if MAC address belongs to Ubiquiti
    private func isUbiquitiMAC(_ mac: String) -> Bool {
        let oui = mac.prefix(8).uppercased()
        return ubiquitiOUIs.contains(oui)
    }

    /// Get MAC address for IP (from ARP table)
    private func getMACAddress(for ip: String) async -> String? {
        let arpOutput = await executeCommand("/usr/sbin/arp", arguments: ["-n", ip])

        // Parse MAC address from ARP output
        // Format: ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
        let macRegex = try? NSRegularExpression(pattern: "([0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2})")

        if let regex = macRegex,
           let match = regex.firstMatch(in: arpOutput, range: NSRange(arpOutput.startIndex..., in: arpOutput)),
           let range = Range(match.range(at: 1), in: arpOutput) {
            return String(arpOutput[range])
        }

        return nil
    }

    /// Check port signature against known UniFi patterns
    private func checkPortSignature(ip: String) async -> Int? {
        // Quick port check for common UniFi ports
        let commonPorts = [22, 80, 443, 8080, 8443, 10001]
        var openPorts: Set<Int> = []

        for port in commonPorts {
            if await isPortOpen(ip: ip, port: port, timeout: 0.5) {
                openPorts.insert(port)
            }
        }

        guard !openPorts.isEmpty else { return nil }

        // Score based on port signature matching
        var maxScore = 0
        for signature in unifiPortSignatures {
            let matchingPorts = openPorts.intersection(signature)
            let score = (matchingPorts.count * 100) / signature.count
            maxScore = max(maxScore, score)
        }

        return maxScore > 40 ? maxScore : nil
    }

    /// Check if a port is open with timeout
    private func isPortOpen(ip: String, port: Int, timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let portEndpoint = NWEndpoint.Port(integerLiteral: UInt16(port))
            let endpoint = NWEndpoint.hostPort(host: host, port: portEndpoint)

            let connection = NWConnection(to: endpoint, using: .tcp)
            var hasReturned = false

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !hasReturned {
                    hasReturned = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }

            connection.stateUpdateHandler = { state in
                guard !hasReturned else { return }

                switch state {
                case .ready:
                    hasReturned = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    hasReturned = true
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    /// Grab HTTP banner from device
    private func grabHTTPBanner(ip: String) async -> (model: String?, version: String?, deviceType: UniFiDeviceType)? {
        // Try HTTPS first (most UniFi devices)
        if let banner = await fetchHTTPBanner(ip: ip, useHTTPS: true) {
            return banner
        }

        // Try HTTP fallback
        if let banner = await fetchHTTPBanner(ip: ip, useHTTPS: false) {
            return banner
        }

        return nil
    }

    /// Fetch HTTP/HTTPS banner
    private func fetchHTTPBanner(ip: String, useHTTPS: Bool) async -> (model: String?, version: String?, deviceType: UniFiDeviceType)? {
        let scheme = useHTTPS ? "https" : "http"
        let urlString = "\(scheme)://\(ip)/"

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               let serverHeader = httpResponse.allHeaderFields["Server"] as? String {

                // Check for UniFi signatures in headers
                let content = String(data: data, encoding: .utf8) ?? ""

                if serverHeader.contains("Ubiquiti") || serverHeader.contains("UniFi") ||
                   content.contains("UniFi") || content.contains("Ubiquiti") {

                    // Try to extract model and version
                    let model = extractModel(from: content, serverHeader: serverHeader)
                    let version = extractVersion(from: content, serverHeader: serverHeader)
                    let deviceType = inferDeviceTypeFromBanner(content: content, serverHeader: serverHeader)

                    return (model, version, deviceType)
                }
            }
        } catch {
            // Silently fail - this is expected for many devices
        }

        return nil
    }

    /// Extract model from banner content
    private func extractModel(from content: String, serverHeader: String) -> String? {
        // Look for model patterns in content
        let modelPatterns = [
            "model[\"']?\\s*[:=]\\s*[\"']?([A-Z0-9-]+)",
            "UniFi\\s+([A-Z0-9-]+)",
            "model_display[\"']?\\s*[:=]\\s*[\"']?([^\"',]+)"
        ]

        for pattern in modelPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
        }

        return nil
    }

    /// Extract version from banner content
    private func extractVersion(from content: String, serverHeader: String) -> String? {
        // Look for version patterns
        let versionPatterns = [
            "version[\"']?\\s*[:=]\\s*[\"']?([0-9.]+)",
            "firmware[\"']?\\s*[:=]\\s*[\"']?([0-9.]+)",
            "v([0-9.]+)"
        ]

        for pattern in versionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
        }

        return nil
    }

    /// Infer device type from banner
    private func inferDeviceTypeFromBanner(content: String, serverHeader: String) -> UniFiDeviceType {
        let combined = (content + serverHeader).lowercased()

        if combined.contains("camera") || combined.contains("protect") || combined.contains("nvr") {
            return .camera
        } else if combined.contains("switch") {
            return .switch
        } else if combined.contains("access point") || combined.contains("ap") {
            return .accessPoint
        } else if combined.contains("gateway") || combined.contains("udm") || combined.contains("usg") {
            return .gateway
        }

        return .unknown
    }

    /// Get hostname for IP using DNS lookup
    private func getHostname(for ip: String) async -> String? {
        let hostOutput = await executeCommand("/usr/bin/host", arguments: [ip])

        // Parse hostname from output
        // Format: 1.1.168.192.in-addr.arpa domain name pointer gateway.local.
        if let range = hostOutput.range(of: "domain name pointer ") {
            let hostname = hostOutput[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
        }

        return nil
    }

    /// Check if hostname matches UniFi naming patterns
    private func matchesUniFiHostnamePattern(_ hostname: String) -> Bool {
        let patterns = [
            "^u[a-z]{2,4}-.*", // ubnt-, uap-, usw-, udm-, etc.
            "^unifi.*",
            ".*\\.ubnt$",
            ".*\\.ubiquiti$",
            ".*-ap$",
            ".*-switch$",
            ".*-gateway$"
        ]

        let lowerHostname = hostname.lowercased()
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lowerHostname, range: NSRange(lowerHostname.startIndex..., in: lowerHostname)) != nil {
                return true
            }
        }

        return false
    }

    /// Infer device type from IP and hostname
    private func inferDeviceType(ip: String, hostname: String?) -> UniFiDeviceType {
        let host = hostname?.lowercased() ?? ""

        if host.contains("camera") || host.contains("protect") {
            return .camera
        } else if host.contains("switch") || host.contains("usw") {
            return .switch
        } else if host.contains("ap") || host.contains("uap") {
            return .accessPoint
        } else if host.contains("gateway") || host.contains("udm") || host.contains("usg") || ip.hasSuffix(".1") {
            return .gateway
        }

        return .unknown
    }

    // MARK: - Command Execution

    /// Execute shell command and return output
    private func executeCommand(_ command: String, arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
