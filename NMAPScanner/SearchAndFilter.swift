//
//  SearchAndFilter.swift
//  NMAPScanner
//
//  Comprehensive search and filtering system for network devices
//  Supports text search, multi-criteria filtering, and saved searches
//  Created by Jordan Koch on 11/23/2025.
//

import Foundation
import SwiftUI

/// Advanced search and filter manager for devices
@MainActor
class SearchFilterManager: ObservableObject {
    static let shared = SearchFilterManager()

    @Published var criteria = FilterCriteria()
    @Published var savedSearches: [SavedSearch] = []
    @Published var isFiltering = false

    private let userDefaults = UserDefaults.standard
    private let savedSearchesKey = "saved_searches"

    // MARK: - Filter Criteria

    struct FilterCriteria {
        var searchText: String = ""
        var deviceTypes: Set<EnhancedDevice.DeviceType> = []
        var threatLevels: Set<String> = [] // Would integrate with ThreatAnalyzer
        var isRogue: Bool? = nil // nil = show all, true = rogue only, false = non-rogue only
        var isOnline: Bool? = nil // nil = show all, true = online only, false = offline only
        var isKnown: Bool? = nil // nil = show all, true = known only, false = unknown only
        var manufacturers: Set<String> = []
        var tags: Set<String> = [] // Requires DeviceAnnotations integration
        var groups: Set<String> = [] // Requires DeviceAnnotations integration
        var portRange: ClosedRange<Int>? = nil
        var specificPorts: Set<Int> = []
        var hasHostname: Bool? = nil
        var hasMACAddress: Bool? = nil
        var dateRange: DateRange? = nil

        struct DateRange {
            var start: Date
            var end: Date
        }

        var isActive: Bool {
            return !searchText.isEmpty ||
                   !deviceTypes.isEmpty ||
                   !threatLevels.isEmpty ||
                   isRogue != nil ||
                   isOnline != nil ||
                   isKnown != nil ||
                   !manufacturers.isEmpty ||
                   !tags.isEmpty ||
                   !groups.isEmpty ||
                   portRange != nil ||
                   !specificPorts.isEmpty ||
                   hasHostname != nil ||
                   hasMACAddress != nil ||
                   dateRange != nil
        }

        mutating func reset() {
            self = FilterCriteria()
        }
    }

    // MARK: - Saved Search

    struct SavedSearch: Codable, Identifiable {
        let id: UUID
        var name: String
        var searchText: String
        var deviceTypes: [String]
        var isRogue: Bool?
        var isOnline: Bool?
        var isKnown: Bool?
        var manufacturers: [String]
        var tags: [String]
        var groups: [String]
        var specificPorts: [Int]
        var createdAt: Date

        init(name: String, criteria: FilterCriteria) {
            self.id = UUID()
            self.name = name
            self.searchText = criteria.searchText
            self.deviceTypes = criteria.deviceTypes.map { $0.rawValue }
            self.isRogue = criteria.isRogue
            self.isOnline = criteria.isOnline
            self.isKnown = criteria.isKnown
            self.manufacturers = Array(criteria.manufacturers)
            self.tags = Array(criteria.tags)
            self.groups = Array(criteria.groups)
            self.specificPorts = Array(criteria.specificPorts)
            self.createdAt = Date()
        }
    }

    // MARK: - Initialization

    init() {
        loadSavedSearches()
    }

    // MARK: - Filtering

