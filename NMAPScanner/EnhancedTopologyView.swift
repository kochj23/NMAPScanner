//
//  EnhancedTopologyView.swift
//  NMAPScanner
//
//  Created by Jordan Koch on 2025-11-29.
//  Enhanced network topology with animations, clustering, and zoom
//

import SwiftUI

struct EnhancedTopologyView: View {
    let devices: [EnhancedDevice]
    @Binding var selectedDevice: EnhancedDevice?
    @StateObject private var trafficManager = RealtimeTrafficManager.shared
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var collapsedGroups: Set<String> = []
    @State private var showMiniMap = true
    @State private var isScanning = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main topology canvas
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Background grid
                        TopologyGrid()

                        // Connection lines between devices
                        ConnectionLinesLayer(devices: devices, geometry: geometry)

                        // Heat map overlay
                        if trafficManager.isMonitoring {
                            HeatMapLayer(devices: devices, trafficStats: trafficManager.deviceStats, geometry: geometry)
                        }

                        // Animated packet flows
                        if trafficManager.isMonitoring {
                            PacketFlowLayer(flows: trafficManager.activeFlows, devices: devices, geometry: geometry)
                        }

                        // Scanning wave effect
                        if isScanning {
                            ScanningWaveLayer(devices: devices, geometry: geometry)
                        }

                        // Device nodes with clustering
                        DeviceNodesLayer(
                            devices: devices,
                            selectedDevice: $selectedDevice,
                            collapsedGroups: $collapsedGroups,
                            geometry: geometry
                        )
                    }
                    .frame(width: geometry.size.width * 2, height: geometry.size.height * 2)
                    .scaleEffect(zoomScale)
                    .offset(offset)
                }

                // Mini-map navigator
                if showMiniMap {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MiniMapNavigator(
                                devices: devices,
                                viewportSize: geometry.size,
                                zoomScale: $zoomScale,
                                offset: $offset
                            )
                            .frame(width: 200, height: 150)
                            .padding()
                        }
                    }
                }

                // Zoom controls
                VStack {
                    HStack {
                        Spacer()
                        ZoomControls(zoomScale: $zoomScale)
                            .padding()
                    }
                    Spacer()
                }

                // Traffic monitoring toggle
                VStack {
                    HStack {
                        TrafficMonitoringToggle(isMonitoring: $trafficManager.isMonitoring)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Topology Grid Background

struct TopologyGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let gridSize: CGFloat = 50
                let columns = Int(geometry.size.width / gridSize) + 1
                let rows = Int(geometry.size.height / gridSize) + 1

                // Vertical lines
                for i in 0..<columns {
                    let x = CGFloat(i) * gridSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }

                // Horizontal lines
                for i in 0..<rows {
                    let y = CGFloat(i) * gridSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Connection Lines Layer

struct ConnectionLinesLayer: View {
    let devices: [EnhancedDevice]
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            // Find router/gateway
            if let router = devices.first(where: { $0.deviceType == .router }) {
                let routerPos = devicePosition(for: router, in: geometry)

                // Draw lines from router to all other devices
                ForEach(devices.filter { $0.id != router.id }) { device in
                    let devicePos = devicePosition(for: device, in: geometry)

                    ConnectionLine(start: routerPos, end: devicePos)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
            }
        }
    }

    private func devicePosition(for device: EnhancedDevice, in geometry: GeometryProxy) -> CGPoint {
        let index = devices.firstIndex(where: { $0.id == device.id }) ?? 0
        let angle = (Double(index) / Double(devices.count)) * 2 * .pi
        let radius = min(geometry.size.width, geometry.size.height) * 0.35

        return CGPoint(
            x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
            y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
        )
    }
}

// MARK: - Heat Map Layer

struct HeatMapLayer: View {
    let devices: [EnhancedDevice]
    let trafficStats: [String: RealtimeDeviceTrafficStats]
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            ForEach(devices) { device in
                if let stats = trafficStats[device.ipAddress], stats.activityLevel > 0.1 {
                    let position = devicePosition(for: device, in: geometry)
                    HeatMapOverlay(activityLevel: stats.activityLevel)
                        .position(position)
                }
            }
        }
    }

    private func devicePosition(for device: EnhancedDevice, in geometry: GeometryProxy) -> CGPoint {
        let index = devices.firstIndex(where: { $0.id == device.id }) ?? 0
        let angle = (Double(index) / Double(devices.count)) * 2 * .pi
        let radius = min(geometry.size.width, geometry.size.height) * 0.35

        return CGPoint(
            x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
            y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
        )
    }
}

