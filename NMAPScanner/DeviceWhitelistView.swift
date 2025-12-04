//
//  DeviceWhitelistView.swift
//  NMAP Scanner - Device Whitelist Management
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI

struct DeviceWhitelistView: View {
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @State private var selectedDevice: PersistedDevice?
    @State private var showingEditDevice = false
    @State private var filterWhitelistedOnly = false

    var filteredDevices: [PersistedDevice] {
        if filterWhitelistedOnly {
            return persistenceManager.persistedDevices.filter { $0.isWhitelisted }
        }
        return persistenceManager.persistedDevices
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                Text("Device Whitelist")
                    .font(.system(size: 50, weight: .bold))

                // Filter Toggle
                Toggle(isOn: $filterWhitelistedOnly) {
                    Text("Show Whitelisted Only")
                        .font(.system(size: 24))
                }
                // .toggleStyle(.switch) // Not available in tvOS 16
                .padding(20)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // Stats
                HStack(spacing: 40) {
                    StatBox(
                        label: "Total Devices",
                        value: "\(persistenceManager.persistedDevices.count)",
                        color: .blue
                    )

                    StatBox(
                        label: "Whitelisted",
                        value: "\(persistenceManager.persistedDevices.filter { $0.isWhitelisted }.count)",
                        color: .green
                    )

                    StatBox(
                        label: "Unknown",
                        value: "\(persistenceManager.persistedDevices.filter { !$0.isWhitelisted }.count)",
                        color: .orange
                    )
                }

                // Device List
                Text("Devices (\(filteredDevices.count))")
                    .font(.system(size: 36, weight: .semibold))

                ForEach(filteredDevices) { device in
                    Button(action: {
                        selectedDevice = device
                        showingEditDevice = true
                    }) {
                        WhitelistDeviceCard(device: device)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedDevice) { device in
            DeviceEditView(device: device)
        }
    }
}

// MARK: - Whitelist Device Card

struct WhitelistDeviceCard: View {
    let device: PersistedDevice

    var body: some View {
        HStack(spacing: 20) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: device.isWhitelisted ? "checkmark.shield.fill" : "questionmark.circle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(statusColor)
            }

            // Device Info
            VStack(alignment: .leading, spacing: 8) {
                Text(device.customName ?? device.hostname ?? device.ipAddress)
                    .font(.system(size: 26, weight: .semibold))

                Text(device.ipAddress)
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(.secondary)

                if let mac = device.macAddress {
                    Text("MAC: \(mac)")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                        Text("First: \(formatDate(device.firstSeen))")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                        Text("Last: \(formatDate(device.lastSeen))")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.secondary)
                }

                if device.isWhitelisted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("WHITELISTED")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("UNKNOWN DEVICE")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(statusColor)
        }
        .padding(24)
        .background(statusColor.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var statusColor: Color {
        device.isWhitelisted ? .green : .orange
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Device Edit View

struct DeviceEditView: View {
    let device: PersistedDevice
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var customName: String
    @State private var userNotes: String
    @State private var isWhitelisted: Bool

    init(device: PersistedDevice) {
        self.device = device
        _customName = State(initialValue: device.customName ?? "")
        _userNotes = State(initialValue: device.userNotes ?? "")
        _isWhitelisted = State(initialValue: device.isWhitelisted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                HStack {
                    Text("Device Details")
                        .font(.system(size: 50, weight: .bold))
                    Spacer()
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.system(size: 28))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // Device Info Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Device Information")
                        .font(.system(size: 36, weight: .semibold))

                    InfoRow(label: "IP Address", value: device.ipAddress, monospaced: true)
                    if let mac = device.macAddress {
                        InfoRow(label: "MAC Address", value: mac, monospaced: true)
                    }
                    if let hostname = device.hostname {
                        InfoRow(label: "Hostname", value: hostname)
                    }
                    if let manufacturer = device.manufacturer {
                        InfoRow(label: "Manufacturer", value: manufacturer)
                    }
                    InfoRow(label: "Device Type", value: device.deviceType)
                    InfoRow(label: "First Seen", value: formatDateTime(device.firstSeen))
                    InfoRow(label: "Last Seen", value: formatDateTime(device.lastSeen))
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)

                // Whitelist Toggle
                VStack(alignment: .leading, spacing: 20) {
                    Text("Trust Status")
                        .font(.system(size: 36, weight: .semibold))

                    Toggle(isOn: $isWhitelisted) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Whitelist this device")
                                .font(.system(size: 26, weight: .semibold))
                            Text("Whitelisted devices are marked as known/trusted")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                    }
                    // .toggleStyle(.switch) // Not available in tvOS 16
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)

                // Custom Name
                VStack(alignment: .leading, spacing: 20) {
                    Text("Custom Name")
                        .font(.system(size: 36, weight: .semibold))

                    TextField("Enter custom name", text: $customName)
                        .font(.system(size: 24))
                        .padding(20)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)

                // Notes
                VStack(alignment: .leading, spacing: 20) {
                    Text("Notes")
                        .font(.system(size: 36, weight: .semibold))

                    TextField("Notes", text: $userNotes, axis: .vertical)
                        .font(.system(size: 24))
                        .frame(height: 200)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)

                // Delete Button
                Button(action: {
                    persistenceManager.deleteDevice(id: device.id)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 28))
                        Text("Delete Device")
                            .font(.system(size: 26, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
    }

    private func saveChanges() {
        if isWhitelisted {
            persistenceManager.whitelistDevice(ipAddress: device.ipAddress)
        } else {
            persistenceManager.removeFromWhitelist(ipAddress: device.ipAddress)
        }

        if !customName.isEmpty {
            persistenceManager.setCustomName(customName, for: device.ipAddress)
        }

        if !userNotes.isEmpty {
            persistenceManager.setNotes(userNotes, for: device.ipAddress)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
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

// MARK: - Stat Box Component

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    DeviceWhitelistView()
}
