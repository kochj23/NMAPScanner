//
//  HomeKitPortDefinitions.swift
//  NMAP Scanner - HomeKit and Apple Device Port Definitions
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation

/// Comprehensive port definitions for HomeKit and Apple devices
struct HomeKitPortDefinitions {

    /// Enhanced port service mapping including HomeKit and Apple-specific ports
    static let serviceMapping: [Int: PortServiceInfo] = [
        // HomeKit Ports
        5000: PortServiceInfo(
            service: "AirPlay Audio",
            description: "Apple HomeKit AirPlay Audio Stream (HomePod, Apple TV)",
            category: .homeKit,
            deviceTypes: [.homePod, .appleTV]
        ),
        7000: PortServiceInfo(
            service: "AirPlay Control",
            description: "Apple HomeKit AirPlay Control Channel (HomePod, Apple TV)",
            category: .homeKit,
            deviceTypes: [.homePod, .appleTV]
        ),
        3689: PortServiceInfo(
            service: "DAAP",
            description: "Digital Audio Access Protocol (iTunes/Music sharing)",
            category: .homeKit,
            deviceTypes: [.appleTV, .homePod, .mac]
        ),
        49152: PortServiceInfo(
            service: "HomeKit HAP",
            description: "HomeKit Accessory Protocol",
            category: .homeKit,
            deviceTypes: [.homePod, .appleTV, .homeKitAccessory]
        ),

        // Apple TV Specific Ports
        62078: PortServiceInfo(
            service: "Apple TV Remote",
            description: "Apple TV Remote Protocol",
            category: .homeKit,
            deviceTypes: [.appleTV]
        ),

        // HomePod Specific Ports
        5353: PortServiceInfo(
            service: "mDNS/Bonjour",
            description: "Multicast DNS (used by all Apple devices for discovery)",
            category: .discovery,
            deviceTypes: [.homePod, .appleTV, .mac, .iPhone, .iPad]
        ),

        // Common HomeKit Accessory Ports
        8080: PortServiceInfo(
            service: "HomeKit Bridge",
            description: "HomeKit Bridge Service (Hue, etc.)",
            category: .homeKit,
            deviceTypes: [.homeKitAccessory]
        ),
        80: PortServiceInfo(
            service: "HTTP",
            description: "Web interface for HomeKit accessories",
            category: .web,
            deviceTypes: [.homeKitAccessory, .iot]
        ),
        443: PortServiceInfo(
            service: "HTTPS",
            description: "Secure web interface",
            category: .web,
            deviceTypes: [.homeKitAccessory, .iot]
        ),

        // Additional Apple Services
        548: PortServiceInfo(
            service: "AFP",
            description: "Apple Filing Protocol (Time Machine, file sharing)",
            category: .fileSharing,
            deviceTypes: [.mac, .nas]
        ),
        631: PortServiceInfo(
            service: "IPP",
            description: "Internet Printing Protocol (AirPrint)",
            category: .printing,
            deviceTypes: [.printer]
        ),
        5009: PortServiceInfo(
            service: "AirPort Admin",
            description: "AirPort Base Station Management",
            category: .network,
            deviceTypes: [.router]
        ),


        // iCloud and Continuity
        5223: PortServiceInfo(
            service: "iCloud Push",
            description: "Apple Push Notification Service (APNs)",
            category: .apple,
            deviceTypes: [.iPhone, .iPad, .mac, .appleTV, .homePod]
        ),

        // Screen Sharing and Remote Management
        5900: PortServiceInfo(
            service: "VNC/Screen Sharing",
            description: "Apple Remote Desktop/Screen Sharing",
            category: .remote,
            deviceTypes: [.mac]
        ),
        3283: PortServiceInfo(
            service: "Apple Remote Desktop",
            description: "ARD Management",
            category: .remote,
            deviceTypes: [.mac]
        ),

        // Standard Network Services (enhanced for Apple devices)
        22: PortServiceInfo(
            service: "SSH",
            description: "Secure Shell (enabled on some Apple devices)",
            category: .remote,
            deviceTypes: [.mac, .linux]
        ),
        445: PortServiceInfo(
            service: "SMB",
            description: "Server Message Block (macOS file sharing)",
            category: .fileSharing,
            deviceTypes: [.mac, .nas, .windows]
        ),
        139: PortServiceInfo(
            service: "NetBIOS",
            description: "Network Basic Input/Output System",
            category: .fileSharing,
            deviceTypes: [.windows, .nas]
        ),

        // Smart Home Integration
        1883: PortServiceInfo(
            service: "MQTT",
            description: "Message Queue Telemetry Transport (IoT)",
            category: .iot,
            deviceTypes: [.iot, .homeKitAccessory]
        ),
        8883: PortServiceInfo(
            service: "MQTT/TLS",
            description: "Secure MQTT",
            category: .iot,
            deviceTypes: [.iot, .homeKitAccessory]
        ),


        // Common IoT Devices
        1900: PortServiceInfo(
            service: "UPnP",
            description: "Universal Plug and Play",
            category: .discovery,
            deviceTypes: [.iot, .router, .printer]
        ),

        // DHCP
        67: PortServiceInfo(
            service: "DHCP Server",
            description: "Dynamic Host Configuration Protocol",
            category: .network,
            deviceTypes: [.router]
        ),
        68: PortServiceInfo(
            service: "DHCP Client",
            description: "DHCP Client Port",
            category: .network,
            deviceTypes: [.router]
        ),

        // DNS
        53: PortServiceInfo(
            service: "DNS",
            description: "Domain Name System",
            category: .network,
            deviceTypes: [.router, .server]
        )
    ]

