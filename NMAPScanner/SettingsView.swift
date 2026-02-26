//
//  SettingsView.swift
//  NMAP Scanner - Settings & Configuration
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var persistenceManager = DevicePersistenceManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var rogueDeviceTimeWindow: Int
    @State private var enableAutomaticScanning: Bool
    @State private var scanInterval: Int
    @State private var enableRogueDeviceAlerts: Bool
    @State private var enableBackdoorAlerts: Bool
    @State private var autoWhitelistKnownServices: Bool

    init() {
        let settings = DevicePersistenceManager.shared.settings
        _rogueDeviceTimeWindow = State(initialValue: settings.rogueDeviceTimeWindowMinutes)
        _enableAutomaticScanning = State(initialValue: settings.enableAutomaticScanning)
        _scanInterval = State(initialValue: settings.scanIntervalMinutes)
        _enableRogueDeviceAlerts = State(initialValue: settings.enableRogueDeviceAlerts)
        _enableBackdoorAlerts = State(initialValue: settings.enableBackdoorAlerts)
        _autoWhitelistKnownServices = State(initialValue: settings.autoWhitelistKnownServices)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 50, weight: .bold))
                        Spacer()
                        Button("Done") {
                            saveSettings()
                            dismiss()
                        }
                        .font(.system(size: 28))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // Threat Detection Settings
                    SettingsSection(title: "Threat Detection") {
                        VStack(alignment: .leading, spacing: 24) {
                            // Rogue Device Time Window
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Rogue Device Time Window")
                                    .font(.system(size: 26, weight: .semibold))

                                Text("Flag devices as rogue if first seen within:")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)

                                Picker("Time Window", selection: $rogueDeviceTimeWindow) {
                                    Text("5 minutes").tag(5)
                                    Text("15 minutes").tag(15)
                                    Text("30 minutes").tag(30)
                                    Text("1 hour").tag(60)
                                    Text("2 hours").tag(120)
                                    Text("6 hours").tag(360)
                                    Text("12 hours").tag(720)
                                    Text("24 hours").tag(1440)
                                }
                                // .pickerStyle(.menu) // Not available in tvOS 16
                                .font(.system(size: 24))
                            }

                            Divider()

                            // Alert Toggles
                            Toggle(isOn: $enableRogueDeviceAlerts) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rogue Device Alerts")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("Show critical alerts for unknown devices")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                            // .toggleStyle(.switch) // Not available in tvOS 16

                            Toggle(isOn: $enableBackdoorAlerts) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Backdoor Port Alerts")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("Show alerts for known backdoor/trojan ports")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                            // .toggleStyle(.switch) // Not available in tvOS 16

                            Toggle(isOn: $autoWhitelistKnownServices) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Auto-Whitelist Known Services")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("Automatically trust devices with common services")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                            // .toggleStyle(.switch) // Not available in tvOS 16
                        }
                    }

                    // Scanning Settings
                    SettingsSection(title: "Network Scanning") {
                        VStack(alignment: .leading, spacing: 24) {
                            Toggle(isOn: $enableAutomaticScanning) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Automatic Scanning")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("Automatically scan network on app launch")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                            // .toggleStyle(.switch) // Not available in tvOS 16

                            if enableAutomaticScanning {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Scan Interval")
                                        .font(.system(size: 26, weight: .semibold))

                                    Text("Automatically rescan every:")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)

                                    Picker("Interval", selection: $scanInterval) {
                                        Text("15 minutes").tag(15)
                                        Text("30 minutes").tag(30)
                                        Text("1 hour").tag(60)
                                        Text("2 hours").tag(120)
                                        Text("6 hours").tag(360)
                                        Text("Never").tag(0)
                                    }
                                    // .pickerStyle(.menu) // Not available in tvOS 16
                                    .font(.system(size: 24))
                                }
                            }
                        }
                    }

                    // Device Management
                    NavigationLink(destination: DeviceWhitelistView()) {
                        SettingsSection(title: "Device Whitelist") {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Manage Known Devices")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("\(persistenceManager.persistedDevices.filter { $0.isWhitelisted }.count) whitelisted devices")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Network History - DISABLED (NetworkHistoryView not in project)
                    /*
                    NavigationLink(destination: NetworkHistoryView()) {
                        SettingsSection(title: "Network History") {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("View Scanned Networks")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("\(persistenceManager.networkHistory.count) networks tracked")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    */

                    // Data Management
                    SettingsSection(title: "Data Management") {
                        VStack(alignment: .leading, spacing: 20) {
                            Button(action: {
                                // Export data
                                if let exportString = persistenceManager.exportData() {
                                    print("Export data:\n\(exportString)")
                                    // In production, would save to file or share
                                }
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 28))
                                    Text("Export Data")
                                        .font(.system(size: 26))
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                persistenceManager.clearAll()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 28))
                                    Text("Clear All Data")
                                        .font(.system(size: 26))
                                }
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // App Info
                    SettingsSection(title: "About") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Version")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("2.3")
                                    .font(.system(size: 24, weight: .semibold))
                            }

                            HStack {
                                Text("Devices Tracked")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(persistenceManager.persistedDevices.count)")
                                    .font(.system(size: 24, weight: .semibold))
                            }

                            HStack {
                                Text("Networks Scanned")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(persistenceManager.networkHistory.count)")
                                    .font(.system(size: 24, weight: .semibold))
                            }
                        }
                    }

                    // New Features Section
                    SettingsSection(title: "Advanced Features") {
                        VStack(alignment: .leading, spacing: 24) {
                            // Notifications Link
                            NavigationLink(destination: NotificationSettingsView()) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Notifications")
                                            .font(.system(size: 26, weight: .semibold))
                                        Text("Configure alerts and notifications")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Note: Other advanced features (Scan Schedules, Presets, Historical Timeline)
                            // will be accessible through the main dashboard once their UI views are created
                        }
                    }
                }
                .padding(40)
            }
        }
    }

    private func saveSettings() {
        let newSettings = ThreatDetectionSettings(
            rogueDeviceTimeWindowMinutes: rogueDeviceTimeWindow,
            enableAutomaticScanning: enableAutomaticScanning,
            scanIntervalMinutes: scanInterval,
            enableRogueDeviceAlerts: enableRogueDeviceAlerts,
            enableBackdoorAlerts: enableBackdoorAlerts,
            autoWhitelistKnownServices: autoWhitelistKnownServices
        )
        persistenceManager.updateSettings(newSettings)
    }
}

// MARK: - Settings Section Component

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 36, weight: .semibold))

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(30)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

#Preview {
    SettingsView()
}
