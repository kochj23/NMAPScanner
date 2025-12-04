//
//  NetworkVisualizationComponents.swift
//  NMAPScanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-29.
//  Visual components for network traffic and topology
//

import SwiftUI

// MARK: - Animated Pulse Indicator

struct PulsingIndicator: View {
    let color: Color
    let size: CGFloat
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size, height: size)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0.0 : 1.0)

            Circle()
                .fill(color)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Sparkline Graph

struct SparklineGraph: View {
    let dataPoints: [Double]
    let color: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            if dataPoints.count >= 2 {
                Path { path in
                    let maxValue = dataPoints.max() ?? 1.0
                    let minValue = dataPoints.min() ?? 0.0
                    let range = maxValue - minValue == 0 ? 1.0 : maxValue - minValue
                    let width = geometry.size.width
                    let stepX = width / CGFloat(dataPoints.count - 1)

                    for (index, value) in dataPoints.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue = (value - minValue) / range
                        let y = height - (CGFloat(normalizedValue) * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Bandwidth Meter

struct BandwidthMeter: View {
    let bytesPerSecond: Double
    let maxBandwidth: Double = 10_000_000 // 10 MB/s

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text(formatBandwidth(bytesPerSecond))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(bandwidthColor)
                        .frame(width: geometry.size.width * CGFloat(min(bytesPerSecond / maxBandwidth, 1.0)))
                }
            }
            .frame(height: 6)
        }
    }

    private var bandwidthColor: Color {
        let percentage = bytesPerSecond / maxBandwidth
        if percentage < 0.3 { return .green }
        if percentage < 0.7 { return .yellow }
        return .red
    }

    private func formatBandwidth(_ bytes: Double) -> String {
        let kb = bytes / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 { return String(format: "%.2f MB/s", mb) }
        if kb >= 1.0 { return String(format: "%.2f KB/s", kb) }
        return String(format: "%.0f B/s", bytes)
    }
}

// MARK: - Traffic Protocol Breakdown Chart

struct TrafficProtocolBreakdownChart: View {
    let breakdown: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protocol Distribution")
                .font(.system(size: 16, weight: .semibold))

            if breakdown.isEmpty {
                Text("No traffic data")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                let total = breakdown.values.reduce(0, +)

                ForEach(Array(breakdown.sorted(by: { $0.value > $1.value })), id: \.key) { proto, count in
                    HStack {
                        Text(proto)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 60, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForProtocol(proto))
                                    .frame(width: geometry.size.width * CGFloat(count) / CGFloat(total))
                            }
                        }
                        .frame(height: 20)

                        Text("\(count)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func colorForProtocol(_ proto: String) -> Color {
        switch proto {
        case "TCP": return .blue
        case "UDP": return .green
        case "ICMP": return .orange
        default: return .purple
        }
    }
}

// MARK: - Device Health Badge

struct DeviceHealthBadge: View {
    let grade: String
    let score: Double // 0.0 - 1.0

    var body: some View {
        HStack(spacing: 4) {
            Text(grade)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(gradeColor)
                .clipShape(Circle())

            if score >= 0 {
                Text("\(Int(score * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(gradeColor)
            }
        }
    }

    private var gradeColor: Color {
        switch grade {
        case "A": return .green
        case "B": return Color(red: 0.6, green: 0.8, blue: 0.2)
        case "C": return .yellow
        case "D": return .orange
        case "F": return .red
        default: return .gray
        }
    }
}

// MARK: - Quick Action Buttons

struct QuickActionButtons: View {
    let device: EnhancedDevice
    let onWhitelist: () -> Void
    let onBlock: () -> Void
    let onDeepScan: () -> Void
    let onIsolate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ActionButton(icon: "checkmark.shield", color: .green, label: "Whitelist", action: onWhitelist)
            ActionButton(icon: "hand.raised", color: .red, label: "Block", action: onBlock)
            ActionButton(icon: "magnifyingglass", color: .blue, label: "Deep Scan", action: onDeepScan)
            ActionButton(icon: "lock.shield", color: .orange, label: "Isolate", action: onIsolate)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isHovered ? .white : color)
            .frame(width: 60, height: 50)
            .background(isHovered ? color : color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Relative Time Formatter

extension Date {
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Last Seen Indicator

struct LastSeenIndicator: View {
    let date: Date

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 11))
            Text(date.relativeTimeString())
                .font(.system(size: 11))
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Connection Line (for topology)

struct ConnectionLine: Shape {
    var start: CGPoint
    var end: CGPoint

    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set {
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Animated Packet Flow

struct AnimatedPacketFlow: View {
    let flow: PacketFlow
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        ZStack {
            // Connection line
            ConnectionLine(start: start, end: end)
                .stroke(colorForProtocol(flow.protocolType), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .opacity(0.3)

            // Moving packet
            Circle()
                .fill(colorForProtocol(flow.protocolType))
                .frame(width: 8, height: 8)
                .position(interpolatedPosition)
                .shadow(color: colorForProtocol(flow.protocolType).opacity(0.6), radius: 4)
        }
    }

    private var interpolatedPosition: CGPoint {
        let progress = CGFloat(flow.animationProgress)
        return CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private func colorForProtocol(_ proto: PacketFlow.ProtocolType) -> Color {
        switch proto {
        case .tcp: return .blue
        case .udp: return .green
        case .icmp: return .orange
        case .other: return .purple
        }
    }
}

// MARK: - Scanning Wave Effect

struct ScanningWave: View {
    let center: CGPoint
    let maxRadius: CGFloat
    @State private var waveProgress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.blue.opacity(1.0 - waveProgress), lineWidth: 2)
                    .frame(width: maxRadius * 2 * waveProgress, height: maxRadius * 2 * waveProgress)
                    .position(center)
                    .opacity(1.0 - waveProgress)
                    .animation(
                        .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                        value: waveProgress
                    )
            }
        }
        .onAppear {
            waveProgress = 1.0
        }
    }
}

// MARK: - Heat Map Overlay

struct HeatMapOverlay: View {
    let activityLevel: Double // 0.0 - 1.0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [heatMapColor.opacity(activityLevel * 0.7), heatMapColor.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 50
                )
            )
            .frame(width: 100, height: 100)
            .blur(radius: 20)
    }

    private var heatMapColor: Color {
        if activityLevel < 0.2 { return .green }
        if activityLevel < 0.5 { return .yellow }
        if activityLevel < 0.8 { return .orange }
        return .red
    }
}
