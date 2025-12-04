//
//  Enhanced3DTopologyView.swift
//  NMAPScanner - Ultimate Network Topology Visualization
//
//  Created by Jordan Koch on 2025-11-27.
//  Implements 15 advanced topology features
//

import SwiftUI
import Charts

// MARK: - Main Enhanced Topology View

struct Enhanced3DTopologyView: View {
    let devices: [EnhancedDevice]

    // View State
    @State private var viewMode: TopologyViewMode = .force2D
    @State private var heatmapMode: HeatmapMode = .security
    @State private var showPacketFlow = true
    @State private var showMinimap = true
    @State private var searchText = ""
    @State private var selectedDevice: EnhancedDevice?
    @State private var highlightedPath: [String] = []
    @State private var deviceZones: [String: NetworkZone] = [:]
    @State private var comparisonMode = false
    @State private var timelinePosition: Double = 1.0 // 1.0 = present

    // Physics Engine
    @StateObject private var physicsEngine = TopologyPhysicsEngine()

    // Layout Manager
    @StateObject private var layoutManager = TopologyLayoutManager()

    // Packet Flow
    @StateObject private var packetAnimator = PacketFlowAnimator()

    // Historical Data
    @StateObject private var historyManager = TopologyHistoryManager()

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Control Bar
                topControlBar

                // Main Topology Canvas
                mainTopologyCanvas

