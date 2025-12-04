//
//  UniFiDiscoveryScanner.swift
//  NMAP Plus Security Scanner - UniFi UDP Discovery Protocol
//
//  Created by Jordan Koch & Claude Code on 2025-12-01.
//
//  Implements UniFi Discovery Protocol (UDP port 10001) for finding all UniFi devices.
//  This is the most reliable method as ALL UniFi devices respond to discovery broadcasts.
//

import Foundation
import Network
import SwiftUI

// MARK: - UniFi Discovery Device Model

/// Detailed information from UniFi discovery protocol
struct UniFiDiscoveredDevice: Identifiable, Codable {
    let id = UUID()
    let mac: String
    let ipAddress: String
    let hostname: String?
    let model: String?
    let modelDisplay: String?
    let version: String?
    let uptime: Int?
    let adopted: Bool?
    let isDefault: Bool?
    let locating: Bool?
    let state: Int?
    let requiredVersion: String?
    let boardRevision: Int?
    let bootromVersion: String?
    let cfgVersion: String?
    let configNetworkType: String?
    let essid: String?
    let guestToken: String?
    let hideSSID: Bool?
    let informURL: String?
    let lanIP: String?
    let ledEnabled: Bool?
    let netmask: String?
    let platform: String?
    let radioTable: [RadioInfo]?
    let shortname: String?
    let ssid: String?
    let sysid: String?
    let ubootVersion: String?
    let uplinkTable: [UplinkInfo]?
    let vwireTable: [VwireInfo]?
    let wlanconfigTable: [WlanConfigInfo]?

    /// Device type based on model
    var deviceType: UniFiDeviceType {
        guard let model = model else { return .unknown }

        if model.starts(with: "U") && (model.contains("AP") || model.contains("AC") || model.contains("6")) {
            return .accessPoint
        } else if model.starts(with: "USW") || model.contains("Switch") {
            return .switch
        } else if model.starts(with: "UDM") || model.starts(with: "UXG") || model.starts(with: "USG") {
            return .gateway
        } else if model.starts(with: "G") || model.contains("Camera") {
            return .camera
        } else if model.starts(with: "UNVR") || model.contains("NVR") {
            return .nvr
        }

        return .unknown
    }

    /// Friendly display name
    var displayName: String {
        if let hostname = hostname, !hostname.isEmpty {
            return hostname
        } else if let modelDisplay = modelDisplay {
            return modelDisplay
        } else if let model = model {
            return model
        } else {
            return mac
        }
    }

    enum CodingKeys: String, CodingKey {
        case mac
        case ipAddress = "ip_address"
        case hostname
        case model
        case modelDisplay = "model_display"
        case version
        case uptime
        case adopted
        case isDefault = "default"
        case locating
        case state
        case requiredVersion = "required_version"
        case boardRevision = "board_rev"
        case bootromVersion = "bootrom_version"
        case cfgVersion = "cfgversion"
        case configNetworkType = "config_network_type"
        case essid
        case guestToken = "guest_token"
        case hideSSID = "hide_ssid"
        case informURL = "inform_url"
        case lanIP = "lan_ip"
        case ledEnabled = "led_enabled"
        case netmask
        case platform
        case radioTable = "radio_table"
        case shortname
        case ssid
        case sysid
        case ubootVersion = "uboot_version"
        case uplinkTable = "uplink_table"
        case vwireTable = "vwire_table"
        case wlanconfigTable = "wlanconfig_table"
    }
}

struct RadioInfo: Codable {
    let name: String?
    let radio: String?
    let channel: Int?
    let txPower: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case radio
        case channel
        case txPower = "tx_power"
    }
}

struct UplinkInfo: Codable {
    let name: String?
    let speed: Int?
    let fullDuplex: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case speed
        case fullDuplex = "full_duplex"
    }
}

struct VwireInfo: Codable {
    let name: String?
}

struct WlanConfigInfo: Codable {
    let name: String?
    let ssid: String?
    let channel: Int?
}

enum UniFiDeviceType: String, Codable {
    case accessPoint = "Access Point"
    case `switch` = "Switch"
    case gateway = "Gateway"
    case camera = "Camera"
    case nvr = "NVR"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .accessPoint: return "wifi.router"
        case .switch: return "network"
        case .gateway: return "server.rack"
        case .camera: return "video"
        case .nvr: return "externaldrive.connected.to.line.below"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .accessPoint: return "blue"
        case .switch: return "green"
        case .gateway: return "purple"
        case .camera: return "orange"
        case .nvr: return "red"
        case .unknown: return "gray"
        }
    }
}

// MARK: - UniFi Discovery Scanner

/// Scanner for UniFi devices using UDP discovery protocol (port 10001)
@MainActor
class UniFiDiscoveryScanner: ObservableObject {
    static let shared = UniFiDiscoveryScanner()

    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var discoveredDevices: [UniFiDiscoveredDevice] = []

    private var connection: NWConnection?
    private let discoveryPort: UInt16 = 10001
    private let scanDuration: TimeInterval = 5.0  // Listen for 5 seconds

    private init() {}

