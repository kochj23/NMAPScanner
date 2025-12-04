//
//  LCARSDashboardVisualizations.swift
//  NMAPScanner - Star Trek LCARS-Inspired Security Visualizations
//
//  Created by Jordan Koch on 2025-11-27.
//

import SwiftUI
import Charts

// MARK: - LCARS Color Palette

struct LCARSColors {
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let paleOrange = Color(red: 1.0, green: 0.8, blue: 0.6)
    static let red = Color(red: 0.8, green: 0.0, blue: 0.0)
    static let peach = Color(red: 1.0, green: 0.7, blue: 0.5)
    static let yellow = Color(red: 1.0, green: 0.9, blue: 0.0)
    static let blue = Color(red: 0.6, green: 0.8, blue: 1.0)
    static let skyBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let purple = Color(red: 0.7, green: 0.4, blue: 1.0)
    static let lavender = Color(red: 0.9, green: 0.7, blue: 1.0)
    static let tan = Color(red: 0.8, green: 0.7, blue: 0.5)
    static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let panelBackground = Color(red: 0.1, green: 0.1, blue: 0.15)
}

// MARK: - 1. Network Security Health Ring Chart

struct NetworkSecurityHealthRing: View {
    let securityScore: Int
    let criticalIssues: Int
    let highIssues: Int
    let mediumIssues: Int

    @State private var animatedScore: Double = 0

    var securityGrade: String {
        switch securityScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    var gradeColor: Color {
        switch securityScore {
        case 90...100: return LCARSColors.blue
        case 80..<90: return LCARSColors.skyBlue
        case 70..<80: return LCARSColors.yellow
        case 60..<70: return LCARSColors.orange
        default: return LCARSColors.red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // LCARS Header
            HStack {
                Text("NETWORK SECURITY STATUS")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                Text("STARFLEET COMMAND")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LCARSColors.blue)
            }
            .padding(.horizontal, 20)

            ZStack {
                // Outer rings
                ForEach(0..<3) { ring in
                    Circle()
                        .stroke(
                            LCARSColors.panelBackground,
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: CGFloat(280 - ring * 30), height: CGFloat(280 - ring * 30))
                }

                // Animated security ring
                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                LCARSColors.red,
                                LCARSColors.orange,
                                LCARSColors.yellow,
                                LCARSColors.blue
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 25, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: gradeColor.opacity(0.8), radius: 20)

                // Center content
                VStack(spacing: 8) {
                    Text(securityGrade)
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(gradeColor)

                    Text("\(Int(animatedScore))%")
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .foregroundColor(LCARSColors.paleOrange)

                    Text("SECURITY RATING")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(LCARSColors.blue)
                }
            }
            .frame(height: 320)

            // Issue breakdown
            HStack(spacing: 20) {
                IssueIndicator(count: criticalIssues, label: "CRITICAL", color: LCARSColors.red)
                IssueIndicator(count: highIssues, label: "HIGH", color: LCARSColors.orange)
                IssueIndicator(count: mediumIssues, label: "MEDIUM", color: LCARSColors.yellow)
            }
            .padding(.horizontal, 20)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0)) {
                animatedScore = Double(securityScore)
            }
        }
    }
}

struct IssueIndicator: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(LCARSColors.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .cornerRadius(10)
    }
}

// MARK: - 2. Live Threat Heatmap

struct LiveThreatHeatmap: View {
    let devices: [EnhancedDevice]
    let vulnerabilityScanner: VulnerabilityScanner

    private let columns = 8