    /// Filter devices based on current criteria
    func filter(_ devices: [EnhancedDevice]) -> [EnhancedDevice] {
        isFiltering = true
        defer { isFiltering = false }

        var filtered = devices

        // Text search (searches IP, hostname, manufacturer, MAC)
        if !criteria.searchText.isEmpty {
            let searchLower = criteria.searchText.lowercased()
            filtered = filtered.filter { device in
                device.ipAddress.lowercased().contains(searchLower) ||
                device.hostname?.lowercased().contains(searchLower) == true ||
                device.manufacturer?.lowercased().contains(searchLower) == true ||
                device.macAddress?.lowercased().contains(searchLower) == true
            }
        }

        // Device type filter
        if !criteria.deviceTypes.isEmpty {
            filtered = filtered.filter { device in
                criteria.deviceTypes.contains(device.deviceType)
            }
        }

        // Rogue device filter
        if let isRogue = criteria.isRogue {
            filtered = filtered.filter { $0.isRogue == isRogue }
        }

        // Online status filter
        if let isOnline = criteria.isOnline {
            filtered = filtered.filter { $0.isOnline == isOnline }
        }

        // Known device filter
        if let isKnown = criteria.isKnown {
            filtered = filtered.filter { $0.isKnownDevice == isKnown }
        }

        // Manufacturer filter
        if !criteria.manufacturers.isEmpty {
            filtered = filtered.filter { device in
                if let manufacturer = device.manufacturer {
                    return criteria.manufacturers.contains(manufacturer)
                }
                return false
            }
        }

        // Tags filter (requires DeviceAnnotations integration)
        if !criteria.tags.isEmpty {
            let annotationManager = DeviceAnnotationManager.shared
            filtered = filtered.filter { device in
                let deviceTags = annotationManager.getTags(for: device.ipAddress)
                return !criteria.tags.isDisjoint(with: deviceTags)
            }
        }

        // Groups filter (requires DeviceAnnotations integration)
        if !criteria.groups.isEmpty {
            let annotationManager = DeviceAnnotationManager.shared
            filtered = filtered.filter { device in
                if let group = annotationManager.getGroup(for: device.ipAddress) {
                    return criteria.groups.contains(group)
                }
                return false
            }
        }

        // Port range filter
        if let range = criteria.portRange {
            filtered = filtered.filter { device in
                device.openPorts.contains { range.contains($0.port) }
            }
        }

        // Specific ports filter
        if !criteria.specificPorts.isEmpty {
            filtered = filtered.filter { device in
                let devicePorts = Set(device.openPorts.map { $0.port })
                return !criteria.specificPorts.isDisjoint(with: devicePorts)
            }
        }

        // Hostname presence filter
        if let hasHostname = criteria.hasHostname {
            filtered = filtered.filter { device in
                hasHostname ? device.hostname != nil : device.hostname == nil
            }
        }

        // MAC address presence filter
        if let hasMACAddress = criteria.hasMACAddress {
            filtered = filtered.filter { device in
                hasMACAddress ? device.macAddress != nil : device.macAddress == nil
            }
        }

        // Date range filter
        if let dateRange = criteria.dateRange {
            filtered = filtered.filter { device in
                device.lastSeen >= dateRange.start && device.lastSeen <= dateRange.end
            }
        }

        return filtered
    }

    // MARK: - Saved Searches

    func saveSearch(name: String, criteria: FilterCriteria) {
        let search = SavedSearch(name: name, criteria: criteria)
        savedSearches.append(search)
        saveSavedSearches()
    }

    func deleteSearch(_ search: SavedSearch) {
        savedSearches.removeAll { $0.id == search.id }
        saveSavedSearches()
    }

    func loadSearch(_ search: SavedSearch) {
        var newCriteria = FilterCriteria()
        newCriteria.searchText = search.searchText
        newCriteria.deviceTypes = Set(search.deviceTypes.compactMap { EnhancedDevice.DeviceType(rawValue: $0) })
        newCriteria.isRogue = search.isRogue
        newCriteria.isOnline = search.isOnline
        newCriteria.isKnown = search.isKnown
        newCriteria.manufacturers = Set(search.manufacturers)
        newCriteria.tags = Set(search.tags)
        newCriteria.groups = Set(search.groups)
        newCriteria.specificPorts = Set(search.specificPorts)

        criteria = newCriteria
    }

    // MARK: - Quick Filters

    func showRogueOnly() {
        criteria.reset()
        criteria.isRogue = true
    }

    func showUnknownOnly() {
        criteria.reset()
        criteria.isKnown = false
    }

    func showOnlineOnly() {
        criteria.reset()
        criteria.isOnline = true
    }

    func showWithOpenPorts(_ ports: [Int]) {
        criteria.reset()
        criteria.specificPorts = Set(ports)
    }

    // MARK: - Persistence

    private func loadSavedSearches() {
        if let data = userDefaults.data(forKey: savedSearchesKey),
           let decoded = try? JSONDecoder().decode([SavedSearch].self, from: data) {
            savedSearches = decoded
        }
    }

    private func saveSavedSearches() {
        if let data = try? JSONEncoder().encode(savedSearches) {
            userDefaults.set(data, forKey: savedSearchesKey)
        }
    }

    // MARK: - Helper Methods

    /// Get all unique manufacturers from devices
    func getAvailableManufacturers(from devices: [EnhancedDevice]) -> [String] {
        let manufacturers = devices.compactMap { $0.manufacturer }
        return Array(Set(manufacturers)).sorted()
    }

    /// Get all device types present in devices
    func getAvailableDeviceTypes(from devices: [EnhancedDevice]) -> [EnhancedDevice.DeviceType] {
        let types = devices.map { $0.deviceType }
        return Array(Set(types)).sorted { $0.rawValue < $1.rawValue }
    }

