//
//  MonitoringViews.swift
//  NMAP Scanner - Monitoring & Security Views
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI

// MARK: - Network Traffic View

struct NetworkTrafficView: View {
    @StateObject private var trafficManager = NetworkTrafficManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Network Traffic Monitor")
                    .font(.system(size: 50, weight: .bold))

                // Control buttons
                HStack(spacing: 20) {
                    Button(trafficManager.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                        if trafficManager.isMonitoring {
                            trafficManager.stopMonitoring()
                        } else {
                            trafficManager.startMonitoring()
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(trafficManager.isMonitoring ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Clear Stats") {
                        trafficManager.clearStatistics()
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }

                // Statistics
                StatisticsCard(statistics: trafficManager.statistics)

                // Active connections
                if !trafficManager.activeConnections.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Active Connections (\(trafficManager.activeConnections.count))")
                            .font(.system(size: 36, weight: .semibold))

                        ForEach(trafficManager.activeConnections) { connection in
                            ConnectionCard(connection: connection)
                        }
                    }
                }

                // Recent activity
                if !trafficManager.recentActivity.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Activity")
                            .font(.system(size: 36, weight: .semibold))

                        ForEach(trafficManager.recentActivity.prefix(10), id: \.timestamp) { activity in
                            HStack {
                                Text(formatTime(activity.timestamp))
                                    .font(.system(size: 18, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text(activity.description)
                                    .font(.system(size: 20))
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
            .padding(40)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct StatisticsCard: View {
    let statistics: TrafficStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Statistics")
                .font(.system(size: 36, weight: .semibold))

            HStack(spacing: 40) {
                StatItem(label: "Total Connections", value: "\(statistics.connectionCount)")
                StatItem(label: "Active", value: "\(statistics.activeConnections)")
                StatItem(label: "Failed", value: "\(statistics.failedConnections)")
            }

            HStack(spacing: 40) {
                StatItem(label: "Bytes In", value: statistics.formattedBytes(statistics.totalBytesIn))
                StatItem(label: "Bytes Out", value: statistics.formattedBytes(statistics.totalBytesOut))
                StatItem(label: "Total", value: statistics.formattedBytes(statistics.totalBytes))
            }

            if !statistics.protocolBreakdown.isEmpty {
                Text("Protocol Breakdown")
                    .font(.system(size: 28, weight: .medium))

                HStack(spacing: 30) {
                    ForEach(Array(statistics.protocolBreakdown.keys.sorted()), id: \.self) { proto in
                        StatItem(label: proto, value: "\(statistics.protocolBreakdown[proto] ?? 0)")
                    }
                }
            }
        }
        .padding(24)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

// StatItem is defined in DashboardView.swift

struct ConnectionCard: View {
    let connection: NetworkConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(connection.remoteEndpoint)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                Spacer()
                Text(connection.stateDescription)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor(connection.stateDescription))
            }

            HStack(spacing: 40) {
                Label("\(connection.protocolType)", systemImage: "network")
                    .font(.system(size: 18))
                Label(String(format: "%.1fs", connection.duration), systemImage: "clock")
                    .font(.system(size: 18))
                if connection.bytesIn > 0 || connection.bytesOut > 0 {
                    Label("↓ \(formatBytes(connection.bytesIn)) ↑ \(formatBytes(connection.bytesOut))", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 18))
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func statusColor(_ state: String) -> Color {
        switch state {
        case "Connected": return .green
        case "Failed": return .red
        case "Waiting": return .orange
        default: return .gray
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - Packet Capture View

struct PacketCaptureView: View {
    @StateObject private var captureManager = PacketCaptureManager()
    @State private var selectedPacket: CapturedPacket?
    @State private var filterHost: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Packet Capture")
                    .font(.system(size: 50, weight: .bold))

                // Controls
                HStack(spacing: 20) {
                    Button(captureManager.isCapturing ? "Stop Capture" : "Start Capture") {
                        if captureManager.isCapturing {
                            captureManager.stopCapture()
                        } else {
                            captureManager.startCapture()
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(captureManager.isCapturing ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Clear") {
                        captureManager.clearCapture()
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)

                    Button("Export") {
                        let report = captureManager.exportCapture()
                        print(report) // In real app, would share/save file
                    }
                    .font(.system(size: 24))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(10)
                }

                // Statistics
                CaptureStatsCard(stats: captureManager.statistics)

                // Filter controls
                VStack(alignment: .leading, spacing: 15) {
                    Text("Filters")
                        .font(.system(size: 32, weight: .semibold))

                    HStack(spacing: 15) {
                        FilterToggle(label: "TCP", isActive: captureManager.filter.protocols.contains(.tcp)) {
                            toggleProtocol(.tcp)
                        }
                        FilterToggle(label: "UDP", isActive: captureManager.filter.protocols.contains(.udp)) {
                            toggleProtocol(.udp)
                        }
                        FilterToggle(label: "HTTP", isActive: captureManager.filter.protocols.contains(.http)) {
                            toggleProtocol(.http)
                        }
                        FilterToggle(label: "HTTPS", isActive: captureManager.filter.protocols.contains(.https)) {
                            toggleProtocol(.https)
                        }
                        FilterToggle(label: "DNS", isActive: captureManager.filter.protocols.contains(.dns)) {
                            toggleProtocol(.dns)
                        }
                    }
                }

                // Packets list
                VStack(alignment: .leading, spacing: 15) {
                    Text("Captured Packets (\(captureManager.capturedPackets.count))")
                        .font(.system(size: 36, weight: .semibold))

                    if captureManager.capturedPackets.isEmpty {
                        Text("No packets captured yet")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                            .padding(40)
                    } else {
                        ForEach(captureManager.capturedPackets.prefix(50)) { packet in
                            PacketRow(packet: packet)
                                .onTapGesture {
                                    selectedPacket = packet
                                }
                        }
                    }
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedPacket) { packet in
            PacketDetailView(packet: packet)
        }
    }

    private func toggleProtocol(_ protocolType: CapturedPacket.PacketProtocol) {
        if captureManager.filter.protocols.contains(protocolType) {
            captureManager.filter.protocols.remove(protocolType)
        } else {
            captureManager.filter.protocols.insert(protocolType)
        }
    }
}

struct CaptureStatsCard: View {
    let stats: CaptureStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Capture Statistics")
                .font(.system(size: 32, weight: .semibold))

            HStack(spacing: 40) {
                StatItem(label: "Total Packets", value: "\(stats.totalPackets)")
                StatItem(label: "Dropped", value: "\(stats.droppedPackets)")
                StatItem(label: "Bytes", value: formatBytes(stats.bytesProcessed))
                if stats.packetsPerSecond > 0 {
                    StatItem(label: "Packets/sec", value: String(format: "%.1f", stats.packetsPerSecond))
                }
            }

            if !stats.protocolCounts.isEmpty {
                Text("Protocol Distribution")
                    .font(.system(size: 24, weight: .medium))

                HStack(spacing: 25) {
                    ForEach(Array(stats.protocolCounts.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { proto in
                        StatItem(label: proto.rawValue, value: "\(stats.protocolCounts[proto] ?? 0)")
                    }
                }
            }
        }
        .padding(24)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    }
}

struct FilterToggle: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isActive ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

struct PacketRow: View {
    let packet: CapturedPacket

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Text(packet.direction.symbol)
                .font(.system(size: 24))
                .foregroundColor(directionColor(packet.direction))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(packet.summary)
                    .font(.system(size: 18, design: .monospaced))

                Text(formatTimestamp(packet.timestamp))
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(packet.protocolType.rawValue)
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(protocolColor(packet.protocolType))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    private func directionColor(_ direction: CapturedPacket.PacketDirection) -> Color {
        switch direction {
        case .incoming: return .green
        case .outgoing: return .blue
        case .local: return .orange
        }
    }

    private func protocolColor(_ protocolType: CapturedPacket.PacketProtocol) -> Color {
        switch protocolType {
        case .tcp: return .blue
        case .udp: return .purple
        case .icmp: return .orange
        case .http: return .green
        case .https: return .cyan
        case .dns: return .pink
        default: return .gray
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

struct PacketDetailView: View {
    let packet: CapturedPacket
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Packet Details")
                        .font(.system(size: 40, weight: .bold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 24))
                }

                Text(packet.detailedDescription)
                    .font(.system(size: 20, design: .monospaced))
                    .padding(20)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                if let payload = packet.payload {
                    Text("Payload (\(payload.count) bytes)")
                        .font(.system(size: 28, weight: .semibold))

                    Text(payload.hexDump)
                        .font(.system(size: 16, design: .monospaced))
                        .padding(20)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                }
            }
            .padding(40)
        }
    }
}

extension Data {
    var hexDump: String {
        var output = ""
        var offset = 0

        while offset < count {
            let rowData = self[offset..<Swift.min(offset + 16, count)]
            let hex = rowData.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = rowData.map { (32...126).contains($0) ? Character(UnicodeScalar($0)) : "." }

            output += String(format: "%04X:  %-48s  %@\n", offset, hex, String(ascii))
            offset += 16
        }

        return output
    }
}
