//
//  DependencyGraphView.swift
//  NMAPScanner - Service Dependency Graph Visualization
//
//  Created by Jordan Koch on 2026-02-02.
//  Visual graph showing service connections and dependencies
//

import SwiftUI

// MARK: - Main Dependency Graph View

struct DependencyGraphView: View {
    let devices: [EnhancedDevice]

    @StateObject private var tracker = ServiceDependencyTracker.shared
    @State private var selectedNode: ServiceNode?
    @State private var selectedConnection: ServiceConnection?
    @State private var filterCategory: ServiceCategory?
    @State private var showOnlyAI = false
    @State private var highlightSPOF = true
    @State private var viewMode: GraphViewMode = .circular
    @State private var zoomLevel: CGFloat = 1.0

    enum GraphViewMode: String, CaseIterable {
        case circular = "Circular"
        case hierarchical = "Hierarchical"
        case force = "Force-Directed"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header and Controls
            headerView

            Divider()

            // Main Content
            HStack(spacing: 0) {
                // Graph Canvas
                graphCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Side Panel
                if selectedNode != nil || selectedConnection != nil {
                    sidePanel
                        .frame(width: 320)
                        .transition(.move(edge: .trailing))
                }
            }

            Divider()

            // Legend
            legendBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            tracker.detectDependencies(devices: devices)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Service Dependency Map")
                        .font(.system(size: 28, weight: .bold))