    /// Get most common ports in devices
    func getMostCommonPorts(from devices: [EnhancedDevice], limit: Int = 10) -> [Int] {
        var portCounts: [Int: Int] = [:]

        for device in devices {
            for portInfo in device.openPorts {
                portCounts[portInfo.port, default: 0] += 1
            }
        }

        return portCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
}

// MARK: - Search & Filter UI

struct SearchAndFilterView: View {
    @Binding var devices: [EnhancedDevice]
    @StateObject private var filterManager = SearchFilterManager.shared
    @State private var showingAdvancedFilters = false
    @State private var showingSaveDialog = false
    @State private var saveSearchName = ""

    var filteredDevices: [EnhancedDevice] {
        filterManager.filter(devices)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Search bar
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)

                TextField("Search IP, hostname, manufacturer...", text: $filterManager.criteria.searchText)
                    .font(.system(size: 24))
                    .textFieldStyle(.plain)

                if filterManager.criteria.isActive {
                    Button(action: {
                        filterManager.criteria.reset()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    showingAdvancedFilters = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 28))
                        Text("Filters")
                            .font(.system(size: 24))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)

            // Quick filter chips
            if filterManager.criteria.isActive {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ActiveFilterChip(text: "Active Filters", isHeader: true)

                        if !filterManager.criteria.searchText.isEmpty {
                            ActiveFilterChip(text: "Search: \"\(filterManager.criteria.searchText)\"") {
                                filterManager.criteria.searchText = ""
                            }
                        }

                        if let isRogue = filterManager.criteria.isRogue {
                            ActiveFilterChip(text: isRogue ? "Rogue Devices" : "Safe Devices") {
                                filterManager.criteria.isRogue = nil
                            }
                        }

                        if let isOnline = filterManager.criteria.isOnline {
                            ActiveFilterChip(text: isOnline ? "Online" : "Offline") {
                                filterManager.criteria.isOnline = nil
                            }
                        }

                        if !filterManager.criteria.deviceTypes.isEmpty {
                            ActiveFilterChip(text: "Types: \(filterManager.criteria.deviceTypes.count)") {
                                filterManager.criteria.deviceTypes.removeAll()
                            }
                        }

                        if !filterManager.criteria.specificPorts.isEmpty {
                            ActiveFilterChip(text: "Ports: \(filterManager.criteria.specificPorts.count)") {
                                filterManager.criteria.specificPorts.removeAll()
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }

            // Results info
            HStack {
                Text("\(filteredDevices.count) of \(devices.count) devices")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)

                Spacer()

                if filterManager.criteria.isActive {
                    Button("Save Search") {
                        showingSaveDialog = true
                    }
                    .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 40)
        }
        .sheet(isPresented: $showingAdvancedFilters) {
            AdvancedFiltersSheet(devices: devices)
        }
        .alert("Save Search", isPresented: $showingSaveDialog) {
            TextField("Search Name", text: $saveSearchName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                filterManager.saveSearch(name: saveSearchName.isEmpty ? "Untitled Search" : saveSearchName, criteria: filterManager.criteria)
                saveSearchName = ""
            }
        } message: {
            Text("Enter a name for this search configuration")
        }
    }
}

struct ActiveFilterChip: View {
    let text: String
    var isHeader: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: isHeader ? 20 : 18, weight: isHeader ? .bold : .regular))

            if !isHeader, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHeader ? Color.blue : Color.blue.opacity(0.2))
        .foregroundColor(isHeader ? .white : .blue)
        .cornerRadius(20)
    }
}

struct AdvancedFiltersSheet: View {
    let devices: [EnhancedDevice]
    @StateObject private var filterManager = SearchFilterManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Status filters
                Section(header: Text("Device Status")) {
                    Picker("Online Status", selection: Binding(
                        get: { filterManager.criteria.isOnline },
                        set: { filterManager.criteria.isOnline = $0 }
                    )) {
                        Text("All").tag(nil as Bool?)
                        Text("Online Only").tag(true as Bool?)
                        Text("Offline Only").tag(false as Bool?)
                    }

                    Picker("Rogue Status", selection: Binding(
                        get: { filterManager.criteria.isRogue },
                        set: { filterManager.criteria.isRogue = $0 }
                    )) {
                        Text("All").tag(nil as Bool?)
                        Text("Rogue Only").tag(true as Bool?)
                        Text("Safe Only").tag(false as Bool?)
                    }

                    Picker("Known Status", selection: Binding(
                        get: { filterManager.criteria.isKnown },
                        set: { filterManager.criteria.isKnown = $0 }
                    )) {
                        Text("All").tag(nil as Bool?)
                        Text("Known Only").tag(true as Bool?)
                        Text("Unknown Only").tag(false as Bool?)
                    }
                }