    private func getThreatLevel(for device: EnhancedDevice) -> LCARSThreatLevel {
        let vulnCount = vulnerabilityScanner.vulnerabilities.filter { $0.host == device.ipAddress }.count

        if vulnCount > 5 || !device.isOnline {
            return .critical
        } else if vulnCount > 2 {
            return .high
        } else if vulnCount > 0 {
            return .medium
        } else {
            return .secure
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // LCARS Header
            HStack {
                Text("THREAT DETECTION GRID")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                HStack(spacing: 16) {
                    LegendItem(color: LCARSColors.blue, label: "SECURE")
                    LegendItem(color: LCARSColors.yellow, label: "MEDIUM")
                    LegendItem(color: LCARSColors.orange, label: "HIGH")
                    LegendItem(color: LCARSColors.red, label: "CRITICAL")
                }
            }
            .padding(.horizontal, 20)

            // Heatmap Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(devices.prefix(32)) { device in
                    ThreatCell(device: device, threatLevel: getThreatLevel(for: device))
                }
            }
            .padding(20)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
    }
}

struct ThreatCell: View {
    let device: EnhancedDevice
    let threatLevel: LCARSThreatLevel

    @State private var isHovered = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(threatLevel.color.opacity(isHovered ? 0.8 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(threatLevel.color, lineWidth: isHovered ? 3 : 1)
                )
                .shadow(color: threatLevel.color.opacity(0.6), radius: isHovered ? 8 : 3)

            if isHovered {
                VStack(spacing: 2) {
                    Text(device.hostname ?? device.ipAddress)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if device.hostname != nil {
                        Text(device.ipAddress)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(LCARSColors.paleOrange)
                    }
                }
            }
        }
        .frame(height: 60)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

enum LCARSThreatLevel {
    case secure, medium, high, critical

    var color: Color {
        switch self {
        case .secure: return LCARSColors.blue
        case .medium: return LCARSColors.yellow
        case .high: return LCARSColors.orange
        case .critical: return LCARSColors.red
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(LCARSColors.blue)
        }
    }
}

// MARK: - 3. Vulnerability Severity Donut Chart

struct VulnerabilityDonutChart: View {
    let critical: Int
    let high: Int
    let medium: Int
    let low: Int

    var total: Int {
        critical + high + medium + low
    }

    @State private var animationProgress: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // LCARS Header
            HStack {
                Text("VULNERABILITY ANALYSIS")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
            }
            .padding(.horizontal, 20)

            ZStack {
                // Donut segments
                if total > 0 {
                    DonutSegment(
                        startAngle: 0,
                        endAngle: 360 * Double(critical) / Double(total) * animationProgress,
                        color: LCARSColors.red
                    )

                    DonutSegment(
                        startAngle: 360 * Double(critical) / Double(total),
                        endAngle: 360 * Double(critical + high) / Double(total) * animationProgress,
                        color: LCARSColors.orange
                    )

                    DonutSegment(
                        startAngle: 360 * Double(critical + high) / Double(total),
                        endAngle: 360 * Double(critical + high + medium) / Double(total) * animationProgress,
                        color: LCARSColors.yellow
                    )

                    DonutSegment(
                        startAngle: 360 * Double(critical + high + medium) / Double(total),
                        endAngle: 360 * animationProgress,
                        color: LCARSColors.blue
                    )
                }

                // Center content
                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(LCARSColors.orange)
                    Text("VULNERABILITIES")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(LCARSColors.blue)
                }
            }
            .frame(width: 250, height: 250)

            // Legend
            VStack(spacing: 12) {
                DonutLegendRow(count: critical, label: "CRITICAL", color: LCARSColors.red, total: total)
                DonutLegendRow(count: high, label: "HIGH", color: LCARSColors.orange, total: total)
                DonutLegendRow(count: medium, label: "MEDIUM", color: LCARSColors.yellow, total: total)
                DonutLegendRow(count: low, label: "LOW", color: LCARSColors.blue, total: total)
            }
            .padding(.horizontal, 20)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
}

struct DonutSegment: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color

    var body: some View {
        Circle()
            .trim(from: startAngle / 360, to: endAngle / 360)
            .stroke(color, style: StrokeStyle(lineWidth: 40, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.6), radius: 8)
    }
}

struct DonutLegendRow: View {
    let count: Int
    let label: String
    let color: Color
    let total: Int

    var percentage: Int {
        total > 0 ? (count * 100) / total : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)

