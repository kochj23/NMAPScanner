//
//  EnhancedDeviceCard.swift
//  NMAPScanner
//
//  Created by Jordan Koch on 2025-11-29.
//  Enhanced device card with animations, health scores, and quick actions
//

import SwiftUI

struct EnhancedDeviceCard: View {
    let device: EnhancedDevice
    @StateObject private var trafficManager = RealtimeTrafficManager.shared
    @State private var isHovered = false
    @State private var showQuickActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Device icon with status indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(deviceColor.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: deviceIcon)
                        .font(.system(size: 28))
                        .foregroundColor(deviceColor)

                    // Animated pulse for online devices
                    if device.isOnline {
                        PulsingIndicator(color: .green, size: 16)
                            .offset(x: 4, y: 4)
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 12, height: 12)
                            .offset(x: 4, y: 4)
                    }
                }

                // Device info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(device.hostname ?? device.ipAddress)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)

                        Spacer()

                        // Health score badge
                        DeviceHealthBadge(grade: healthGrade, score: healthScore)
                    }

                    if device.hostname != nil {
                        Text(device.ipAddress)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if let manufacturer = device.manufacturer {
                        Text(manufacturer)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Last seen
                    LastSeenIndicator(date: device.lastSeen)
                }
            }

            // Sparkline graph (bandwidth history)
            if let history = trafficManager.bandwidthHistory[device.ipAddress],
               !history.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bandwidth History")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    SparklineGraph(
                        dataPoints: history.map { $0.bytesPerSecond },
                        color: .blue,
                        height: 30
                    )
                }
            }

            // Bandwidth meter
            if let stats = trafficManager.deviceStats[device.ipAddress] {
                BandwidthMeter(bytesPerSecond: stats.recentBytesPerSecond)
            }

            // Device stats
            HStack(spacing: 16) {
                DeviceStatBadge(icon: "network", value: "\(device.openPorts.count)", label: "Ports", color: .blue)

                DeviceStatBadge(icon: "exclamationmark.triangle", value: device.threatLevel.rawValue, label: "Risk", color: threatColor)

                if device.isWhitelisted {
                    DeviceStatBadge(icon: "checkmark.shield", value: "Safe", label: "Trusted", color: .green)
                }

                // HomeKit badge
                if let homeKitInfo = device.homeKitMDNSInfo {
                    DeviceStatBadge(
                        icon: homeKitInfo.icon,
                        value: homeKitInfo.isHomeKitAccessory ? "HomeKit" : "Apple",
                        label: homeKitInfo.category,
                        color: .orange
                    )
                }

                Spacer()
            }

            // Quick actions (shown on hover)
            if showQuickActions || isHovered {
                QuickActionButtons(
                    device: device,
                    onWhitelist: { handleWhitelist() },
                    onBlock: { handleBlock() },
                    onDeepScan: { handleDeepScan() },
                    onIsolate: { handleIsolate() }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: isHovered ? .blue.opacity(0.3) : .clear, radius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(device.isOnline ? deviceColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.easeInOut(duration: 0.2)) {
                showQuickActions = hovering
            }
        }
    }

    // MARK: - Computed Properties

    private var deviceColor: Color {
        if device.isRogue { return .red }
        if device.isWhitelisted { return .green }

        switch device.deviceType {
        case .router: return .blue
        case .computer: return .purple
        case .mobile: return .cyan
        case .iot: return .orange
        case .printer: return .pink
        default: return .gray
        }
    }

    private var deviceIcon: String {
        if device.isRogue { return "exclamationmark.triangle.fill" }

        // Use HomeKit-specific icon if available
        if let homeKitInfo = device.homeKitMDNSInfo {
            return homeKitInfo.icon
        }

        switch device.deviceType {
        case .router: return "wifi.router"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "lightbulb.fill"
        case .printer: return "printer"
        case .networkDevice: return "network"
        default: return "questionmark.circle"
        }
    }

    private var threatColor: Color {
        switch device.threatLevel {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }

    private var healthScore: Double {
        var score = 1.0

        // Deduct for open ports
        if device.openPorts.count > 20 {
            score -= 0.2
        } else if device.openPorts.count > 10 {
            score -= 0.1
        }

        // Deduct for threat level
        switch device.threatLevel {
        case .critical: score -= 0.5
        case .high: score -= 0.3
        case .medium: score -= 0.2
        case .low: score -= 0.1
        }

        // Deduct for rogue status
        if device.isRogue {
            score -= 0.4
        }

        // Deduct for insecure ports
        let insecurePorts = device.openPorts.filter { $0.isBackdoorPort || $0.isInsecurePort }
        score -= Double(insecurePorts.count) * 0.05

        // Bonus for whitelisted
        if device.isWhitelisted {
            score += 0.1
        }

        return max(score, 0.0)
    }

    private var healthGrade: String {
        if healthScore >= 0.9 { return "A" }
        if healthScore >= 0.8 { return "B" }
        if healthScore >= 0.7 { return "C" }
        if healthScore >= 0.6 { return "D" }
        return "F"
    }

    // MARK: - IP Validation

    /// Validates that a string is a legitimate IPv4 address to prevent command injection.
    /// IP addresses from network discovery could be spoofed with shell metacharacters.
    private func isValidIPv4Address(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        return parts.count == 4 && parts.allSatisfy { $0 >= 0 && $0 <= 255 }
    }

    // MARK: - Actions

    private func handleWhitelist() {
        print("Whitelisting device: \(device.ipAddress)")

        // Add to whitelist in UserDefaults
        var whitelist = UserDefaults.standard.stringArray(forKey: "DeviceWhitelist") ?? []
        if !whitelist.contains(device.ipAddress) {
            whitelist.append(device.ipAddress)
            UserDefaults.standard.set(whitelist, forKey: "DeviceWhitelist")

            // Also store MAC address if available
            if let mac = device.macAddress, !mac.isEmpty {
                var macWhitelist = UserDefaults.standard.stringArray(forKey: "MACWhitelist") ?? []
                if !macWhitelist.contains(mac) {
                    macWhitelist.append(mac)
                    UserDefaults.standard.set(macWhitelist, forKey: "MACWhitelist")
                }
            }

            print("[DeviceCard] ✅ Device \(device.ipAddress) added to whitelist")
            print("[DeviceCard] Device Whitelisted: \(device.hostname ?? device.ipAddress) is now trusted")
        }
    }

    private func handleBlock() {
        print("Blocking device: \(device.ipAddress)")

        // Add to block list
        var blocklist = UserDefaults.standard.stringArray(forKey: "DeviceBlocklist") ?? []
        if !blocklist.contains(device.ipAddress) {
            blocklist.append(device.ipAddress)
            UserDefaults.standard.set(blocklist, forKey: "DeviceBlocklist")

            print("[DeviceCard] ✅ Device \(device.ipAddress) added to blocklist")

            // Validate IP address before passing to shell command to prevent command injection.
            // The IP comes from network discovery and could be spoofed with shell metacharacters.
            guard isValidIPv4Address(device.ipAddress) else {
                print("[DeviceCard] ⚠️ Invalid IP address format, refusing to execute firewall command: \(device.ipAddress)")
                return
            }

            // Try to add firewall rule (requires admin)
            let script = """
            do shell script "pfctl -t blocklist -T add \(device.ipAddress)" with administrator privileges
            """

            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)

                if let error = error {
                    print("[DeviceCard] ⚠️ Firewall rule failed (needs admin): \(error)")
                } else {
                    print("[DeviceCard] ✅ Firewall rule added for \(device.ipAddress)")
                }
            }
        }
    }

    private func handleDeepScan() {
        print("Starting deep scan on: \(device.ipAddress)")

        // Launch aggressive nmap scan in background
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/nmap")
            process.arguments = [
                "-A",           // Aggressive scan (OS detection, version, scripts, traceroute)
                "-T4",          // Aggressive timing
                "-p-",          // All ports
                "-sV",          // Service version detection
                device.ipAddress
            ]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: outputData, encoding: .utf8) {
                    print("[DeviceCard] Deep scan complete for \(device.ipAddress)")
                    print(output)

                    await MainActor.run {
                    }
                }
            } catch {
                print("[DeviceCard] Deep scan failed: \(error)")
            }
        }

    }

    private func handleIsolate() {
        print("Isolating device: \(device.ipAddress)")

        // Add to isolated devices list
        var isolated = UserDefaults.standard.stringArray(forKey: "IsolatedDevices") ?? []
        if !isolated.contains(device.ipAddress) {
            isolated.append(device.ipAddress)
            UserDefaults.standard.set(isolated, forKey: "IsolatedDevices")

            if let mac = device.macAddress {
                var macIsolated = UserDefaults.standard.stringArray(forKey: "IsolatedMACs") ?? []
                if !macIsolated.contains(mac) {
                    macIsolated.append(mac)
                    UserDefaults.standard.set(macIsolated, forKey: "IsolatedMACs")
                }
            }

            print("[DeviceCard] ✅ Device \(device.ipAddress) marked as isolated")
            print("[DeviceCard] Note: UniFi API integration requires controller configuration")
        }
    }
}

// MARK: - Device Stat Badge Component

struct DeviceStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EnhancedDeviceCard_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedDeviceCard(device: EnhancedDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "HomePod-Kitchen",
            manufacturer: "Apple Inc.",
            deviceType: .iot,
            openPorts: [
                PortInfo(port: 80, service: "HTTP", version: nil, state: .open, protocolType: "TCP", banner: nil),
                PortInfo(port: 443, service: "HTTPS", version: nil, state: .open, protocolType: "TCP", banner: nil)
            ],
            isOnline: true,
            firstSeen: Date().addingTimeInterval(-3600),
            lastSeen: Date().addingTimeInterval(-60),
            isKnownDevice: true,
            operatingSystem: "iOS",
            deviceName: "HomePod Kitchen",
            homeKitMDNSInfo: nil
        ))
        .frame(width: 400)
        .padding()
    }
}
#endif
