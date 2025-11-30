//
//  HomeKitTabView.swift
//  NMAP Plus Security Scanner - Dedicated HomeKit Discovery Tab
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Provides a dedicated tab for HomeKit device discovery without requiring Mac Catalyst.
//  Uses Bonjour/mDNS for device discovery and enriches network scan results.
//

import SwiftUI
import Foundation

/// Dedicated HomeKit Discovery Tab View
struct HomeKitTabView: View {
    @StateObject private var homeKitDiscovery = HomeKitDiscoveryMacOS.shared
    @StateObject private var preferences = HomeKitDevicePreferences.shared
    @StateObject private var healthMonitor = HomeKitDeviceHealthMonitor.shared
    @StateObject private var notificationManager = HomeKitNotificationManager.shared
    @State private var showInfo = false
    @State private var searchText = ""
    @State private var filterType: DeviceFilter = .all
    @State private var showExportSheet = false
    @State private var selectedDevice: HomeKitDevice?

    enum DeviceFilter: Hashable {
        case all
        case homeKit
        case airPlay
        case online
        case offline
        case category(String)
        case serviceType(String)

        var displayName: String {
            switch self {
            case .all: return "All Devices"
            case .homeKit: return "HomeKit Only"
            case .airPlay: return "AirPlay"
            case .online: return "Online"
            case .offline: return "Offline"
            case .category(let cat): return cat
            case .serviceType(let type): return type
            }
        }

        static var baseFilters: [DeviceFilter] {
            return [.all, .homeKit, .airPlay, .online, .offline]
        }
    }