                    if let lastTime = tracker.lastAnalysisTime {
                        Text("Last analyzed: \(lastTime, formatter: timeFormatter)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // View Mode Picker
                Picker("View", selection: $viewMode) {
                    ForEach(GraphViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                // Refresh Button
                Button(action: {
                    tracker.detectDependencies(devices: devices)
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(tracker.isAnalyzing)
            }

            HStack(spacing: 16) {
                // Category Filter
                Menu {
                    Button("All Categories") {
                        filterCategory = nil
                    }
                    Divider()
                    ForEach(ServiceCategory.allCases) { category in
                        Button(action: { filterCategory = category }) {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterCategory?.rawValue ?? "All Categories")
                    }
                }

                // AI Filter Toggle
                Toggle("AI Services Only", isOn: $showOnlyAI)

                // SPOF Highlight Toggle
                Toggle("Highlight Single Points of Failure", isOn: $highlightSPOF)

                Spacer()

                // Stats
                HStack(spacing: 20) {
                    DependencyStatBadge(label: "Services", value: "\(filteredNodes.count)", color: .blue)
                    DependencyStatBadge(label: "Connections", value: "\(filteredConnections.count)", color: .green)
                    DependencyStatBadge(label: "SPOFs", value: "\(tracker.singlePointsOfFailure.count)", color: .red)
                }
            }
        }
        .padding()
    }

    // MARK: - Graph Canvas

    private var graphCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.controlBackgroundColor)

                if tracker.isAnalyzing {
                    // Loading State
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing service dependencies...")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                } else if filteredNodes.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No services found")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Run a network scan to discover services")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Graph Content
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack {
                            // Connection Lines
                            ForEach(filteredConnections) { connection in
                                ConnectionLineView(
                                    connection: connection,
                                    nodes: filteredNodes,
                                    geometry: geometry,
                                    viewMode: viewMode,
                                    isSelected: selectedConnection?.id == connection.id
                                )
                                .onTapGesture {
                                    selectedConnection = connection
                                    selectedNode = nil
                                }
                            }

                            // Service Nodes
                            ForEach(filteredNodes) { node in
                                ServiceNodeView(
                                    node: node,
                                    position: nodePosition(for: node, in: geometry.size),
                                    isSelected: selectedNode?.id == node.id,
                                    isSPOF: tracker.singlePointsOfFailure.contains(node),
                                    highlightSPOF: highlightSPOF,
                                    tracker: tracker
                                )
                                .onTapGesture {
                                    selectedNode = node
                                    selectedConnection = nil
                                }
                            }
                        }
                        .frame(
                            width: max(geometry.size.width, CGFloat(filteredNodes.count * 120)),
                            height: max(geometry.size.height, CGFloat(filteredNodes.count * 80))
                        )
                        .scaleEffect(zoomLevel)
                    }
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoomLevel = min(max(value, 0.5), 3.0)
                    }
            )
        }
    }

    // MARK: - Side Panel

    private var sidePanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if selectedNode != nil {
                    Text("Service Details")
                        .font(.system(size: 18, weight: .semibold))
                } else if selectedConnection != nil {
                    Text("Connection Details")
                        .font(.system(size: 18, weight: .semibold))
                }

                Spacer()

                Button(action: {
                    selectedNode = nil
                    selectedConnection = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                if let node = selectedNode {
                    ServiceNodeDetailView(node: node, tracker: tracker)
                } else if let connection = selectedConnection {
                    ConnectionDetailView(connection: connection)
                }
            }
        }
    }

    // MARK: - Legend Bar

    private var legendBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                Text("Categories:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                ForEach(ServiceCategory.allCases) { category in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 12, height: 12)
                        Text(category.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .frame(height: 20)

                Text("Connections:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                ForEach([ConnectionType.inference, .database, .api, .cache]) { type in
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 12))
                            .foregroundColor(type.color)
                        Text(type.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Computed Properties

    private var filteredNodes: [ServiceNode] {
        var nodes = tracker.serviceNodes

        if let category = filterCategory {
            nodes = nodes.filter { $0.category == category }
        }

        if showOnlyAI {
            nodes = nodes.filter { $0.category == .aiMl }
        }

        return nodes
    }

    private var filteredConnections: [ServiceConnection] {
        var connections = tracker.connections

        if showOnlyAI {
            connections = connections.filter { $0.connectionType == .inference }
        }

        // Filter to only show connections between visible nodes
        let visibleKeys = Set(filteredNodes.map { $0.uniqueKey })
        connections = connections.filter { conn in
            let sourceKey = "\(conn.sourceHost):\(conn.sourcePort)"
            let destKey = "\(conn.destHost):\(conn.destPort)"
            return visibleKeys.contains(sourceKey) && visibleKeys.contains(destKey)
        }

        return connections
    }

    // MARK: - Layout Helpers

    private func nodePosition(for node: ServiceNode, in size: CGSize) -> CGPoint {
        let nodes = filteredNodes
        guard let index = nodes.firstIndex(of: node) else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        switch viewMode {
        case .circular:
            return circularPosition(index: index, total: nodes.count, size: size)
        case .hierarchical:
            return hierarchicalPosition(for: node, index: index, size: size)
        case .force:
            return forceDirectedPosition(for: node, index: index, size: size)
        }
    }

    private func circularPosition(index: Int, total: Int, size: CGSize) -> CGPoint {
        let angle = (Double(index) / Double(max(total, 1))) * 2 * .pi - .pi / 2
        let radius = min(size.width, size.height) * 0.35
        let centerX = size.width / 2
        let centerY = size.height / 2

        return CGPoint(
            x: centerX + CGFloat(Darwin.cos(angle)) * radius,
            y: centerY + CGFloat(Darwin.sin(angle)) * radius
        )
    }

    private func hierarchicalPosition(for node: ServiceNode, index: Int, size: CGSize) -> CGPoint {
        // Group by category, arrange in layers
        let categories = ServiceCategory.allCases
        guard let categoryIndex = categories.firstIndex(of: node.category) else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let layerHeight = size.height / CGFloat(categories.count + 1)
        let y = layerHeight * CGFloat(categoryIndex + 1)

        // Get nodes in same category
        let sameCategory = filteredNodes.filter { $0.category == node.category }
        guard let posInCategory = sameCategory.firstIndex(of: node) else {
            return CGPoint(x: size.width / 2, y: y)
        }

        let spacing = size.width / CGFloat(sameCategory.count + 1)
        let x = spacing * CGFloat(posInCategory + 1)

        return CGPoint(x: x, y: y)
    }

    private func forceDirectedPosition(for node: ServiceNode, index: Int, size: CGSize) -> CGPoint {
        // Simplified force-directed layout using category grouping
        // AI/ML at top, databases at bottom, web servers in middle
        let categoryOffsets: [ServiceCategory: CGPoint] = [
            .aiMl: CGPoint(x: 0, y: -0.3),
            .database: CGPoint(x: 0, y: 0.3),
            .webServer: CGPoint(x: -0.2, y: 0),
            .mediaServer: CGPoint(x: 0.2, y: 0),
            .devOps: CGPoint(x: -0.3, y: 0.15),
            .messaging: CGPoint(x: 0.3, y: 0.15),
            .storage: CGPoint(x: 0, y: 0.2),
            .network: CGPoint(x: 0, y: -0.2),
            .monitoring: CGPoint(x: 0.25, y: -0.15),
            .other: CGPoint(x: 0, y: 0)
        ]

        let offset = categoryOffsets[node.category] ?? .zero
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Add some jitter based on index to spread nodes
        let jitterAngle = Double(index) * 0.5
        let jitterRadius = 50.0 + Double(index % 5) * 20

        return CGPoint(
            x: centerX + offset.x * size.width * 0.4 + cos(jitterAngle) * jitterRadius,
            y: centerY + offset.y * size.height * 0.4 + sin(jitterAngle) * jitterRadius
        )
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Service Node View

struct ServiceNodeView: View {
    let node: ServiceNode
    let position: CGPoint
    let isSelected: Bool
    let isSPOF: Bool
    let highlightSPOF: Bool
    let tracker: ServiceDependencyTracker

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .fill(node.category.color.opacity(0.2))
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: node.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(node.category.color)

                // SPOF indicator
                if isSPOF && highlightSPOF {
                    Circle()
                        .stroke(Color.red, lineWidth: 3)
                        .frame(width: 62, height: 62)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .offset(x: 20, y: -20)
                }

                // Selection ring
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 66, height: 66)
                }
            }

            // Service name
            Text(node.serviceName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: 80)

            // Host:port
            Text("\(node.host):\(node.port)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)

            // Connection count badge
            let connections = tracker.getConnections(for: node)
            let totalConnections = connections.incoming.count + connections.outgoing.count
            if totalConnections > 0 {
                HStack(spacing: 2) {
                    if connections.incoming.count > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "arrow.down")
                            Text("\(connections.incoming.count)")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    }
                    if connections.outgoing.count > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "arrow.up")
                            Text("\(connections.outgoing.count)")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isSelected ? 8 : 4)
        )
        .position(position)
    }
}

