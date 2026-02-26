//
//  ScannerAccessibilityHelpers.swift
//  NMAPScanner
//
//  Accessibility helpers for DynamicType, VoiceOver, and security alerts
//  Ensures network scanning is accessible to all users
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Scaled Font Extension

extension Font {
    /// Predefined scaled fonts for NMAPScanner
    static var scannerTitle: Font { .system(.title, design: .default, weight: .bold) }
    static var scannerHeadline: Font { .system(.headline, design: .default, weight: .semibold) }
    static var scannerBody: Font { .system(.body, design: .default) }
    static var scannerCaption: Font { .system(.caption, design: .default) }
    static var scannerMono: Font { .system(.body, design: .monospaced) }
}

// MARK: - Accessible Device Card

struct AccessibleDeviceCard: View {
    let deviceName: String
    let ipAddress: String
    let macAddress: String?
    let isOnline: Bool
    let isThreat: Bool
    let ports: [Int]
    let action: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: spacing) {
                // Status indicator and name
                HStack {
                    // Online indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deviceName)
                            .font(.scannerHeadline)

                        Text(ipAddress)
                            .font(.scannerMono)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isThreat {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: iconSize))
                            .accessibilityLabel("Potential threat")
                    }
                }

                // MAC address if available
                if let mac = macAddress {
                    Text("MAC: \(mac)")
                        .font(.scannerCaption)
                        .foregroundColor(.secondary)
                }

                // Open ports
                if !ports.isEmpty {
                    HStack {
                        Text("Ports:")
                            .font(.scannerCaption)
                            .foregroundColor(.secondary)

                        ForEach(ports.prefix(5), id: \.self) { port in
                            Text("\(port)")
                                .font(.scannerMono)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.2))
                                .cornerRadius(4)
                        }

                        if ports.count > 5 {
                            Text("+\(ports.count - 5)")
                                .font(.scannerCaption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(padding)
            .background(backgroundStyle)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isThreat ? Color.red : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap for device details")
        .accessibilityAddTraits(.isButton)
    }

    private var statusColor: Color {
        if isThreat { return .red }
        return isOnline ? .green : .secondary
    }

    private var backgroundStyle: some ShapeStyle {
        if isThreat {
            return Color.red.opacity(0.1)
        }
        return Color.secondary.opacity(0.1)
    }

    private var indicatorSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var iconSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 24 : 20
    }

    private var spacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 8
    }

    private var padding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 16
    }

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var accessibilityLabel: String {
        var label = deviceName
        label += ". IP address: \(ipAddress)"

        if isOnline {
            label += ". Currently online"
        } else {
            label += ". Currently offline"
        }

        if isThreat {
            label += ". Warning: Potential security threat detected"
        }

        if !ports.isEmpty {
            label += ". \(ports.count) open ports"
        }

        return label
    }
}

// MARK: - Accessible Scan Progress

struct AccessibleScanProgress: View {
    let progress: Double
    let currentHost: String?
    let devicesFound: Int
    let threatsFound: Int

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(spacing: spacing) {
            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(threatsFound > 0 ? .red : .cyan)
                .accessibilityLabel("Scan progress \(Int(progress * 100)) percent")

            // Progress text
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.scannerHeadline)

                Spacer()

                if let host = currentHost {
                    Text("Scanning: \(host)")
                        .font(.scannerCaption)
                        .foregroundColor(.secondary)
                }
            }

            // Stats
            HStack(spacing: 16) {
                AccessibilityStatBadge(
                    icon: "desktopcomputer",
                    value: "\(devicesFound)",
                    label: "Devices",
                    color: .blue
                )

                AccessibilityStatBadge(
                    icon: threatsFound > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                    value: "\(threatsFound)",
                    label: "Threats",
                    color: threatsFound > 0 ? .red : .green
                )
            }
        }
        .padding(padding)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var spacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var padding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 16
    }

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var accessibilityLabel: String {
        var label = "Scan progress \(Int(progress * 100)) percent"
        label += ". \(devicesFound) devices found"

        if threatsFound > 0 {
            label += ". Warning: \(threatsFound) potential threats detected"
        } else {
            label += ". No threats detected"
        }

        if let host = currentHost {
            label += ". Currently scanning \(host)"
        }

        return label
    }
}

// MARK: - Stat Badge

struct AccessibilityStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(color)

            Text(value)
                .font(.scannerHeadline)

            Text(label)
                .font(.scannerCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(padding)
        .background(color.opacity(0.1))
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var iconSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 28 : 24
    }

    private var padding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 8
    }
}

// MARK: - Security Alert View

struct AccessibleSecurityAlert: View {
    let threatCount: Int
    let threatDevices: [String]
    let action: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.red)

                VStack(alignment: .leading) {
                    Text("Security Alert")
                        .font(.scannerHeadline)
                        .foregroundColor(.red)

                    Text("\(threatCount) potential threat\(threatCount == 1 ? "" : "s") detected")
                        .font(.scannerCaption)
                }

                Spacer()
            }

            // Affected devices
            ForEach(threatDevices.prefix(3), id: \.self) { device in
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                    Text(device)
                        .font(.scannerBody)
                }
            }

            if threatDevices.count > 3 {
                Text("and \(threatDevices.count - 3) more...")
                    .font(.scannerCaption)
                    .foregroundColor(.secondary)
            }

            Button(action: action) {
                Text("View Details")
                    .font(.scannerBody)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(padding)
        .background(Color.red.opacity(0.1))
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.red, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var iconSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 32 : 28
    }

    private var spacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var padding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 16
    }

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var accessibilityLabel: String {
        var label = "Security alert. \(threatCount) potential threat"
        if threatCount != 1 { label += "s" }
        label += " detected."

        label += " Affected devices: \(threatDevices.joined(separator: ", "))."
        label += " Double tap to view details."

        return label
    }
}

// MARK: - VoiceOver Announcer for Security Events

struct SecurityVoiceOverAnnouncer {
    /// Announces a security alert
    static func announceThreatDetected(deviceName: String) {
        let message = "Security alert: Potential threat detected on \(deviceName)"
        announceMessage(message, priority: .high)
    }

    /// Announces scan completion
    static func announceScanComplete(devicesFound: Int, threatsFound: Int) {
        var message = "Scan complete. \(devicesFound) devices found."
        if threatsFound > 0 {
            message += " Warning: \(threatsFound) potential threats detected."
        } else {
            message += " No threats detected. Network is secure."
        }
        announceMessage(message, priority: .high)
    }

    /// Announces device status change
    static func announceDeviceStatusChange(deviceName: String, isOnline: Bool) {
        let status = isOnline ? "online" : "offline"
        let message = "\(deviceName) is now \(status)"
        announceMessage(message, priority: .low)
    }

    private static func announceMessage(_ message: String, priority: Priority) {
        #if os(macOS)
        // Use NSSpeechSynthesizer for macOS
        let synthesizer = NSSpeechSynthesizer()
        synthesizer.startSpeaking(message)
        #endif
    }

    enum Priority {
        case low
        case high
    }
}

// MARK: - Dynamic Type Size Extension

extension DynamicTypeSize {
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}
