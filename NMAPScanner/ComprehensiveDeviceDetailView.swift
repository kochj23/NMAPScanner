//
//  ComprehensiveDeviceDetailView.swift
//  NMAP Scanner - Complete Device Information View
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI

struct ComprehensiveDeviceDetailView: View {
    let device: EnhancedDevice
    @StateObject private var vulnerabilityScanner = VulnerabilityScanner()
    @StateObject private var trafficAnalyzer = NetworkTrafficAnalyzer.shared
    @StateObject private var dnsResolver = DNSResolver.shared
    @Environment(\.dismiss) private var dismiss
    @State private var resolvedDNS: String?
    @State private var serviceDetails: [Int: String] = [:]

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(device.hostname ?? device.ipAddress)
                            .font(.system(size: 40, weight: .bold))

                        if device.hostname != nil {
                            Text(device.ipAddress)
                                .font(.system(size: 24, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            // Online status
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(device.isOnline ? Color.green : Color.gray)
                                    .frame(width: 12, height: 12)
                                Text(device.isOnline ? "Online" : "Offline")
                                    .font(.system(size: 18))
                            }

                            if device.isKnownDevice {
                                Label("Known Device", systemImage: "checkmark.shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)

                Divider()

                // Basic Information
                DetailSection(title: "Basic Information", icon: "info.circle.fill", color: .blue) {
                    VStack(spacing: 16) {
                        DetailRow(label: "IP Address", value: device.ipAddress, icon: "network")

                        if let mac = device.macAddress {
                            DetailRow(label: "MAC Address", value: mac, icon: "cpu")
                        }

                        if let hostname = device.hostname {
                            DetailRow(label: "Hostname", value: hostname, icon: "server.rack")
                        } else if let resolved = resolvedDNS {
                            DetailRow(label: "Hostname (DNS)", value: resolved, icon: "server.rack")
                        }

                        if let manufacturer = device.manufacturer {
                            DetailRow(label: "Manufacturer", value: manufacturer, icon: "building.2")
                        }

                        DetailRow(label: "Device Type", value: device.deviceType.rawValue.capitalized, icon: "desktopcomputer")

                        if let appleType = device.detectAppleDeviceType() {
                            DetailRow(label: "Detected As", value: appleType, icon: "applelogo")
                        }

                        if let os = device.operatingSystem {
                            DetailRow(label: "Operating System", value: os, icon: "square.stack.3d.up")
                        }

                        // SSH Detection
                        if device.openPorts.contains(where: { $0.port == 22 }) {
                            HStack(spacing: 8) {
                                Image(systemName: "terminal.fill")
                                    .foregroundColor(.green)
                                Text("SSH Available")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }

                        // Web Interface Detection
                        if device.openPorts.contains(where: { $0.port == 80 || $0.port == 443 }) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                Text("Web Interface Available")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                if device.openPorts.contains(where: { $0.port == 443 }) {
                                    Text("(HTTPS)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Network Traffic
                if let trafficStats = trafficAnalyzer.getStats(for: device.ipAddress) {
                    DetailSection(title: "Network Traffic", icon: "chart.line.uptrend.xyaxis", color: .green) {
                        VStack(spacing: 16) {
                            DetailRow(
                                label: "Bandwidth",
                                value: NetworkTrafficAnalyzer.formatBandwidth(trafficStats.bytesPerSecond),
                                icon: "arrow.up.arrow.down"
                            )

                            DetailRow(
                                label: "Total Data Transferred",
                                value: NetworkTrafficAnalyzer.formatBytes(trafficStats.totalBytes),
                                icon: "internaldrive"
                            )

                            DetailRow(
                                label: "Active Connections",
                                value: "\(trafficStats.activeConnections)",
                                icon: "link"
                            )

                            DetailRow(
                                label: "Last Update",
                                value: formatDate(trafficStats.lastUpdate),
                                icon: "clock"
                            )
                        }
                    }
                }

                // Network Capabilities
                DetailSection(title: "Network Capabilities", icon: "network.badge.shield.half.filled", color: .indigo) {
                    VStack(spacing: 16) {
                        // Protocols supported
                        if !device.openPorts.isEmpty {
                            DetailRow(
                                label: "Open Ports",
                                value: "\(device.openPorts.count) detected",
                                icon: "door.left.hand.open"
                            )
                        }

                        // Service categories
                        let hasWebServices = device.openPorts.contains(where: { $0.port == 80 || $0.port == 443 || $0.port == 8080 })
                        let hasRemoteAccess = device.openPorts.contains(where: { $0.port == 22 || $0.port == 23 || $0.port == 3389 })
                        let hasFileSharing = device.openPorts.contains(where: { $0.port == 445 || $0.port == 139 || $0.port == 548 || $0.port == 2049 })
                        let hasDatabaseServices = device.openPorts.contains(where: { $0.port == 3306 || $0.port == 5432 || $0.port == 27017 || $0.port == 6379 })
                        let hasMediaServices = device.openPorts.contains(where: { $0.port == 5000 || $0.port == 7000 || $0.port == 32400 })

                        if hasWebServices {
                            DetailRow(label: "Web Services", value: "Available", icon: "globe")
                        }
                        if hasRemoteAccess {
                            DetailRow(label: "Remote Access", value: "Enabled", icon: "terminal")
                        }
                        if hasFileSharing {
                            DetailRow(label: "File Sharing", value: "Active", icon: "folder.badge.gearshape")
                        }
                        if hasDatabaseServices {
                            DetailRow(label: "Database Services", value: "Running", icon: "cylinder.split.1x2")
                        }
                        if hasMediaServices {
                            DetailRow(label: "Media Services", value: "Available", icon: "play.rectangle.fill")
                        }
                    }
                }

                // Open Ports
                if !device.openPorts.isEmpty {
                    DetailSection(title: "Open Ports (\(device.openPorts.count))", icon: "door.left.hand.open", color: .orange) {
                        VStack(spacing: 12) {
                            ForEach(device.openPorts.sorted(by: { $0.port < $1.port })) { portInfo in
                                EnhancedPortDetailRow(portInfo: portInfo, device: device)
                            }
                        }
                    }
                }

                // HomeKit Information (check for HomeKit-related ports)
                if HomeKitPortDefinitions.isLikelyHomeKitAccessory(ports: device.openPorts.map { $0.port }) {
                    DetailSection(title: "HomeKit Features", icon: "homekit", color: .purple) {
                        VStack(spacing: 16) {
                            DetailRow(
                                label: "Features",
                                value: "HomeKit Accessory Detected",
                                icon: "house.fill"
                            )

                            if HomeKitPortDefinitions.isLikelyHomePod(ports: device.openPorts.map { $0.port }) {
                                DetailRow(
                                    label: "Device Type",
                                    value: "HomePod / HomePod mini",
                                    icon: "hifispeaker.fill"
                                )
                            }

                            if HomeKitPortDefinitions.isLikelyAppleTV(ports: device.openPorts.map { $0.port }) {
                                DetailRow(
                                    label: "Device Type",
                                    value: "Apple TV",
                                    icon: "appletv.fill"
                                )
                            }
                        }
                    }
                }

                // Port Vulnerabilities
                let vulnerabilities = vulnerabilityScanner.vulnerabilities.filter { $0.host == device.ipAddress }
                if !vulnerabilities.isEmpty {
                    DetailSection(title: "Port Vulnerabilities (\(vulnerabilities.count))", icon: "exclamationmark.shield.fill", color: .red) {
                        VStack(spacing: 16) {
                            ForEach(vulnerabilities.sorted(by: { $0.severity > $1.severity })) { vuln in
                                PortVulnerabilityDetailRow(vulnerability: vuln)
                            }
                        }
                    }
                }

                // Device History
                DetailSection(title: "Device History", icon: "clock.arrow.circlepath", color: .cyan) {
                    VStack(spacing: 16) {
                        DetailRow(
                            label: "First Seen",
                            value: formatFullDate(device.firstSeen),
                            icon: "calendar.badge.plus"
                        )

                        DetailRow(
                            label: "Last Seen",
                            value: formatFullDate(device.lastSeen),
                            icon: "calendar.badge.clock"
                        )

                        let uptime = device.lastSeen.timeIntervalSince(device.firstSeen)
                        let days = Int(uptime / 86400)
                        DetailRow(
                            label: "Tracked For",
                            value: days > 0 ? "\(days) days" : "< 1 day",
                            icon: "chart.line.uptrend.xyaxis.circle"
                        )
                    }
                }

                Spacer(minLength: 32)
            }
        }
        .frame(width: 900, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            // Resolve DNS if not already resolved
            if device.hostname == nil {
                resolvedDNS = await dnsResolver.resolveIP(device.ipAddress)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Section

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 28, weight: .semibold))
            }
            .padding(.horizontal, 32)

            content
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 16)
        .background(color.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 32)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 200, alignment: .leading)

            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Port Detail Row

struct PortDetailRow: View {
    let portInfo: PortInfo

    var body: some View {
        HStack(spacing: 16) {
            // Port number
            Text("\(portInfo.port)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                // Service name
                Text(portInfo.service)
                    .font(.system(size: 18, weight: .medium))

                // Additional info
                if let homeKitService = HomeKitPortDefinitions.getServiceInfo(for: portInfo.port) {
                    HStack(spacing: 8) {
                        Image(systemName: "homekit")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)

                        Text(homeKitService.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                // Version
                if let version = portInfo.version {
                    Text(version)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // State badge
            Text(portInfo.state.rawValue.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(portInfo.state == .open ? Color.green : Color.gray)
                .cornerRadius(8)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Port Vulnerability Detail Row

struct PortVulnerabilityDetailRow: View {
    let vulnerability: Vulnerability

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Vulnerability Type Badge
                Text(vulnerability.type.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor)
                    .cornerRadius(8)

                Spacer()

                // Severity
                Text(vulnerability.severity.rawValue.uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor)
                    .cornerRadius(8)
            }

            // Port info
            if let port = vulnerability.port {
                Text("Port \(port)")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }

            // Description
            Text(vulnerability.description)
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            // Recommendation
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)

                Text(vulnerability.recommendation)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(16)
        .background(severityColor.opacity(0.05))
        .cornerRadius(12)
    }

    private var severityColor: Color {
        switch vulnerability.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

// MARK: - Enhanced Port Detail Row

struct EnhancedPortDetailRow: View {
    let portInfo: PortInfo
    let device: EnhancedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Port number
                Text("\(portInfo.port)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .frame(width: 80, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    // Service name
                    Text(portInfo.service)
                        .font(.system(size: 18, weight: .medium))

                    // HomeKit service info
                    if let homeKitService = HomeKitPortDefinitions.getServiceInfo(for: portInfo.port) {
                        HStack(spacing: 8) {
                            Image(systemName: "homekit")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)

                            Text(homeKitService.description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Version info
                    if let version = portInfo.version {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(version)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Common port usage hints
                    if let hint = getPortUsageHint(portInfo.port) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            Text(hint)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // State badge
                Text(portInfo.state.rawValue.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(portInfo.state == .open ? Color.green : Color.gray)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func getPortUsageHint(_ port: Int) -> String? {
        switch port {
        case 22:
            return "SSH access available - use: ssh user@\(device.ipAddress)"
        case 80:
            return "Web interface - visit: http://\(device.ipAddress)"
        case 443:
            return "Secure web interface - visit: https://\(device.ipAddress)"
        case 3389:
            return "Remote Desktop - use RDP client"
        case 5900:
            return "VNC/Screen Sharing available"
        case 8080:
            return "Alternative web interface - visit: http://\(device.ipAddress):8080"
        case 445:
            return "SMB file sharing - use Finder > Connect to Server"
        case 548:
            return "AFP file sharing (Apple Filing Protocol)"
        case 3306:
            return "MySQL database server"
        case 5432:
            return "PostgreSQL database server"
        case 27017:
            return "MongoDB database server"
        case 6379:
            return "Redis cache server"
        case 32400:
            return "Plex Media Server"
        default:
            return nil
        }
    }
}

#Preview {
    ComprehensiveDeviceDetailView(device: EnhancedDevice(
        ipAddress: "192.168.1.100",
        macAddress: "00:11:22:33:44:55",
        hostname: "test-device.local",
        manufacturer: "Apple",
        deviceType: .computer,
        openPorts: [
            PortInfo(port: 22, service: "SSH", version: "OpenSSH 8.2", state: .open, protocolType: "TCP", banner: nil),
            PortInfo(port: 5000, service: "HomeKit AirPlay", version: nil, state: .open, protocolType: "TCP", banner: nil),
            PortInfo(port: 7000, service: "HomeKit Control", version: nil, state: .open, protocolType: "TCP", banner: nil)
        ],
        isOnline: true,
        firstSeen: Date().addingTimeInterval(-86400 * 7),
        lastSeen: Date(),
        isKnownDevice: true,
        operatingSystem: "macOS 14.0",
        deviceName: "Test Device"
    ))
}
