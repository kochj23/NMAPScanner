//
//  WiFiNetworkScanner.swift
//  NMAP Plus Security Scanner - WiFi Network Discovery
//
//  Created by Jordan Koch & Claude Code on 2025-12-01.
//
//  Scans for all visible WiFi networks with detailed information.
//  Requires CoreWLAN framework for macOS WiFi scanning.
//

import Foundation
import CoreWLAN
import SwiftUI

// MARK: - WiFi Network Information

/// Detailed information about a discovered WiFi network
struct WiFiNetworkInfo: Identifiable, Hashable {
    let id = UUID()
    let ssid: String
    let bssid: String  // MAC address of access point
    let rssi: Int  // Signal strength in dBm
    let channel: Int
    let channelWidth: String
    let channelBand: String  // 2.4 GHz or 5 GHz
    let securityType: String
    let countryCode: String?
    let beaconInterval: Int
    let noise: Int  // Noise level in dBm
    let supportedRates: [Double]
    let supportedPHYModes: [String]
    let isIBSS: Bool  // Ad-hoc network
    let isPasspoint: Bool
    let isPersonalHotspot: Bool

    /// Signal quality percentage (0-100%)
    var signalQuality: Int {
        // RSSI typically ranges from -30 (excellent) to -90 (poor)
        // Convert to 0-100 scale
        let normalized = max(0, min(100, (rssi + 100) * 2))
        return normalized
    }

    /// Signal strength description
    var signalStrength: String {
        switch rssi {
        case -30...0: return "Excellent"
        case -50..<(-30): return "Very Good"
        case -60..<(-50): return "Good"
        case -70..<(-60): return "Fair"
        case -80..<(-70): return "Weak"
        default: return "Very Weak"
        }
    }

    /// Security level assessment
    var securityLevel: String {
        if securityType.contains("WPA3") {
            return "Excellent"
        } else if securityType.contains("WPA2") {
            return "Good"
        } else if securityType.contains("WPA") {
            return "Fair"
        } else if securityType.contains("WEP") {
            return "Weak"
        } else if securityType.contains("Open") || securityType.contains("None") {
            return "None"
        }
        return "Unknown"
    }

    /// Channel congestion estimate (based on common channels)
    var estimatedCongestion: String {
        if channelBand.contains("2.4") {
            // 2.4 GHz - channels 1, 6, 11 are non-overlapping
            switch channel {
            case 1, 6, 11: return "Low (optimal channel)"
            case 2...5, 7...10: return "High (overlapping channel)"
            default: return "Medium"
            }
        } else if channelBand.contains("5") {
            // 5 GHz has more non-overlapping channels
            return "Low (5 GHz band)"
        }
        return "Unknown"
    }
}

// MARK: - WiFi Network Scanner

@MainActor
class WiFiNetworkScanner: ObservableObject {
    static let shared = WiFiNetworkScanner()

    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var discoveredNetworks: [WiFiNetworkInfo] = []
    @Published var currentNetwork: WiFiNetworkInfo?
    @Published var availableInterfaces: [String] = []

    private var wifiClient: CWWiFiClient?
    private var interface: CWInterface?

    private init() {
        wifiClient = CWWiFiClient.shared()
        if let interfaceName = wifiClient?.interface()?.interfaceName {
            interface = wifiClient?.interface(withName: interfaceName)
            availableInterfaces = wifiClient?.interfaceNames() ?? []
        }
    }

    /// Check if WiFi scanning is available
    func isWiFiAvailable() -> Bool {
        return interface != nil
    }

    /// Get current WiFi interface name
    func getCurrentInterfaceName() -> String? {
        return interface?.interfaceName
    }

    /// Scan for all visible WiFi networks
    func scanNetworks() async throws {
        guard let interface = interface else {
            throw WiFiScanError.noInterface
        }

        isScanning = true
        progress = 0
        status = "Starting WiFi network scan..."
        discoveredNetworks = []

        print("📡 WiFiScanner: Starting scan on interface \(interface.interfaceName ?? "unknown")")

        // Get current network first
        status = "Getting current network info..."
        progress = 0.1
        await getCurrentNetworkInfo()

        // Scan for networks
        status = "Scanning for WiFi networks..."
        progress = 0.3

        var networks: Set<CWNetwork> = []
        do {
            networks = try interface.scanForNetworks(withSSID: nil)
            print("📡 WiFiScanner: Found \(networks.count) networks")
        } catch {
            print("📡 WiFiScanner: Error scanning: \(error)")
            throw WiFiScanError.scanFailed(error.localizedDescription)
        }

        // Process networks with progress
        status = "Processing \(networks.count) networks..."
        progress = 0.5

        var processedNetworks: [WiFiNetworkInfo] = []
        let sortedNetworks = networks.sorted { $0.rssiValue > $1.rssiValue }

        for (index, network) in sortedNetworks.enumerated() {
            let networkInfo = convertToNetworkInfo(network)
            processedNetworks.append(networkInfo)

            progress = 0.5 + (Double(index + 1) / Double(networks.count) * 0.4)
            status = "Processing networks... (\(index + 1)/\(networks.count))"
        }

        discoveredNetworks = processedNetworks

        status = "WiFi scan complete - \(discoveredNetworks.count) networks found"
        progress = 1.0
        isScanning = false

        print("📡 WiFiScanner: Scan complete")
        print("📡 WiFiScanner: 2.4 GHz networks: \(discoveredNetworks.filter { $0.channelBand.contains("2.4") }.count)")
        print("📡 WiFiScanner: 5 GHz networks: \(discoveredNetworks.filter { $0.channelBand.contains("5") }.count)")
    }

