//
//  ScanPresets.swift
//  NMAPScanner
//
//  Preconfigured scan presets for common use cases
//  Allows quick-launch of specialized scans (web servers, IoT, databases, etc.)
//  Created by Jordan Koch on 11/23/2025.
//

import Foundation
import SwiftUI

/// Scan preset configuration
struct ScanPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var color: String
    var ports: [Int]
    var scanType: ScanType
    var timeout: TimeInterval
    var maxThreads: Int
    var isBuiltIn: Bool

    enum ScanType: String, Codable {
        case targeted = "Targeted"
        case comprehensive = "Comprehensive"
        case fast = "Fast"
    }

    init(name: String, description: String, icon: String, color: String, ports: [Int], scanType: ScanType = .targeted, timeout: TimeInterval = 2.0, maxThreads: Int = 50, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.ports = ports
        self.scanType = scanType
        self.timeout = timeout
        self.maxThreads = maxThreads
        self.isBuiltIn = isBuiltIn
    }

    // MARK: - Built-in Presets

    static let webServices = ScanPreset(
        name: "Web Services",
        description: "Scan for web servers and HTTP services",
        icon: "globe",
        color: "blue",
        ports: [80, 443, 8000, 8080, 8443, 8888, 3000, 5000],
        scanType: .fast,
        timeout: 1.5,
        maxThreads: 100,
        isBuiltIn: true
    )

    static let iotDevices = ScanPreset(
        name: "IoT Devices",
        description: "Find smart home and IoT devices",
        icon: "sensor",
        color: "purple",
        ports: [80, 443, 1883, 8883, 5683, 8080, 9000, 10000],
        scanType: .targeted,
        timeout: 2.0,
        maxThreads: 50,
        isBuiltIn: true
    )

    static let databases = ScanPreset(
        name: "Databases",
        description: "Scan for database servers",
        icon: "server.rack",
        color: "orange",
        ports: [3306, 5432, 27017, 6379, 1433, 5984, 9042, 7000, 7001],
        scanType: .targeted,
        timeout: 3.0,
        maxThreads: 30,
        isBuiltIn: true
    )

    static let fileServers = ScanPreset(
        name: "File Servers",
        description: "Locate file sharing and storage services",
        icon: "externaldrive",
        color: "green",
        ports: [445, 139, 548, 2049, 111, 21, 22, 990],
        scanType: .targeted,
        timeout: 2.5,
        maxThreads: 40,
        isBuiltIn: true
    )

    static let mailServers = ScanPreset(
        name: "Mail Servers",
        description: "Find email servers and services",
        icon: "envelope",
        color: "blue",
        ports: [25, 110, 143, 465, 587, 993, 995, 2525],
        scanType: .targeted,
        timeout: 2.0,
        maxThreads: 50,
        isBuiltIn: true
    )

    static let remoteAccess = ScanPreset(
        name: "Remote Access",
        description: "Scan for remote access services (SSH, RDP, VNC)",
        icon: "desktopcomputer",
        color: "red",
        ports: [22, 23, 3389, 5900, 5901, 5902, 5938, 8022],
        scanType: .targeted,
        timeout: 2.0,
        maxThreads: 40,
        isBuiltIn: true
    )

    static let printers = ScanPreset(
        name: "Printers",
        description: "Find network printers and print servers",
        icon: "printer",
        color: "gray",
        ports: [631, 9100, 515, 721],
        scanType: .fast,
        timeout: 1.5,
        maxThreads: 60,
        isBuiltIn: true
    )

    static let mediaDevices = ScanPreset(
        name: "Media Devices",
        description: "Scan for media servers and streaming devices",
        icon: "play.tv",
        color: "purple",
        ports: [8080, 8096, 32400, 1900, 7000, 9090, 8443],
        scanType: .targeted,
        timeout: 2.0,
        maxThreads: 50,
        isBuiltIn: true
    )

    static let securityAudit = ScanPreset(
        name: "Security Audit",
        description: "Comprehensive scan of 1024 most common ports",
        icon: "shield.checkered",
        color: "red",
        ports: Array(1...1024),
        scanType: .comprehensive,
        timeout: 1.0,
        maxThreads: 200,
        isBuiltIn: true
    )

    static let quickScan = ScanPreset(
        name: "Quick Scan",
        description: "Fast scan of 20 most common ports",
        icon: "bolt",
        color: "yellow",
        ports: [21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 5432, 5900, 8080, 8443, 27017, 6379, 1433, 9200],
        scanType: .fast,
        timeout: 1.0,
        maxThreads: 100,
        isBuiltIn: true
    )

    // MARK: - Preset Collections

    static let builtInPresets: [ScanPreset] = [
        .quickScan,
        .webServices,
        .iotDevices,
        .databases,
        .fileServers,
        .mailServers,
        .remoteAccess,
        .printers,
        .mediaDevices,
        .securityAudit
    ]
}

