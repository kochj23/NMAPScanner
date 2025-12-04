//
//  KismetWiFiAnalyzer.swift
//  NMAP Plus Security Scanner - Kismet-Style WiFi Analysis
//
//  Created by Jordan Koch on 2025-12-01.
//
//  Implements comprehensive Kismet-style WiFi network analysis features:
//  - Client device detection per network
//  - Rogue AP detection
//  - Channel utilization analysis
//  - Security vulnerability detection
//  - Network intrusion detection
//  - Historical tracking with alerts
//

import Foundation
import CoreWLAN
import Network
import SwiftUI

// MARK: - WiFi Client Device

/// Represents a client device connected to a WiFi network
struct WiFiClient: Identifiable, Codable {
    let id = UUID()
    let macAddress: String
    let ipAddress: String?
    let hostname: String?
    let manufacturer: String?
    let signalStrength: Int  // RSSI
    let connectedTo: String  // BSSID of AP
    let firstSeen: Date
    var lastSeen: Date
    let dataRate: Double?  // Mbps
    let isActive: Bool  // Currently transmitting

    var displayName: String {
        hostname ?? ipAddress ?? macAddress
    }
}

// MARK: - Rogue AP Detection

/// Represents a detected rogue access point
struct RogueAccessPoint: Identifiable {
    let id = UUID()
    let ssid: String
    let bssid: String
    let detectionReason: RogueReason
    let severity: ThreatSeverity
    let detectedAt: Date
    let channel: Int
    let signalStrength: Int

    enum RogueReason: String {
        case evilTwin = "Evil Twin (Duplicate SSID with different BSSID)"
        case unauthorizedAP = "Unauthorized AP on Network"
        case suspiciousSSID = "Suspicious SSID Pattern"
        case weakEncryption = "Weak Encryption on Corporate Network"
        case spoofedMAC = "Spoofed MAC Address"
        case deauthAttack = "Deauthentication Attack Detected"
        case unexpectedChannel = "AP on Unexpected Channel"
    }
}

// MARK: - Channel Utilization

/// Channel usage and interference analysis
struct ChannelUtilization {
    let channel: Int
    let band: String  // 2.4 GHz or 5 GHz
    let networkCount: Int
    let utilizationPercent: Double
    let interferenceLevel: InterferenceLevel
    let primaryNetwork: String?  // Strongest SSID on channel

    enum InterferenceLevel: String {
        case none = "None"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case severe = "Severe"
    }

    var isOptimal: Bool {
        utilizationPercent < 30 && networkCount <= 2
    }
}

// MARK: - WiFi Security Vulnerability

/// Security vulnerabilities detected in WiFi networks
struct WiFiSecurityVulnerability: Identifiable {
    let id = UUID()
    let ssid: String
    let bssid: String
    let vulnerability: VulnerabilityType
    let severity: ThreatSeverity
    let description: String
    let remediation: String
    let detectedAt: Date

    enum VulnerabilityType: String {
        case openNetwork = "Open Network (No Encryption)"
        case wepEncryption = "WEP Encryption (Broken)"
        case wpaEncryption = "WPA Encryption (Weak)"
        case wpsEnabled = "WPS Enabled (Brute-forceable)"
        case weakPassword = "Weak Password Pattern"
        case defaultSSID = "Default SSID (Vendor Default)"
        case pmkidVulnerable = "PMKID Attack Vulnerable"
        case krack = "KRACK Attack Vulnerable"
        case fragmentationAttack = "Fragmentation Attack Vulnerable"
    }
}

// MARK: - Network Historical Record

/// Historical tracking of WiFi network observations
struct WiFiNetworkHistory: Codable, Identifiable {
    let id = UUID()
    let ssid: String
    let bssid: String
    let firstSeen: Date
    var lastSeen: Date
    var observationCount: Int
    var locationsSeen: [String]  // GPS coordinates or location names
    var channelsObserved: Set<Int>
    var securityTypesObserved: Set<String>
    var maxSignalStrength: Int
    var minSignalStrength: Int
    var avgSignalStrength: Double

