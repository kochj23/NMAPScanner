//
//  NetworkTopologyView.swift
//  NMAP Scanner - Enhanced Network Topology Visualization
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI

struct NetworkTopologyView: View {
    let devices: [EnhancedDevice]
    @State private var selectedDevice: EnhancedDevice?
    @State private var layoutMode: LayoutMode = .grid
    @State private var zoomLevel: CGFloat = 1.0
    @State private var searchText = ""
    @State private var showDependencyOverlay = false
    @StateObject private var dependencyTracker = ServiceDependencyTracker.shared

    enum LayoutMode: String, CaseIterable {
        case grid = "Grid"
        case hierarchical = "Hierarchical"
    }

    var filteredDevices: [EnhancedDevice] {
        if searchText.isEmpty {
            return devices
        }
        return devices.filter { device in
            device.ipAddress.contains(searchText) ||
            device.hostname?.localizedCaseInsensitiveContains(searchText) == true ||
            device.manufacturer?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header with controls
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Network Topology")
                            .font(.system(size: 50, weight: .bold))

                        Text("\(filteredDevices.count) of \(devices.count) devices")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Layout mode picker
                    Picker("Layout", selection: $layoutMode) {
                        ForEach(LayoutMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 400)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search devices...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if filteredDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: searchText.isEmpty ? "network.slash" : "magnifyingglass")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "No devices discovered yet" : "No devices match '\(searchText)'")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "Run a network scan to discover devices" : "Try a different search term")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(60)
                } else {
                    // Topology visualization based on layout mode
                    switch layoutMode {
                    case .grid:
                        GridLayoutView(devices: filteredDevices, selectedDevice: $selectedDevice)
                    case .hierarchical:
                        HierarchicalLayoutView(devices: filteredDevices, selectedDevice: $selectedDevice)
                    }

                    // Service Dependencies Summary (NEW in v8.3.0)
                    ServiceDependencySummaryCard(devices: filteredDevices, tracker: dependencyTracker)

                    // Device statistics
                    DeviceStatisticsCard(devices: filteredDevices)

                    // Device type breakdown
                    DeviceTypeBreakdownCard(devices: filteredDevices)
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedDevice) { device in
            ComprehensiveDeviceDetailView(device: device)
        }
    }
}

// MARK: - Grid Layout (Best for many devices)

struct GridLayoutView: View {
    let devices: [EnhancedDevice]
    @Binding var selectedDevice: EnhancedDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Device Grid")
                .font(.system(size: 36, weight: .semibold))

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
            ], spacing: 16) {
                ForEach(devices) { device in
                    DeviceGridCard(device: device)
                        .onTapGesture {
                            selectedDevice = device
                        }
                }
            }
        }
    }
}

struct DeviceGridCard: View {
    let device: EnhancedDevice

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(deviceColor)
                    .frame(width: 60, height: 60)