/// Manages scan presets
@MainActor
class ScanPresetManager: ObservableObject {
    static let shared = ScanPresetManager()

    @Published var customPresets: [ScanPreset] = []
    @Published var isApplyingPreset = false

    private let userDefaults = UserDefaults.standard
    private let customPresetsKey = "custom_scan_presets"

    var allPresets: [ScanPreset] {
        ScanPreset.builtInPresets + customPresets
    }

    init() {
        loadCustomPresets()
    }

    // MARK: - Preset Management

    func addPreset(_ preset: ScanPreset) {
        var newPreset = preset
        newPreset.isBuiltIn = false
        customPresets.append(newPreset)
        saveCustomPresets()
    }

    func removePreset(_ preset: ScanPreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()
    }

    func updatePreset(_ preset: ScanPreset) {
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
            saveCustomPresets()
        }
    }

    // MARK: - Apply Preset to Scanner

    func applyPreset(_ preset: ScanPreset, to scanner: IntegratedScannerV3) {
        isApplyingPreset = true
        // Note: This would require extending IntegratedScannerV3 to accept custom port lists
        // For now, this demonstrates the pattern
        isApplyingPreset = false
    }

    /// Start a scan with the specified preset
    func startScan(with preset: ScanPreset, scanner: IntegratedScannerV3) async {
        // This would integrate with the scanner to run a custom scan with preset ports
        // Implementation would depend on enhancing IntegratedScannerV3
        print("Starting scan with preset: \(preset.name)")
        print("Scanning ports: \(preset.ports)")
    }

    // MARK: - Preset Analysis

    /// Get statistics about a preset
    func getPresetStatistics(_ preset: ScanPreset) -> PresetStatistics {
        let estimatedTimePerHost = Double(preset.ports.count) * preset.timeout / Double(preset.maxThreads)

        return PresetStatistics(
            portCount: preset.ports.count,
            estimatedTimePerHost: estimatedTimePerHost,
            estimatedTimeFor254Hosts: estimatedTimePerHost * 254,
            scanType: preset.scanType,
            threadsUsed: preset.maxThreads
        )
    }

    struct PresetStatistics {
        let portCount: Int
        let estimatedTimePerHost: TimeInterval
        let estimatedTimeFor254Hosts: TimeInterval
        let scanType: ScanPreset.ScanType
        let threadsUsed: Int

        var formattedTimePerHost: String {
            String(format: "%.1fs", estimatedTimePerHost)
        }

        var formattedTotalTime: String {
            let minutes = Int(estimatedTimeFor254Hosts / 60)
            let seconds = Int(estimatedTimeFor254Hosts.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }

    // MARK: - Persistence

    private func loadCustomPresets() {
        if let data = userDefaults.data(forKey: customPresetsKey),
           let decoded = try? JSONDecoder().decode([ScanPreset].self, from: data) {
            customPresets = decoded
        }
    }

    private func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            userDefaults.set(data, forKey: customPresetsKey)
        }
    }
}

// MARK: - Preset Selection UI

struct PresetSelectionView: View {
    @StateObject private var presetManager = ScanPresetManager.shared
    @State private var showingAddPreset = false
    @State private var selectedPreset: ScanPreset?
    let onSelectPreset: (ScanPreset) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan Presets")
                            .font(.system(size: 42, weight: .bold))