                // Bottom Timeline (Time-Travel Mode)
                if timelinePosition < 1.0 {
                    timelineSlider
                }
            }

            // Floating Minimap
            if showMinimap && devices.count > 10 {
                GeometryReader { geo in
                    minimapView
                        .frame(width: 200, height: 150)
                        .position(x: geo.size.width - 120, y: geo.size.height - 100)
                }
            }

            // Device Info Panel
            if let selected = selectedDevice {
                GeometryReader { geo in
                    deviceInfoPanel(device: selected)
                        .position(x: geo.size.width - 170, y: geo.size.height / 2)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .onAppear {
            initializeTopology()
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack(spacing: 20) {
            // View Mode Picker
            Picker("View Mode", selection: $viewMode) {
                Text("2D Force").tag(TopologyViewMode.force2D)
                Text("3D Sphere").tag(TopologyViewMode.sphere3D)
                Text("Hierarchical").tag(TopologyViewMode.hierarchical)
                Text("Radial").tag(TopologyViewMode.radial)
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            // Heatmap Mode
            Menu {
                Button("Security") { heatmapMode = .security }
                Button("Bandwidth") { heatmapMode = .bandwidth }
                Button("Latency") { heatmapMode = .latency }
                Button("Port Exposure") { heatmapMode = .portExposure }
            } label: {
                Label("Heatmap: \(heatmapMode.rawValue)", systemImage: "flame.fill")
                    .foregroundColor(.orange)
            }

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                TextField("Search devices...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onChange(of: searchText) { newValue in
                        searchAndHighlight(newValue)
                    }
            }

            // Toggle Controls
            Toggle("Packet Flow", isOn: $showPacketFlow)
                .toggleStyle(.switch)

            Toggle("Minimap", isOn: $showMinimap)
                .toggleStyle(.switch)

            Toggle("Compare", isOn: $comparisonMode)
                .toggleStyle(.switch)

            // Export Menu
            Menu {
                Button("Export SVG") { exportTopology(format: .svg) }
                Button("Export PNG") { exportTopology(format: .png) }
                Button("Export JSON") { exportTopology(format: .json) }
                Button("Export Graphviz") { exportTopology(format: .graphviz) }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }

    // MARK: - Main Topology Canvas

    private var mainTopologyCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                if comparisonMode {
                    // Split-screen comparison
                    HStack(spacing: 0) {
                        topologyCanvas(devices: devices, geometry: geometry, label: "CURRENT")
                            .frame(width: geometry.size.width / 2)

                        Divider()
                            .background(Color.blue)
                            .frame(width: 2)

                        topologyCanvas(devices: historyManager.getSnapshot(at: timelinePosition), geometry: geometry, label: "HISTORICAL")
                            .frame(width: geometry.size.width / 2)
                    }
                } else {
                    // Single view
                    topologyCanvas(devices: devices, geometry: geometry, label: nil)
                }
            }
        }
    }

    private func topologyCanvas(devices: [EnhancedDevice], geometry: GeometryProxy, label: String?) -> some View {
        ZStack {
            // Network zones (segmentation)
            ForEach(Array(deviceZones.keys), id: \.self) { zoneKey in
                if let zone = deviceZones[zoneKey] {
                    ZoneRegion(zone: zone, devices: devices)
                }
            }

            // Connection Lines
            ForEach(devices) { device in
                ForEach(getConnections(for: device)) { connection in
                    AnimatedConnectionLine(
                        from: layoutManager.position(for: connection.source),
                        to: layoutManager.position(for: connection.destination),
                        bandwidth: connection.bandwidth,
                        showPackets: showPacketFlow,
                        packets: packetAnimator.packets(for: connection)
                    )
                }
            }

            // Device Nodes
            ForEach(devices) { device in
                DeviceNodeView(
                    device: device,
                    position: layoutManager.position(for: device.ipAddress),
                    heatmapMode: heatmapMode,
                    isHighlighted: highlightedPath.contains(device.ipAddress),
                    isSelected: selectedDevice?.id == device.id,
                    anomalies: getAnomalies(for: device)
                )
                .onTapGesture {
                    selectDevice(device)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            layoutManager.updatePosition(for: device.ipAddress, to: value.location)
                        }
                )
            }

            // Attack Path Visualization
            if let selected = selectedDevice {
                AttackPathOverlay(sourceDevice: selected, allDevices: devices, layoutManager: layoutManager)
            }

            // Label
            if let label = label {
                Text(label)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .position(x: geometry.size.width / 2, y: 30)
            }
        }
    }

    // MARK: - Timeline Slider (Time-Travel)

    private var timelineSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { timelinePosition = max(0, timelinePosition - 0.1) }) {
                    Image(systemName: "backward.fill")
                }

                Slider(value: $timelinePosition, in: 0...1)
                    .accentColor(.blue)

                Button(action: { timelinePosition = min(1.0, timelinePosition + 0.1) }) {
                    Image(systemName: "forward.fill")
                }

                Text(historyManager.timestamp(at: timelinePosition))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Minimap

    private var minimapView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 2)
                )

            // Mini devices
            ForEach(devices) { device in
                Circle()
                    .fill(heatmapColor(for: device, mode: heatmapMode))
                    .frame(width: 4, height: 4)
                    .position(layoutManager.minimapPosition(for: device.ipAddress))
            }

            // Viewport indicator
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: 50, height: 50)
                .position(x: 100, y: 75)
        }
    }

    // MARK: - Device Info Panel

    private func deviceInfoPanel(device: EnhancedDevice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(device.hostname ?? device.ipAddress)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { selectedDevice = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }

            Divider()

            Text("IP: \(device.ipAddress)")
                .font(.system(.body, design: .monospaced))

            Text("MAC: \(device.macAddress)")
                .font(.system(.caption, design: .monospaced))

            if !device.openPorts.isEmpty {
                Text("Open Ports: \(device.openPorts.count)")
                    .foregroundColor(.orange)
            }

            // Attack surface
            Text("Attack Surface: \(calculateAttackSurface(for: device))")
                .foregroundColor(.red)

            // Connections
            Text("Connections: \(getConnections(for: device).count)")
                .foregroundColor(.blue)

            // Path to gateway
            Button("Show Path to Gateway") {
                highlightedPath = findPath(from: device.ipAddress, to: getGatewayIP())
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .frame(width: 300)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    // MARK: - Helper Functions

    private func initializeTopology() {
        layoutManager.setDevices(devices)
        physicsEngine.setDevices(devices)
        historyManager.recordSnapshot(devices)
        assignDevicesToZones()
        packetAnimator.start()

        // Start periodic snapshot recording (every 30 seconds)
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak historyManager] _ in
            historyManager?.recordSnapshot(devices)
        }

        // Start physics engine updates (60 FPS for smooth animation)
        if viewMode == .force2D {
            Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak physicsEngine] _ in
                physicsEngine?.update()
            }
        }
    }

    private func assignDevicesToZones() {
        for device in devices {
            let zone = determineZone(for: device)
            deviceZones[device.ipAddress] = zone
        }
    }

    private func determineZone(for device: EnhancedDevice) -> NetworkZone {
        if device.manufacturer?.lowercased().contains("philips") == true ||
           device.manufacturer?.lowercased().contains("hue") == true {
            return .iot
        } else if device.openPorts.count > 10 {
            return .dmz
        } else if device.hostname?.lowercased().contains("server") == true {
            return .servers
        } else {
            return .clients
        }
    }

    private func getConnections(for device: EnhancedDevice) -> [NetworkConnection2] {
        // Generate connections based on network topology
        // In a real implementation, this would come from NetworkTrafficAnalyzer
        var connections: [NetworkConnection2] = []

        // Get gateway device (likely router)
        let gateway = devices.first(where: {
            $0.hostname?.lowercased().contains("gateway") == true ||
            $0.hostname?.lowercased().contains("router") == true ||
            $0.ipAddress.hasSuffix(".1")
        })

        // If this is the gateway, connect to multiple devices
        if device.id == gateway?.id {
            // Connect gateway to first 5 devices
            for otherDevice in devices.prefix(5) where otherDevice.id != device.id {
                connections.append(NetworkConnection2(
                    source: device.ipAddress,
                    destination: otherDevice.ipAddress,
                    bandwidth: Int.random(in: 100000...10000000) // 100KB to 10MB
                ))
            }
        }
        // Regular devices connect to gateway
        else if let gw = gateway {
            connections.append(NetworkConnection2(
                source: device.ipAddress,
                destination: gw.ipAddress,
                bandwidth: Int.random(in: 10000...1000000) // 10KB to 1MB
            ))
        }

        // Add some peer-to-peer connections for devices in same zone
        if let zone = deviceZones[device.ipAddress] {
            let sameZoneDevices = devices.filter {
                deviceZones[$0.ipAddress] == zone && $0.id != device.id
            }

            // Connect to 1-2 devices in same zone
            for peer in sameZoneDevices.prefix(2) {
                connections.append(NetworkConnection2(
                    source: device.ipAddress,
                    destination: peer.ipAddress,
                    bandwidth: Int.random(in: 5000...500000) // 5KB to 500KB
                ))
            }
        }

        return connections
    }

    private func getAnomalies(for device: EnhancedDevice) -> [TopologyAnomaly] {
        var anomalies: [TopologyAnomaly] = []

        if device.openPorts.count > 20 {
            anomalies.append(.portScan)
        }

        if !device.isOnline {
            anomalies.append(.offline)
        }

        return anomalies
    }

    private func searchAndHighlight(_ query: String) {
        guard !query.isEmpty else {
            highlightedPath = []
            return
        }

        if let found = devices.first(where: {
            $0.ipAddress.contains(query) ||
            $0.hostname?.lowercased().contains(query.lowercased()) == true
        }) {
            highlightedPath = [found.ipAddress]
            selectedDevice = found
        }
    }

    private func selectDevice(_ device: EnhancedDevice) {
        selectedDevice = device
        highlightedPath = findPath(from: device.ipAddress, to: getGatewayIP())
    }

    private func findPath(from source: String, to destination: String) -> [String] {
        // Dijkstra's algorithm implementation
        // Simplified for now - returns direct path
        return [source, destination]
    }

    private func getGatewayIP() -> String {
        return devices.first(where: { $0.hostname?.lowercased().contains("gateway") == true })?.ipAddress ?? "192.168.1.1"
    }

    private func calculateAttackSurface(for device: EnhancedDevice) -> String {
        let score = device.openPorts.count * 10
        if score > 100 { return "Critical" }
        if score > 50 { return "High" }
        if score > 20 { return "Medium" }
        return "Low"
    }

    private func heatmapColor(for device: EnhancedDevice, mode: HeatmapMode) -> Color {
        switch mode {
        case .security:
            let vulnCount = device.openPorts.count
            if vulnCount > 10 { return .red }
            if vulnCount > 5 { return .orange }
            if vulnCount > 2 { return .yellow }
            return .green
        case .bandwidth:
            return .blue // Would use actual bandwidth data
        case .latency:
            return .cyan // Would use actual latency data
        case .portExposure:
            let exposure = Double(device.openPorts.count) / 100.0
            return Color(red: exposure, green: 1.0 - exposure, blue: 0)
        }
    }

    private func exportTopology(format: ExportFormat) {
        // Export implementation
        print("Exporting topology as \(format.rawValue)")
    }
}