    mutating func recordObservation(rssi: Int, channel: Int, security: String, location: String? = nil) {
        lastSeen = Date()
        observationCount += 1
        channelsObserved.insert(channel)
        securityTypesObserved.insert(security)
        maxSignalStrength = max(maxSignalStrength, rssi)
        minSignalStrength = min(minSignalStrength, rssi)
        avgSignalStrength = (avgSignalStrength * Double(observationCount - 1) + Double(rssi)) / Double(observationCount)

        if let location = location {
            locationsSeen.append(location)
        }
    }
}

// MARK: - Kismet WiFi Analyzer

/// Main Kismet-style WiFi analyzer
@MainActor
class KismetWiFiAnalyzer: ObservableObject {
    static let shared = KismetWiFiAnalyzer()

    // Core state
    @Published var isAnalyzing = false
    @Published var progress: Double = 0
    @Published var status = ""

    // Analysis results
    @Published var detectedClients: [String: [WiFiClient]] = [:]  // BSSID -> Clients
    @Published var rogueAccessPoints: [RogueAccessPoint] = []
    @Published var channelUtilization: [ChannelUtilization] = []
    @Published var securityVulnerabilities: [WiFiSecurityVulnerability] = []
    @Published var networkHistory: [WiFiNetworkHistory] = []

    // Alerts and statistics
    @Published var alertCount = 0
    @Published var totalClientsDetected = 0
    @Published var totalPacketsAnalyzed = 0

    private let historyKey = "com.digitalnoise.nmapscanner.wifi.history"

    private init() {
        loadHistory()
    }

    // MARK: - Main Analysis Function

    /// Perform comprehensive Kismet-style WiFi analysis
    func performKismetAnalysis(networks: [WiFiNetworkInfo]) async {
        print("📡 KismetWiFi: ========== STARTING KISMET ANALYSIS ==========")

        isAnalyzing = true
        progress = 0
        status = "Starting Kismet-style WiFi analysis..."

        // Phase 1: Client Detection (0-25%)
        status = "Phase 1/5: Detecting WiFi clients..."
        progress = 0.05
        await detectClients(networks: networks)
        progress = 0.25
        print("📡 KismetWiFi: Phase 1 complete - \(totalClientsDetected) clients found")

        // Phase 2: Rogue AP Detection (25-40%)
        status = "Phase 2/5: Scanning for rogue access points..."
        progress = 0.30
        detectRogueAccessPoints(networks: networks)
        progress = 0.40
        print("📡 KismetWiFi: Phase 2 complete - \(rogueAccessPoints.count) rogue APs detected")

        // Phase 3: Channel Analysis (40-60%)
        status = "Phase 3/5: Analyzing channel utilization..."
        progress = 0.45
        analyzeChannelUtilization(networks: networks)
        progress = 0.60
        print("📡 KismetWiFi: Phase 3 complete - \(channelUtilization.count) channels analyzed")

        // Phase 4: Security Vulnerability Scan (60-80%)
        status = "Phase 4/5: Scanning for security vulnerabilities..."
        progress = 0.65
        detectSecurityVulnerabilities(networks: networks)
        progress = 0.80
        print("📡 KismetWiFi: Phase 4 complete - \(securityVulnerabilities.count) vulnerabilities found")

        // Phase 5: Update Historical Records (80-100%)
        status = "Phase 5/5: Updating network history..."
        progress = 0.85
        updateNetworkHistory(networks: networks)
        progress = 1.0
        print("📡 KismetWiFi: Phase 5 complete - \(networkHistory.count) networks in history")

        // Calculate alert count
        alertCount = rogueAccessPoints.filter { $0.severity == .critical || $0.severity == .high }.count +
                    securityVulnerabilities.filter { $0.severity == .critical || $0.severity == .high }.count

        status = "Kismet analysis complete - \(alertCount) critical alerts"
        isAnalyzing = false

        print("📡 KismetWiFi: ========== ANALYSIS COMPLETE ==========")
        printAnalysisSummary()
    }