                        Text("Choose a preconfigured scan or create your own")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)

                    // Built-in presets
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Built-in Presets")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 30)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 24)], spacing: 24) {
                            ForEach(ScanPreset.builtInPresets) { preset in
                                PresetCard(preset: preset) {
                                    selectedPreset = preset
                                    onSelectPreset(preset)
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                    }

                    // Custom presets
                    if !presetManager.customPresets.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Custom Presets")
                                .font(.system(size: 28, weight: .semibold))
                                .padding(.horizontal, 30)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 24)], spacing: 24) {
                                ForEach(presetManager.customPresets) { preset in
                                    PresetCard(preset: preset) {
                                        selectedPreset = preset
                                        onSelectPreset(preset)
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                    }

                    // Add custom preset button
                    Button(action: {
                        showingAddPreset = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                            Text("Create Custom Preset")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
                .padding(.vertical, 20)
            }
            .sheet(isPresented: $showingAddPreset) {
                AddPresetView()
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

struct PresetCard: View {
    let preset: ScanPreset
    let onSelect: () -> Void
    @StateObject private var presetManager = ScanPresetManager.shared

    var statistics: ScanPresetManager.PresetStatistics {
        presetManager.getPresetStatistics(preset)
    }

    var cardColor: Color {
        switch preset.color {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .blue
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: preset.icon)
                        .font(.system(size: 32))
                        .foregroundColor(cardColor)
                        .frame(width: 60, height: 60)
                        .background(cardColor.opacity(0.2))
                        .cornerRadius(12)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(preset.ports.count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(cardColor)
                        Text("ports")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }

                Text(preset.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text(preset.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack(spacing: 16) {
                    PresetStatBadge(icon: "clock", value: statistics.formattedTimePerHost)
                    PresetStatBadge(icon: "network", value: preset.scanType.rawValue)
                    if preset.isBuiltIn {
                        PresetStatBadge(icon: "checkmark.seal.fill", value: "Built-in")
                    }
                }
            }
            .padding(24)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardColor.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PresetStatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(value)
                .font(.system(size: 15))
        }
        .foregroundColor(.secondary)
    }
}

struct AddPresetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var presetManager = ScanPresetManager.shared

    @State private var name = ""
    @State private var description = ""
    @State private var portsText = ""
    @State private var selectedIcon = "network"
    @State private var selectedColor = "blue"
    @State private var scanType: ScanPreset.ScanType = .targeted
    @State private var timeout: Double = 2.0
    @State private var maxThreads: Double = 50

    let availableIcons = [
        "network", "globe", "server.rack", "sensor", "desktopcomputer",
        "printer", "externaldrive", "envelope", "shield", "lock"
    ]

    let availableColors = [
        "blue", "purple", "orange", "green", "red", "yellow", "gray"
    ]

    var parsedPorts: [Int] {
        portsText.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && $0 <= 65535 }
    }

    var isValid: Bool {
        !name.isEmpty && !parsedPorts.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Preset Name", text: $name)
                        .font(.system(size: 24))

                    TextField("Description", text: $description)
                        .font(.system(size: 20))
                }

                Section(header: Text("Appearance")) {
                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(availableIcons, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                Text(icon)
                            }
                            .tag(icon)
                        }
                    }

                    Picker("Color", selection: $selectedColor) {
                        ForEach(availableColors, id: \.self) { color in
                            Text(color.capitalized).tag(color)
                        }
                    }
                }

                Section(header: Text("Ports to Scan")) {
                    // TextEditor not available on tvOS, use TextField with multiple lines
                    TextField("Enter ports", text: $portsText, axis: .vertical)
                        .lineLimit(5...10)
                        .font(.system(size: 20, design: .monospaced))

                    Text("Enter ports separated by commas (e.g., 80,443,8080)")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)

                    if !parsedPorts.isEmpty {
                        Text("\(parsedPorts.count) valid ports")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text("Scan Configuration")) {
                    Picker("Scan Type", selection: $scanType) {
                        Text("Fast").tag(ScanPreset.ScanType.fast)
                        Text("Targeted").tag(ScanPreset.ScanType.targeted)
                        Text("Comprehensive").tag(ScanPreset.ScanType.comprehensive)
                    }

                    // Slider and Stepper not available on tvOS, use buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timeout: \(String(format: "%.1f", timeout))s")
                            .font(.system(size: 20))
                        HStack(spacing: 8) {
                            ForEach([0.5, 1.0, 2.0, 3.0, 5.0], id: \.self) { value in
                                Button("\(String(format: "%.1f", value))s") {
                                    timeout = value
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Threads: \(Int(maxThreads))")
                            .font(.system(size: 20))
                        HStack(spacing: 8) {
                            ForEach([10, 50, 100, 150, 200], id: \.self) { value in
                                Button("\(value)") {
                                    maxThreads = Double(value)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let preset = ScanPreset(
                            name: name,
                            description: description.isEmpty ? "Custom scan preset" : description,
                            icon: selectedIcon,
                            color: selectedColor,
                            ports: parsedPorts,
                            scanType: scanType,
                            timeout: timeout,
                            maxThreads: Int(maxThreads)
                        )
                        presetManager.addPreset(preset)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

/// Quick preset launcher for dashboard
struct PresetQuickLauncher: View {
    let onSelectPreset: (ScanPreset) -> Void

    let quickPresets: [ScanPreset] = [
        .quickScan,
        .webServices,
        .iotDevices,
        .securityAudit
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text("Quick Launch")
                    .font(.system(size: 36, weight: .bold))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(quickPresets) { preset in
                        CompactPresetButton(preset: preset) {
                            onSelectPreset(preset)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}

struct CompactPresetButton: View {
    let preset: ScanPreset
    let onSelect: () -> Void

    var cardColor: Color {
        switch preset.color {
        case "blue": return .blue
        case "yellow": return .yellow
        case "purple": return .purple
        case "red": return .red
        default: return .blue
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 36))
                    .foregroundColor(cardColor)
                    .frame(width: 80, height: 80)
                    .background(cardColor.opacity(0.2))
                    .cornerRadius(16)

                Text(preset.name)
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("\(preset.ports.count) ports")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(width: 160)
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
