//
//  DeviceDetailView.swift
//  NMAP Scanner - Device Detail Screen
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import SwiftUI

struct DeviceDetailView: View {
    let device: DiscoveredDevice
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header with close button
                HStack {
                    Text("Device Details")
                        .font(.system(size: 50, weight: .bold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 28, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }

                // Device header card
                DeviceHeaderCard(device: device)

                // Network information
                NetworkInfoCard(device: device)

                // Open ports
                if !device.openPorts.isEmpty {
                    OpenPortsCard(ports: device.openPorts.map { $0.port })
                }

                // Security status
                SecurityStatusCard(device: device)

                // Connection history
                ConnectionHistoryCard(device: device)
            }
            .padding(40)
        }
    }
}

struct DeviceHeaderCard: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 30) {
            // Device icon
            ZStack {
                Circle()
                    .fill(deviceColor.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: deviceIcon)
                    .font(.system(size: 60))
                    .foregroundColor(deviceColor)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(device.hostname ?? "Unknown Device")
                    .font(.system(size: 40, weight: .bold))

                Text(device.ipAddress)
                    .font(.system(size: 32, design: .monospaced))
                    .foregroundColor(.secondary)

                if let manufacturer = device.manufacturer {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .font(.system(size: 20))
                        Text(manufacturer)
                            .font(.system(size: 24))
                    }
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(device.isOnline ? Color.green : Color.gray)
                            .frame(width: 16, height: 16)
                        Text(device.isOnline ? "Online" : "Offline")
                            .font(.system(size: 22))
                            .foregroundColor(device.isOnline ? .green : .gray)
                    }

                    Text(deviceTypeName)
                        .font(.system(size: 22))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(deviceColor.opacity(0.2))
                        .foregroundColor(deviceColor)
                        .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding(30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(20)
    }

    private var deviceIcon: String {
        switch device.deviceType {
        case .router: return "wifi.router"
        case .server: return "server.rack"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "sensor"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }

    private var deviceColor: Color {
        if !device.isOnline { return .gray }
        if !device.vulnerabilities.isEmpty { return .red }
        if device.openPorts.count > 5 { return .orange }
        return .green
    }

    private var deviceTypeName: String {
        switch device.deviceType {
        case .router: return "Router"
        case .server: return "Server"
        case .computer: return "Computer"
        case .mobile: return "Mobile Device"
        case .iot: return "IoT Device"
        case .printer: return "Printer"
        case .unknown: return "Unknown Type"
        }
    }
}

struct NetworkInfoCard: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Information")
                .font(.system(size: 36, weight: .semibold))

            VStack(alignment: .leading, spacing: 16) {
                InfoRowWithIcon(label: "IP Address", value: device.ipAddress, icon: "network")

                if let mac = device.macAddress {
                    InfoRowWithIcon(label: "MAC Address", value: mac, icon: "antenna.radiowaves.left.and.right")
                }

                if let hostname = device.hostname {
                    InfoRowWithIcon(label: "Hostname", value: hostname, icon: "server.rack")
                }

                InfoRowWithIcon(
                    label: "First Seen",
                    value: formatDate(device.firstSeen),
                    icon: "clock"
                )

                InfoRowWithIcon(
                    label: "Last Seen",
                    value: formatDate(device.lastSeen),
                    icon: "clock.fill"
                )
            }
        }
        .padding(24)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row with Icon

struct InfoRowWithIcon: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
            }
        }
    }
}

struct OpenPortsCard: View {
    let ports: [Int]

    private let portServices: [Int: String] = [
        21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
        80: "HTTP", 110: "POP3", 139: "NetBIOS", 143: "IMAP", 443: "HTTPS",
        445: "SMB", 993: "IMAPS", 995: "POP3S", 3306: "MySQL", 3389: "RDP",
        5432: "PostgreSQL", 5900: "VNC", 8080: "HTTP-Proxy", 8443: "HTTPS-Alt"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Open Ports")
                    .font(.system(size: 36, weight: .semibold))
                Spacer()
                Text("\(ports.count) total")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(ports.sorted(), id: \.self) { port in
                    PortCard(port: port, service: portServices[port] ?? "Unknown")
                }
            }
        }
        .padding(24)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
}

struct PortCard: View {
    let port: Int
    let service: String

    var body: some View {
        VStack(spacing: 8) {
            Text("\(port)")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)

            Text(service)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SecurityStatusCard: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Security Status")
                .font(.system(size: 36, weight: .semibold))

            HStack(spacing: 40) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(vulnerabilityColor.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: vulnerabilityIcon)
                            .font(.system(size: 50))
                            .foregroundColor(vulnerabilityColor)
                    }

                    Text("\(device.vulnerabilities)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(vulnerabilityColor)

                    Text("Vulnerabilities")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(securityRating)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(vulnerabilityColor)

                    Text(securityMessage)
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    if !device.vulnerabilities.isEmpty {
                        Button(action: {
                            // Navigate to vulnerability details
                        }) {
                            Text("View Details")
                                .font(.system(size: 22, weight: .semibold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(vulnerabilityColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(24)
        .background(vulnerabilityColor.opacity(0.1))
        .cornerRadius(16)
    }

    private var vulnerabilityColor: Color {
        if device.vulnerabilities.isEmpty { return .green }
        if device.vulnerabilities.count < 3 { return .orange }
        return .red
    }

    private var vulnerabilityIcon: String {
        if device.vulnerabilities.isEmpty { return "checkmark.shield.fill" }
        return "exclamationmark.shield.fill"
    }

    private var securityRating: String {
        if device.vulnerabilities.isEmpty { return "Secure" }
        if device.vulnerabilities.count < 3 { return "Warning" }
        return "Critical"
    }

    private var securityMessage: String {
        if device.vulnerabilities.isEmpty { return "No security issues detected" }
        if device.vulnerabilities.count < 3 { return "Some security concerns found" }
        return "Immediate attention required"
    }
}

struct ConnectionHistoryCard: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connection History")
                .font(.system(size: 36, weight: .semibold))

            VStack(spacing: 16) {
                HistoryItem(
                    icon: "eye",
                    title: "First Discovered",
                    subtitle: formatDate(device.firstSeen),
                    color: .blue
                )

                HistoryItem(
                    icon: "clock.fill",
                    title: "Last Activity",
                    subtitle: formatDate(device.lastSeen),
                    color: .green
                )

                HistoryItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Uptime",
                    subtitle: calculateUptime(),
                    color: .orange
                )
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func calculateUptime() -> String {
        let interval = device.lastSeen.timeIntervalSince(device.firstSeen)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes)m"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

struct HistoryItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}
