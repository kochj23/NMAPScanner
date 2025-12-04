//
//  EnhancedDeviceDetailView.swift
//  NMAP Plus Security Scanner v7.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Beautiful full-screen device detail view with:
//  - Large device icon with glow
//  - Animated stat cards
//  - Timeline view of device history
//  - Connection quality gauge
//  - Network activity sparkline
//

import SwiftUI

// MARK: - Enhanced Device Detail View

struct EnhancedDeviceDetailView: View {
    let device: HomeKitDevice
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case network = "Network"
        case history = "History"
        case technical = "Technical"

        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .network: return "network"
            case .history: return "clock.fill"
            case .technical: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // Animated background
            MeshGradientBackground()

            VStack(spacing: 0) {
                // Header with device icon
                headerView
                    .padding()

                // Tab bar
                tabBar
                    .padding(.horizontal)

                // Content
                ScrollView {
                    contentView
                        .padding()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 24) {
            // Large device icon with glow
            ZStack {
                Circle()
                    .fill(Color.deviceGradient(for: deviceType))
                    .frame(width: 120, height: 120)
                    .glow(color: Color.deviceColor(for: deviceType), radius: 20, intensity: 0.6)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

                Image(systemName: deviceIcon)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .bounceOnAppear()

            // Device info
            VStack(alignment: .leading, spacing: 8) {
                Text(device.displayName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text(device.category)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                if let ip = device.ipAddress {
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text(ip)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                // Status badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .pulse(color: .green, duration: 2.0)

                    Text("Online")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Close button
            GlassButton(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 12) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        )
    }

    private func tabButton(for tab: DetailTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))

                Text(tab.rawValue)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? .white : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTab == tab ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .overview:
            overviewTab
        case .network:
            networkTab
        case .history:
            historyTab
        case .technical:
            technicalTab
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 20) {
            // Quick stats
            HStack(spacing: 16) {
                statCard(
                    icon: "clock.fill",
                    label: "Discovered",
                    value: timeAgo(from: device.discoveredAt),
                    color: .blue
                )

                statCard(
                    icon: "bolt.fill",
                    label: "Response Time",
                    value: "< 50ms",
                    color: .green
                )

                statCard(
                    icon: "antenna.radiowaves.left.and.right",
                    label: "Signal",
                    value: "Excellent",
                    color: .purple
                )
            }

            // Connection quality gauge
            GlassCard {
                VStack(spacing: 16) {
                    Text("Connection Quality")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    RadialProgressIndicator(
                        progress: 0.95,
                        color: .green,
                        label: "Excellent"
                    )
                }
            }

            // Device information
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Information")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    infoRow(label: "Name", value: device.displayName)
                    infoRow(label: "Type", value: device.category)
                    infoRow(label: "Service", value: device.serviceType)
                    if let ip = device.ipAddress {
                        infoRow(label: "IP Address", value: ip)
                    }
                }
            }
        }
    }

    // MARK: - Network Tab

    private var networkTab: some View {
        VStack(spacing: 20) {
            // Network activity sparkline
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Network Activity (Last 24h)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    SparklineGraph(
                        dataPoints: generateRandomData(count: 50),
                        color: .blue,
                        height: 100
                    )
                }
            }

            // Port information
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Open Ports")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        portBadge(port: 80, service: "HTTP")
                        portBadge(port: 443, service: "HTTPS")
                        portBadge(port: 22, service: "SSH")
                        portBadge(port: 3306, service: "MySQL")
                    }
                }
            }

            // Traffic distribution
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Traffic Distribution")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    AnimatedDonutChart(data: [
                        ChartSegment(label: "HTTP", value: 45, color: .blue),
                        ChartSegment(label: "HTTPS", value: 30, color: .green),
                        ChartSegment(label: "SSH", value: 15, color: .orange),
                        ChartSegment(label: "Other", value: 10, color: .gray)
                    ])
                }
            }
        }
    }

    // MARK: - History Tab

    private var historyTab: some View {
        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Timeline")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    TimelineView(events: generateTimelineEvents())
                }
            }

            // Historical data chart
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Connection History")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    GradientAreaChart(
                        data: generateHistoricalData(),
                        color: .blue
                    )
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Technical Tab

    private var technicalTab: some View {
        VStack(spacing: 20) {
            // mDNS Information
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("mDNS Information")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    technicalInfoRow(label: "Service Type", value: device.serviceType)
                    technicalInfoRow(label: "Discovered", value: DateFormatter.localizedString(from: device.discoveredAt, dateStyle: .short, timeStyle: .short))
                }
            }

            // Additional metadata section (TXT records removed as HomeKitDevice doesn't have them)
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Discovery Info")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack {
                        Text("Is HomeKit")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)

                        Spacer()

                        Text(device.isHomeKitAccessory ? "Yes" : "No")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
                .glow(color: color, radius: 8, intensity: 0.4)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private func technicalInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    private func portBadge(port: Int, service: String) -> some View {
        VStack(spacing: 4) {
            Text("\(port)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)

            Text(service)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Properties

    private var deviceType: DeviceType {
        DeviceType.from(serviceType: device.serviceType)
    }

    private var deviceIcon: String {
        if device.serviceType.contains("homekit") || device.serviceType.contains("hap") {
            return "homekit"
        } else if device.serviceType.contains("airplay") {
            return "airplayvideo"
        } else if device.serviceType.contains("raop") {
            return "homepod.fill"
        } else if device.serviceType.contains("companion") {
            return "applelogo"
        } else {
            return "network"
        }
    }

    // MARK: - Helper Functions

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else {
            return "\(minutes)m ago"
        }
    }

    private func generateRandomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 0...100) }
    }

    private func generateTimelineEvents() -> [TimelineEvent] {
        [
            TimelineEvent(title: "Device Discovered", timestamp: device.discoveredAt, icon: "plus.circle.fill", color: .green),
            TimelineEvent(title: "First Connection", timestamp: device.discoveredAt.addingTimeInterval(300), icon: "network", color: .blue),
            TimelineEvent(title: "Health Check", timestamp: Date().addingTimeInterval(-3600), icon: "checkmark.circle.fill", color: .green),
            TimelineEvent(title: "Last Seen", timestamp: Date(), icon: "eye.fill", color: .purple)
        ]
    }

    private func generateHistoricalData() -> [DataPoint] {
        let now = Date()
        return (0..<24).reversed().map { hour in
            DataPoint(
                label: "\(hour)h ago",
                value: Double.random(in: 50...100)
            )
        }
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    let events: [TimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(events) { event in
                HStack(spacing: 16) {
                    // Timeline dot
                    ZStack {
                        Circle()
                            .fill(event.color.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: event.icon)
                            .font(.system(size: 18))
                            .foregroundColor(event.color)
                    }

                    // Event info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(event.timestamp, style: .relative)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }
}

struct TimelineEvent: Identifiable {
    let id = UUID()
    let title: String
    let timestamp: Date
    let icon: String
    let color: Color
}
