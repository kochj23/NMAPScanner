//
//  DeviceIconSystem.swift
//  NMAP Plus Security Scanner v7.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  Comprehensive device icon and recognition system with:
//  - SF Symbols with gradient fills
//  - Manufacturer detection
//  - Signal strength indicators
//  - Device type badges
//

import SwiftUI

// MARK: - Device Icon Manager

class DeviceIconManager {
    static let shared = DeviceIconManager()

    private init() {}

    /// Get SF Symbol name for device
    func iconName(for device: HomeKitDevice) -> String {
        let serviceType = (device.serviceType ?? "").lowercased()
        let name = device.name.lowercased()

        // HomeKit devices
        if serviceType.contains("homekit") || serviceType.contains("hap") {
            if name.contains("light") || name.contains("bulb") {
                return "lightbulb.fill"
            } else if name.contains("lock") {
                return "lock.fill"
            } else if name.contains("thermostat") || name.contains("temperature") {
                return "thermometer"
            } else if name.contains("sensor") {
                return "sensor.fill"
            } else if name.contains("switch") {
                return "light.switch.fill"
            } else if name.contains("camera") {
                return "video.fill"
            } else if name.contains("door") {
                return "door.left.hand.closed"
            } else if name.contains("garage") {
                return "garage"
            } else {
                return "homekit"
            }
        }

        // AirPlay devices
        if serviceType.contains("airplay") {
            if name.contains("tv") {
                return "appletv.fill"
            } else {
                return "airplayvideo"
            }
        }

        // Audio devices
        if serviceType.contains("raop") || serviceType.contains("audio") {
            if name.contains("homepod") {
                return "homepod.fill"
            } else {
                return "speaker.wave.2.fill"
            }
        }

        // Apple devices
        if serviceType.contains("companion") {
            if name.contains("iphone") {
                return "iphone"
            } else if name.contains("ipad") {
                return "ipad"
            } else if name.contains("mac") {
                return "macbook"
            } else if name.contains("watch") {
                return "applewatch"
            } else {
                return "applelogo"
            }
        }

        // Network devices
        if name.contains("router") || name.contains("gateway") {
            return "wifi.router"
        } else if name.contains("bridge") {
            return "network.badge.shield.half.filled"
        }

        // Default
        return "network"
    }

    /// Get device manufacturer from name or service type
    func manufacturer(for device: HomeKitDevice) -> Manufacturer {
        let name = device.name.lowercased()

        if name.contains("apple") || name.contains("homepod") || name.contains("airport") {
            return .apple
        } else if name.contains("philips") || name.contains("hue") {
            return .philips
        } else if name.contains("samsung") {
            return .samsung
        } else if name.contains("lg") {
            return .lg
        } else if name.contains("sony") {
            return .sony
        } else if name.contains("nest") || name.contains("google") {
            return .google
        } else if name.contains("amazon") || name.contains("echo") {
            return .amazon
        } else {
            return .unknown
        }
    }
}

enum Manufacturer: String {
    case apple = "Apple"
    case philips = "Philips"
    case samsung = "Samsung"
    case lg = "LG"
    case sony = "Sony"
    case google = "Google"
    case amazon = "Amazon"
    case unknown = "Unknown"

    var logo: String? {
        switch self {
        case .apple:
            return "applelogo"
        case .google:
            return "g.circle.fill"
        default:
            return nil
        }
    }

