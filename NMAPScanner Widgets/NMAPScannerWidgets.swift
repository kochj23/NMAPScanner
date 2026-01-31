//
//  NMAPScannerWidgets.swift
//  NMAPScanner Widgets
//
//  WidgetKit widgets for macOS - Security status, device count, threats
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct SecurityWidgetEntry: TimelineEntry {
    let date: Date
    let deviceCount: Int
    let threatCount: Int
    let lastScanTime: Date?
    let nextScheduledScan: Date?
    let isScanning: Bool
    let securityScore: Int // 0-100
    let recentDevices: [WidgetDevice]
}

struct WidgetDevice: Identifiable, Codable {
    let id: String
    let name: String
    let ipAddress: String
    let isOnline: Bool
    let isThreat: Bool
    let deviceType: String
}

// MARK: - Timeline Provider

struct SecurityWidgetProvider: TimelineProvider {
    typealias Entry = SecurityWidgetEntry

    func placeholder(in context: Context) -> SecurityWidgetEntry {
        SecurityWidgetEntry(
            date: Date(),
            deviceCount: 24,
            threatCount: 0,
            lastScanTime: Date().addingTimeInterval(-3600),
            nextScheduledScan: Date().addingTimeInterval(3600),
            isScanning: false,
            securityScore: 95,
            recentDevices: [
                WidgetDevice(id: "1", name: "MacBook Pro", ipAddress: "192.168.1.100", isOnline: true, isThreat: false, deviceType: "computer"),
                WidgetDevice(id: "2", name: "iPhone", ipAddress: "192.168.1.101", isOnline: true, isThreat: false, deviceType: "phone"),
                WidgetDevice(id: "3", name: "Smart TV", ipAddress: "192.168.1.102", isOnline: true, isThreat: false, deviceType: "tv")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SecurityWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SecurityWidgetEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh every 5 minutes for security monitoring
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> SecurityWidgetEntry {
        let data = SecurityWidgetDataStore.shared.loadData()
        return SecurityWidgetEntry(
            date: Date(),
            deviceCount: data.deviceCount,
            threatCount: data.threatCount,
            lastScanTime: data.lastScanTime,
            nextScheduledScan: data.nextScheduledScan,
            isScanning: data.isScanning,
            securityScore: data.securityScore,
            recentDevices: data.recentDevices
        )
    }
}

// MARK: - Widget Data Store

class SecurityWidgetDataStore {
    static let shared = SecurityWidgetDataStore()

    private let suiteName = "group.com.jordankoch.NMAPScanner"
    private let dataKey = "widgetData"

    struct WidgetData: Codable {
        let deviceCount: Int
        let threatCount: Int
        let lastScanTime: Date?
        let nextScheduledScan: Date?
        let isScanning: Bool
        let securityScore: Int
        let recentDevices: [WidgetDevice]
    }

    func loadData() -> WidgetData {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: dataKey),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return WidgetData(
                deviceCount: 0,
                threatCount: 0,
                lastScanTime: nil,
                nextScheduledScan: nil,
                isScanning: false,
                securityScore: 100,
                recentDevices: []
            )
        }
        return widgetData
    }

    func saveData(_ data: WidgetData) {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data) else { return }
        userDefaults.set(encoded, forKey: dataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Security Status Widget View

struct SecurityStatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: SecurityWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(spacing: 8) {
            // Security score ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(entry.securityScore) / 100)
                    .stroke(securityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(entry.securityScore)")
                        .font(.title.bold())
                        .foregroundColor(securityColor)
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            // Status
            HStack(spacing: 4) {
                if entry.threatCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(entry.threatCount)")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Secure")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }

            Text("\(entry.deviceCount) devices")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left side - Security score
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: CGFloat(entry.securityScore) / 100)
                        .stroke(securityColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(entry.securityScore)")
                            .font(.title2.bold())
                            .foregroundColor(securityColor)
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 70, height: 70)

                if entry.isScanning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Scanning...")
                            .font(.caption2)
                    }
                }
            }

            Divider()

            // Right side - Stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.cyan)
                    Text("NMAPScanner")
                        .font(.headline)
                }

                Spacer()

                StatRow(icon: "desktopcomputer", label: "Devices", value: "\(entry.deviceCount)", color: .blue)

                if entry.threatCount > 0 {
                    StatRow(icon: "exclamationmark.triangle.fill", label: "Threats", value: "\(entry.threatCount)", color: .red)
                } else {
                    StatRow(icon: "checkmark.shield.fill", label: "Status", value: "Secure", color: .green)
                }

                Spacer()

                // Last scan time
                if let lastScan = entry.lastScanTime {
                    Text("Last scan: \(lastScan, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Large Widget

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(.cyan)

                VStack(alignment: .leading) {
                    Text("NMAPScanner")
                        .font(.headline)
                    Text("Network Security Monitor")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Security score badge
                VStack {
                    Text("\(entry.securityScore)")
                        .font(.title.bold())
                        .foregroundColor(securityColor)
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(securityColor.opacity(0.15))
                .cornerRadius(12)
            }

            Divider()

            // Stats grid
            HStack(spacing: 16) {
                StatCard(icon: "desktopcomputer", label: "Devices", value: "\(entry.deviceCount)", color: .blue)
                StatCard(icon: entry.threatCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                        label: "Threats",
                        value: entry.threatCount > 0 ? "\(entry.threatCount)" : "None",
                        color: entry.threatCount > 0 ? .red : .green)
            }

            Divider()

            // Recent devices
            Text("Recent Devices")
                .font(.subheadline.bold())

            ForEach(entry.recentDevices.prefix(4)) { device in
                DeviceRow(device: device)
            }

            Spacer()

            // Footer
            HStack {
                if let lastScan = entry.lastScanTime {
                    Text("Last scan: \(lastScan, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let nextScan = entry.nextScheduledScan {
                    Text("Next: \(nextScan, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var securityColor: Color {
        if entry.threatCount > 0 { return .red }
        if entry.securityScore >= 90 { return .green }
        if entry.securityScore >= 70 { return .yellow }
        return .orange
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: WidgetDevice

    var body: some View {
        HStack {
            Image(systemName: iconForDeviceType(device.deviceType))
                .foregroundColor(device.isThreat ? .red : (device.isOnline ? .green : .secondary))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(device.ipAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(device.isOnline ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }

    private func iconForDeviceType(_ type: String) -> String {
        switch type {
        case "computer": return "desktopcomputer"
        case "phone": return "iphone"
        case "tablet": return "ipad"
        case "tv": return "tv"
        case "router": return "wifi.router"
        case "iot": return "sensor.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Widget Bundle

@main
struct NMAPScannerWidgetBundle: WidgetBundle {
    var body: some Widget {
        SecurityStatusWidget()
        DeviceCountWidget()
    }
}

// MARK: - Security Status Widget

struct SecurityStatusWidget: Widget {
    let kind: String = "SecurityStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SecurityWidgetProvider()) { entry in
            SecurityStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Security Status")
        .description("Monitor your network security")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Device Count Widget View

struct DeviceCountWidgetView: View {
    let entry: SecurityWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.blue)
                Text("Devices")
                    .font(.headline)
            }

            Spacer()

            Text("\(entry.deviceCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.blue)

            Text("on network")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Circle()
                    .fill(entry.threatCount > 0 ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text(entry.threatCount > 0 ? "\(entry.threatCount) threats" : "All secure")
                    .font(.caption2)
                    .foregroundColor(entry.threatCount > 0 ? .red : .green)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Device Count Widget

struct DeviceCountWidget: Widget {
    let kind: String = "DeviceCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SecurityWidgetProvider()) { entry in
            DeviceCountWidgetView(entry: entry)
        }
        .configurationDisplayName("Device Count")
        .description("Quick view of network devices")
        .supportedFamilies([.systemSmall])
    }
}
