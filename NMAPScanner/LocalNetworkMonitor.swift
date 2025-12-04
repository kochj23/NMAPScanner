//
//  LocalNetworkMonitor.swift
//  NMAP Plus Security Scanner - Passive Network Monitoring
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation
import Network

/// Passive network monitoring - no active scanning
/// Just monitors local network configuration and connected devices
@MainActor
class LocalNetworkMonitor: ObservableObject {
    @Published var localIP: String = "Unknown"
    @Published var subnetMask: String = "Unknown"
    @Published var gatewayIP: String = "Unknown"
    @Published var isMonitoring = false

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.nmapscanner.networkmonitor")

    /// Start passive monitoring
    func startMonitoring() {
        print("📡 LocalNetworkMonitor: Starting passive monitoring...")
        isMonitoring = true

        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor?.start(queue: monitorQueue)
    }

    /// Stop monitoring
    func stopMonitoring() {
        print("📡 LocalNetworkMonitor: Stopping monitoring")
        monitor?.cancel()
        monitor = nil
        isMonitoring = false
    }

    /// Handle network path updates
    private func handlePathUpdate(_ path: NWPath) {
        print("📡 LocalNetworkMonitor: Network path updated")
        print("📡 Status: \(path.status)")
        print("📡 Available interfaces: \(path.availableInterfaces.count)")

        for interface in path.availableInterfaces {
            print("📡 Interface: \(interface.name) - \(interface.type)")
        }

        // Try to extract local IP from WiFi interface
        if let wifiInterface = path.availableInterfaces.first(where: { $0.type == .wifi }) {
            print("📡 Found WiFi interface: \(wifiInterface.name)")
            extractNetworkInfo(from: wifiInterface)
        } else if let ethernetInterface = path.availableInterfaces.first(where: { $0.type == .wiredEthernet }) {
            print("📡 Found Ethernet interface: \(ethernetInterface.name)")
            extractNetworkInfo(from: ethernetInterface)
        }

        // Check for gateway
        if path.gateways.count > 0 {
            print("📡 Gateways found: \(path.gateways.count)")
            for gateway in path.gateways {
                if case .hostPort(let host, _) = gateway {
                    gatewayIP = "\(host)"
                    print("📡 Gateway: \(gatewayIP)")
                }
            }
        }
    }

    /// Extract network info from interface
    private func extractNetworkInfo(from interface: NWInterface) {
        // Use system APIs to get IP address
        // Note: tvOS severely restricts network enumeration
        print("📡 Attempting to extract IP from interface: \(interface.name)")

        // We can't directly enumerate IPs on tvOS due to sandboxing
        // The best we can do is detect connectivity
        localIP = "Connected via \(interface.name)"
        subnetMask = "Unknown (tvOS limitation)"

        print("📡 Local info: \(localIP)")
    }

    /// Get basic network summary
    func getNetworkSummary() -> String {
        """
        Local Network Information:
        • Local IP: \(localIP)
        • Subnet Mask: \(subnetMask)
        • Gateway: \(gatewayIP)
        • Status: \(isMonitoring ? "Monitoring" : "Stopped")

        Note: tvOS severely restricts network scanning.
        Active scanning is not reliable on this platform.
        """
    }
}