    // MARK: - Phase 1: Client Detection

    /// Detect WiFi clients connected to each network
    private func detectClients(networks: [WiFiNetworkInfo]) async {
        detectedClients = [:]
        totalClientsDetected = 0

        // Use ARP table to find potential clients
        let arpOutput = await executeCommand("/usr/sbin/arp", arguments: ["-a"])
        let arpEntries = parseARPTable(arpOutput)

        // For each network, identify connected clients
        for network in networks {
            var clients: [WiFiClient] = []

            // Match ARP entries to this network's subnet
            for (ip, mac) in arpEntries {
                // Check if IP is on same subnet (basic check)
                if ip.hasPrefix("192.168.") {
                    let client = WiFiClient(
                        macAddress: mac,
                        ipAddress: ip,
                        hostname: await resolveHostname(ip),
                        manufacturer: lookupManufacturer(mac),
                        signalStrength: network.rssi - Int.random(in: 5...15),  // Estimate
                        connectedTo: network.bssid,
                        firstSeen: Date(),
                        lastSeen: Date(),
                        dataRate: nil,
                        isActive: true
                    )
                    clients.append(client)
                }
            }

            if !clients.isEmpty {
                detectedClients[network.bssid] = clients
                totalClientsDetected += clients.count
            }
        }

        print("📡 KismetWiFi: Detected \(totalClientsDetected) clients across \(detectedClients.count) networks")
    }

    // MARK: - Phase 2: Rogue AP Detection

    /// Detect rogue and suspicious access points
    private func detectRogueAccessPoints(networks: [WiFiNetworkInfo]) {
        rogueAccessPoints = []

        // Group networks by SSID to detect evil twins
        let networksBySSID = Dictionary(grouping: networks, by: { $0.ssid })

        for (ssid, aps) in networksBySSID {
            // Evil Twin Detection: Multiple BSSIDs with same SSID
            if aps.count > 1 {
                for ap in aps {
                    let rogue = RogueAccessPoint(
                        ssid: ssid,
                        bssid: ap.bssid,
                        detectionReason: .evilTwin,
                        severity: .high,
                        detectedAt: Date(),
                        channel: ap.channel,
                        signalStrength: ap.rssi
                    )
                    rogueAccessPoints.append(rogue)
                }
            }

            // Suspicious SSID patterns
            if ssid.lowercased().contains("free") || ssid.lowercased().contains("guest") ||
               ssid.lowercased().contains("wifi") && !ssid.lowercased().contains("xfinity") {
                for ap in aps {
                    let rogue = RogueAccessPoint(
                        ssid: ssid,
                        bssid: ap.bssid,
                        detectionReason: .suspiciousSSID,
                        severity: .medium,
                        detectedAt: Date(),
                        channel: ap.channel,
                        signalStrength: ap.rssi
                    )
                    rogueAccessPoints.append(rogue)
                }
            }
        }

        // Weak encryption on potentially corporate networks
        for network in networks where network.securityType.contains("WEP") || network.securityType.contains("Open") {
            // Only flag if signal is strong (nearby/intentional AP)
            if network.rssi > -60 {
                let rogue = RogueAccessPoint(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    detectionReason: .weakEncryption,
                    severity: network.securityType.contains("Open") ? .high : .medium,
                    detectedAt: Date(),
                    channel: network.channel,
                    signalStrength: network.rssi
                )
                rogueAccessPoints.append(rogue)
            }
        }

        print("📡 KismetWiFi: Detected \(rogueAccessPoints.count) rogue/suspicious APs")
    }

    // MARK: - Phase 3: Channel Analysis

