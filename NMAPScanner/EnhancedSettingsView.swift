//
//  EnhancedSettingsView.swift
//  NMAP Scanner - Enhanced Settings with All Features
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI

struct EnhancedSettingsView: View {
    @StateObject private var scheduledScanManager = ScheduledScanManager.shared
    @StateObject private var anomalyManager = AnomalyDetectionManager.shared
    @StateObject private var groupingManager = DeviceGroupingManager.shared
    @StateObject private var dnsResolver = CustomDNSResolver.shared
    @AppStorage("customPortList") private var customPortList = "20-25,80,443,3306,5432,8080,8443"
    @AppStorage("enableDarkMode") private var enableDarkMode = false
    @AppStorage("enableBulkOperations") private var enableBulkOperations = false
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Tab Bar
            HStack(spacing: 0) {
                SettingsTab(title: "General", icon: "gearshape", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                SettingsTab(title: "Scanning", icon: "antenna.radiowaves.left.and.right", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                SettingsTab(title: "Network", icon: "network", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                SettingsTab(title: "Alerts", icon: "bell", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                SettingsTab(title: "Grouping", icon: "square.grid.2x2", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
                SettingsTab(title: "Advanced", icon: "slider.horizontal.3", isSelected: selectedTab == 5) {
                    selectedTab = 5
                }
            }
            .padding(.horizontal, 20)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case 0:
                        GeneralSettings(enableDarkMode: $enableDarkMode, enableBulkOperations: $enableBulkOperations)
                    case 1:
                        ScanningSettings(scheduledScanManager: scheduledScanManager, customPortList: $customPortList)
                    case 2:
                        NetworkSettings(dnsResolver: dnsResolver)
                    case 3:
                        AlertSettings(anomalyManager: anomalyManager)
                    case 4:
                        GroupingSettings(groupingManager: groupingManager)
                    case 5:
                        AdvancedSettings()
                    default:
                        EmptyView()
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 700, height: 600)
        .preferredColorScheme(enableDarkMode ? .dark : .light)
    }
}

// MARK: - Settings Tab

struct SettingsTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Settings

struct GeneralSettings: View {
    @Binding var enableDarkMode: Bool
    @Binding var enableBulkOperations: Bool
    @AppStorage("RunInMenuBarOnly") private var runInMenuBarOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.system(size: 22, weight: .semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $enableDarkMode) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dark Mode")
                                .font(.system(size: 15, weight: .medium))
                            Text("Switch between light and dark appearance")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Toggle(isOn: $enableBulkOperations) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bulk Operations")
                                .font(.system(size: 15, weight: .medium))
                            Text("Enable multi-select and bulk scanning")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Toggle(isOn: $runInMenuBarOnly) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Run in Menu Bar Only")
                                .font(.system(size: 15, weight: .medium))
                            Text("Keep app running in menu bar when window is closed")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }

            // Menu Bar Status
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Menu Bar Agent", systemImage: "menubar.rectangle")
                        .font(.system(size: 15, weight: .medium))

                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Active in menu bar")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Text("Quick scan and notifications available from the menu bar icon")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

// MARK: - Scanning Settings

struct ScanningSettings: View {
    @ObservedObject var scheduledScanManager: ScheduledScanManager
    @Binding var customPortList: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Scanning")
                .font(.system(size: 22, weight: .semibold))

            // Scheduled Scanning
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Scheduled Scanning", systemImage: "calendar.badge.clock")
                        .font(.system(size: 15, weight: .medium))

                    Toggle(isOn: Binding(
                        get: { scheduledScanManager.isEnabled },
                        set: { enabled in
                            if enabled {
                                scheduledScanManager.enable(with: scheduledScanManager.scanInterval)
                            } else {
                                scheduledScanManager.disable()
                            }
                        }
                    )) {
                        Text("Enable automatic scanning")
                    }

                    if scheduledScanManager.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scan Interval")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Picker("", selection: Binding(
                                get: { scheduledScanManager.scanInterval },
                                set: { interval in
                                    scheduledScanManager.enable(with: interval)
                                }
                            )) {
                                ForEach(ScheduledScanManager.ScanInterval.allCases, id: \.self) { interval in
                                    Text(interval.rawValue).tag(interval)
                                }
                            }
                            .pickerStyle(.menu)

                            if let timeUntilNext = scheduledScanManager.timeUntilNextScan {
                                Text("Next scan in: \(timeUntilNext)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding()
            }

            // Custom Port List
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Custom Port List", systemImage: "list.number")
                        .font(.system(size: 15, weight: .medium))

                    Text("Define custom ports to scan (comma-separated, ranges allowed)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    TextField("20-25,80,443,3306,5432,8080", text: $customPortList)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))

                    HStack(spacing: 16) {
                        Button("Standard Ports") {
                            customPortList = "20-25,80,110,143,443,993,995,3306,5432,8080"
                        }
                        .font(.system(size: 12))

                        Button("Common Services") {
                            customPortList = "21,22,23,25,53,80,110,143,443,445,3389,5900,8080"
                        }
                        .font(.system(size: 12))

                        Button("Extended Range") {
                            customPortList = "1-1024,3306,5432,8080,8443"
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Alert Settings

struct AlertSettings: View {
    @ObservedObject var anomalyManager: AnomalyDetectionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Alerts & Monitoring")
                .font(.system(size: 22, weight: .semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $anomalyManager.isEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Network Anomaly Detection", systemImage: "exclamationmark.triangle")
                                .font(.system(size: 15, weight: .medium))
                            Text("Get alerted when network changes are detected")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    if anomalyManager.isEnabled {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Alert Types")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                AlertTypeRow(icon: "plus.circle", label: "New devices", color: .blue)
                                AlertTypeRow(icon: "minus.circle", label: "Missing devices", color: .orange)
                                AlertTypeRow(icon: "arrow.triangle.2.circlepath", label: "MAC address changes", color: .red)
                                AlertTypeRow(icon: "network", label: "New open ports", color: .green)
                            }
                        }

                        if !anomalyManager.anomalies.isEmpty {
                            Divider()

                            HStack {
                                Text("\(anomalyManager.anomalies.count) active anomalies")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button("Clear All") {
                                    anomalyManager.clearAnomalies()
                                }
                                .font(.system(size: 12))
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct AlertTypeRow: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))
        }
    }
}

// MARK: - Grouping Settings

struct GroupingSettings: View {
    @ObservedObject var groupingManager: DeviceGroupingManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Device Grouping")
                .font(.system(size: 22, weight: .semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Grouping Mode", systemImage: "square.grid.2x2")
                        .font(.system(size: 15, weight: .medium))

                    Text("Organize devices by category")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Picker("", selection: $groupingManager.groupingMode) {
                        ForEach(DeviceGroupingManager.GroupingMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding()
            }
        }
    }
}

// MARK: - Network Settings

struct NetworkSettings: View {
    @ObservedObject var dnsResolver: CustomDNSResolver

    @State private var dnsServer1 = ""
    @State private var dnsServer2 = ""
    @State private var dnsServer3 = ""
    @State private var showDNSConfig = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Integration")
                .font(.system(size: 22, weight: .semibold))

            // Custom DNS Servers
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Custom DNS Servers", systemImage: "server.rack")
                        .font(.system(size: 15, weight: .medium))

                    Text("Use custom DNS servers for better internal hostname resolution")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Toggle(isOn: $dnsResolver.useCustomDNS) {
                        Text("Enable custom DNS")
                            .font(.system(size: 13))
                    }

                    if dnsResolver.useCustomDNS {
                        VStack(alignment: .leading, spacing: 8) {
                            if !dnsResolver.dnsServers.isEmpty {
                                ForEach(Array(dnsResolver.dnsServers.enumerated()), id: \.offset) { index, server in
                                    HStack {
                                        Text("Server \(index + 1):")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .frame(width: 70, alignment: .leading)
                                        Text(server)
                                            .font(.system(size: 12, design: .monospaced))
                                    }
                                }
                            }

                            Button("Configure DNS Servers") {
                                if !dnsResolver.dnsServers.isEmpty {
                                    dnsServer1 = dnsResolver.dnsServers.count > 0 ? dnsResolver.dnsServers[0] : ""
                                    dnsServer2 = dnsResolver.dnsServers.count > 1 ? dnsResolver.dnsServers[1] : ""
                                    dnsServer3 = dnsResolver.dnsServers.count > 2 ? dnsResolver.dnsServers[2] : ""
                                }
                                showDNSConfig = true
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 12))

                            Button("Use System DNS") {
                                let systemDNS = dnsResolver.getSystemDNSServers()
                                dnsResolver.configure(servers: systemDNS, enabled: true)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }

            // Note about HomeKit tab
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("HomeKit Discovery", systemImage: "homekit")
                        .font(.system(size: 15, weight: .medium))

                    Text("HomeKit device discovery has been moved to its own dedicated tab. Look for the \"HomeKit\" tab in the main tab bar to discover and manage HomeKit devices.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showDNSConfig) {
            DNSConfigSheet(
                server1: $dnsServer1,
                server2: $dnsServer2,
                server3: $dnsServer3,
                onSave: {
                    let servers = [dnsServer1, dnsServer2, dnsServer3].filter { !$0.isEmpty }
                    dnsResolver.configure(servers: servers, enabled: true)
                    showDNSConfig = false
                },
                onCancel: {
                    showDNSConfig = false
                }
            )
        }
    }
}

// MARK: - DNS Configuration Sheet

struct DNSConfigSheet: View {
    @Binding var server1: String
    @Binding var server2: String
    @Binding var server3: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Custom DNS Servers")
                .font(.system(size: 24, weight: .bold))

            Text("Enter up to 3 DNS server IP addresses")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary DNS Server")
                        .font(.system(size: 13, weight: .medium))
                    TextField("192.168.1.1", text: $server1)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Secondary DNS Server (Optional)")
                        .font(.system(size: 13, weight: .medium))
                    TextField("8.8.8.8", text: $server2)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tertiary DNS Server (Optional)")
                        .font(.system(size: 13, weight: .medium))
                    TextField("1.1.1.1", text: $server3)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Text("Common DNS Servers:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button("Google (8.8.8.8)") {
                        if server1.isEmpty { server1 = "8.8.8.8" }
                        else if server2.isEmpty { server2 = "8.8.8.8" }
                    }
                    .font(.system(size: 11))

                    Button("Cloudflare (1.1.1.1)") {
                        if server1.isEmpty { server1 = "1.1.1.1" }
                        else if server2.isEmpty { server2 = "1.1.1.1" }
                    }
                    .font(.system(size: 11))

                    Button("Quad9 (9.9.9.9)") {
                        if server1.isEmpty { server1 = "9.9.9.9" }
                        else if server2.isEmpty { server2 = "9.9.9.9" }
                    }
                    .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(server1.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 600, height: 500)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced")
                .font(.system(size: 22, weight: .semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Network Topology", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 15, weight: .medium))

                    Text("Visualize your network structure")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Button("View Network Map") {
                        // Will be implemented
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Device Notes", systemImage: "note.text")
                        .font(.system(size: 15, weight: .medium))

                    Text("Add custom labels and notes to devices")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("Click on any device card to add notes")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .padding()
            }
        }
    }
}

#Preview {
    EnhancedSettingsView()
}