                // Device type filter
                Section(header: Text("Device Types")) {
                    let availableTypes = filterManager.getAvailableDeviceTypes(from: devices)
                    ForEach(availableTypes, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { filterManager.criteria.deviceTypes.contains(type) },
                            set: { enabled in
                                if enabled {
                                    filterManager.criteria.deviceTypes.insert(type)
                                } else {
                                    filterManager.criteria.deviceTypes.remove(type)
                                }
                            }
                        ))
                    }
                }

                // Manufacturer filter
                Section(header: Text("Manufacturers")) {
                    let manufacturers = filterManager.getAvailableManufacturers(from: devices)
                    if manufacturers.isEmpty {
                        Text("No manufacturer data available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(manufacturers, id: \.self) { manufacturer in
                            Toggle(manufacturer, isOn: Binding(
                                get: { filterManager.criteria.manufacturers.contains(manufacturer) },
                                set: { enabled in
                                    if enabled {
                                        filterManager.criteria.manufacturers.insert(manufacturer)
                                    } else {
                                        filterManager.criteria.manufacturers.remove(manufacturer)
                                    }
                                }
                            ))
                        }
                    }
                }

                // Common ports quick filter
                Section(header: Text("Common Open Ports")) {
                    let commonPorts = filterManager.getMostCommonPorts(from: devices)
                    if commonPorts.isEmpty {
                        Text("No open ports detected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(commonPorts, id: \.self) { port in
                            Toggle("Port \(port) (\(getServiceName(port)))", isOn: Binding(
                                get: { filterManager.criteria.specificPorts.contains(port) },
                                set: { enabled in
                                    if enabled {
                                        filterManager.criteria.specificPorts.insert(port)
                                    } else {
                                        filterManager.criteria.specificPorts.remove(port)
                                    }
                                }
                            ))
                        }
                    }
                }

                // Data presence filters
                Section(header: Text("Data Availability")) {
                    Picker("Has Hostname", selection: Binding(
                        get: { filterManager.criteria.hasHostname },
                        set: { filterManager.criteria.hasHostname = $0 }
                    )) {
                        Text("All").tag(nil as Bool?)
                        Text("With Hostname").tag(true as Bool?)
                        Text("No Hostname").tag(false as Bool?)
                    }

                    Picker("Has MAC Address", selection: Binding(
                        get: { filterManager.criteria.hasMACAddress },
                        set: { filterManager.criteria.hasMACAddress = $0 }
                    )) {
                        Text("All").tag(nil as Bool?)
                        Text("With MAC").tag(true as Bool?)
                        Text("No MAC").tag(false as Bool?)
                    }
                }

                // Saved searches
                if !filterManager.savedSearches.isEmpty {
                    Section(header: Text("Saved Searches")) {
                        ForEach(filterManager.savedSearches) { search in
                            Button(action: {
                                filterManager.loadSearch(search)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(search.name)
                                            .font(.system(size: 22, weight: .semibold))
                                        Text("Created \(search.createdAt, style: .date)")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                filterManager.deleteSearch(filterManager.savedSearches[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Advanced Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset All") {
                        filterManager.criteria.reset()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func getServiceName(_ port: Int) -> String {
        let services: [Int: String] = [
            22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS", 80: "HTTP",
            110: "POP3", 143: "IMAP", 443: "HTTPS", 445: "SMB", 3306: "MySQL",
            3389: "RDP", 5432: "PostgreSQL", 5900: "VNC", 8080: "HTTP-Alt"
        ]
        return services[port] ?? "Unknown"
    }
}

/// Quick filter buttons for dashboard
struct QuickFiltersBar: View {
    @StateObject private var filterManager = SearchFilterManager.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickFilterButton(title: "Rogue", icon: "exclamationmark.shield", color: .red) {
                    filterManager.showRogueOnly()
                }

                QuickFilterButton(title: "Unknown", icon: "questionmark.circle", color: .orange) {
                    filterManager.showUnknownOnly()
                }

                QuickFilterButton(title: "Online", icon: "circle.fill", color: .green) {
                    filterManager.showOnlineOnly()
                }

                QuickFilterButton(title: "High Risk Ports", icon: "lock.open", color: .red) {
                    filterManager.showWithOpenPorts([22, 23, 3389, 5900])
                }

                QuickFilterButton(title: "Web Servers", icon: "server.rack", color: .blue) {
                    filterManager.showWithOpenPorts([80, 443, 8080, 8443])
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

struct QuickFilterButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