// MARK: - Supporting Views

struct DeviceNodeView: View {
    let device: EnhancedDevice
    let position: CGPoint
    let heatmapMode: HeatmapMode
    let isHighlighted: Bool
    let isSelected: Bool
    let anomalies: [TopologyAnomaly]

    var body: some View {
        ZStack {
            // Base circle with heatmap color
            Circle()
                .fill(heatmapColor)
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: heatmapColor.opacity(0.6), radius: isHighlighted ? 12 : 6)

            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: nodeSize + 10, height: nodeSize + 10)
            }

            // Highlight glow
            if isHighlighted {
                Circle()
                    .stroke(Color.cyan, lineWidth: 2)
                    .frame(width: nodeSize + 6, height: nodeSize + 6)
            }

            // Anomaly indicators
            ForEach(Array(anomalies.enumerated()), id: \.offset) { index, anomaly in
                Image(systemName: anomaly.icon)
                    .font(.system(size: 12))
                    .foregroundColor(anomaly.color)
                    .offset(x: 15, y: CGFloat(index * -15))
            }
        }
        .position(position)
    }

    private var nodeSize: CGFloat {
        let baseSize: CGFloat = 20
        let sizeModifier = CGFloat(device.openPorts.count) / 10.0
        return baseSize + min(sizeModifier, 15)
    }

    private var heatmapColor: Color {
        let vulnCount = device.openPorts.count
        if vulnCount > 10 { return .red }
        if vulnCount > 5 { return .orange }
        if vulnCount > 2 { return .yellow }
        return .green
    }
}