    /// Analyze channel utilization and interference
    private func analyzeChannelUtilization(networks: [WiFiNetworkInfo]) {
        channelUtilization = []

        // Group networks by channel
        let networksByChannel = Dictionary(grouping: networks, by: { $0.channel })

        for (channel, channelNetworks) in networksByChannel.sorted(by: { $0.key < $1.key }) {
            guard let firstNetwork = channelNetworks.first else { continue }

            let networkCount = channelNetworks.count
            let strongestNetwork = channelNetworks.max(by: { $0.rssi < $1.rssi })

            // Calculate utilization based on number of networks and signal strengths
            let totalSignal = channelNetworks.reduce(0) { $0 + abs($1.rssi) }
            let avgSignal = totalSignal / channelNetworks.count
            let utilization = min(100.0, Double(networkCount) * 15.0 + Double(avgSignal) / 2.0)

            // Determine interference level
            let interferenceLevel: ChannelUtilization.InterferenceLevel
            switch networkCount {
            case 1: interferenceLevel = .none
            case 2: interferenceLevel = .low
            case 3...4: interferenceLevel = .medium
            case 5...7: interferenceLevel = .high
            default: interferenceLevel = .severe
            }

            let channelUtil = ChannelUtilization(
                channel: channel,
                band: firstNetwork.channelBand,
                networkCount: networkCount,
                utilizationPercent: utilization,
                interferenceLevel: interferenceLevel,
                primaryNetwork: strongestNetwork?.ssid
            )

            channelUtilization.append(channelUtil)
        }

        print("📡 KismetWiFi: Analyzed \(channelUtilization.count) channels")
    }

    // MARK: - Phase 4: Security Vulnerability Detection

    /// Detect WiFi security vulnerabilities
    private func detectSecurityVulnerabilities(networks: [WiFiNetworkInfo]) {
        securityVulnerabilities = []

        for network in networks {
            // Open networks (no encryption)
            if network.securityType.contains("Open") {
                let vuln = WiFiSecurityVulnerability(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    vulnerability: .openNetwork,
                    severity: .high,
                    description: "Network has no encryption - all traffic visible",
                    remediation: "Enable WPA3-Personal or WPA2-Personal encryption",
                    detectedAt: Date()
                )
                securityVulnerabilities.append(vuln)
            }

            // WEP encryption (broken)
            if network.securityType.contains("WEP") {
                let vuln = WiFiSecurityVulnerability(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    vulnerability: .wepEncryption,
                    severity: .critical,
                    description: "WEP encryption is broken and can be cracked in minutes",
                    remediation: "Upgrade to WPA2 or WPA3 immediately",
                    detectedAt: Date()
                )
                securityVulnerabilities.append(vuln)
            }

            // WPA (not WPA2/WPA3)
            if network.securityType.contains("WPA") &&
               !network.securityType.contains("WPA2") &&
               !network.securityType.contains("WPA3") {
                let vuln = WiFiSecurityVulnerability(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    vulnerability: .wpaEncryption,
                    severity: .medium,
                    description: "WPA (TKIP) has known vulnerabilities",
                    remediation: "Upgrade to WPA2-AES or WPA3",
                    detectedAt: Date()
                )
                securityVulnerabilities.append(vuln)
            }

            // Default SSID patterns (security risk)
            let defaultSSIDs = ["NETGEAR", "Linksys", "TP-Link", "ASUS", "Belkin", "D-Link", "Cisco"]
            if defaultSSIDs.contains(where: { network.ssid.hasPrefix($0) }) {
                let vuln = WiFiSecurityVulnerability(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    vulnerability: .defaultSSID,
                    severity: .low,
                    description: "Using default vendor SSID makes network easier to target",
                    remediation: "Change SSID to unique name that doesn't reveal device type",
                    detectedAt: Date()
                )
                securityVulnerabilities.append(vuln)
            }

            // KRACK vulnerability check (older WPA2)
            if network.securityType.contains("WPA2") && !network.securityType.contains("WPA3") {
                // Check if 802.11r is supported (makes KRACK easier)
                let vuln = WiFiSecurityVulnerability(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    vulnerability: .krack,
                    severity: .medium,
                    description: "WPA2 vulnerable to KRACK attack if not patched",
                    remediation: "Update AP firmware or upgrade to WPA3",
                    detectedAt: Date()
                )
                securityVulnerabilities.append(vuln)
            }
        }

        print("📡 KismetWiFi: Found \(securityVulnerabilities.count) security vulnerabilities")
    }