// MARK: - Connection Line View

struct ConnectionLineView: View {
    let connection: ServiceConnection
    let nodes: [ServiceNode]
    let geometry: GeometryProxy
    let viewMode: DependencyGraphView.GraphViewMode
    let isSelected: Bool

    var body: some View {
        let sourceNode = nodes.first { $0.host == connection.sourceHost && $0.port == connection.sourcePort }
        let destNode = nodes.first { $0.host == connection.destHost && $0.port == connection.destPort }

        if let source = sourceNode, let dest = destNode {
            let sourcePos = nodePosition(for: source)
            let destPos = nodePosition(for: dest)

            ZStack {
                // Line
                Path { path in
                    path.move(to: sourcePos)

                    // Add curve for better visualization
                    let midX = (sourcePos.x + destPos.x) / 2
                    let midY = (sourcePos.y + destPos.y) / 2
                    let offset = abs(sourcePos.x - destPos.x) * 0.2

                    path.addQuadCurve(
                        to: destPos,
                        control: CGPoint(x: midX, y: midY - offset)
                    )
                }
                .stroke(
                    connection.connectionType.color.opacity(isSelected ? 1.0 : 0.6),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 3 : 2,
                        dash: connection.isInferred ? [5, 5] : []
                    )
                )

                // Arrow at destination
                arrowHead(from: sourcePos, to: destPos)
                    .fill(connection.connectionType.color)

                // Connection type icon at midpoint
                let midPoint = CGPoint(
                    x: (sourcePos.x + destPos.x) / 2,
                    y: (sourcePos.y + destPos.y) / 2 - 15
                )

                Image(systemName: connection.connectionType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(connection.connectionType.color)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(radius: 2)
                    )
                    .position(midPoint)
            }
        }
    }

    private func nodePosition(for node: ServiceNode) -> CGPoint {
        guard let index = nodes.firstIndex(of: node) else {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }

        switch viewMode {
        case .circular:
            let angle = (Double(index) / Double(max(nodes.count, 1))) * 2 * .pi - .pi / 2
            let radius = min(geometry.size.width, geometry.size.height) * 0.35
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            return CGPoint(
                x: centerX + CGFloat(Darwin.cos(angle)) * radius,
                y: centerY + CGFloat(Darwin.sin(angle)) * radius
            )
        case .hierarchical:
            let categories = ServiceCategory.allCases
            guard let categoryIndex = categories.firstIndex(of: node.category) else {
                return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            let layerHeight = geometry.size.height / CGFloat(categories.count + 1)
            let y = layerHeight * CGFloat(categoryIndex + 1)
            let sameCategory = nodes.filter { $0.category == node.category }
            guard let posInCategory = sameCategory.firstIndex(of: node) else {
                return CGPoint(x: geometry.size.width / 2, y: y)
            }
            let spacing = geometry.size.width / CGFloat(sameCategory.count + 1)
            let x = spacing * CGFloat(posInCategory + 1)
            return CGPoint(x: x, y: y)
        case .force:
            let categoryOffsets: [ServiceCategory: CGPoint] = [
                .aiMl: CGPoint(x: 0, y: -0.3),
                .database: CGPoint(x: 0, y: 0.3),
                .webServer: CGPoint(x: -0.2, y: 0),
                .mediaServer: CGPoint(x: 0.2, y: 0),
                .devOps: CGPoint(x: -0.3, y: 0.15),
                .messaging: CGPoint(x: 0.3, y: 0.15),
                .storage: CGPoint(x: 0, y: 0.2),
                .network: CGPoint(x: 0, y: -0.2),
                .monitoring: CGPoint(x: 0.25, y: -0.15),
                .other: CGPoint(x: 0, y: 0)
            ]
            let offset = categoryOffsets[node.category] ?? .zero
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            let jitterAngle = Double(index) * 0.5
            let jitterRadius = 50.0 + Double(index % 5) * 20
            return CGPoint(
                x: centerX + offset.x * geometry.size.width * 0.4 + cos(jitterAngle) * jitterRadius,
                y: centerY + offset.y * geometry.size.height * 0.4 + sin(jitterAngle) * jitterRadius
            )
        }
    }

    private func arrowHead(from: CGPoint, to: CGPoint) -> Path {
        let arrowLength: CGFloat = 10
        let arrowWidth: CGFloat = 8

        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowPoint = CGPoint(
            x: to.x - 30 * cos(angle),
            y: to.y - 30 * sin(angle)
        )

        return Path { path in
            path.move(to: arrowPoint)
            path.addLine(to: CGPoint(
                x: arrowPoint.x - arrowLength * cos(angle - .pi / 6),
                y: arrowPoint.y - arrowLength * sin(angle - .pi / 6)
            ))
            path.addLine(to: CGPoint(
                x: arrowPoint.x - arrowLength * cos(angle + .pi / 6),
                y: arrowPoint.y - arrowLength * sin(angle + .pi / 6)
            ))
            path.closeSubpath()
        }
    }
}