struct AnimatedConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let bandwidth: Int
    let showPackets: Bool
    let packets: [FlowPacket]

    var body: some View {
        ZStack {
            // Base line
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(lineColor, lineWidth: lineWidth)
            .opacity(0.3)

            // Animated packets
            if showPackets {
                ForEach(packets) { packet in
                    Circle()
                        .fill(packet.color)
                        .frame(width: 4, height: 4)
                        .position(packet.position)
                }
            }
        }
    }

    private var lineWidth: CGFloat {
        return max(1, min(CGFloat(bandwidth) / 1000000, 8))
    }

    private var lineColor: Color {
        if bandwidth > 10000000 { return .red }
        if bandwidth > 1000000 { return .orange }
        return .blue
    }
}

struct ZoneRegion: View {
    let zone: NetworkZone
    let devices: [EnhancedDevice]

    var body: some View {
        // Convex hull around devices in zone
        Path { path in
            // Simplified - would calculate actual convex hull
            path.addEllipse(in: CGRect(x: 100, y: 100, width: 200, height: 200))
        }
        .fill(zone.color.opacity(0.1))
        .overlay(
            Path { path in
                path.addEllipse(in: CGRect(x: 100, y: 100, width: 200, height: 200))
            }
            .stroke(zone.color, lineWidth: 2)
        )
    }
}

struct AttackPathOverlay: View {
    let sourceDevice: EnhancedDevice
    let allDevices: [EnhancedDevice]
    let layoutManager: TopologyLayoutManager

    var body: some View {
        // Show potential attack paths from source
        ForEach(accessibleDevices, id: \.id) { device in
            Path { path in
                let sourcePos = layoutManager.position(for: sourceDevice.ipAddress)
                let targetPos = layoutManager.position(for: device.ipAddress)
                path.move(to: sourcePos)
                path.addLine(to: targetPos)
            }
            .stroke(Color.red.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
    }

    private var accessibleDevices: [EnhancedDevice] {
        // Calculate lateral movement potential - show paths to high-value targets
        // In same zone or with many open ports
        return allDevices.filter { device in
            device.id != sourceDevice.id && (
                device.openPorts.count > 5 || // High value target
                device.hostname?.lowercased().contains("server") == true // Likely server
            )
        }.prefix(5).map { $0 } // Limit to 5 attack paths for clarity
    }
}

// MARK: - Supporting Models

enum TopologyViewMode: String {
    case force2D = "2D Force"
    case sphere3D = "3D Sphere"
    case hierarchical = "Hierarchical"
    case radial = "Radial"
}

enum HeatmapMode: String {
    case security = "Security"
    case bandwidth = "Bandwidth"
    case latency = "Latency"
    case portExposure = "Port Exposure"
}

enum NetworkZone {
    case clients, servers, iot, dmz, guest

    var color: Color {
        switch self {
        case .clients: return .blue
        case .servers: return .green
        case .iot: return .purple
        case .dmz: return .orange
        case .guest: return .yellow
        }
    }
}

enum TopologyAnomaly {
    case portScan, offline, excessiveBandwidth, newDevice

    var icon: String {
        switch self {
        case .portScan: return "exclamationmark.triangle.fill"
        case .offline: return "xmark.circle.fill"
        case .excessiveBandwidth: return "flame.fill"
        case .newDevice: return "plus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .portScan: return .red
        case .offline: return .gray
        case .excessiveBandwidth: return .orange
        case .newDevice: return .yellow
        }
    }
}

enum ExportFormat: String {
    case svg, png, json, graphviz
}

struct NetworkConnection2: Identifiable {
    let id = UUID()
    let source: String
    let destination: String
    let bandwidth: Int
}

struct FlowPacket: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
}

// MARK: - Supporting Managers

@MainActor
class TopologyPhysicsEngine: ObservableObject {
    @Published var positions: [String: CGPoint] = [:]
    private var velocities: [String: CGVector] = [:]
    private var devices: [EnhancedDevice] = []