            Text(label)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(LCARSColors.paleOrange)
                .frame(width: 80, alignment: .leading)

            ProgressView(value: Double(count), total: Double(max(total, 1)))
                .progressViewStyle(LCARSProgressStyle(color: color))

            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)

            Text("\(percentage)%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(LCARSColors.blue)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct LCARSProgressStyle: ProgressViewStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LCARSColors.panelBackground)
                    .frame(height: 10)
                    .cornerRadius(5)

                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 10)
                    .cornerRadius(5)
                    .shadow(color: color.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - 4. Timeline of Security Events

struct SecurityEventsTimeline: View {
    let events: [SecurityEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // LCARS Header
            HStack {
                Text("SECURITY EVENT LOG")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                Text("LAST 24 HOURS")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LCARSColors.blue)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(events.prefix(20)) { event in
                        TimelineEventCard(event: event)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
    }
}

struct SecurityEvent: Identifiable {
    let id = UUID()
    let type: EventType
    let title: String
    let timestamp: Date
    let severity: LCARSThreatLevel

    enum EventType {
        case vulnerability, malware, anomaly, portScan, breach, authentication

        var icon: String {
            switch self {
            case .vulnerability: return "exclamationmark.shield.fill"
            case .malware: return "ant.fill"
            case .anomaly: return "waveform.path.ecg"
            case .portScan: return "network.badge.shield.half.filled"
            case .breach: return "lock.open.fill"
            case .authentication: return "person.badge.key.fill"
            }
        }
    }
}

struct TimelineEventCard: View {
    let event: SecurityEvent
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(event.severity.color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: event.type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(event.severity.color)
            }
            .shadow(color: event.severity.color.opacity(0.6), radius: 8)

            // Time
            Text(formatTime(event.timestamp))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(LCARSColors.orange)

            // Title
            Text(event.title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(LCARSColors.paleOrange)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
        }
        .padding(12)
        .background(event.severity.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(event.severity.color, lineWidth: 2)
        )
        .scaleEffect(isVisible ? 1.0 : 0.5)
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 5. IoT Security Gauge Dashboard

struct IoTSecurityGaugeDashboard: View {
    let devices: [EnhancedDevice]
    let iotScores: [IoTSecurityScore]

    var iotDevices: [EnhancedDevice] {
        devices.filter { $0.deviceType == .iot }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // LCARS Header
            HStack {
                Text("IoT DEVICE SECURITY MATRIX")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                Text("\(iotDevices.count) DEVICES")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LCARSColors.blue)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(iotDevices.prefix(6)) { device in
                    if let score = iotScores.first(where: { $0.device.id == device.id }) {
                        IoTSecurityGauge(device: device, score: score)
                    }
                }
            }
            .padding(20)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
    }
}

struct IoTSecurityGauge: View {
    let device: EnhancedDevice
    let score: IoTSecurityScore

    @State private var animatedScore: Double = 0

    var gaugeColor: Color {
        switch score.score {
        case 80...100: return LCARSColors.blue
        case 60..<80: return LCARSColors.yellow
        default: return LCARSColors.red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Gauge
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(LCARSColors.panelBackground, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(135))

                // Score arc
                Circle()
                    .trim(from: 0, to: 0.75 * (animatedScore / 100))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(135))
                    .shadow(color: gaugeColor.opacity(0.6), radius: 8)

                // Center display
                VStack(spacing: 2) {
                    Text("\(Int(animatedScore))")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(gaugeColor)

                    Text(score.grade)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(LCARSColors.orange)
                }
            }

            // Device info
            VStack(spacing: 4) {
                Text(device.hostname ?? device.ipAddress)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.paleOrange)
                    .lineLimit(1)

                if device.hostname != nil {
                    Text(device.ipAddress)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(LCARSColors.blue)
                }
            }
        }
        .padding(16)
        .background(gaugeColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(gaugeColor, lineWidth: 2)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedScore = Double(score.score)
            }
        }
    }
}