// MARK: - Service Node Detail View

struct ServiceNodeDetailView: View {
    let node: ServiceNode
    let tracker: ServiceDependencyTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Service Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: node.category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(node.category.color)

                    VStack(alignment: .leading) {
                        Text(node.serviceName)
                            .font(.system(size: 18, weight: .semibold))
                        Text(node.category.rawValue)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                DependencyInfoRow(label: "Host", value: node.host)
                DependencyInfoRow(label: "Port", value: "\(node.port)")
                if let version = node.version {
                    DependencyInfoRow(label: "Version", value: version)
                }
                if let deviceName = node.deviceName {
                    DependencyInfoRow(label: "Device", value: deviceName)
                }

                HStack {
                    Circle()
                        .fill(node.isRunning ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(node.isRunning ? "Running" : "Offline")
                        .font(.system(size: 14))
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            // SPOF Warning
            if tracker.singlePointsOfFailure.contains(node) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Single Point of Failure")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Connections
            let connections = tracker.getConnections(for: node)

            if !connections.incoming.isEmpty {
                ConnectionListSection(
                    title: "Incoming Connections",
                    connections: connections.incoming,
                    isIncoming: true
                )
            }

            if !connections.outgoing.isEmpty {
                ConnectionListSection(
                    title: "Outgoing Connections",
                    connections: connections.outgoing,
                    isIncoming: false
                )
            }

            // Dependency Chain
            let chains = tracker.getDependencyChain(from: node)
            if !chains.isEmpty && chains.first?.count ?? 0 > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dependency Chain")
                        .font(.system(size: 16, weight: .semibold))

                    ForEach(chains.prefix(3), id: \.self) { chain in
                        HStack(spacing: 4) {
                            ForEach(chain.indices, id: \.self) { index in
                                if index > 0 {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Text(chain[index].serviceName)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(chain[index].category.color.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Connection Detail View

struct ConnectionDetailView: View {
    let connection: ServiceConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Connection Header
            HStack {
                Image(systemName: connection.connectionType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(connection.connectionType.color)

                VStack(alignment: .leading) {
                    Text(connection.connectionType.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                    Text(connection.isInferred ? "Inferred" : "Observed")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Source
            VStack(alignment: .leading, spacing: 4) {
                Text("Source")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(connection.sourceService)
                    .font(.system(size: 16, weight: .medium))

                Text("\(connection.sourceHost):\(connection.sourcePort)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "arrow.down")
                .font(.system(size: 20))
                .foregroundColor(connection.connectionType.color)
                .frame(maxWidth: .infinity)

            // Destination
            VStack(alignment: .leading, spacing: 4) {
                Text("Destination")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(connection.destService)
                    .font(.system(size: 16, weight: .medium))

                Text("\(connection.destHost):\(connection.destPort)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(connection.description)
                    .font(.system(size: 14))
            }

            // Confidence
            HStack {
                Text("Confidence")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(connection.confidence * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(confidenceColor)
            }

            ProgressView(value: connection.confidence)
                .tint(confidenceColor)

            Spacer()
        }
        .padding()
    }

    private var confidenceColor: Color {
        if connection.confidence >= 0.8 { return .green }
        if connection.confidence >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Connection List Section

struct ConnectionListSection: View {
    let title: String
    let connections: [ServiceConnection]
    let isIncoming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))

            ForEach(connections) { connection in
                HStack {
                    Image(systemName: connection.connectionType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(connection.connectionType.color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isIncoming ? connection.sourceService : connection.destService)
                            .font(.system(size: 14, weight: .medium))

                        Text(isIncoming
                             ? "\(connection.sourceHost):\(connection.sourcePort)"
                             : "\(connection.destHost):\(connection.destPort)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(connection.connectionType.rawValue)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(connection.connectionType.color.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct DependencyStatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

struct DependencyInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, design: .monospaced))
        }
    }
}

// MARK: - Preview

#Preview {
    DependencyGraphView(devices: [])
        .frame(width: 1200, height: 800)
}