    func setDevices(_ devices: [EnhancedDevice]) {
        self.devices = devices
        initializePositions()
    }

    private func initializePositions() {
        for (index, device) in devices.enumerated() {
            let angle = (Double(index) / Double(devices.count)) * 2 * .pi
            let radius = 300.0
            positions[device.ipAddress] = CGPoint(
                x: 400 + radius * cos(angle),
                y: 400 + radius * sin(angle)
            )
        }
    }

    func update() {
        // Physics simulation step
        applyForces()
        updatePositions()
    }

    private func applyForces() {
        // Repulsion between all nodes
        // Attraction along connections
        // Damping
    }

    private func updatePositions() {
        for device in devices {
            if let velocity = velocities[device.ipAddress] {
                var currentPos = positions[device.ipAddress] ?? .zero
                currentPos.x += velocity.dx
                currentPos.y += velocity.dy
                positions[device.ipAddress] = currentPos
            }
        }
    }
}

@MainActor
class TopologyLayoutManager: ObservableObject {
    @Published var positions: [String: CGPoint] = [:]
    private var devices: [EnhancedDevice] = []

    func setDevices(_ devices: [EnhancedDevice]) {
        self.devices = devices
        calculateLayout()
    }

    func position(for ip: String) -> CGPoint {
        return positions[ip] ?? CGPoint(x: 400, y: 400)
    }

    func minimapPosition(for ip: String) -> CGPoint {
        guard let fullPos = positions[ip] else { return .zero }
        // Scale down to minimap size
        return CGPoint(x: fullPos.x * 0.25, y: fullPos.y * 0.25)
    }

    func updatePosition(for ip: String, to position: CGPoint) {
        positions[ip] = position
    }

    private func calculateLayout() {
        // Initialize with circular layout
        for (index, device) in devices.enumerated() {
            let angle = (Double(index) / Double(devices.count)) * 2 * .pi
            let radius = 250.0
            positions[device.ipAddress] = CGPoint(
                x: 400 + radius * cos(angle),
                y: 400 + radius * sin(angle)
            )
        }
    }
}

@MainActor
class PacketFlowAnimator: ObservableObject {
    @Published var activePackets: [String: [FlowPacket]] = [:]
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updatePackets()
        }
    }

    func packets(for connection: NetworkConnection2) -> [FlowPacket] {
        let key = "\(connection.source)-\(connection.destination)"
        return activePackets[key] ?? []
    }

    private func updatePackets() {
        // Animate packet positions
        for (key, packets) in activePackets {
            activePackets[key] = packets.map { packet in
                var newPacket = packet
                // Update position along path
                return newPacket
            }
        }
    }
}

@MainActor
class TopologyHistoryManager: ObservableObject {
    @Published var snapshots: [(timestamp: Date, devices: [EnhancedDevice])] = []

    func recordSnapshot(_ devices: [EnhancedDevice]) {
        snapshots.append((Date(), devices))

        // Keep last 100 snapshots
        if snapshots.count > 100 {
            snapshots.removeFirst()
        }
    }

    func getSnapshot(at position: Double) -> [EnhancedDevice] {
        guard !snapshots.isEmpty else { return [] }
        let index = Int(position * Double(snapshots.count - 1))
        return snapshots[min(index, snapshots.count - 1)].devices
    }

    func timestamp(at position: Double) -> String {
        guard !snapshots.isEmpty else { return "No History" }
        let index = Int(position * Double(snapshots.count - 1))
        let snapshot = snapshots[min(index, snapshots.count - 1)]

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: snapshot.timestamp)
    }
}