    /// Get information about currently connected network
    private func getCurrentNetworkInfo() async {
        guard let interface = interface, let network = interface.ssid() else {
            currentNetwork = nil
            return
        }

        // Try to find current network in available networks
        if let cwNetwork = try? interface.scanForNetworks(withSSID: nil).first(where: { $0.ssid == network }) {
            currentNetwork = convertToNetworkInfo(cwNetwork)
            print("📡 WiFiScanner: Current network - \(network) (\(currentNetwork?.rssi ?? 0) dBm)")
        }
    }

    /// Convert CWNetwork to WiFiNetworkInfo
    private func convertToNetworkInfo(_ network: CWNetwork) -> WiFiNetworkInfo {
        let channelNumber = network.wlanChannel?.channelNumber ?? 0
        let channelBand = network.wlanChannel?.channelBand == .band2GHz ? "2.4 GHz" :
                         network.wlanChannel?.channelBand == .band5GHz ? "5 GHz" : "Unknown"

        let channelWidth: String
        switch network.wlanChannel?.channelWidth {
        case .width20MHz: channelWidth = "20 MHz"
        case .width40MHz: channelWidth = "40 MHz"
        case .width80MHz: channelWidth = "80 MHz"
        case .width160MHz: channelWidth = "160 MHz"
        default: channelWidth = "Unknown"
        }

        let security = getSecurityType(network)

        let phyModes = getPHYModes(network)

        // Get SSID - COMPREHENSIVE extraction with debugging
        let ssid: String
        var extractionMethod = "unknown"

        // DEBUG: Print ALL available properties
        print("📡 WiFiScanner: ======== SSID EXTRACTION DEBUG ========")
        print("📡 WiFiScanner: BSSID: \(network.bssid ?? "nil")")
        print("📡 WiFiScanner: network.ssid type: \(type(of: network.ssid))")
        print("📡 WiFiScanner: network.ssid value: '\(network.ssid ?? "nil")'")
        print("📡 WiFiScanner: network.ssid isEmpty: \(network.ssid?.isEmpty ?? true)")
        print("📡 WiFiScanner: network.ssidData: \(network.ssidData != nil ? "exists" : "nil")")
        if let data = network.ssidData {
            print("📡 WiFiScanner: ssidData count: \(data.count) bytes")
            print("📡 WiFiScanner: ssidData hex: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        // METHOD 1: Direct ssid property (most common)
        if let networkSSID = network.ssid, !networkSSID.isEmpty {
            let trimmed = networkSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                ssid = trimmed
                extractionMethod = "direct ssid property"
                print("📡 WiFiScanner: ✅ METHOD 1 SUCCESS: '\(ssid)'")
            } else {
                ssid = "Hidden Network"
                extractionMethod = "ssid was only whitespace"
                print("📡 WiFiScanner: ⚠️  METHOD 1 FAILED: ssid was only whitespace")
            }
        }
        // METHOD 2: ssidData with UTF-8 encoding
        else if let ssidData = network.ssidData, !ssidData.isEmpty,
                let decoded = String(data: ssidData, encoding: .utf8) {
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                ssid = trimmed
                extractionMethod = "ssidData UTF-8"
                print("📡 WiFiScanner: ✅ METHOD 2 SUCCESS (UTF-8): '\(ssid)'")
            } else {
                ssid = "Hidden Network"
                extractionMethod = "ssidData UTF-8 was empty"
                print("📡 WiFiScanner: ⚠️  METHOD 2 FAILED: UTF-8 decode was empty")
            }
        }
        // METHOD 3: ssidData with ASCII encoding
        else if let ssidData = network.ssidData, !ssidData.isEmpty,
                let decoded = String(data: ssidData, encoding: .ascii) {
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                ssid = trimmed
                extractionMethod = "ssidData ASCII"
                print("📡 WiFiScanner: ✅ METHOD 3 SUCCESS (ASCII): '\(ssid)'")
            } else {
                ssid = "Hidden Network"
                extractionMethod = "ssidData ASCII was empty"
                print("📡 WiFiScanner: ⚠️  METHOD 3 FAILED: ASCII decode was empty")
            }
        }
        // METHOD 4: ssidData with ISO Latin1 encoding
        else if let ssidData = network.ssidData, !ssidData.isEmpty,
                let decoded = String(data: ssidData, encoding: .isoLatin1) {
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                ssid = trimmed
                extractionMethod = "ssidData ISO Latin1"
                print("📡 WiFiScanner: ✅ METHOD 4 SUCCESS (Latin1): '\(ssid)'")
            } else {
                ssid = "Hidden Network"
                extractionMethod = "ssidData Latin1 was empty"
                print("📡 WiFiScanner: ⚠️  METHOD 4 FAILED: Latin1 decode was empty")
            }
        }
        // METHOD 5: Truly hidden network
        else {
            ssid = "Hidden Network (No SSID Broadcast)"
            extractionMethod = "none - truly hidden"
            print("📡 WiFiScanner: ❌ ALL METHODS FAILED - Truly hidden network")
        }

        print("📡 WiFiScanner: FINAL SSID: '\(ssid)' via [\(extractionMethod)]")
        print("📡 WiFiScanner: ========================================")


        return WiFiNetworkInfo(
            ssid: ssid,
            bssid: network.bssid ?? "Unknown",
            rssi: network.rssiValue ?? -100,
            channel: channelNumber,
            channelWidth: channelWidth,
            channelBand: channelBand,
            securityType: security,
            countryCode: network.countryCode,
            beaconInterval: network.beaconInterval,
            noise: network.noiseMeasurement ?? -100,
            supportedRates: [],  // supportedDataRates not available in this API version
            supportedPHYModes: phyModes,
            isIBSS: network.ibss,
            isPasspoint: false,  // CWNetwork doesn't expose this directly
            isPersonalHotspot: network.ssid?.contains("iPhone") ?? false ||
                             network.ssid?.contains("iPad") ?? false
        )
    }

    /// Get security type string from CWNetwork
    private func getSecurityType(_ network: CWNetwork) -> String {
        var types: [String] = []

        if network.supportsSecurity(.wpa3Enterprise) || network.supportsSecurity(.wpa3Personal) {
            types.append("WPA3")
        }
        if network.supportsSecurity(.wpa2Enterprise) || network.supportsSecurity(.wpa2Personal) {
            types.append("WPA2")
        }
        if network.supportsSecurity(.wpaEnterprise) || network.supportsSecurity(.wpaPersonal) {
            types.append("WPA")
        }
        if network.supportsSecurity(.dynamicWEP) {
            types.append("WEP")
        }
        if network.supportsSecurity(.none) {
            types.append("Open")
        }

        return types.isEmpty ? "Unknown" : types.joined(separator: " / ")
    }

    /// Get PHY modes (802.11a/b/g/n/ac/ax)
    private func getPHYModes(_ network: CWNetwork) -> [String] {
        var modes: [String] = []

        if network.supportsPHYMode(.mode11a) {
            modes.append("802.11a")
        }
        if network.supportsPHYMode(.mode11b) {
            modes.append("802.11b")
        }
        if network.supportsPHYMode(.mode11g) {
            modes.append("802.11g")
        }
        if network.supportsPHYMode(.mode11n) {
            modes.append("802.11n")
        }
        if network.supportsPHYMode(.mode11ac) {
            modes.append("802.11ac")
        }
        if network.supportsPHYMode(.mode11ax) {
            modes.append("802.11ax (WiFi 6)")
        }

        return modes
    }

    /// Get network statistics and analysis
    func getNetworkStatistics() -> WiFiNetworkStatistics {
        let total = discoveredNetworks.count
        let networks2_4GHz = discoveredNetworks.filter { $0.channelBand.contains("2.4") }.count
        let networks5GHz = discoveredNetworks.filter { $0.channelBand.contains("5") }.count
        let openNetworks = discoveredNetworks.filter { $0.securityType.contains("Open") }.count
        let secureNetworks = total - openNetworks
        let personalHotspots = discoveredNetworks.filter { $0.isPersonalHotspot }.count

        let avgRSSI = discoveredNetworks.isEmpty ? 0 :
                     discoveredNetworks.reduce(0) { $0 + $1.rssi } / discoveredNetworks.count

        // Channel congestion analysis
        let channelCounts = Dictionary(grouping: discoveredNetworks, by: { $0.channel })
        let mostCongestedChannel = channelCounts.max(by: { $0.value.count < $1.value.count })

        return WiFiNetworkStatistics(
            totalNetworks: total,
            networks2_4GHz: networks2_4GHz,
            networks5GHz: networks5GHz,
            openNetworks: openNetworks,
            secureNetworks: secureNetworks,
            personalHotspots: personalHotspots,
            averageRSSI: avgRSSI,
            mostCongestedChannel: mostCongestedChannel?.key ?? 0,
            mostCongestedChannelCount: mostCongestedChannel?.value.count ?? 0
        )
    }
}

// MARK: - WiFi Network Statistics

struct WiFiNetworkStatistics {
    let totalNetworks: Int
    let networks2_4GHz: Int
    let networks5GHz: Int
    let openNetworks: Int
    let secureNetworks: Int
    let personalHotspots: Int
    let averageRSSI: Int
    let mostCongestedChannel: Int
    let mostCongestedChannelCount: Int
}

// MARK: - WiFi Scan Errors

enum WiFiScanError: LocalizedError {
    case noInterface
    case scanFailed(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noInterface:
            return "No WiFi interface found. Ensure WiFi is enabled."
        case .scanFailed(let message):
            return "WiFi scan failed: \(message)"
        case .permissionDenied:
            return "Permission denied. Grant Location Services access in System Settings."
        }
    }
}