// MARK: - 6. Real-Time Bandwidth Meter

struct RealTimeBandwidthMeter: View {
    let currentBandwidth: Int // bytes per second
    let maxBandwidth: Int = 1_000_000_000 // 1 Gbps

    @State private var animatedValue: Double = 0

    var percentage: Double {
        min(Double(currentBandwidth) / Double(maxBandwidth), 1.0)
    }

    var displayValue: String {
        if currentBandwidth >= 1_000_000_000 {
            return String(format: "%.2f GB/s", Double(currentBandwidth) / 1_000_000_000)
        } else if currentBandwidth >= 1_000_000 {
            return String(format: "%.2f MB/s", Double(currentBandwidth) / 1_000_000)
        } else {
            return String(format: "%.2f KB/s", Double(currentBandwidth) / 1_000)
        }
    }

    var gaugeColor: Color {
        switch percentage {
        case 0..<0.5: return LCARSColors.blue
        case 0.5..<0.8: return LCARSColors.yellow
        default: return LCARSColors.red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // LCARS Header
            HStack {
                Text("BANDWIDTH MONITOR")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                Text("REAL-TIME")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LCARSColors.blue)
            }
            .padding(.horizontal, 20)

            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(LCARSColors.panelBackground, style: StrokeStyle(lineWidth: 30, lineCap: .round))
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(135))

                // Animated gauge arc
                Circle()
                    .trim(from: 0, to: 0.75 * animatedValue)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                LCARSColors.blue,
                                LCARSColors.yellow,
                                LCARSColors.red
                            ]),
                            center: .center,
                            startAngle: .degrees(135),
                            endAngle: .degrees(405)
                        ),
                        style: StrokeStyle(lineWidth: 30, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(135))
                    .shadow(color: gaugeColor.opacity(0.8), radius: 15)

                // Center display
                VStack(spacing: 8) {
                    Text(displayValue)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(gaugeColor)

                    Text("CURRENT THROUGHPUT")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(LCARSColors.blue)

                    Text("\(Int(percentage * 100))% CAPACITY")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(LCARSColors.orange)
                }
            }
            .frame(height: 300)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                animatedValue = percentage
            }
        }
        .onChange(of: currentBandwidth) { newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = min(Double(newValue) / Double(maxBandwidth), 1.0)
            }
        }
    }
}

// MARK: - 7. Anomaly Detection Radar Chart

struct AnomalyDetectionRadar: View {
    let portScanning: Double // 0-1
    let bandwidthSpikes: Double
    let timeAnomalies: Double
    let externalConnections: Double
    let dataExfiltration: Double
    let beaconing: Double

    @State private var animationProgress: Double = 0