    var color: Color {
        switch self {
        case .apple:
            return .gray
        case .philips:
            return .blue
        case .samsung:
            return Color(red: 0.05, green: 0.35, blue: 0.75)
        case .lg:
            return Color(red: 0.65, green: 0.05, blue: 0.15)
        case .sony:
            return .black
        case .google:
            return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .amazon:
            return Color(red: 1.0, green: 0.6, blue: 0.0)
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Device Icon View with Gradient

struct DeviceIconWithGradient: View {
    let device: HomeKitDevice
    let size: CGFloat

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(deviceGradient)
                .frame(width: size, height: size)
                .shadow(color: deviceColor.opacity(0.4), radius: size * 0.2, y: size * 0.08)
                .glow(color: deviceColor, radius: size * 0.15, intensity: 0.3)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)

            // Manufacturer badge (if applicable)
            if let logo = manufacturer.logo {
                Image(systemName: logo)
                    .font(.system(size: size * 0.25))
                    .foregroundColor(.white)
                    .padding(size * 0.08)
                    .background(
                        Circle()
                            .fill(manufacturer.color)
                            .shadow(radius: 2)
                    )
                    .offset(x: size * 0.35, y: size * 0.35)
            }

            // Signal strength indicator
            SignalStrengthIndicator(strength: .excellent)
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.35, y: size * 0.35)
        }
        .scaleEffect(isAnimating ? 1.0 : 0.8)
        .opacity(isAnimating ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }

    private var iconName: String {
        DeviceIconManager.shared.iconName(for: device)
    }

    private var manufacturer: Manufacturer {
        DeviceIconManager.shared.manufacturer(for: device)
    }

    private var deviceType: DeviceType {
        DeviceType.from(serviceType: device.serviceType ?? "")
    }

    private var deviceColor: Color {
        Color.deviceColor(for: deviceType)
    }

    private var deviceGradient: LinearGradient {
        Color.deviceGradient(for: deviceType)
    }
}

// MARK: - Signal Strength Indicator

struct SignalStrengthIndicator: View {
    let strength: SignalStrength

    enum SignalStrength {
        case excellent, good, fair, poor

        var bars: Int {
            switch self {
            case .excellent: return 4
            case .good: return 3
            case .fair: return 2
            case .poor: return 1
            }
        }

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .yellow
            case .poor: return .orange
            }
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < strength.bars ? strength.color : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat((index + 1) * 3))
            }
        }
        .padding(4)
        .background(
            Circle()
                .fill(Color.black.opacity(0.6))
        )
    }
}

// MARK: - Device Type Badge

struct DeviceTypeBadge: View {
    let type: DeviceType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 12))

            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.deviceColor(for: type))
                .shadow(color: Color.deviceColor(for: type).opacity(0.3), radius: 4, y: 2)
        )
    }

    private var iconName: String {
        switch type {
        case .homeKit:
            return "homekit"
        case .airPlay:
            return "airplayvideo"
        case .apple:
            return "applelogo"
        case .iot:
            return "sensor.fill"
        case .network:
            return "network"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var label: String {
        switch type {
        case .homeKit:
            return "HomeKit"
        case .airPlay:
            return "AirPlay"
        case .apple:
            return "Apple"
        case .iot:
            return "IoT"
        case .network:
            return "Network"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Mini Device Card

struct MiniDeviceCard: View {
    let device: HomeKitDevice
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            DeviceIconWithGradient(device: device, size: 44)

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    DeviceTypeBadge(type: DeviceType.from(serviceType: device.serviceType ?? ""))

                    if let ipAddress = device.ipAddress {
                        Text(ipAddress)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .opacity(isHovered ? 1.0 : 0.5)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHovered ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 10 : 5, y: isHovered ? 5 : 3)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Large Device Card

struct LargeDeviceCard: View {
    let device: HomeKitDevice
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 16) {
            // Device icon
            DeviceIconWithGradient(device: device, size: 80)

            // Device name
            Text(device.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Device info
            VStack(spacing: 8) {
                DeviceTypeBadge(type: DeviceType.from(serviceType: device.serviceType ?? ""))

                if let ipAddress = device.ipAddress {
                    Text(ipAddress)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)

                    Text("Online")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .frame(width: 180, height: 220)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isHovered ? LinearGradient(
                                colors: [
                                    Color.deviceColor(for: DeviceType.from(serviceType: device.serviceType ?? "")).opacity(0.6),
                                    Color.deviceColor(for: DeviceType.from(serviceType: device.serviceType ?? "")).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