    /// Start UniFi device discovery scan
    func startScan() async {
        print("🔍 UniFiDiscoveryScanner: Starting UDP discovery on port \(discoveryPort)")

        isScanning = true
        progress = 0
        status = "Starting UniFi device discovery..."
        discoveredDevices = []

        // Create discovery packet
        let discoveryCommand = ["cmd": "discovery"]
        guard let discoveryData = try? JSONSerialization.data(withJSONObject: discoveryCommand) else {
            print("❌ UniFiDiscoveryScanner: Failed to create discovery packet")
            status = "Failed to create discovery packet"
            isScanning = false
            return
        }

        // Create UDP connection for broadcast
        let endpoint = NWEndpoint.hostPort(host: .ipv4(.broadcast), port: NWEndpoint.Port(integerLiteral: discoveryPort))
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        connection = NWConnection(to: endpoint, using: parameters)

        // Set up receive handler
        setupReceiveHandler()

        // Start connection
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    print("🔍 UniFiDiscoveryScanner: Connection ready, sending broadcast")
                    self.status = "Broadcasting discovery packet..."
                    self.progress = 0.2

                    // Send discovery packet
                    self.connection?.send(content: discoveryData, completion: .contentProcessed { error in
                        if let error = error {
                            print("❌ UniFiDiscoveryScanner: Send failed - \(error)")
                        } else {
                            print("✅ UniFiDiscoveryScanner: Discovery packet sent")
                        }
                    })

                    // Start listening for responses
                    Task {
                        await self.listenForResponses()
                    }

                case .failed(let error):
                    print("❌ UniFiDiscoveryScanner: Connection failed - \(error)")
                    self.status = "Discovery failed: \(error.localizedDescription)"
                    self.isScanning = false

                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
    }

    /// Set up continuous receive handler
    private func setupReceiveHandler() {
        receiveNextMessage()
    }

    /// Receive next UDP message
    private func receiveNextMessage() {
        connection?.receiveMessage { [weak self] data, context, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let data = data, !data.isEmpty {
                    self.processResponse(data: data)
                }

                // Continue receiving if still scanning
                if self.isScanning {
                    self.receiveNextMessage()
                }
            }
        }
    }

    /// Listen for responses for specified duration
    private func listenForResponses() async {
        status = "Listening for UniFi devices..."
        progress = 0.3

        // Listen for scanDuration seconds with progress updates
        let steps = 10
        let stepDuration = scanDuration / Double(steps)

        for i in 1...steps {
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))

            let currentProgress = 0.3 + (Double(i) / Double(steps) * 0.6)  // 30-90%
            progress = currentProgress

            let deviceCount = discoveredDevices.count
            let remaining = steps - i
            status = "Listening for devices... (\(deviceCount) found, \(remaining)s remaining)"
        }

        // Stop scanning
        status = "Finalizing discovery..."
        progress = 0.95
        connection?.cancel()
        connection = nil

        let deviceCount = discoveredDevices.count
        status = "Discovery complete - \(deviceCount) UniFi device\(deviceCount == 1 ? "" : "s") found"
        progress = 1.0
        isScanning = false

        print("✅ UniFiDiscoveryScanner: Scan complete - found \(deviceCount) devices")
        printDeviceSummary()
    }

    /// Process discovery response
    private func processResponse(data: Data) {
        do {
            // Parse JSON response
            let decoder = JSONDecoder()
            let device = try decoder.decode(UniFiDiscoveredDevice.self, from: data)

            // Check if device already discovered (by MAC)
            if !discoveredDevices.contains(where: { $0.mac == device.mac }) {
                discoveredDevices.append(device)

                print("🔍 UniFiDiscoveryScanner: Found device - \(device.displayName) (\(device.deviceType.rawValue)) at \(device.ipAddress)")
            }

        } catch {
            print("⚠️ UniFiDiscoveryScanner: Failed to parse response - \(error)")

            // Try to decode as raw JSON for debugging
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("📦 UniFiDiscoveryScanner: Raw response: \(json)")
            }
        }
    }

    /// Print device discovery summary
    private func printDeviceSummary() {
        guard !discoveredDevices.isEmpty else { return }

        print("\n📊 UniFi Device Discovery Summary:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Count by type
        let typeGroups = Dictionary(grouping: discoveredDevices, by: { $0.deviceType })

        for (type, devices) in typeGroups.sorted(by: { $0.value.count > $1.value.count }) {
            print("\(type.rawValue)s: \(devices.count)")
            for device in devices {
                print("  - \(device.displayName) [\(device.ipAddress)] - v\(device.version ?? "unknown")")
            }
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// Stop scanning
    func stopScan() {
        guard isScanning else { return }

        print("🛑 UniFiDiscoveryScanner: Stopping scan")
        connection?.cancel()
        connection = nil
        isScanning = false
        status = "Scan stopped"
    }

    /// Get devices by type
    func getDevices(ofType type: UniFiDeviceType) -> [UniFiDiscoveredDevice] {
        return discoveredDevices.filter { $0.deviceType == type }
    }

    /// Get device statistics
    func getStatistics() -> UniFiDiscoveryStatistics {
        let accessPoints = discoveredDevices.filter { $0.deviceType == .accessPoint }.count
        let switches = discoveredDevices.filter { $0.deviceType == .switch }.count
        let gateways = discoveredDevices.filter { $0.deviceType == .gateway }.count
        let cameras = discoveredDevices.filter { $0.deviceType == .camera }.count
        let nvrs = discoveredDevices.filter { $0.deviceType == .nvr }.count
        let unknown = discoveredDevices.filter { $0.deviceType == .unknown }.count

        let adopted = discoveredDevices.filter { $0.adopted == true }.count
        let unadopted = discoveredDevices.filter { $0.adopted == false }.count

        return UniFiDiscoveryStatistics(
            totalDevices: discoveredDevices.count,
            accessPoints: accessPoints,
            switches: switches,
            gateways: gateways,
            cameras: cameras,
            nvrs: nvrs,
            unknown: unknown,
            adopted: adopted,
            unadopted: unadopted
        )
    }
}

// MARK: - Statistics

struct UniFiDiscoveryStatistics {
    let totalDevices: Int
    let accessPoints: Int
    let switches: Int
    let gateways: Int
    let cameras: Int
    let nvrs: Int
    let unknown: Int
    let adopted: Int
    let unadopted: Int
}
