//
//  ShadowAIMonitorView.swift
//  NMAPScanner - Shadow AI Monitoring Dashboard
//
//  Provides a comprehensive view for monitoring and managing AI services
//  detected on the network, with timeline, authorization controls, and alerts.
//
//  Created by Jordan Koch on 2025-02-02.
//

import SwiftUI

// MARK: - Main Monitor View

struct ShadowAIMonitorView: View {
    @StateObject private var detector = ShadowAIDetector.shared
    @State private var selectedTab: MonitorTab = .dashboard
    @State private var showingSettings = false
    @State private var selectedService: AIServiceInfo?
    @State private var showingServiceDetail = false

    enum MonitorTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case services = "Services"
        case timeline = "Timeline"
        case unauthorized = "Unauthorized"

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.67percent"
            case .services: return "server.rack"
            case .timeline: return "clock.arrow.circlepath"
            case .unauthorized: return "exclamationmark.shield"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                tabSelector

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .dashboard:
                        dashboardView
                    case .services:
                        servicesListView
                    case .timeline:
                        timelineView
                    case .unauthorized:
                        unauthorizedView
                    }
                }
            }
            .navigationTitle("Shadow AI Monitor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        // Scan button
                        Button(action: {
                            Task {
                                await detector.scanForAIServices()
                            }
                        }) {
                            Label("Scan Now", systemImage: detector.isScanning ? "stop.circle" : "magnifyingglass")
                        }
                        .disabled(detector.isScanning)

                        // Settings button
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ShadowAISettingsView()
            }
            .sheet(item: $selectedService) { service in
                AIServiceDetailView(service: service)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(MonitorTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: .medium))

                        // Badge for unauthorized
                        if tab == .unauthorized && !detector.unauthorizedServices.isEmpty {
                            Text("\(detector.unauthorizedServices.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Dashboard View

    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Monitoring Status Card
                monitoringStatusCard

                // Statistics Cards
                statisticsGrid

                // Recent Activity
                recentActivityCard

                // Service Type Distribution
                serviceDistributionCard
            }
            .padding(24)
        }
    }

    private var monitoringStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: detector.isMonitoring ? "eye.fill" : "eye.slash")
                    .font(.system(size: 32))
                    .foregroundColor(detector.isMonitoring ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(detector.isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                        .font(.system(size: 20, weight: .semibold))
                    Text(detector.currentStatus)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { detector.isMonitoring },
                    set: { enabled in
                        if enabled {
                            detector.startMonitoring()
                        } else {
                            detector.stopMonitoring()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            // Progress bar during scan
            if detector.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: detector.scanProgress)
                        .progressViewStyle(.linear)
                    Text("\(Int(detector.scanProgress * 100))% complete")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Last scan info
            if let lastScan = detector.lastScanDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Last scan: \(lastScan, style: .relative) ago")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var statisticsGrid: some View {
        let stats = detector.statistics

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ShadowStatCard(
                title: "Online",
                value: "\(stats.onlineServices)",
                icon: "checkmark.circle.fill",
                color: .green
            )

            ShadowStatCard(
                title: "Offline",
                value: "\(stats.offlineServices)",
                icon: "xmark.circle.fill",
                color: .gray
            )

            ShadowStatCard(
                title: "Authorized",
                value: "\(stats.authorizedServices)",
                icon: "checkmark.shield.fill",
                color: .blue
            )

            ShadowStatCard(
                title: "Unauthorized",
                value: "\(stats.unauthorizedServices)",
                icon: "exclamationmark.shield.fill",
                color: stats.unauthorizedServices > 0 ? .red : .green
            )
        }
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("Last 24 hours: \(detector.statistics.eventsLast24Hours) events")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            if detector.events.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No events recorded yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("Start a scan to detect AI services")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(detector.events.prefix(5)) { event in
                        EventRow(event: event, compact: true)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var serviceDistributionCard: some View {
        let stats = detector.statistics

        return VStack(alignment: .leading, spacing: 16) {
            Text("Service Distribution")
                .font(.system(size: 18, weight: .semibold))

            if stats.servicesByType.isEmpty {
                HStack {
                    Spacer()
                    Text("No services detected")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(stats.servicesByType.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .foregroundColor(type.riskLevel.color)
                            VStack(alignment: .leading) {
                                Text(type.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                Text("\(count) service\(count == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Services List View

    private var servicesListView: some View {
        ScrollView {
            if detector.knownServices.isEmpty {
                emptyStateView(
                    icon: "server.rack",
                    title: "No AI Services Found",
                    message: "Run a scan to discover AI services on your network"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(detector.knownServices.values.sorted(by: { $0.host < $1.host })) { service in
                        ServiceCard(service: service) {
                            selectedService = service
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        ScrollView {
            if detector.events.isEmpty {
                emptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Events Recorded",
                    message: "Events will appear here when AI services are detected or change"
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(detector.events) { event in
                        EventRow(event: event, compact: false)
                        Divider()
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Unauthorized View

    private var unauthorizedView: some View {
        ScrollView {
            if detector.unauthorizedServices.isEmpty {
                emptyStateView(
                    icon: "checkmark.shield.fill",
                    title: "No Unauthorized Services",
                    message: "All detected AI services are authorized",
                    iconColor: .green
                )
            } else {
                VStack(spacing: 16) {
                    // Warning banner
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unauthorized AI Services Detected")
                                .font(.system(size: 16, weight: .semibold))
                            Text("These services may pose a security risk. Review and authorize or investigate.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)

                    // List of unauthorized services
                    LazyVStack(spacing: 12) {
                        ForEach(detector.unauthorizedServices) { service in
                            UnauthorizedServiceCard(service: service) {
                                selectedService = service
                            } onAuthorize: {
                                detector.markAsAuthorized(host: service.host, port: service.port)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Helper Views

    private func emptyStateView(icon: String, title: String, message: String, iconColor: Color = .secondary) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: 24, weight: .semibold))

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if !detector.isScanning {
                Button(action: {
                    Task {
                        await detector.scanForAIServices()
                    }
                }) {
                    Label("Start Scan", systemImage: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(60)
    }
}

// MARK: - Stat Card

struct ShadowStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Service Card

struct ServiceCard: View {
    let service: AIServiceInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Status indicator
                Circle()
                    .fill(service.isOnline ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                // Service icon
                Image(systemName: service.serviceType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(service.serviceType.riskLevel.color)
                    .frame(width: 40)

                // Service info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(service.serviceName)
                            .font(.system(size: 16, weight: .semibold))

                        if service.isAuthorized {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }

                    Text("\(service.host):\(service.port)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let modelInfo = service.modelInfo {
                        Text("Models: \(modelInfo)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Risk level badge
                Text(service.serviceType.riskLevel.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(service.serviceType.riskLevel.color.opacity(0.2))
                    .foregroundColor(service.serviceType.riskLevel.color)
                    .cornerRadius(8)

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unauthorized Service Card

struct UnauthorizedServiceCard: View {
    let service: AIServiceInfo
    let onTap: () -> Void
    let onAuthorize: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)

                    // Service info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.serviceName)
                            .font(.system(size: 16, weight: .semibold))

                        Text("\(service.host):\(service.port)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Text(service.serviceType.rawValue)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Text("Risk: \(service.serviceType.riskLevel.rawValue)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(service.serviceType.riskLevel.color)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(16)

            Divider()

            // Action buttons
            HStack(spacing: 16) {
                Button(action: onAuthorize) {
                    Label("Authorize", systemImage: "checkmark.shield")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: onTap) {
                    Label("Investigate", systemImage: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("First seen: \(service.firstSeen, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: AIServiceEvent
    let compact: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Event icon
            Image(systemName: event.icon)
                .font(.system(size: compact ? 20 : 24))
                .foregroundColor(event.color)
                .frame(width: compact ? 32 : 40)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.eventType.rawValue)
                        .font(.system(size: compact ? 14 : 16, weight: .medium))

                    if !event.isAuthorized && (event.eventType == .appeared) {
                        Text("UNAUTHORIZED")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }

                Text("\(event.serviceName) on \(event.host):\(event.port)")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundColor(.secondary)

                if !compact {
                    if let details = event.details {
                        Text(details)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if let previousValue = event.previousValue, let newValue = event.newValue {
                        HStack(spacing: 4) {
                            Text(previousValue)
                                .strikethrough()
                                .foregroundColor(.red)
                            Image(systemName: "arrow.right")
                            Text(newValue)
                                .foregroundColor(.green)
                        }
                        .font(.system(size: 12))
                    }
                }
            }

            Spacer()

            // Timestamp
            Text(event.timestamp, style: .relative)
                .font(.system(size: compact ? 12 : 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, compact ? 8 : 12)
    }
}

// MARK: - AI Service Detail View

struct AIServiceDetailView: View {
    let service: AIServiceInfo
    @StateObject private var detector = ShadowAIDetector.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: service.serviceType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(service.serviceType.riskLevel.color)

                        Text(service.serviceName)
                            .font(.system(size: 28, weight: .bold))

                        HStack(spacing: 16) {
                            Label(service.isOnline ? "Online" : "Offline", systemImage: service.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(service.isOnline ? .green : .gray)

                            Label(service.isAuthorized ? "Authorized" : "Unauthorized", systemImage: service.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .foregroundColor(service.isAuthorized ? .green : .red)
                        }
                        .font(.system(size: 16))
                    }
                    .padding(24)

                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        ShadowDetailRow(label: "Host", value: service.host)
                        ShadowDetailRow(label: "Port", value: "\(service.port)")
                        ShadowDetailRow(label: "Service Type", value: service.serviceType.rawValue)
                        ShadowDetailRow(label: "Risk Level", value: service.serviceType.riskLevel.rawValue, valueColor: service.serviceType.riskLevel.color)

                        if let modelInfo = service.modelInfo {
                            ShadowDetailRow(label: "Models", value: modelInfo)
                        }

                        if let version = service.version {
                            ShadowDetailRow(label: "Version", value: version)
                        }

                        if let responseTime = service.responseTime {
                            ShadowDetailRow(label: "Response Time", value: String(format: "%.0f ms", responseTime * 1000))
                        }

                        ShadowDetailRow(label: "First Seen", value: service.firstSeen.formatted(date: .abbreviated, time: .shortened))
                        ShadowDetailRow(label: "Last Seen", value: service.lastSeen.formatted(date: .abbreviated, time: .shortened))
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )

                    // Actions
                    VStack(spacing: 12) {
                        if service.isAuthorized {
                            Button(action: {
                                detector.revokeAuthorization(host: service.host, port: service.port)
                                dismiss()
                            }) {
                                Label("Revoke Authorization", systemImage: "xmark.shield")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button(action: {
                                detector.markAsAuthorized(host: service.host, port: service.port)
                                dismiss()
                            }) {
                                Label("Authorize Service", systemImage: "checkmark.shield")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }

                        // Open in browser (if web service)
                        if service.serviceType != .triton && service.serviceType != .milvus {
                            Button(action: {
                                let protocol_prefix = [8443, 443].contains(service.port) ? "https" : "http"
                                if let url = URL(string: "\(protocol_prefix)://\(service.host):\(service.port)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Label("Open in Browser", systemImage: "safari")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(20)
                }
                .padding(24)
            }
            .navigationTitle("Service Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

struct ShadowDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Settings View

struct ShadowAISettingsView: View {
    @StateObject private var detector = ShadowAIDetector.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Monitoring") {
                    Picker("Scan Interval", selection: $detector.alertSettings.monitoringInterval) {
                        Text("1 minute").tag(TimeInterval(60))
                        Text("5 minutes").tag(TimeInterval(300))
                        Text("15 minutes").tag(TimeInterval(900))
                        Text("30 minutes").tag(TimeInterval(1800))
                        Text("1 hour").tag(TimeInterval(3600))
                    }

                    Toggle("Auto-start monitoring on launch", isOn: .constant(false))
                        .disabled(true) // Disabled: requires persistent launch-agent configuration to auto-start Shadow AI monitoring
                }

                Section("Notifications") {
                    Toggle("New AI service detected", isOn: $detector.alertSettings.notifyOnNewService)
                    Toggle("Service went offline", isOn: $detector.alertSettings.notifyOnServiceOffline)
                    Toggle("Unauthorized service detected", isOn: $detector.alertSettings.notifyOnUnauthorized)
                    Toggle("Model changed", isOn: $detector.alertSettings.notifyOnModelChange)
                }

                Section("Authorized Hosts") {
                    if detector.authorizedHosts.isEmpty {
                        Text("No authorized hosts configured")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(detector.authorizedHosts).sorted(), id: \.self) { host in
                            HStack {
                                Text(host)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(action: {
                                    if host.contains(":") {
                                        let parts = host.components(separatedBy: ":")
                                        if let port = Int(parts[1]) {
                                            detector.revokeAuthorization(host: parts[0], port: port)
                                        }
                                    } else {
                                        detector.revokeAuthorization(host: host)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Data Management") {
                    Button(action: { showingClearConfirmation = true }) {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                Section("About") {
                    LabeledContent("Services Tracked", value: "\(detector.knownServices.count)")
                    LabeledContent("Events Recorded", value: "\(detector.events.count)")
                    if let lastScan = detector.lastScanDate {
                        LabeledContent("Last Scan", value: lastScan.formatted())
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Shadow AI Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        detector.saveAlertSettings()
                        dismiss()
                    }
                }
            }
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    detector.clearAllData()
                }
            } message: {
                Text("This will remove all detected services, events, and authorized hosts. This action cannot be undone.")
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }
}

// MARK: - Preview

#Preview {
    ShadowAIMonitorView()
}