    /// Get service info for a port
    static func getServiceInfo(for port: Int) -> PortServiceInfo? {
        return serviceMapping[port]
    }

    /// Detect if a device is likely a HomePod based on open ports
    static func isLikelyHomePod(ports: [Int]) -> Bool {
        let homePodPorts: Set<Int> = [5000, 7000, 3689, 5353, 49152]
        let openPortsSet = Set(ports)
        let matchingPorts = homePodPorts.intersection(openPortsSet)

        // If has ports 5000 and 7000, very likely HomePod
        if openPortsSet.contains(5000) && openPortsSet.contains(7000) {
            return true
        }

        // If has 3 or more HomeKit ports, likely HomePod
        return matchingPorts.count >= 3
    }

    /// Detect if a device is likely an Apple TV based on open ports
    static func isLikelyAppleTV(ports: [Int]) -> Bool {
        let appleTVPorts: Set<Int> = [3689, 7000, 62078, 5353, 49152]
        let openPortsSet = Set(ports)
        let matchingPorts = appleTVPorts.intersection(openPortsSet)

        // If has Apple TV Remote port, definitely Apple TV
        if openPortsSet.contains(62078) {
            return true
        }

        // If has AirPlay (7000) and DAAP (3689), likely Apple TV
        if openPortsSet.contains(7000) && openPortsSet.contains(3689) {
            return true
        }

        return matchingPorts.count >= 3
    }

    /// Detect if a device is likely a HomeKit accessory
    static func isLikelyHomeKitAccessory(ports: [Int]) -> Bool {
        let homeKitPorts: Set<Int> = [49152, 80, 443, 8080]
        let openPortsSet = Set(ports)

        // If has HomeKit HAP port
        if openPortsSet.contains(49152) {
            return true
        }

        return false
    }
}

// MARK: - Data Models

/// Port service information
struct PortServiceInfo {
    let service: String
    let description: String
    let category: ServiceCategory
    let deviceTypes: [DeviceType]

    enum ServiceCategory: String {
        case homeKit = "HomeKit"
        case media = "Media"
        case discovery = "Discovery"
        case fileSharing = "File Sharing"
        case printing = "Printing"
        case network = "Network"
        case apple = "Apple Service"
        case remote = "Remote Access"
        case iot = "IoT"
        case web = "Web"
    }

    enum DeviceType: String {
        case homePod = "HomePod"
        case appleTV = "Apple TV"
        case homeKitAccessory = "HomeKit Accessory"
        case mac = "Mac"
        case iPhone = "iPhone"
        case iPad = "iPad"
        case router = "Router"
        case nas = "NAS"
        case printer = "Printer"
        case iot = "IoT Device"
        case linux = "Linux"
        case windows = "Windows"
        case server = "Server"
    }
}
