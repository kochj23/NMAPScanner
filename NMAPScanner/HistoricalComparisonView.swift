//
//  HistoricalComparisonView.swift
//  NMAP Scanner - Historical Device Comparison
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI

struct HistoricalComparisonView: View {
    let device: EnhancedDevice
    @StateObject private var tracker = HistoricalTracker.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device History")
                        .font(.system(size: 28, weight: .bold))

                    Text(device.hostname ?? device.ipAddress)
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Current Status
                    GroupBox(label: Text("Current Status").font(.system(size: 18, weight: .semibold))) {
                        VStack(spacing: 16) {
                            HStack(spacing: 24) {
                                StatusItem(label: "Status", value: device.isOnline ? "Online" : "Offline", color: device.isOnline ? .green : .gray)
                                StatusItem(label: "Open Ports", value: "\(device.openPorts.count)", color: .blue)
                                if let mac = device.macAddress {
                                    StatusItem(label: "MAC", value: String(mac.prefix(17)), color: .purple)
                                }
                            }

                            Divider()

                            HStack(spacing: 24) {
                                StatusItem(label: "First Seen", value: formatDate(device.firstSeen), color: .orange)
                                StatusItem(label: "Last Seen", value: formatDate(device.lastSeen), color: .cyan)
                            }
                        }
                        .padding()
                    }

                    // Port Information
                    if !device.openPorts.isEmpty {
                        GroupBox(label: Text("Open Ports").font(.system(size: 18, weight: .semibold))) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(device.openPorts) { portInfo in
                                    HStack {
                                        Text("\(portInfo.port)")
                                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                                            .foregroundColor(.blue)
                                            .frame(width: 60, alignment: .leading)

                                        Text(portInfo.service)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if let version = portInfo.version {
                                            Text(version)
                                                .font(.system(size: 13, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)

                                    if portInfo.id != device.openPorts.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                        }
                    }

                    // Device Information
                    GroupBox(label: Text("Device Information").font(.system(size: 18, weight: .semibold))) {
                        VStack(spacing: 12) {
                            HistoricalInfoRow(label: "IP Address", value: device.ipAddress)
                            if let mac = device.macAddress {
                                HistoricalInfoRow(label: "MAC Address", value: mac)
                            }
                            if let hostname = device.hostname {
                                HistoricalInfoRow(label: "Hostname", value: hostname)
                            }
                            if let manufacturer = device.manufacturer {
                                HistoricalInfoRow(label: "Manufacturer", value: manufacturer)
                            }
                            HistoricalInfoRow(label: "Device Type", value: device.deviceType.rawValue.capitalized)
                            HistoricalInfoRow(label: "Known Device", value: device.isKnownDevice ? "Yes" : "No")
                        }
                        .padding()
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 700, height: 600)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Historical Info Row

struct HistoricalInfoRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: monospaced ? .monospaced : .default))
        }
    }
}

#Preview {
    HistoricalComparisonView(device: EnhancedDevice(
        ipAddress: "192.168.1.100",
        macAddress: "00:11:22:33:44:55",
        hostname: "test-device",
        manufacturer: "Apple",
        deviceType: .computer,
        openPorts: [
            PortInfo(port: 22, service: "SSH", version: "OpenSSH 8.2", state: .open, protocolType: "TCP", banner: nil),
            PortInfo(port: 80, service: "HTTP", version: nil, state: .open, protocolType: "TCP", banner: nil),
            PortInfo(port: 443, service: "HTTPS", version: nil, state: .open, protocolType: "TCP", banner: nil)
        ],
        isOnline: true,
        firstSeen: Date().addingTimeInterval(-86400),
        lastSeen: Date(),
        isKnownDevice: true,
        operatingSystem: nil,
        deviceName: nil
    ))
}