                Image(systemName: deviceIcon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(device.deviceName ?? device.hostname ?? device.ipAddress)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

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

                // HomeKit Badge
                if let homeKitInfo = device.homeKitMDNSInfo, homeKitInfo.isHomeKitAccessory {
                    HStack(spacing: 4) {
                        Image(systemName: "homekit")
                            .font(.system(size: 10))
                        Text("HomeKit")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .cornerRadius(6)
                }
            }

            // Status indicators
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(device.isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(device.isOnline ? "Online" : "Offline")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if !device.openPorts.isEmpty {
                    Text("\(device.openPorts.count) ports")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(device.isOnline ? deviceColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
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
        switch device.deviceType {
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

// MARK: - List Layout (Detailed view)

struct ListLayoutView: View {
    let devices: [EnhancedDevice]
    @Binding var selectedDevice: EnhancedDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Device List")
                .font(.system(size: 36, weight: .semibold))

            VStack(spacing: 12) {
                ForEach(devices) { device in
                    DeviceListRow(device: device)
                        .onTapGesture {
                            selectedDevice = device
                        }
                }
            }
        }
    }
}

struct DeviceListRow: View {
    let device: EnhancedDevice

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(deviceColor)
                    .frame(width: 50, height: 50)

                Image(systemName: deviceIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.hostname ?? "Unknown Device")
                    .font(.system(size: 18, weight: .semibold))

                HStack(spacing: 12) {
                    Text(device.ipAddress)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let mac = device.macAddress {
                        Text(mac)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if let manufacturer = device.manufacturer {
                        Text(manufacturer)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Status and ports
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(device.isOnline ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(device.isOnline ? "Online" : "Offline")
                        .font(.system(size: 14))
                }

                if !device.openPorts.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(device.openPorts.count)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(deviceColor)
                        Text("ports")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
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
        switch device.deviceType {
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

// MARK: - Circular Layout (Better for fewer devices)

struct CircularLayoutView: View {
    let devices: [EnhancedDevice]
    @Binding var selectedDevice: EnhancedDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Circular Topology")
                .font(.system(size: 36, weight: .semibold))

            if devices.count > 30 {
                Text("⚠️ Too many devices for circular view (\(devices.count)). Switch to Grid or List layout for better visibility.")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
            }

            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.05))

                    // Gateway/Router in center
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 80, height: 80)

                            Image(systemName: "wifi.router.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        Text("Gateway")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                    // Devices arranged in multiple rings if needed
                    let devicesPerRing = 12
                    let totalRings = max(1, (devices.count + devicesPerRing - 1) / devicesPerRing)

                    ForEach(devices.indices, id: \.self) { index in
                        let device = devices[index]
                        let ring = index / devicesPerRing
                        let positionInRing = index % devicesPerRing
                        let devicesInRing = min(devicesPerRing, devices.count - ring * devicesPerRing)

                        let angle = Double(positionInRing) * (360.0 / Double(devicesInRing)) * .pi / 180.0
                        let baseRadius = min(geometry.size.width, geometry.size.height) / 3.5
                        let radius = baseRadius + CGFloat(ring) * 120
                        let x = geometry.size.width / 2 + cos(angle) * radius
                        let y = geometry.size.height / 2 + sin(angle) * radius

                        // Connection line
                        Path { path in
                            path.move(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        .stroke(device.isOnline ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)

                        // Device node
                        Button(action: {
                            selectedDevice = device
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(deviceColor(device))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: deviceIcon(device))
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }

                                Text(device.hostname ?? String(device.ipAddress.suffix(7)))
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .frame(width: 90)
                            }
                            .position(x: x, y: y)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: max(600, CGFloat(devices.count > 12 ? 800 : 600)))
            .padding(20)
        }
    }

    private func deviceIcon(_ device: EnhancedDevice) -> String {
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

    private func deviceColor(_ device: EnhancedDevice) -> Color {
        if !device.isOnline { return .gray }
        switch device.deviceType {
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

// MARK: - Hierarchical Layout (Organized by type)

struct HierarchicalLayoutView: View {
    let devices: [EnhancedDevice]
    @Binding var selectedDevice: EnhancedDevice?

    var devicesByType: [(EnhancedDevice.DeviceType, [EnhancedDevice])] {
        let grouped = Dictionary(grouping: devices) { $0.deviceType }
        return grouped.sorted { typeOrder($0.key) < typeOrder($1.key) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Hierarchical View")
                .font(.system(size: 36, weight: .semibold))

            ForEach(devicesByType, id: \.0) { type, typeDevices in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: iconForType(type))
                            .font(.system(size: 28))
                            .foregroundColor(colorForType(type))

                        Text(nameForType(type))
                            .font(.system(size: 28, weight: .semibold))

                        Text("(\(typeDevices.count))")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 12)
                    ], spacing: 12) {
                        ForEach(typeDevices) { device in
                            DeviceGridCard(device: device)
                                .onTapGesture {
                                    selectedDevice = device
                                }
                        }
                    }
                }
                .padding(20)
                .background(colorForType(type).opacity(0.05))
                .cornerRadius(16)
            }
        }
    }

    private func typeOrder(_ type: EnhancedDevice.DeviceType) -> Int {
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

    private func nameForType(_ type: EnhancedDevice.DeviceType) -> String {
        switch type {
        case .router: return "Network Devices"
        case .server: return "Servers & NAS"
        case .computer: return "Computers"
        case .mobile: return "Mobile Devices"
        case .iot: return "IoT & Smart Home"
        case .printer: return "Printers"
        case .unknown: return "Unknown Devices"
        }
    }

    private func iconForType(_ type: EnhancedDevice.DeviceType) -> String {
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

    private func colorForType(_ type: EnhancedDevice.DeviceType) -> Color {
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

// MARK: - Supporting Views

struct DeviceStatisticsCard: View {
    let devices: [EnhancedDevice]

    var onlineDevices: Int {
        devices.filter { $0.isOnline }.count
    }

    var totalOpenPorts: Int {
        devices.reduce(0) { $0 + $1.openPorts.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Statistics")
                .font(.system(size: 36, weight: .semibold))

            HStack(spacing: 40) {
                TopologyStatItem(label: "Total Devices", value: "\(devices.count)")
                TopologyStatItem(label: "Online", value: "\(onlineDevices)")
                TopologyStatItem(label: "Open Ports", value: "\(totalOpenPorts)")
            }
        }
        .padding(24)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

struct TopologyStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        }
    }
}

struct DeviceTypeBreakdownCard: View {
    let devices: [EnhancedDevice]

    var typeCounts: [EnhancedDevice.DeviceType: Int] {
        var counts: [EnhancedDevice.DeviceType: Int] = [:]
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

    private func typeOrder(_ type: EnhancedDevice.DeviceType) -> Int {
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

    private func iconForType(_ type: EnhancedDevice.DeviceType) -> String {
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

    private func colorForType(_ type: EnhancedDevice.DeviceType) -> Color {
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
    let type: EnhancedDevice.DeviceType
    let count: Int
    let icon: String
    let color: Color

    var typeName: String {
        switch type {
        case .router: return "Network"
        case .server: return "Servers"
        case .computer: return "Computers"
        case .mobile: return "Mobile"
        case .iot: return "Smart Home"
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

// MARK: - Service Dependency Summary Card

struct ServiceDependencySummaryCard: View {
    let devices: [EnhancedDevice]
    @ObservedObject var tracker: ServiceDependencyTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Service Dependencies")
                        .font(.system(size: 36, weight: .semibold))

                    Text("AI and infrastructure service connections")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    tracker.detectDependencies(devices: devices)
                }) {
                    Label("Analyze", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(tracker.isAnalyzing)
            }

            if tracker.isAnalyzing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing service dependencies...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if tracker.serviceNodes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Click Analyze to detect service dependencies")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                // Stats Row
                HStack(spacing: 40) {
                    ServiceDepStatItem(
                        label: "Services",
                        value: "\(tracker.serviceNodes.count)",
                        icon: "server.rack",
                        color: .blue
                    )
                    ServiceDepStatItem(
                        label: "Connections",
                        value: "\(tracker.connections.count)",
                        icon: "arrow.left.arrow.right",
                        color: .green
                    )
                    ServiceDepStatItem(
                        label: "AI Services",
                        value: "\(tracker.serviceNodes.filter { $0.category == .aiMl }.count)",
                        icon: "brain.head.profile",
                        color: .purple
                    )
                    ServiceDepStatItem(
                        label: "Single Points of Failure",
                        value: "\(tracker.singlePointsOfFailure.count)",
                        icon: "exclamationmark.triangle",
                        color: .red
                    )
                }

                // AI Dependencies Preview
                let aiConnections = tracker.connections.filter { $0.connectionType == .inference }
                if !aiConnections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Service Dependencies")
                            .font(.system(size: 24, weight: .semibold))

                        ForEach(aiConnections.prefix(5)) { connection in
                            HStack {
                                // Source
                                HStack(spacing: 8) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading) {
                                        Text(connection.sourceService)
                                            .font(.system(size: 16, weight: .medium))
                                        Text("\(connection.sourceHost):\(connection.sourcePort)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                // Arrow
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)

                                Spacer()

                                // Destination
                                HStack(spacing: 8) {
                                    VStack(alignment: .trailing) {
                                        Text(connection.destService)
                                            .font(.system(size: 16, weight: .medium))
                                        Text("\(connection.destHost):\(connection.destPort)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: connection.connectionType.icon)
                                        .foregroundColor(connection.connectionType.color)
                                }
                            }
                            .padding(12)
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(8)
                        }

                        if aiConnections.count > 5 {
                            Text("+ \(aiConnections.count - 5) more AI dependencies")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }

                // Single Points of Failure Warning
                if !tracker.singlePointsOfFailure.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Single Points of Failure Detected")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                        }

                        ForEach(tracker.singlePointsOfFailure.prefix(3)) { node in
                            HStack {
                                Image(systemName: node.category.icon)
                                    .foregroundColor(node.category.color)
                                VStack(alignment: .leading) {
                                    Text(node.serviceName)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("\(node.host):\(node.port)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()

                                let connections = tracker.getConnections(for: node)
                                Text("\(connections.incoming.count) dependents")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }

                // Hint to view full dependency graph
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("View the Dependencies tab for the full interactive service dependency graph")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
        .onAppear {
            if tracker.serviceNodes.isEmpty && !devices.isEmpty {
                tracker.detectDependencies(devices: devices)
            }
        }
    }
}

struct ServiceDepStatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
}
