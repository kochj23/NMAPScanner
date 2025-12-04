//
//  ManufacturerIconManager.swift
//  NMAP Plus Security Scanner - Manufacturer Icon Management
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI
import AppKit

/// Manager for manufacturer icons and logos
class ManufacturerIconManager {
    static let shared = ManufacturerIconManager()

    private init() {}

    /// Get SF Symbol icon for manufacturer
    func getIcon(for manufacturer: String?) -> String? {
        guard let mfr = manufacturer?.lowercased() else { return nil }

        let iconMap: [String: String] = [
            // Apple
            "apple": "applelogo",

            // Computer manufacturers
            "microsoft": "laptopcomputer",
            "dell": "desktopcomputer",
            "hp": "printer.fill",
            "lenovo": "laptopcomputer",
            "asus": "laptopcomputer",
            "acer": "laptopcomputer",
            "samsung": "display",

            // Network equipment
            "cisco": "network",
            "netgear": "wifi.router",
            "linksys": "wifi.router",
            "tp-link": "wifi.router",
            "d-link": "wifi.router",
            "ubiquiti": "antenna.radiowaves.left.and.right",
            "arris": "cable.connector",
            "motorola": "cable.connector",

            // IoT & Smart Home
            "philips lighting": "lightbulb.fill",
            "philips hue": "lightbulb.fill",
            "hue": "lightbulb.fill",
            "lifx": "lightbulb.fill",
            "sengled": "lightbulb.fill",
            "ge lighting": "lightbulb.fill",
            "ikea tradfri": "lightbulb.fill",

            // Smart speakers
            "sonos": "hifispeaker.fill",
            "google": "homepod.fill",
            "amazon": "homepod.fill",

            // IoT platforms
            "espressif": "cpu",
            "raspberry pi": "cpu",
            "azurewave": "antenna.radiowaves.left.and.right",
            "texas instruments": "cpu",

            // Smart switches & plugs
            "belkin wemo": "powerplug.fill",
            "wemo": "powerplug.fill",
            "tp-link kasa": "powerplug.fill",
            "kasa": "powerplug.fill",
            "shelly": "powerplug.fill",
            "lutron": "poweroutlet.type.a.fill",

            // Cameras
            "wyze": "video.fill",
            "ring": "video.doorbell.fill",

            // Thermostats
            "ecobee": "thermometer",
            "nest": "thermometer",

            // Gaming & Entertainment
            "sony": "gamecontroller.fill",
            "nintendo": "gamecontroller.fill",
            "roku": "appletv.fill",

            // Virtualization
            "vmware": "square.stack.3d.up.fill",
            "virtualbox": "square.stack.3d.up.fill",
            "qemu": "square.stack.3d.up.fill",

            // Printers
            "brother": "printer.fill",
            "canon": "printer.fill",
            "epson": "printer.fill"
        ]

        // Check for exact match
        if let icon = iconMap[mfr] {
            return icon
        }

        // Check for partial match
        for (key, icon) in iconMap {
            if mfr.contains(key) {
                return icon
            }
        }

        return nil
    }

    /// Get color for manufacturer
    func getColor(for manufacturer: String?) -> Color? {
        guard let mfr = manufacturer?.lowercased() else { return nil }

        let colorMap: [String: Color] = [
            // Apple
            "apple": .primary,

            // Network equipment
            "cisco": .blue,
            "ubiquiti": .blue,
            "netgear": .teal,
            "linksys": .blue,
            "tp-link": .green,

            // IoT & Smart Home
            "philips": .purple,
            "hue": .purple,
            "lifx": .purple,
            "google": .red,
            "amazon": .orange,
            "sonos": .black,

            // Smart switches
            "belkin": .green,
            "wemo": .green,
            "kasa": .green,
            "shelly": .cyan,

            // Cameras
            "wyze": .blue,
            "ring": .blue,

            // Thermostats
            "ecobee": .green,
            "nest": .orange,

            // Gaming
            "sony": .blue,
            "nintendo": .red,

            // IoT platforms
            "espressif": .orange,
            "raspberry pi": .pink
        ]

        // Check for exact match
        if let color = colorMap[mfr] {
            return color
        }

        // Check for partial match
        for (key, color) in colorMap {
            if mfr.contains(key) {
                return color
            }
        }

        return nil
    }

    /// Get emoji/logo for manufacturer (for UI display)
    func getEmoji(for manufacturer: String?) -> String? {
        guard let mfr = manufacturer?.lowercased() else { return nil }

        let emojiMap: [String: String] = [
            // Apple
            "apple": "🍎",

            // Computer manufacturers
            "microsoft": "🪟",
            "dell": "💻",
            "hp": "🖨️",
            "samsung": "📱",
            "lenovo": "💻",
            "intel": "⚡️",

            // Network equipment
            "cisco": "🌐",
            "netgear": "📡",
            "linksys": "📶",
            "tp-link": "🔗",
            "d-link": "🔌",
            "ubiquiti": "🛜",
            "broadcom": "📟",

            // Virtualization
            "vmware": "☁️",
            "virtualbox": "📦",
            "qemu": "🖥️",

            // IoT & Smart Home
            "philips": "💡",
            "hue": "💡",
            "lifx": "💡",
            "google": "🔊",
            "amazon": "🔊",
            "sonos": "🔊",
            "wyze": "📹",
            "ring": "🔔",
            "ecobee": "🌡️",
            "nest": "🏠",

            // IoT platforms
            "raspberry pi": "🥧",
            "espressif": "🔧",
            "azurewave": "📡",

            // Gaming
            "sony": "🎮",
            "nintendo": "🎮",
            "roku": "📺"
        ]

        // Check for exact match
        if let emoji = emojiMap[mfr] {
            return emoji
        }

        // Check for partial match
        for (key, emoji) in emojiMap {
            if mfr.contains(key) {
                return emoji
            }
        }

        return nil
    }

    /// Get device type icon based on manufacturer and device type
    func getDeviceTypeIcon(for deviceType: EnhancedDevice.DeviceType, manufacturer: String?) -> String {
        // First try manufacturer-specific icon
        if let manufacturerIcon = getIcon(for: manufacturer) {
            return manufacturerIcon
        }

        // Fall back to device type icon
        switch deviceType {
        case .router:
            return "wifi.router"
        case .server:
            return "server.rack"
        case .computer:
            return "desktopcomputer"
        case .mobile:
            return "iphone"
        case .iot:
            return "sensor.fill"
        case .printer:
            return "printer.fill"
            return "homekit"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Get icon view for device card
    func getIconView(for device: EnhancedDevice) -> some View {
        let icon = getDeviceTypeIcon(for: device.deviceType, manufacturer: device.manufacturer)
        let color = getColor(for: device.manufacturer) ?? deviceTypeColor(for: device.deviceType)

        return Image(systemName: icon)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(color)
    }

    /// Get device type color
    private func deviceTypeColor(for deviceType: EnhancedDevice.DeviceType) -> Color {
        switch deviceType {
        case .router: return .blue
        case .server: return .purple
        case .computer: return .orange
        case .mobile: return .green
        case .iot: return .cyan
        case .printer: return .pink
        case .unknown: return .gray
        }
    }
}