    var filteredDevices: [HomeKitDevice] {
        var devices = homeKitDiscovery.discoveredDevices

        // Apply filter type
        switch filterType {
        case .all:
            break
        case .homeKit:
            devices = devices.filter { $0.isHomeKitAccessory }
        case .airPlay:
            devices = devices.filter { $0.serviceType.contains("airplay") }
        case .online:
            devices = devices.filter { $0.ipAddress != nil }
        case .offline:
            devices = devices.filter { $0.ipAddress == nil }
        case .category(let categoryName):
            devices = devices.filter { $0.category == categoryName }
        case .serviceType(let serviceName):
            devices = devices.filter { $0.serviceType == serviceName }
        }

        // Apply search text
        if !searchText.isEmpty {
            devices = devices.filter { device in
                device.displayName.localizedCaseInsensitiveContains(searchText) ||
                device.serviceType.localizedCaseInsensitiveContains(searchText) ||
                device.category.localizedCaseInsensitiveContains(searchText) ||
                (device.ipAddress?.contains(searchText) ?? false)
            }
        }

        return devices.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HomeKit Discovery")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.primary)

                            if !homeKitDiscovery.discoveredDevices.isEmpty {
                                Text("\(homeKitDiscovery.discoveredDevices.count) devices")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Info Button
                        Button(action: {
                            showInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Status Card with Quick Actions
                    StatusCardWithActions(
                        homeKitDiscovery: homeKitDiscovery,
                        showExportSheet: $showExportSheet
                    )

                    // Search and Filter Bar
                    if !homeKitDiscovery.discoveredDevices.isEmpty {
                        SearchAndFilterBar(
                            searchText: $searchText,
                            filterType: $filterType,
                            totalCount: homeKitDiscovery.discoveredDevices.count,
                            filteredCount: filteredDevices.count
                        )

                        // Active Filter Badge
                        if filterType != .all {
                            ActiveFilterBadge(filterType: $filterType)
                        }
                    }

                    // Statistics Cards
                    if homeKitDiscovery.isAuthorized && !homeKitDiscovery.discoveredDevices.isEmpty {
                        StatisticsGrid(homeKitDiscovery: homeKitDiscovery, filterType: $filterType)

                        // Service Type Breakdown
                        ServiceTypeBreakdownView(homeKitDiscovery: homeKitDiscovery, filterType: $filterType)

                        // Device Category Chart
                        DeviceCategoryChartView(homeKitDiscovery: homeKitDiscovery, filterType: $filterType)

                        // Service Type Legend (Phase 2)
                        ServiceTypeLegendView(homeKitDiscovery: homeKitDiscovery)

                        // Historical Timeline (Phase 2)
                        HomeKitHistoricalTimelineView(homeKitDiscovery: homeKitDiscovery)

                        // Comparison View (Phase 2)
                        HomeKitComparisonView(homeKitDiscovery: homeKitDiscovery)
                    }

                    // Device List (filtered)
                    if !filteredDevices.isEmpty {
                        DeviceListSectionFiltered(
                            devices: filteredDevices,
                            selectedDevice: $selectedDevice
                        )
                    } else if !searchText.isEmpty || filterType != .all {
                        // No results message
                        NoResultsView(searchText: searchText, filterType: filterType)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .sheet(isPresented: $showInfo) {
            InfoSheet()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(devices: homeKitDiscovery.discoveredDevices)
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailSheet(
                device: device,
                preferences: preferences,
                healthMonitor: healthMonitor
            )
        }
        .onChange(of: homeKitDiscovery.discoveredDevices) { _, newDevices in
            // Process devices for notifications
            notificationManager.processDevices(newDevices)

            // Start health monitoring for new devices with IPs
            for device in newDevices where device.ipAddress != nil {
                Task {
                    _ = await healthMonitor.quickHealthCheck(for: device)
                }
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("HomeKit (mDNS)", systemImage: "homekit")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if homeKitDiscovery.isAuthorized {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Active")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                if homeKitDiscovery.isScanning {
                    ProgressView()
                        .controlSize(.regular)
                }
            }

            Text("Discovers HomeKit and smart home devices using Bonjour/mDNS network discovery")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Text(homeKitDiscovery.authorizationStatus)
                .font(.system(size: 15))
                .foregroundColor(.blue)

            HStack(spacing: 12) {
                Button(action: {
                    homeKitDiscovery.requestAuthorization()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: homeKitDiscovery.isScanning ? "antenna.radiowaves.left.and.right" : "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                        Text(homeKitDiscovery.isScanning ? "Scanning..." : "Discover Devices")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: homeKitDiscovery.isScanning ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(homeKitDiscovery.isScanning)

                if homeKitDiscovery.isAuthorized && !homeKitDiscovery.discoveredDevices.isEmpty {
                    Button(action: {
                        Task {
                            await homeKitDiscovery.startDiscovery()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Rescan")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let lastSync = homeKitDiscovery.lastSync {
                Text("Last scanned: \(lastSync, style: .relative) ago")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Statistics Grid

struct StatisticsGrid: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @Binding var filterType: HomeKitTabView.DeviceFilter

    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "homekit",
                value: "\(homeKitDiscovery.discoveredDevices.count)",
                label: "Total Devices",
                color: .blue,
                action: {
                    filterType = .all
                }
            )

            StatCard(
                icon: "checkmark.seal.fill",
                value: "\(homeKitDiscovery.discoveredDevices.filter { $0.isHomeKitAccessory }.count)",
                label: "HomeKit",
                color: .orange,
                action: {
                    filterType = .homeKit
                }
            )

            StatCard(
                icon: "network",
                value: "\(homeKitDiscovery.devicesByIP.count)",
                label: "With IPs",
                color: .green,
                action: {
                    filterType = .online
                }
            )
        }
        .padding(.horizontal, 20)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .help("Click to filter by \(label.lowercased())")
    }
}

// MARK: - Device List Section

struct DeviceListSection: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discovered Devices")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(homeKitDiscovery.discoveredDevices.sorted(by: { $0.name < $1.name })) { device in
                    HomeKitDeviceCardRow(device: device)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    if device.id != homeKitDiscovery.discoveredDevices.sorted(by: { $0.name < $1.name }).last?.id {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
        }
    }
}

struct HomeKitDeviceCardRow: View {
    let device: HomeKitDevice

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: device.isHomeKitAccessory ? "homekit" : "network")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(device.category)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let ip = device.ipAddress {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(ip)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // HomeKit Badge
            if device.isHomeKitAccessory {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                    Text("HomeKit")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
    }

    private var iconColor: Color {
        device.isHomeKitAccessory ? .orange : .blue
    }
}

// MARK: - Info Sheet

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("About HomeKit Discovery")
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 16) {
                HomeKitInfoRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Bonjour/mDNS Discovery",
                    description: "Discovers HomeKit devices using network service discovery without requiring iOS frameworks"
                )

                HomeKitInfoRow(
                    icon: "homekit",
                    title: "HomeKit Protocol",
                    description: "Identifies genuine HomeKit accessories using HAP (HomeKit Accessory Protocol)"
                )

                HomeKitInfoRow(
                    icon: "network",
                    title: "IP Resolution",
                    description: "Automatically resolves IP addresses for discovered devices and enriches network scan data"
                )

                HomeKitInfoRow(
                    icon: "lock.shield",
                    title: "Privacy Focused",
                    description: "No HomeKit authorization required. Uses local network discovery only"
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Service Types Scanned")
                    .font(.system(size: 15, weight: .semibold))

                VStack(alignment: .leading, spacing: 8) {
                    ServiceTypeRow(type: "_homekit._tcp", description: "HomeKit General")
                    ServiceTypeRow(type: "_hap._tcp", description: "HomeKit Accessory Protocol")
                    ServiceTypeRow(type: "_airplay._tcp", description: "AirPlay Devices")
                    ServiceTypeRow(type: "_raop._tcp", description: "Remote Audio (HomePod)")
                    ServiceTypeRow(type: "_companion-link._tcp", description: "Apple Ecosystem")
                }
                .font(.system(size: 12, design: .monospaced))
            }

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 600, height: 700)
    }
}

struct HomeKitInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ServiceTypeRow: View {
    let type: String
    let description: String

    var body: some View {
        HStack {
            Text(type)
                .foregroundColor(.blue)
            Text("-")
                .foregroundColor(.secondary)
            Text(description)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Service Type Breakdown

struct ServiceTypeBreakdownView: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @Binding var filterType: HomeKitTabView.DeviceFilter

    var serviceTypeCounts: [(String, Int, Color)] {
        var counts: [String: Int] = [:]
        for device in homeKitDiscovery.discoveredDevices {
            let type = device.serviceType
            counts[type, default: 0] += 1
        }

        let serviceColors: [String: Color] = [
            "_homekit._tcp": .orange,
            "_hap._tcp": .red,
            "_airplay._tcp": .blue,
            "_raop._tcp": .purple,
            "_companion-link._tcp": .green
        ]

        return counts.map { (key, value) in
            let color = serviceColors[key] ?? .gray
            return (key, value, color)
        }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Service Types")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(serviceTypeCounts, id: \.0) { service in
                    ServiceTypeBarRow(
                        serviceType: service.0,
                        count: service.1,
                        total: homeKitDiscovery.discoveredDevices.count,
                        color: service.2,
                        action: {
                            filterType = .serviceType(service.0)
                        }
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
        }
    }
}

struct ServiceTypeBarRow: View {
    let serviceType: String
    let count: Int
    let total: Int
    let color: Color
    var action: (() -> Void)? = nil

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var serviceLabel: String {
        switch serviceType {
        case "_homekit._tcp": return "HomeKit General"
        case "_hap._tcp": return "HomeKit Accessory"
        case "_airplay._tcp": return "AirPlay"
        case "_raop._tcp": return "Remote Audio"
        case "_companion-link._tcp": return "Companion Link"
        default: return serviceType
        }
    }

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(serviceLabel)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 10)

                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: geometry.size.width * percentage, height: 10)
                    }
                }
                .frame(height: 10)
            }
        }
        .buttonStyle(.plain)
        .help("Click to filter by \(serviceLabel)")
    }
}