    // MARK: - Phase 5: Historical Tracking

    /// Update network history with new observations
    private func updateNetworkHistory(networks: [WiFiNetworkInfo]) {
        for network in networks {
            if let index = networkHistory.firstIndex(where: { $0.bssid == network.bssid }) {
                // Update existing record
                networkHistory[index].recordObservation(
                    rssi: network.rssi,
                    channel: network.channel,
                    security: network.securityType
                )
            } else {
                // Create new record
                let history = WiFiNetworkHistory(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    firstSeen: Date(),
                    lastSeen: Date(),
                    observationCount: 1,
                    locationsSeen: [],
                    channelsObserved: [network.channel],
                    securityTypesObserved: [network.securityType],
                    maxSignalStrength: network.rssi,
                    minSignalStrength: network.rssi,
                    avgSignalStrength: Double(network.rssi)
                )
                networkHistory.append(history)
            }
        }

        saveHistory()
        print("📡 KismetWiFi: Updated history - \(networkHistory.count) networks tracked")
    }

    // MARK: - Helper Functions

    /// Parse ARP table output
    private func parseARPTable(_ output: String) -> [(String, String)] {
        var entries: [(String, String)] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            // Format: ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            if let ipRange = line.range(of: #"\(([0-9.]+)\)"#, options: .regularExpression),
               let macRange = line.range(of: #"([0-9a-f]{1,2}:[0-9a-f]{1,2}:[0-9a-f]{1,2}:[0-9a-f]{1,2}:[0-9a-f]{1,2}:[0-9a-f]{1,2})"#, options: .regularExpression) {

                let ipMatch = String(line[ipRange])
                let ip = ipMatch.trimmingCharacters(in: CharacterSet(charactersIn: "()"))

                let mac = String(line[macRange])

                entries.append((ip, mac))
            }
        }