    var axes: [(label: String, value: Double, angle: Double)] {
        [
            ("PORT\nSCANNING", portScanning, 0),
            ("BANDWIDTH\nSPIKES", bandwidthSpikes, 60),
            ("TIME\nANOMALIES", timeAnomalies, 120),
            ("EXTERNAL\nCONNECTIONS", externalConnections, 180),
            ("DATA\nEXFILTRATION", dataExfiltration, 240),
            ("BEACONING", beaconing, 300)
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            // LCARS Header
            HStack {
                Text("ANOMALY DETECTION MATRIX")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                Text("ACTIVE MONITORING")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LCARSColors.blue)
            }
            .padding(.horizontal, 20)

            ZStack {
                // Background grid circles
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(LCARSColors.panelBackground, lineWidth: 1)
                        .frame(width: 280 * scale, height: 280 * scale)
                }

                // Axis lines
                ForEach(axes, id: \.label) { axis in
                    Path { path in
                        let center = CGPoint(x: 150, y: 150)
                        let endpoint = polarToCartesian(
                            radius: 140,
                            angle: axis.angle,
                            center: center
                        )
                        path.move(to: center)
                        path.addLine(to: endpoint)
                    }
                    .stroke(LCARSColors.blue.opacity(0.3), lineWidth: 1)
                }

                // Data polygon
                Path { path in
                    let center = CGPoint(x: 150, y: 150)
                    for (index, axis) in axes.enumerated() {
                        let point = polarToCartesian(
                            radius: 140 * axis.value * animationProgress,
                            angle: axis.angle,
                            center: center
                        )
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                }
                .fill(LCARSColors.orange.opacity(0.3))
                .overlay(
                    Path { path in
                        let center = CGPoint(x: 150, y: 150)
                        for (index, axis) in axes.enumerated() {
                            let point = polarToCartesian(
                                radius: 140 * axis.value * animationProgress,
                                angle: axis.angle,
                                center: center
                            )
                            if index == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                        path.closeSubpath()
                    }
                    .stroke(LCARSColors.orange, lineWidth: 3)
                    .shadow(color: LCARSColors.orange.opacity(0.6), radius: 8)
                )

                // Axis labels
                ForEach(axes, id: \.label) { axis in
                    Text(axis.label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(LCARSColors.paleOrange)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                        .position(
                            polarToCartesian(
                                radius: 170,
                                angle: axis.angle,
                                center: CGPoint(x: 150, y: 150)
                            )
                        )
                }

                // Data points
                ForEach(axes, id: \.label) { axis in
                    Circle()
                        .fill(riskColor(axis.value))
                        .frame(width: 12, height: 12)
                        .shadow(color: riskColor(axis.value).opacity(0.8), radius: 6)
                        .position(
                            polarToCartesian(
                                radius: 140 * axis.value * animationProgress,
                                angle: axis.angle,
                                center: CGPoint(x: 150, y: 150)
                            )
                        )
                }
            }
            .frame(width: 300, height: 300)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }

    private func polarToCartesian(radius: Double, angle: Double, center: CGPoint) -> CGPoint {
        let radians = (angle - 90) * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    private func riskColor(_ value: Double) -> Color {
        switch value {
        case 0..<0.3: return LCARSColors.blue
        case 0.3..<0.6: return LCARSColors.yellow
        case 0.6..<0.8: return LCARSColors.orange
        default: return LCARSColors.red
        }
    }
}

// MARK: - 8. Top Security Risks Panel

struct TopSecurityRisksPanel: View {
    let risks: [SecurityRisk]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // LCARS Header
            HStack {
                Text("TOP SECURITY THREATS")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.orange)
                Spacer()
                Text("PRIORITY ALERTS")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LCARSColors.blue)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(Array(risks.prefix(10).enumerated()), id: \.element.id) { index, risk in
                    SecurityRiskRow(rank: index + 1, risk: risk)
                }
            }
            .padding(20)
        }
        .padding(24)
        .background(LCARSColors.panelBackground)
        .cornerRadius(20)
    }
}

struct SecurityRisk: Identifiable {
    let id = UUID()
    let title: String
    let severity: LCARSThreatLevel
    let affectedDevices: Int
    let category: String
}

struct SecurityRiskRow: View {
    let rank: Int
    let risk: SecurityRisk

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(risk.severity.color)
                    .frame(width: 50, height: 50)

                Text("\(rank)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Risk info
            VStack(alignment: .leading, spacing: 4) {
                Text(risk.title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(LCARSColors.paleOrange)

                HStack(spacing: 12) {
                    Label(risk.category, systemImage: "tag.fill")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(LCARSColors.blue)

                    Label("\(risk.affectedDevices) devices", systemImage: "network")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(LCARSColors.orange)
                }
            }

            Spacer()

            // Severity bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(LCARSColors.panelBackground)
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(risk.severity.color)
                        .frame(width: isVisible ? geometry.size.width * 0.9 : 0, height: 8)
                        .cornerRadius(4)
                        .shadow(color: risk.severity.color.opacity(0.6), radius: 4)
                }
            }
            .frame(width: 100, height: 8)
        }
        .padding(12)
        .background(risk.severity.color.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(risk.severity.color, lineWidth: 2)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(rank) * 0.1)) {
                isVisible = true
            }
        }
    }
}