// MARK: - Packet Flow Layer

struct PacketFlowLayer: View {
    let flows: [PacketFlow]
    let devices: [EnhancedDevice]
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            ForEach(flows) { flow in
                if let sourceDevice = devices.first(where: { $0.ipAddress == flow.sourceIP }),
                   let destDevice = devices.first(where: { $0.ipAddress == flow.destinationIP }) {
                    let start = devicePosition(for: sourceDevice, in: geometry)
                    let end = devicePosition(for: destDevice, in: geometry)

                    AnimatedPacketFlow(flow: flow, start: start, end: end)
                }
            }
        }
    }

    private func devicePosition(for device: EnhancedDevice, in geometry: GeometryProxy) -> CGPoint {
        let index = devices.firstIndex(where: { $0.id == device.id }) ?? 0
        let angle = (Double(index) / Double(devices.count)) * 2 * .pi
        let radius = min(geometry.size.width, geometry.size.height) * 0.35

        return CGPoint(
            x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
            y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
        )
    }
}

// MARK: - Scanning Wave Layer

struct ScanningWaveLayer: View {
    let devices: [EnhancedDevice]
    let geometry: GeometryProxy

    var body: some View {
        if let router = devices.first(where: { $0.deviceType == .router }) {
            let position = devicePosition(for: router, in: geometry)
            let maxRadius = min(geometry.size.width, geometry.size.height) * 0.4

            ScanningWave(center: position, maxRadius: maxRadius)
        }
    }

    private func devicePosition(for device: EnhancedDevice, in geometry: GeometryProxy) -> CGPoint {
        let index = devices.firstIndex(where: { $0.id == device.id }) ?? 0
        let angle = (Double(index) / Double(devices.count)) * 2 * .pi
        let radius = min(geometry.size.width, geometry.size.height) * 0.35

        return CGPoint(
            x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
            y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
        )
    }
}

// MARK: - Device Nodes Layer

struct DeviceNodesLayer: View {
    let devices: [EnhancedDevice]
    @Binding var selectedDevice: EnhancedDevice?
    @Binding var collapsedGroups: Set<String>
    let geometry: GeometryProxy

    var body: some View {
        // Group devices by type
        let grouped = Dictionary(grouping: devices, by: { $0.deviceType })

        ZStack {
            ForEach(Array(grouped.keys), id: \.self) { deviceType in
                let devicesInGroup = grouped[deviceType] ?? []

                if devicesInGroup.count > 1 && collapsedGroups.contains(deviceType.rawValue) {
                    // Show collapsed cluster
                    DeviceClusterNode(
                        deviceType: deviceType,
                        count: devicesInGroup.count,
                        position: centerPosition(for: devicesInGroup, in: geometry),
                        onExpand: {
                            withAnimation {
                                _ = collapsedGroups.remove(deviceType.rawValue)
                            }
                        }
                    )
                } else {
                    // Show individual devices
                    ForEach(devicesInGroup) { device in
                        DeviceNode(
                            device: device,
                            isSelected: selectedDevice?.id == device.id,
                            position: devicePosition(for: device, in: geometry),
                            onTap: { selectedDevice = device }
                        )
                    }
                }
            }
        }
    }

    private func devicePosition(for device: EnhancedDevice, in geometry: GeometryProxy) -> CGPoint {
        let index = devices.firstIndex(where: { $0.id == device.id }) ?? 0
        let angle = (Double(index) / Double(devices.count)) * 2 * .pi
        let radius = min(geometry.size.width, geometry.size.height) * 0.35

        return CGPoint(
            x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
            y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
        )
    }

    private func centerPosition(for devices: [EnhancedDevice], in geometry: GeometryProxy) -> CGPoint {
        let positions = devices.map { devicePosition(for: $0, in: geometry) }
        let avgX = positions.map { $0.x }.reduce(0, +) / CGFloat(positions.count)
        let avgY = positions.map { $0.y }.reduce(0, +) / CGFloat(positions.count)
        return CGPoint(x: avgX, y: avgY)
    }
}

// MARK: - Device Node

struct DeviceNode: View {
    let device: EnhancedDevice
    let isSelected: Bool
    let position: CGPoint
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(deviceColor.opacity(0.2))
                    .frame(width: 70, height: 70)

