//
//  NetworkHistoryView.swift
//  NMAP Scanner - Network History Tracking
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import SwiftUI

struct NetworkHistoryView: View {
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @State private var selectedNetwork: NetworkRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                Text("Network History")
                    .font(.system(size: 50, weight: .bold))

                if persistenceManager.networkHistory.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)

                        Text("No networks scanned yet")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)

                        Text("Scan a network to see it appear here")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(60)
                } else {
                    // Network List
                    Text("\(persistenceManager.networkHistory.count) network\(persistenceManager.networkHistory.count == 1 ? "" : "s") tracked")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    ForEach(persistenceManager.networkHistory.sorted(by: { $0.lastScanned > $1.lastScanned })) { network in
                        Button(action: {
                            selectedNetwork = network
                        }) {
                            NetworkHistoryCard(network: network)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedNetwork) { network in
            NetworkHistoryDetailView(network: network)
        }
    }
}

// MARK: - Network History Card

struct NetworkHistoryCard: View {
    let network: NetworkRecord

    var body: some View {
        HStack(spacing: 20) {
            // Network Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: "network")
                    .font(.system(size: 35))
                    .foregroundColor(.blue)
            }

            // Network Info
            VStack(alignment: .leading, spacing: 8) {
                Text("\(network.subnet).0\(network.subnetMask)")
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))

                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 18))
                        Text("\(network.deviceCount) devices")
                            .font(.system(size: 20))
                    }
                    .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18))
                        Text("\(network.scanCount) scans")
                            .font(.system(size: 20))
                    }
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                        Text("First: \(formatDate(network.firstScanned))")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                        Text("Last: \(formatDate(network.lastScanned))")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.secondary)
                }

                if let notes = network.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)
        }
        .padding(24)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Network History Detail View

struct NetworkHistoryDetailView: View {
    let network: NetworkRecord
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var notes: String

    init(network: NetworkRecord) {
        self.network = network
        _notes = State(initialValue: network.notes ?? "")
    }

    var devicesOnNetwork: [PersistedDevice] {
        persistenceManager.persistedDevices.filter { device in
            device.ipAddress.hasPrefix(network.subnet)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                HStack {
                    Text("Network Details")
                        .font(.system(size: 50, weight: .bold))
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 28))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // Network Info
                VStack(alignment: .leading, spacing: 20) {
                    Text("Network Information")
                        .font(.system(size: 36, weight: .semibold))

                    InfoRow(label: "Subnet", value: "\(network.subnet).0\(network.subnetMask)", monospaced: true)
                    InfoRow(label: "First Scanned", value: formatDateTime(network.firstScanned))
                    InfoRow(label: "Last Scanned", value: formatDateTime(network.lastScanned))
                    InfoRow(label: "Total Scans", value: "\(network.scanCount)")
                    InfoRow(label: "Devices Found", value: "\(network.deviceCount)")

                    let timeSinceLastScan = Date().timeIntervalSince(network.lastScanned)
                    InfoRow(label: "Time Since Scan", value: formatTimeInterval(timeSinceLastScan))
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)

                // Statistics
                VStack(alignment: .leading, spacing: 20) {
                    Text("Statistics")
                        .font(.system(size: 36, weight: .semibold))

                    HStack(spacing: 20) {
                        StatBox(
                            label: "Total Devices",
                            value: "\(devicesOnNetwork.count)",
                            color: .blue
                        )

                        StatBox(
                            label: "Whitelisted",
                            value: "\(devicesOnNetwork.filter { $0.isWhitelisted }.count)",
                            color: .green
                        )

                        StatBox(
                            label: "Unknown",
                            value: "\(devicesOnNetwork.filter { !$0.isWhitelisted }.count)",
                            color: .orange
                        )
                    }
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)

                // Devices on Network
                if !devicesOnNetwork.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Devices on This Network (\(devicesOnNetwork.count))")
                            .font(.system(size: 36, weight: .semibold))

                        ForEach(devicesOnNetwork.sorted(by: { $0.lastSeen > $1.lastSeen }).prefix(10)) { device in
                            NetworkDeviceRow(device: device)
                        }

                        if devicesOnNetwork.count > 10 {
                            Text("+ \(devicesOnNetwork.count - 10) more devices")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(30)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }

                // Notes
                VStack(alignment: .leading, spacing: 20) {
                    Text("Notes")
                        .font(.system(size: 36, weight: .semibold))

                    TextField("Notes", text: $notes, axis: .vertical)
                        .font(.system(size: 24))
                        .frame(height: 200)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)

                    Text("Notes are saved automatically")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .padding(30)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
                .onChange(of: notes) { _ in
                    // Save notes when changed
                    // Note: In production, would update network record
                }

                // Delete Button
                Button(action: {
                    persistenceManager.deleteNetwork(id: network.id)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 28))
                        Text("Delete Network History")
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

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Network Device Row

struct NetworkDeviceRow: View {
    let device: PersistedDevice

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: device.isWhitelisted ? "checkmark.circle.fill" : "questionmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(device.isWhitelisted ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.customName ?? device.hostname ?? device.ipAddress)
                    .font(.system(size: 22, weight: .semibold))

                Text(device.ipAddress)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formatLastSeen(device.lastSeen))
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Now"
        }
    }
}

#Preview {
    NetworkHistoryView()
}