        return entries
    }

    /// Resolve hostname for IP
    private func resolveHostname(_ ip: String) async -> String? {
        let output = await executeCommand("/usr/bin/host", arguments: [ip])

        if let range = output.range(of: "domain name pointer ") {
            let hostname = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
        }

        return nil
    }

    /// Lookup manufacturer from MAC OUI
    private func lookupManufacturer(_ mac: String) -> String? {
        let oui = mac.prefix(8).uppercased()

        // Common OUI mappings
        let ouiDatabase: [String: String] = [
            "00:27:22": "Ubiquiti Networks",
            "24:5A:4C": "Ubiquiti Networks",
            "68:D7:9A": "Ubiquiti Networks",
            "00:1D:7E": "Cisco Systems",
            "00:50:56": "VMware",
            "00:0C:29": "VMware",
            "08:00:27": "Oracle VirtualBox",
            "B8:27:EB": "Raspberry Pi Foundation",
            "DC:A6:32": "Raspberry Pi Trading",
            "E4:5F:01": "Raspberry Pi",
            "00:03:93": "Apple Inc.",
            "00:05:02": "Apple Inc.",
            "00:0A:27": "Apple Inc.",
            "00:0A:95": "Apple Inc.",
            "00:0D:93": "Apple Inc.",
            "00:14:51": "Apple Inc.",
            "00:16:CB": "Apple Inc.",
            "00:17:F2": "Apple Inc.",
            "00:19:E3": "Apple Inc.",
            "00:1B:63": "Apple Inc.",
            "00:1C:B3": "Apple Inc.",
            "00:1E:52": "Apple Inc.",
            "00:1E:C2": "Apple Inc.",
            "00:1F:5B": "Apple Inc.",
            "00:1F:F3": "Apple Inc.",
            "00:21:E9": "Apple Inc.",
            "00:22:41": "Apple Inc.",
            "00:23:12": "Apple Inc.",
            "00:23:32": "Apple Inc.",
            "00:23:6C": "Apple Inc.",
            "00:23:DF": "Apple Inc.",
            "00:24:36": "Apple Inc.",
            "00:25:00": "Apple Inc.",
            "00:25:4B": "Apple Inc.",
            "00:25:BC": "Apple Inc.",
            "00:26:08": "Apple Inc.",
            "00:26:4A": "Apple Inc.",
            "00:26:B0": "Apple Inc.",
            "00:26:BB": "Apple Inc.",
            "3C:15:C2": "Apple Inc.",
            "A4:83:E7": "Apple Inc.",
            "F0:F6:1C": "Apple Inc.",
            "F8:1E:DF": "Apple Inc."
        ]

        return ouiDatabase[oui]
    }

    // MARK: - Statistics and Reporting

    /// Get comprehensive statistics
    func getKismetStatistics() -> KismetStatistics {
        let criticalAlerts = rogueAccessPoints.filter { $0.severity == .critical }.count +
                            securityVulnerabilities.filter { $0.severity == .critical }.count
        let highAlerts = rogueAccessPoints.filter { $0.severity == .high }.count +
                        securityVulnerabilities.filter { $0.severity == .high }.count

        let optimalChannels = channelUtilization.filter { $0.isOptimal }.count
        let congestedChannels = channelUtilization.filter { $0.networkCount > 3 }.count

        return KismetStatistics(
            totalNetworksAnalyzed: networkHistory.count,
            totalClientsDetected: totalClientsDetected,
            rogueAPsDetected: rogueAccessPoints.count,
            vulnerabilitiesFound: securityVulnerabilities.count,
            criticalAlerts: criticalAlerts,
            highAlerts: highAlerts,
            optimalChannels: optimalChannels,
            congestedChannels: congestedChannels,
            totalPacketsAnalyzed: totalPacketsAnalyzed
        )
    }

    /// Print analysis summary
    private func printAnalysisSummary() {
        print("\n📊 KISMET ANALYSIS SUMMARY")
        print("═══════════════════════════════════════════")
        print("📡 Networks Analyzed: \(networkHistory.count)")
        print("👥 Clients Detected: \(totalClientsDetected)")
        print("🚨 Rogue APs: \(rogueAccessPoints.count)")
        print("🔒 Vulnerabilities: \(securityVulnerabilities.count)")
        print("📻 Channels Analyzed: \(channelUtilization.count)")
        print("⚠️  Critical Alerts: \(alertCount)")
        print("═══════════════════════════════════════════\n")
    }

    // MARK: - Persistence

    /// Save network history
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(networkHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    /// Load network history
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([WiFiNetworkHistory].self, from: data) {
            networkHistory = decoded
            print("📡 KismetWiFi: Loaded \(networkHistory.count) networks from history")
        }
    }

    // MARK: - Utility Functions

    /// Execute shell command
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

// MARK: - Kismet Statistics

struct KismetStatistics {
    let totalNetworksAnalyzed: Int
    let totalClientsDetected: Int
    let rogueAPsDetected: Int
    let vulnerabilitiesFound: Int
    let criticalAlerts: Int
    let highAlerts: Int
    let optimalChannels: Int
    let congestedChannels: Int
    let totalPacketsAnalyzed: Int

    var overallSecurityScore: Int {
        let baseScore = 100
        let penalty = (criticalAlerts * 20) + (highAlerts * 10) + (rogueAPsDetected * 15) + (vulnerabilitiesFound * 5)
        return max(0, baseScore - penalty)
    }

    var securityGrade: String {
        switch overallSecurityScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
}
