//
//  AIServiceDetailView.swift
//  NMAP Plus Security Scanner v8.3.0
//
//  Created by Jordan Koch on 2026-02-02.
//
//  SwiftUI views for displaying AI service status and health monitoring.
//  Includes:
//  - Service status cards
//  - GPU memory usage visualization
//  - Model listings
//  - Health indicators
//

import SwiftUI

// MARK: - AI Services Dashboard View

/// Main dashboard view for AI services
struct AIServicesDashboardView: View {
    @StateObject private var healthChecker = AIServiceHealthChecker.shared
    @StateObject private var scanner = IntegratedScannerV3.shared
    @State private var showingScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Quick stats
                if !healthChecker.services.isEmpty {
                    statsCards
                }

                // Scan controls
                scanControlsView

                // Services list
                if healthChecker.services.isEmpty && !healthChecker.isScanning {
                    emptyStateView
                } else {
                    servicesListView
                }
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .glow(color: .blue, radius: 10, intensity: 0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Services Monitor")
                    .font(.system(size: 28, weight: .bold))

                if let lastScan = healthChecker.lastScanDate {
                    Text("Last scan: \(lastScan, style: .relative) ago")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    Text("No scan performed yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Refresh button
            Button(action: {
                Task {
                    await healthChecker.refreshAllServices()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(healthChecker.isScanning)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 16) {
            AIServiceStatCard(
                icon: "server.rack",
                value: "\(healthChecker.services.count)",
                label: "Services Found",
                color: .blue
            )

            AIServiceStatCard(
                icon: "checkmark.circle.fill",
                value: "\(healthChecker.healthyServices.count)",
                label: "Healthy",
                color: .green
            )

            AIServiceStatCard(
                icon: "cube.box.fill",
                value: "\(healthChecker.totalModels)",
                label: "Total Models",
                color: .purple
            )

            if !healthChecker.servicesWithLoadedModels.isEmpty {
                AIServiceStatCard(
                    icon: "bolt.fill",
                    value: "\(healthChecker.servicesWithLoadedModels.count)",
                    label: "Active Models",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Scan Controls

    private var scanControlsView: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Network Scan")
                        .font(.system(size: 18, weight: .semibold))

                    Spacer()

                    if healthChecker.isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(healthChecker.scanStatus)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if healthChecker.isScanning {
                    ProgressView(value: healthChecker.scanProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            // Get all discovered IPs from scanner
                            let hosts = scanner.devices.compactMap { $0.ipAddress }
                            await healthChecker.scanAllServices(hosts: Array(Set(hosts)))
                        }
                    }) {
                        HStack {
                            Image(systemName: "network")
                            Text("Scan Network Devices")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(healthChecker.isScanning || scanner.devices.isEmpty)

                    Button(action: {
                        Task {
                            await healthChecker.scanAllServices(hosts: ["localhost", "127.0.0.1"])
                        }
                    }) {
                        HStack {
                            Image(systemName: "desktopcomputer")
                            Text("Scan Localhost")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(healthChecker.isScanning)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No AI Services Found")
                    .font(.system(size: 20, weight: .semibold))

                Text("Scan your network to discover AI services like Ollama, vLLM, ComfyUI, and more.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Services List

    private var servicesListView: some View {
        VStack(spacing: 12) {
            ForEach(healthChecker.services) { service in
                AIServiceCard(service: service)
            }
        }
    }
}

// MARK: - AI Stat Card

private struct AIServiceStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .glow(color: color, radius: 6, intensity: 0.3)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }
}

// MARK: - AI Service Card

struct AIServiceCard: View {
    let service: AIServiceStatus
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 16) {
                // Service icon with health indicator
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: service.serviceType.icon)
                        .font(.system(size: 32))
                        .foregroundColor(service.serviceType.color)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(service.serviceType.color.opacity(0.15))
                        )
                        .glow(color: service.serviceType.color, radius: 8, intensity: 0.3)

                    // Health indicator
                    Circle()
                        .fill(service.healthStatus.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 4, y: 4)
                }

                // Service info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(service.serviceType.rawValue)
                            .font(.system(size: 18, weight: .semibold))

                        Spacer()

                        // Response time badge
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(String(format: "%.0fms", service.responseTime * 1000))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(responseTimeColor.opacity(0.2))
                        .foregroundColor(responseTimeColor)
                        .cornerRadius(4)
                    }

                    Text("\(service.host):\(service.port)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        // Models count
                        if let models = service.models {
                            HStack(spacing: 4) {
                                Image(systemName: "cube.box")
                                    .font(.system(size: 12))
                                Text("\(models.count) models")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                        }

                        // Loaded model
                        if let loaded = service.loadedModel {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12))
                                Text(loaded)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.orange)
                        }

                        // GPU memory
                        if let gpuString = service.gpuMemoryString {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .font(.system(size: 12))
                                Text(gpuString)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.purple)
                        }
                    }
                }

                // Expand button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                expandedContent
                    .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHovered ? service.serviceType.color.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // Response time color based on latency
    private var responseTimeColor: Color {
        if service.responseTime < 0.1 { return .green }
        if service.responseTime < 0.5 { return .yellow }
        return .orange
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Models list
            if let models = service.models, !models.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Models")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                        ForEach(models, id: \.self) { model in
                            ModelBadge(
                                name: model,
                                isLoaded: service.loadedModel == model
                            )
                        }
                    }
                }
            }

            // GPU Memory usage
            if let percentage = service.gpuMemoryPercentage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GPU Memory")
                            .font(.system(size: 14, weight: .semibold))

                        Spacer()

                        if let gpuString = service.gpuMemoryString {
                            Text(gpuString)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    GPUMemoryBar(percentage: percentage)
                }
            }

            // Last checked
            HStack {
                Text("Last checked")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Text(service.lastChecked, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Error message if any
            if let error = service.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Model Badge

private struct ModelBadge: View {
    let name: String
    let isLoaded: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isLoaded {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }

            Text(name)
                .font(.system(size: 12, weight: isLoaded ? .semibold : .regular))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isLoaded ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
        )
        .foregroundColor(isLoaded ? .orange : .primary)
    }
}

// MARK: - GPU Memory Bar

private struct GPUMemoryBar: View {
    let percentage: Double

    private var barColor: Color {
        if percentage < 50 { return .green }
        if percentage < 80 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.8), barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (percentage / 100), height: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentage)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - AI Service Health Indicator (for device detail views)

/// Compact health indicator to embed in device detail views
struct AIServiceHealthIndicator: View {
    let service: AIServiceStatus

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: service.serviceType.icon)
                .font(.system(size: 16))
                .foregroundColor(service.serviceType.color)

            // Service name
            Text(service.serviceType.rawValue)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            // Health status
            HStack(spacing: 4) {
                Circle()
                    .fill(service.healthStatus.color)
                    .frame(width: 8, height: 8)

                Text(service.healthStatus.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(service.healthStatus.color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(service.serviceType.color.opacity(0.1))
        )
    }
}

// MARK: - AI Services Mini Card (for embedding in other views)

struct AIServicesMiniCard: View {
    @StateObject private var healthChecker = AIServiceHealthChecker.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)

                    Text("AI Services")
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    if !healthChecker.services.isEmpty {
                        Text("\(healthChecker.services.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }

                if healthChecker.services.isEmpty {
                    Text("No AI services detected")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(healthChecker.services.prefix(3)) { service in
                        AIServiceHealthIndicator(service: service)
                    }

                    if healthChecker.services.count > 3 {
                        Text("+ \(healthChecker.services.count - 3) more")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIServicesDashboardView()
        .frame(width: 1000, height: 800)
}