                Circle()
                    .stroke(deviceColor, lineWidth: isSelected ? 3 : 2)
                    .frame(width: 70, height: 70)

                Image(systemName: deviceIcon)
                    .font(.system(size: 30))
                    .foregroundColor(deviceColor)

                if device.isOnline {
                    PulsingIndicator(color: .green, size: 14)
                        .offset(x: 30, y: 30)
                }
            }
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .position(position)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var deviceColor: Color {
        switch device.deviceType {
        case .router: return .blue
        case .computer: return .purple
        case .mobile: return .cyan
        case .iot: return .orange
        default: return .gray
        }
    }

    private var deviceIcon: String {
        switch device.deviceType {
        case .router: return "wifi.router"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "lightbulb.fill"
        default: return "network"
        }
    }
}

// MARK: - Device Cluster Node

struct DeviceClusterNode: View {
    let deviceType: EnhancedDevice.DeviceType
    let count: Int
    let position: CGPoint
    let onExpand: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onExpand) {
            ZStack {
                Circle()
                    .fill(clusterColor.opacity(0.3))
                    .frame(width: 90, height: 90)

                Circle()
                    .stroke(clusterColor, lineWidth: 3)
                    .frame(width: 90, height: 90)

                VStack(spacing: 4) {
                    Image(systemName: clusterIcon)
                        .font(.system(size: 32))
                        .foregroundColor(clusterColor)

                    Text("\(count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(clusterColor)
                }
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .position(position)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var clusterColor: Color {
        switch deviceType {
        case .router: return .blue
        case .computer: return .purple
        case .mobile: return .cyan
        case .iot: return .orange
        default: return .gray
        }
    }

    private var clusterIcon: String {
        switch deviceType {
        case .router: return "wifi.router"
        case .computer: return "desktopcomputer"
        case .mobile: return "iphone"
        case .iot: return "lightbulb.fill"
        default: return "network"
        }
    }
}

// MARK: - Mini Map Navigator

struct MiniMapNavigator: View {
    let devices: [EnhancedDevice]
    let viewportSize: CGSize
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))

            // Simplified device positions
            ForEach(devices) { device in
                Circle()
                    .fill(deviceColor(for: device))
                    .frame(width: 6, height: 6)
                    .position(miniMapPosition(for: device))
            }

            // Viewport indicator
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: viewportSize.width / 10, height: viewportSize.height / 10)
        }
    }

    private func miniMapPosition(for device: EnhancedDevice) -> CGPoint {
        let index = devices.firstIndex(where: { $0.id == device.id }) ?? 0
        let angle = (Double(index) / Double(devices.count)) * 2 * .pi
        let radius: CGFloat = 60

        return CGPoint(
            x: 100 + CGFloat(cos(angle)) * radius,
            y: 75 + CGFloat(sin(angle)) * radius
        )
    }

    private func deviceColor(for device: EnhancedDevice) -> Color {
        switch device.deviceType {
        case .router: return .blue
        case .computer: return .purple
        case .mobile: return .cyan
        case .iot: return .orange
        default: return .gray
        }
    }
}

// MARK: - Zoom Controls

struct ZoomControls: View {
    @Binding var zoomScale: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            Button(action: { zoomIn() }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { zoomOut() }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { resetZoom() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .shadow(radius: 4)
    }

    private func zoomIn() {
        withAnimation {
            zoomScale = min(zoomScale * 1.2, 3.0)
        }
    }

    private func zoomOut() {
        withAnimation {
            zoomScale = max(zoomScale / 1.2, 0.5)
        }
    }

    private func resetZoom() {
        withAnimation {
            zoomScale = 1.0
        }
    }
}

// MARK: - Traffic Monitoring Toggle

struct TrafficMonitoringToggle: View {
    @Binding var isMonitoring: Bool

    var body: some View {
        Button(action: { toggleMonitoring() }) {
            HStack {
                Image(systemName: isMonitoring ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 16))
                Text(isMonitoring ? "Traffic: ON" : "Traffic: OFF")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isMonitoring ? Color.green : Color.gray)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleMonitoring() {
        if isMonitoring {
            RealtimeTrafficManager.shared.stopMonitoring()
        } else {
            RealtimeTrafficManager.shared.startMonitoring()
        }
        isMonitoring.toggle()
    }
}