// MARK: - Device Category Chart

struct DeviceCategoryChartView: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @Binding var filterType: HomeKitTabView.DeviceFilter

    var categoryCounts: [(String, Int, Color)] {
        var counts: [String: Int] = [:]
        for device in homeKitDiscovery.discoveredDevices {
            let category = device.category
            counts[category, default: 0] += 1
        }

        let categoryColors: [String: Color] = [
            "HomeKit Accessory": .orange,
            "AirPlay Device": .blue,
            "Apple Device": .green,
            "Smart Home Device": .purple
        ]

        return counts.map { (key, value) in
            let color = categoryColors[key] ?? .gray
            return (key, value, color)
        }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Categories")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                // Category breakdown cards
                ForEach(categoryCounts, id: \.0) { category in
                    CategoryCard(
                        name: category.0,
                        count: category.1,
                        color: category.2,
                        action: {
                            filterType = .category(category.0)
                        }
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
        }
    }
}

struct CategoryCard: View {
    let name: String
    let count: Int
    let color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Text("\(count)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                }

                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Click to filter by \(name)")
    }
}

// MARK: - Phase 1: Search & Filter

struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var filterType: HomeKitTabView.DeviceFilter
    let totalCount: Int
    let filteredCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search devices...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)

            // Filter picker and results count
            HStack {
                Picker("Filter", selection: $filterType) {
                    ForEach(HomeKitTabView.DeviceFilter.baseFilters, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)

                Spacer()

                if filteredCount < totalCount {
                    Text("\(filteredCount) of \(totalCount) devices")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct NoResultsView: View {
    let searchText: String
    let filterType: HomeKitTabView.DeviceFilter

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No devices found")
                .font(.system(size: 20, weight: .semibold))

            if !searchText.isEmpty {
                Text("No devices match \"\(searchText)\"")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text("No devices match the selected filter")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Active Filter Badge

struct ActiveFilterBadge: View {
    @Binding var filterType: HomeKitTabView.DeviceFilter

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)

                Text("Filtering by: \(filterType.displayName)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }

            Button(action: {
                filterType = .all
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("Clear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Phase 1: Status Card with Quick Actions

struct StatusCardWithActions: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @Binding var showExportSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("HomeKit (mDNS)", systemImage: "homekit")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if homeKitDiscovery.isAuthorized {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Active")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                if homeKitDiscovery.isScanning {
                    ProgressView()
                        .controlSize(.regular)
                }
            }

            Text("Discovers HomeKit and smart home devices using Bonjour/mDNS network discovery")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Text(homeKitDiscovery.authorizationStatus)
                .font(.system(size: 15))
                .foregroundColor(.blue)

            // Quick Actions
            HStack(spacing: 12) {
                // Quick Scan (5 seconds)
                Button(action: {
                    Task {
                        await homeKitDiscovery.startQuickScan()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Quick Scan")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: homeKitDiscovery.isScanning ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(homeKitDiscovery.isScanning)

                // Deep Scan (30 seconds)
                Button(action: {
                    Task {
                        await homeKitDiscovery.startDeepScan()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Deep Scan")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(homeKitDiscovery.isScanning)

                // Export
                Button(action: {
                    showExportSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Export")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(homeKitDiscovery.discoveredDevices.isEmpty)
            }

            if let lastSync = homeKitDiscovery.lastSync {
                Text("Last scanned: \(lastSync, style: .relative) ago")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Phase 1: Device List with Status Indicators

struct DeviceListSectionFiltered: View {
    let devices: [HomeKitDevice]
    @Binding var selectedDevice: HomeKitDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discovered Devices")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(devices) { device in
                    HomeKitDeviceCardRowEnhanced(device: device)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .onTapGesture {
                            selectedDevice = device
                        }

                    if device.id != devices.last?.id {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
        }
    }
}

struct HomeKitDeviceCardRowEnhanced: View {
    let device: HomeKitDevice
    @StateObject private var preferences = HomeKitDevicePreferences.shared
    @StateObject private var healthMonitor = HomeKitDeviceHealthMonitor.shared

    var body: some View {
        HStack(spacing: 16) {
            // Favorite Star Button
            Button(action: {
                preferences.toggleFavorite(device.id)
            }) {
                Image(systemName: preferences.isFavorite(device.id) ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(preferences.isFavorite(device.id) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(preferences.isFavorite(device.id) ? "Remove from favorites" : "Add to favorites")
            // Icon with status indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: device.isHomeKitAccessory ? "homekit" : "network")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)

                // Online/Offline indicator
                Circle()
                    .fill(device.ipAddress != nil ? Color.green : Color.gray)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.controlBackgroundColor), lineWidth: 2)
                    )
                    .offset(x: 4, y: 4)
            }

            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                // Show alias if set, otherwise show device name
                HStack(spacing: 8) {
                    Text(preferences.displayName(for: device))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    // Show original name as badge if alias is set
                    if preferences.alias(for: device.id) != nil {
                        Text(device.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }
                }

                HStack(spacing: 8) {
                    Text(device.category)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let ip = device.ipAddress {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(ip)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("No IP")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }

                    // Health indicator
                    if let health = healthMonitor.health(for: device.id) {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: health.quality.icon)
                                .font(.system(size: 11))
                                .foregroundColor(healthQualityColor(health.quality))
                            Text(health.quality.rawValue)
                                .font(.system(size: 11))
                                .foregroundColor(healthQualityColor(health.quality))
                            if let responseTime = health.responseTime {
                                Text("(\(Int(responseTime))ms)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Last seen
                Text("Discovered \(device.discoveredAt, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status badges
            VStack(alignment: .trailing, spacing: 6) {
                if device.isHomeKitAccessory {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                        Text("HomeKit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                }

                // Online status
                HStack(spacing: 6) {
                    Circle()
                        .fill(device.ipAddress != nil ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(device.ipAddress != nil ? "Online" : "Offline")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    private var iconColor: Color {
        device.isHomeKitAccessory ? .orange : .blue
    }

    private func healthQualityColor(_ quality: DeviceHealth.ConnectionQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .offline: return .red
        }
    }
}

// MARK: - Phase 1: Export Sheet

struct ExportSheet: View {
    let devices: [HomeKitDevice]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .csv
    @State private var showingSavePanel = false

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case markdown = "Markdown"
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Export HomeKit Devices")
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Export \(devices.count) devices to file")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exported data includes:")
                            .font(.system(size: 13, weight: .medium))

                        VStack(alignment: .leading, spacing: 8) {
                            ExportFieldRow(icon: "network", label: "Device name and IP address")
                            ExportFieldRow(icon: "tag", label: "Service type and category")
                            ExportFieldRow(icon: "clock", label: "Discovery timestamp")
                            ExportFieldRow(icon: "checkmark.seal", label: "HomeKit accessory status")
                        }
                    }
                    .padding()
                }
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Export") {
                    exportDevices()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 600, height: 450)
    }

    private func exportDevices() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "homekit-devices-\(Date().formatted(.iso8601.year().month().day()))"

        switch exportFormat {
        case .csv:
            savePanel.allowedContentTypes = [.commaSeparatedText]
            savePanel.nameFieldStringValue += ".csv"
        case .json:
            savePanel.allowedContentTypes = [.json]
            savePanel.nameFieldStringValue += ".json"
        case .markdown:
            savePanel.allowedContentTypes = [.plainText]
            savePanel.nameFieldStringValue += ".md"
        }

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            let content: String
            switch exportFormat {
            case .csv:
                content = generateCSV()
            case .json:
                content = generateJSON()
            case .markdown:
                content = generateMarkdown()
            }

            try? content.write(to: url, atomically: true, encoding: .utf8)
            dismiss()
        }
    }

    private func generateCSV() -> String {
        var csv = "Name,IP Address,Service Type,Category,HomeKit Accessory,Discovered At\n"
        for device in devices {
            csv += "\"\(device.displayName)\","
            csv += "\"\(device.ipAddress ?? "N/A")\","
            csv += "\"\(device.serviceType)\","
            csv += "\"\(device.category)\","
            csv += "\(device.isHomeKitAccessory),"
            csv += "\"\(device.discoveredAt.formatted())\"\n"
        }
        return csv
    }

    private func generateJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let exportData = devices.map { device in
            [
                "name": device.displayName,
                "ip_address": device.ipAddress ?? "N/A",
                "service_type": device.serviceType,
                "category": device.category,
                "is_homekit_accessory": "\(device.isHomeKitAccessory)",
                "discovered_at": device.discoveredAt.formatted(.iso8601)
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }

    private func generateMarkdown() -> String {
        var md = "# HomeKit Devices\n\n"
        md += "Exported: \(Date().formatted())\n\n"
        md += "Total Devices: \(devices.count)\n\n"
        md += "## Device List\n\n"
        md += "| Name | IP Address | Service Type | Category | HomeKit |\n"
        md += "|------|------------|--------------|----------|--------|\n"

        for device in devices {
            md += "| \(device.displayName) "
            md += "| \(device.ipAddress ?? "N/A") "
            md += "| `\(device.serviceType)` "
            md += "| \(device.category) "
            md += "| \(device.isHomeKitAccessory ? "✅" : "❌") |\n"
        }

        return md
    }
}

struct ExportFieldRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
        }
    }
}

// MARK: - Phase 2: Device Detail Sheet

struct DeviceDetailSheet: View {
    let device: HomeKitDevice
    @ObservedObject var preferences: HomeKitDevicePreferences
    @ObservedObject var healthMonitor: HomeKitDeviceHealthMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var aliasText: String = ""
    @State private var isEditingAlias: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.displayName)
                        .font(.system(size: 28, weight: .bold))

                    HStack(spacing: 12) {
                        if device.isHomeKitAccessory {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                Text("HomeKit Accessory")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(device.ipAddress != nil ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(device.ipAddress != nil ? "Online" : "Offline")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(30)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Device Alias (Nickname)
                    HomeKitDetailSection(title: "Device Alias") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Custom Name")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 180, alignment: .leading)

                                if isEditingAlias {
                                    TextField("Enter custom name", text: $aliasText)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 14))

                                    Button("Save") {
                                        preferences.setAlias(aliasText, for: device.id)
                                        isEditingAlias = false
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button("Cancel") {
                                        aliasText = preferences.alias(for: device.id) ?? ""
                                        isEditingAlias = false
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Text(preferences.alias(for: device.id) ?? "Not set")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Button(preferences.alias(for: device.id) == nil ? "Set Alias" : "Edit") {
                                        isEditingAlias = true
                                    }
                                    .buttonStyle(.bordered)

                                    if preferences.alias(for: device.id) != nil {
                                        Button("Remove") {
                                            preferences.removeAlias(for: device.id)
                                            aliasText = ""
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }

                            if let alias = preferences.alias(for: device.id) {
                                Text("Original name: \(device.displayName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            // Favorite toggle
                            Divider()

                            HStack {
                                Text("Favorite")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 180, alignment: .leading)

                                Toggle("", isOn: Binding(
                                    get: { preferences.isFavorite(device.id) },
                                    set: { _ in preferences.toggleFavorite(device.id) }
                                ))
                                .labelsHidden()

                                Spacer()

                                Image(systemName: "star.fill")
                                    .foregroundColor(preferences.isFavorite(device.id) ? .yellow : .secondary)
                            }
                        }
                    }

                    // Device Health Status
                    if let health = healthMonitor.health(for: device.id) {
                        HomeKitDetailSection(title: "Device Health") {
                            HomeKitDetailRow(
                                label: "Connection Quality",
                                value: health.quality.rawValue
                            )

                            if let responseTime = health.responseTime {
                                HomeKitDetailRow(
                                    label: "Response Time",
                                    value: "\(Int(responseTime)) ms",
                                    monospaced: true
                                )
                            }

                            HomeKitDetailRow(
                                label: "Status",
                                value: health.isReachable ? "Reachable" : "Unreachable"
                            )

                            HomeKitDetailRow(
                                label: "Last Checked",
                                value: health.timestamp.formatted()
                            )

                            HomeKitDetailRow(
                                label: "Last Seen",
                                value: health.lastSeen.formatted()
                            )
                        }
                    }

                    // Basic Information
                    HomeKitDetailSection(title: "Basic Information") {
                        HomeKitDetailRow(label: "Device Name", value: device.displayName)
                        HomeKitDetailRow(label: "Category", value: device.category)
                        if let ip = device.ipAddress {
                            HomeKitDetailRow(label: "IP Address", value: ip, monospaced: true)
                        }
                        HomeKitDetailRow(label: "Interface", value: device.interface ?? "Unknown")
                    }

                    // Service Information
                    HomeKitDetailSection(title: "Service Information") {
                        HomeKitDetailRow(label: "Service Type", value: device.serviceType, monospaced: true)
                        HomeKitDetailRow(label: "Domain", value: device.domain)
                        HomeKitDetailRow(label: "HomeKit Accessory", value: device.isHomeKitAccessory ? "Yes" : "No")
                    }

                    // Discovery Information
                    HomeKitDetailSection(title: "Discovery Information") {
                        HomeKitDetailRow(label: "First Discovered", value: device.discoveredAt.formatted())
                        HomeKitDetailRow(label: "Time Since Discovery", value: formatRelativeTime(device.discoveredAt))
                    }

                    // TXT Records (mDNS metadata)
                    if let txtRecords = device.txtRecords, !txtRecords.isEmpty {
                        HomeKitDetailSection(title: "TXT Records (mDNS Metadata)") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Service advertisement metadata from Bonjour/mDNS")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 8)

                                ForEach(Array(txtRecords.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                    HStack {
                                        Text(key)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.blue)
                                            .frame(width: 120, alignment: .leading)

                                        Text("=")
                                            .foregroundColor(.secondary)

                                        Text(value)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)

                                    if key != Array(txtRecords.sorted(by: { $0.key < $1.key })).last?.key {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }

                    // All Service Types (if multiple)
                    HomeKitDetailSection(title: "Technical Details") {
                        HomeKitDetailRow(label: "mDNS Name", value: device.name)
                        HomeKitDetailRow(label: "Service Priority", value: servicePriority())
                    }
                }
                .padding(30)
            }
        }
        .frame(width: 700, height: 800)
        .onAppear {
            // Load current alias
            aliasText = preferences.alias(for: device.id) ?? ""

            // Start health check
            Task {
                _ = await healthMonitor.quickHealthCheck(for: device)
            }
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        } else {
            return "\(minutes)m ago"
        }
    }

    private func servicePriority() -> String {
        if device.serviceType.contains("hap") || device.serviceType.contains("homekit") {
            return "High (HomeKit Accessory)"
        } else if device.serviceType.contains("airplay") {
            return "Medium (AirPlay)"
        } else if device.serviceType.contains("raop") {
            return "Low (Remote Audio)"
        } else {
            return "Standard"
        }
    }
}

struct HomeKitDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                content
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

struct HomeKitDetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 180, alignment: .leading)

            Text(value)
                .font(.system(size: 14, design: monospaced ? .monospaced : .default))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Phase 2: Service Type Legend Panel

struct ServiceTypeLegendView: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)

                    Text("Service Type Legend")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            if isExpanded {
                VStack(spacing: 20) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Understanding mDNS Service Types")
                            .font(.system(size: 18, weight: .semibold))

                        Text("HomeKit devices advertise their presence on the network using mDNS (multicast DNS) service types. Each service type represents a different protocol or capability. A single physical device may advertise multiple service types.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Service type cards
                    ServiceTypeLegendCard(
                        serviceType: "_hap._tcp",
                        name: "HomeKit Accessory Protocol",
                        description: "The primary protocol for HomeKit-certified accessories. Devices advertising this service are genuine HomeKit devices that can be controlled through the Home app and Siri.",
                        icon: "homekit",
                        color: .orange,
                        examples: ["Smart lights", "Thermostats", "Door locks", "Security cameras"]
                    )

                    ServiceTypeLegendCard(
                        serviceType: "_homekit._tcp",
                        name: "HomeKit General",
                        description: "Alternative HomeKit service advertisement. Some devices use this alongside HAP for broader compatibility.",
                        icon: "house.fill",
                        color: .red,
                        examples: ["Bridges", "Hubs", "Multi-function accessories"]
                    )

                    ServiceTypeLegendCard(
                        serviceType: "_airplay._tcp",
                        name: "AirPlay",
                        description: "Apple's wireless streaming protocol for audio and video. Many HomeKit speakers also support AirPlay.",
                        icon: "airplayvideo",
                        color: .blue,
                        examples: ["HomePod", "Apple TV", "AirPlay speakers", "Smart TVs"]
                    )

                    ServiceTypeLegendCard(
                        serviceType: "_raop._tcp",
                        name: "Remote Audio Output Protocol",
                        description: "Legacy protocol for streaming audio to AirPlay devices. RAOP predates AirPlay and is used for audio-only streaming.",
                        icon: "speaker.wave.2.fill",
                        color: .purple,
                        examples: ["HomePod", "AirPort Express", "Audio receivers"]
                    )

                    ServiceTypeLegendCard(
                        serviceType: "_companion-link._tcp",
                        name: "Apple Companion Link",
                        description: "Protocol for communication between Apple devices in the same ecosystem. Enables continuity features and device-to-device coordination.",
                        icon: "link",
                        color: .green,
                        examples: ["Mac", "iPad", "Apple Watch", "Apple TV"]
                    )

                    ServiceTypeLegendCard(
                        serviceType: "_sleep-proxy._udp",
                        name: "Sleep Proxy Service",
                        description: "Network service that allows devices to sleep while maintaining network presence. The proxy responds to network requests on behalf of sleeping devices.",
                        icon: "moon.fill",
                        color: .indigo,
                        examples: ["AirPort base stations", "Mac mini", "Time Capsule"]
                    )

                    // Statistics summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Network Statistics")
                            .font(.system(size: 18, weight: .semibold))

                        HStack(spacing: 20) {
                            StatisticBubble(
                                count: homeKitDiscovery.discoveredDevices.filter { $0.isHomeKitAccessory }.count,
                                label: "HomeKit\nAccessories",
                                color: .orange
                            )

                            StatisticBubble(
                                count: homeKitDiscovery.discoveredDevices.filter { $0.serviceType.contains("airplay") }.count,
                                label: "AirPlay\nDevices",
                                color: .blue
                            )

                            StatisticBubble(
                                count: homeKitDiscovery.discoveredDevices.filter { $0.serviceType.contains("raop") }.count,
                                label: "RAOP\nDevices",
                                color: .purple
                            )

                            StatisticBubble(
                                count: homeKitDiscovery.discoveredDevices.filter { $0.serviceType.contains("companion") }.count,
                                label: "Companion\nDevices",
                                color: .green
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ServiceTypeLegendCard: View {
    let serviceType: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))

                    Text(serviceType)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !examples.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Common Examples:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(examples, id: \.self) { example in
                            Text(example)
                                .font(.system(size: 11))
                                .foregroundColor(color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(color.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct StatisticBubble: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Text("\(count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
    }
}

// MARK: - Phase 2: Historical Timeline View

struct HomeKitHistoricalTimelineView: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @State private var isExpanded = false
    @State private var filter: TimelineFilter = .all

    enum TimelineFilter: String, CaseIterable {
        case all = "All Events"
        case discovered = "Discovered"
        case updated = "Updated"
        case disappeared = "Disappeared"
    }

    var filteredEvents: [DiscoveryEvent] {
        switch filter {
        case .all:
            return homeKitDiscovery.discoveryHistory
        case .discovered:
            return homeKitDiscovery.discoveryHistory.filter { $0.eventType == .discovered }
        case .updated:
            return homeKitDiscovery.discoveryHistory.filter { $0.eventType == .updated }
        case .disappeared:
            return homeKitDiscovery.discoveryHistory.filter { $0.eventType == .disappeared }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)

                    Text("Discovery Timeline")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)

                    if !homeKitDiscovery.discoveryHistory.isEmpty {
                        Text("\(homeKitDiscovery.discoveryHistory.count) events")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            if isExpanded {
                VStack(spacing: 16) {
                    // Filter picker
                    if !homeKitDiscovery.discoveryHistory.isEmpty {
                        Picker("Filter", selection: $filter) {
                            ForEach(TimelineFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if filteredEvents.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text(homeKitDiscovery.discoveryHistory.isEmpty ? "No discovery events yet" : "No events match this filter")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            Text("Run a scan to start discovering HomeKit devices")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                    TimelineEventRow(event: event, isLast: index == filteredEvents.count - 1)
                                }
                            }
                        }
                        .frame(maxHeight: 400)

                        // Timeline statistics
                        HStack(spacing: 16) {
                            TimelineStatCard(
                                count: homeKitDiscovery.discoveryHistory.filter { $0.eventType == .discovered }.count,
                                label: "Discovered",
                                icon: "plus.circle.fill",
                                color: .green
                            )

                            TimelineStatCard(
                                count: homeKitDiscovery.discoveryHistory.filter { $0.eventType == .updated }.count,
                                label: "Updated",
                                icon: "arrow.triangle.2.circlepath",
                                color: .blue
                            )

                            TimelineStatCard(
                                count: homeKitDiscovery.discoveryHistory.filter { $0.eventType == .disappeared }.count,
                                label: "Disappeared",
                                icon: "minus.circle.fill",
                                color: .orange
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

struct TimelineEventRow: View {
    let event: DiscoveryEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(event.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: event.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(event.color)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }

            // Event details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.eventType.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(event.deviceName)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(event.serviceType)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let ip = event.deviceIP {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(ip)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Text(event.timestamp, style: .relative)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct TimelineStatCard: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Phase 2: Comparison View (Network vs HomeKit)

struct HomeKitComparisonView: View {
    @ObservedObject var homeKitDiscovery: HomeKitDiscoveryMacOS
    @StateObject private var scanner = IntegratedScannerV3.shared
    @State private var isExpanded = false

    var homeKitIPs: Set<String> {
        Set(homeKitDiscovery.discoveredDevices.compactMap { $0.ipAddress })
    }

    var networkIPs: Set<String> {
        Set(scanner.devices.map { $0.ipAddress })
    }

    var onlyInHomeKit: [HomeKitDevice] {
        homeKitDiscovery.discoveredDevices.filter { device in
            if let ip = device.ipAddress {
                return !networkIPs.contains(ip)
            }
            return true
        }
    }

    var onlyInNetwork: [EnhancedDevice] {
        scanner.devices.filter { device in
            !homeKitIPs.contains(device.ipAddress)
        }
    }

    var inBoth: [(HomeKitDevice, EnhancedDevice)] {
        var matches: [(HomeKitDevice, EnhancedDevice)] = []
        for homeKit in homeKitDiscovery.discoveredDevices {
            if let ip = homeKit.ipAddress,
               let network = scanner.devices.first(where: { $0.ipAddress == ip }) {
                matches.append((homeKit, network))
            }
        }
        return matches
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)

                    Text("Network vs HomeKit Comparison")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            if isExpanded {
                VStack(spacing: 20) {
                    // Summary statistics
                    HStack(spacing: 16) {
                        ComparisonStatCard(
                            count: onlyInHomeKit.count,
                            label: "Only HomeKit",
                            icon: "homekit",
                            color: .orange,
                            description: "Devices found only via HomeKit discovery"
                        )

                        ComparisonStatCard(
                            count: inBoth.count,
                            label: "In Both",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            description: "Devices found by both methods"
                        )

                        ComparisonStatCard(
                            count: onlyInNetwork.count,
                            label: "Only Network",
                            icon: "network",
                            color: .blue,
                            description: "Devices found only via network scan"
                        )
                    }

                    if onlyInHomeKit.isEmpty && onlyInNetwork.isEmpty && inBoth.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.badge.minus")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No devices to compare")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            Text("Run both network scan and HomeKit discovery to compare results")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        // Detailed comparison sections
                        ScrollView {
                            VStack(spacing: 24) {
                                // Devices in both
                                if !inBoth.isEmpty {
                                    ComparisonSection(
                                        title: "Matched Devices (\(inBoth.count))",
                                        icon: "checkmark.circle.fill",
                                        color: .green
                                    ) {
                                        ForEach(inBoth, id: \.0.id) { homeKit, network in
                                            MatchedDeviceRow(homeKitDevice: homeKit, networkDevice: network)
                                        }
                                    }
                                }

                                // Only in HomeKit
                                if !onlyInHomeKit.isEmpty {
                                    ComparisonSection(
                                        title: "Only in HomeKit (\(onlyInHomeKit.count))",
                                        icon: "homekit",
                                        color: .orange
                                    ) {
                                        ForEach(onlyInHomeKit) { device in
                                            HomeKitOnlyRow(device: device)
                                        }
                                    }
                                }

                                // Only in Network
                                if !onlyInNetwork.isEmpty {
                                    ComparisonSection(
                                        title: "Only in Network Scan (\(onlyInNetwork.count))",
                                        icon: "network",
                                        color: .blue
                                    ) {
                                        ForEach(onlyInNetwork) { device in
                                            NetworkOnlyRow(device: device)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 500)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ComparisonStatCard: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ComparisonSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct MatchedDeviceRow: View {
    let homeKitDevice: HomeKitDevice
    let networkDevice: EnhancedDevice

    var body: some View {
        HStack(spacing: 12) {
            // HomeKit side
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "homekit")
                        .foregroundColor(.orange)
                    Text(homeKitDevice.displayName)
                        .font(.system(size: 14, weight: .medium))
                }

                Text(homeKitDevice.serviceType)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Match indicator
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 16))
                .foregroundColor(.green)

            // Network side
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text(networkDevice.deviceName ?? networkDevice.hostname ?? "Unknown")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                }

                if let manufacturer = networkDevice.manufacturer {
                    Text(manufacturer)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct HomeKitOnlyRow: View {
    let device: HomeKitDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "homekit")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 14, weight: .medium))

                Text(device.serviceType)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                if let ip = device.ipAddress {
                    Text("IP: \(ip)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("No IP resolved")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Text("HomeKit Only")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct NetworkOnlyRow: View {
    let device: EnhancedDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 20))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceName ?? device.hostname ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))

                if let manufacturer = device.manufacturer {
                    Text(manufacturer)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text("IP: \(device.ipAddress)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Network Only")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// FlowLayout for tag-style wrapping
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if currentX + subviewSize.width > maxWidth {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, subviewSize.height)
                currentX += subviewSize.width + spacing
                size.width = max(size.width, currentX)
            }

            size.height = currentY + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}

#Preview {
    HomeKitTabView()
}
