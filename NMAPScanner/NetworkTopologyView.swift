//
//  NetworkTopologyView.swift
//  NMAP Scanner - Network Topology Visualization
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import SwiftUI

struct NetworkTopologyView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var selectedDevice: DiscoveredDevice?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Network Topology")
                    .font(.system(size: 50, weight: .bold))

                if deviceManager.discoveredDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("No devices discovered yet")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                        Text("Run a network scan to discover devices")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(60)
                } else {
                    // Topology visualization
                    TopologyMapView(devices: deviceManager.discoveredDevices, selectedDevice: $selectedDevice)

                    // Device statistics
                    DeviceStatisticsCard(devices: deviceManager.discoveredDevices)

                    // Device type breakdown
                    DeviceTypeBreakdownCard(devices: deviceManager.discoveredDevices)
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailView(device: device)
        }
    }
}

struct TopologyMapView: View {
    let devices: [DiscoveredDevice]
    @Binding var selectedDevice: DiscoveredDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Device Map")
                .font(.system(size: 36, weight: .semibold))

            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.05))

                    // Gateway/Router in center
                    Button(action: {
                        // Could show router details
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 100, height: 100)

                                Image(systemName: "wifi.router.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            Text("Gateway")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .buttonStyle(.plain)

                    // Devices arranged in circle around router
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        let totalDevices = Double(devices.count)
                        let angle = Double(index) * (360.0 / totalDevices) * .pi / 180.0
                        let radius = min(geometry.size.width, geometry.size.height) / 2.5
                        let x = geometry.size.width / 2 + cos(angle) * radius
                        let y = geometry.size.height / 2 + sin(angle) * radius

                        // Connection line from router to device
                        Path { path in
                            path.move(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        .stroke(device.isOnline ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 3)

                        // Device node
                        Button(action: {
                            selectedDevice = device
                        }) {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(deviceColor(device))
                                        .frame(width: 70, height: 70)

                                    Image(systemName: deviceIcon(device))
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }

                                Text(device.hostname ?? "Unknown")
                                    .font(.system(size: 16, weight: .medium))
                                    .lineLimit(1)
                                    .frame(width: 120)

                                Text(device.ipAddress)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .position(x: x, y: y)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 600)
            .padding(20)
        }
    }

    private func deviceIcon(_ device: DiscoveredDevice) -> String {
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

    private func deviceColor(_ device: DiscoveredDevice) -> Color {
        if !device.isOnline { return .gray }
        if device.vulnerabilities > 0 { return .red }
        if device.openPorts.count > 5 { return .orange }
        return .green
    }
}

struct DeviceStatisticsCard: View {
    let devices: [DiscoveredDevice]

    var onlineDevices: Int {
        devices.filter { $0.isOnline }.count
    }

    var vulnerableDevices: Int {
        devices.filter { $0.vulnerabilities > 0 }.count
    }

    var totalOpenPorts: Int {
        devices.reduce(0) { $0 + $1.openPorts.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Statistics")
                .font(.system(size: 36, weight: .semibold))

            HStack(spacing: 40) {
                StatItem(label: "Total Devices", value: "\(devices.count)")
                StatItem(label: "Online", value: "\(onlineDevices)")
                StatItem(label: "Vulnerable", value: "\(vulnerableDevices)")
                StatItem(label: "Open Ports", value: "\(totalOpenPorts)")
            }
        }
        .padding(24)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

struct DeviceTypeBreakdownCard: View {
    let devices: [DiscoveredDevice]

    var typeCounts: [DiscoveredDevice.DeviceType: Int] {
        var counts: [DiscoveredDevice.DeviceType: Int] = [:]
        devices.forEach { device in
            counts[device.deviceType, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Device Types")
                .font(.system(size: 36, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(Array(typeCounts.keys.sorted(by: { typeOrder($0) < typeOrder($1) })), id: \.self) { type in
                    DeviceTypeCard(
                        type: type,
                        count: typeCounts[type] ?? 0,
                        icon: iconForType(type),
                        color: colorForType(type)
                    )
                }
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }

    private func typeOrder(_ type: DiscoveredDevice.DeviceType) -> Int {
        switch type {
        case .router: return 0
        case .server: return 1
        case .computer: return 2
        case .mobile: return 3
        case .iot: return 4
        case .printer: return 5
        case .unknown: return 6
        }
    }

    private func iconForType(_ type: DiscoveredDevice.DeviceType) -> String {
        switch type {
        case .router: return "wifi.router"
        case .server: return "server.rack"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "sensor"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }

    private func colorForType(_ type: DiscoveredDevice.DeviceType) -> Color {
        switch type {
        case .router: return .blue
        case .server: return .purple
        case .computer: return .green
        case .mobile: return .orange
        case .iot: return .cyan
        case .printer: return .pink
        case .unknown: return .gray
        }
    }
}

struct DeviceTypeCard: View {
    let type: DiscoveredDevice.DeviceType
    let count: Int
    let icon: String
    let color: Color

    var typeName: String {
        switch type {
        case .router: return "Routers"
        case .server: return "Servers"
        case .computer: return "Computers"
        case .mobile: return "Mobile"
        case .iot: return "IoT Devices"
        case .printer: return "Printers"
        case .unknown: return "Unknown"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
            }

            Text("\(count)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(color)

            Text(typeName)
                .font(.system(size: 22))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(color.opacity(0.08))
        .cornerRadius(16)
    }
}
