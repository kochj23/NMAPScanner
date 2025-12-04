//
//  MLXSecurityRecommendations.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  AI-powered security recommendations using MLX.
//  Generates actionable security guidance based on network analysis.
//

import Foundation
import SwiftUI

// MARK: - MLX Security Recommendations

@MainActor
class MLXSecurityRecommendations: ObservableObject {
    static let shared = MLXSecurityRecommendations()

    @Published var currentRecommendations: SecurityRecommendationSet?
    @Published var isGenerating: Bool = false

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

    private init() {}

    // MARK: - Generate Recommendations

    /// Generate comprehensive security recommendations for the network
    func generateRecommendations(devices: [EnhancedDevice]) async -> SecurityRecommendationSet? {
        guard capability.isMLXAvailable else {
            return SecurityRecommendationSet.unavailable()
        }

        isGenerating = true
        defer { isGenerating = false }

        let context = buildSecurityContext(devices: devices)

        let systemPrompt = """
        You are a network security consultant providing actionable security recommendations.
        Analyze the network and provide specific, prioritized guidance.
        Focus on practical steps that can be implemented immediately.
        Include both technical and non-technical recommendations.
        """

        let userPrompt = """
        Network Security Assessment:

        \(context)

        Provide comprehensive security recommendations organized by priority:

        1. CRITICAL (Immediate Action Required)
        - List specific vulnerabilities requiring urgent attention
        - Provide step-by-step remediation

        2. HIGH PRIORITY (Address This Week)
        - Important security improvements
        - Implementation steps

        3. MEDIUM PRIORITY (Address This Month)
        - Security enhancements
        - Best practice improvements

        4. LOW PRIORITY (Future Improvements)
        - General hardening
        - Optional enhancements

        For each recommendation:
        - Clear title
        - Why it matters
        - How to implement (step-by-step)
        - Estimated impact
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 2500,
                temperature: 0.4,
                systemPrompt: systemPrompt
            )

            let recommendations = parseRecommendations(response, devices: devices)
            currentRecommendations = recommendations
            return recommendations
        } catch {
            print("Recommendation generation error: \(error)")
            return SecurityRecommendationSet.error(error.localizedDescription)
        }
    }

    /// Generate device-specific recommendations
    func generateDeviceRecommendations(_ device: EnhancedDevice) async -> [SecurityRecommendation] {
        guard capability.isMLXAvailable else { return [] }

        let context = buildDeviceSecurityContext(device: device)

        let systemPrompt = """
        You are a security expert analyzing a specific network device.
        Provide targeted security recommendations for this device.
        """

        let userPrompt = """
        Analyze this device and provide security recommendations:

        \(context)

        Provide 3-5 specific recommendations for securing this device.
        Focus on actionable steps.

        Format each as:
        Title: [recommendation title]
        Priority: [Critical/High/Medium/Low]
        Reason: [why this matters]
        Steps: [numbered implementation steps]
        Impact: [expected security benefit]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 1000,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            return parseDeviceRecommendations(response)
        } catch {
            print("Device recommendation error: \(error)")
            return []
        }
    }

    // MARK: - Context Building

    private func buildSecurityContext(devices: [EnhancedDevice]) -> String {
        var context = "Network Overview:\n"
        context += "Total Devices: \(devices.count)\n"
        context += "Online: \(devices.filter { $0.isOnline }.count)\n"
        context += "Offline: \(devices.filter { !$0.isOnline }.count)\n"
        context += "Rogue Devices: \(devices.filter { $0.isRogue }.count)\n\n"

        // Security concerns
        let devicesWithOpenPorts = devices.filter { !$0.openPorts.isEmpty }
        context += "Devices with Open Ports: \(devicesWithOpenPorts.count)\n"

        let unknownDevices = devices.filter { $0.manufacturer == nil || $0.manufacturer == "Unknown" }
        context += "Unknown/Unidentified Devices: \(unknownDevices.count)\n\n"

        // Device types breakdown
        let deviceTypes = Dictionary(grouping: devices, by: { $0.deviceType })
        context += "Device Types:\n"
        for (type, devicesOfType) in deviceTypes.sorted(by: { $0.value.count > $1.value.count }) {
            context += "- \(type.rawValue): \(devicesOfType.count)\n"
        }
        context += "\n"

        // High-risk devices
        context += "High-Risk Devices:\n"
        for device in devices.prefix(15).filter({ $0.isRogue || !$0.openPorts.isEmpty }) {
            context += "- \(device.displayName) (\(device.ipAddress))\n"
            if device.isRogue {
                context += "  Alert: ROGUE DEVICE\n"
            }
            if !device.openPorts.isEmpty {
                context += "  Open ports: \(device.openPorts.map { String($0.port) }.prefix(5).joined(separator: ", "))\n"
            }
        }

        return context
    }

    private func buildDeviceSecurityContext(device: EnhancedDevice) -> String {
        var context = ""
        context += "Device: \(device.displayName)\n"
        context += "IP: \(device.ipAddress)\n"
        context += "Type: \(device.deviceType.rawValue)\n"
        context += "Manufacturer: \(device.manufacturer ?? "Unknown")\n"
        context += "OS: \(device.operatingSystem ?? "Unknown")\n"
        context += "Status: \(device.isOnline ? "Online" : "Offline")\n"

        if device.isRogue {
            context += "⚠️ FLAGGED AS ROGUE DEVICE\n"
        }

        if !device.openPorts.isEmpty {
            context += "\nOpen Ports:\n"
            for port in device.openPorts {
                context += "- Port \(port.port): \(port.service ?? "unknown")\n"
                if let version = port.version {
                    context += "  Version: \(version)\n"
                }
            }
        }

        return context
    }

    // MARK: - Response Parsing

    private func parseRecommendations(_ response: String, devices: [EnhancedDevice]) -> SecurityRecommendationSet {
        var critical: [SecurityRecommendation] = []
        var high: [SecurityRecommendation] = []
        var medium: [SecurityRecommendation] = []
        var low: [SecurityRecommendation] = []

        let sections = response.components(separatedBy: "\n\n")
        var currentPriority: SecurityPriority = .medium

        for section in sections {
            let sectionLower = section.lowercased()

            if sectionLower.contains("critical") || sectionLower.contains("immediate") {
                currentPriority = .critical
                critical.append(contentsOf: extractRecommendations(from: section, priority: .critical))
            } else if sectionLower.contains("high priority") || sectionLower.contains("address this week") {
                currentPriority = .high
                high.append(contentsOf: extractRecommendations(from: section, priority: .high))
            } else if sectionLower.contains("medium priority") || sectionLower.contains("address this month") {
                currentPriority = .medium
                medium.append(contentsOf: extractRecommendations(from: section, priority: .medium))
            } else if sectionLower.contains("low priority") || sectionLower.contains("future") {
                currentPriority = .low
                low.append(contentsOf: extractRecommendations(from: section, priority: .low))
            }
        }

        return SecurityRecommendationSet(
            critical: critical,
            high: high,
            medium: medium,
            low: low,
            generatedDate: Date(),
            networkSize: devices.count,
            fullResponse: response
        )
    }

    private func extractRecommendations(from text: String, priority: SecurityPriority) -> [SecurityRecommendation] {
        var recommendations: [SecurityRecommendation] = []
        let lines = text.components(separatedBy: "\n")

        var currentTitle = ""
        var currentReason = ""
        var currentSteps: [String] = []
        var currentImpact = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•") {
                // New recommendation
                if !currentTitle.isEmpty {
                    recommendations.append(SecurityRecommendation(
                        title: currentTitle,
                        priority: priority,
                        reason: currentReason.isEmpty ? "Security improvement" : currentReason,
                        steps: currentSteps.isEmpty ? [currentTitle] : currentSteps,
                        impact: currentImpact.isEmpty ? "Improved security posture" : currentImpact
                    ))
                }

                currentTitle = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "-*• "))
                currentReason = ""
                currentSteps = []
                currentImpact = ""
            } else if trimmed.lowercased().starts(with: "reason:") || trimmed.lowercased().starts(with: "why:") {
                currentReason = extractValue(from: trimmed)
            } else if trimmed.lowercased().starts(with: "steps:") || trimmed.lowercased().starts(with: "how:") {
                currentSteps.append(extractValue(from: trimmed))
            } else if trimmed.lowercased().starts(with: "impact:") {
                currentImpact = extractValue(from: trimmed)
            } else if !trimmed.isEmpty && trimmed.count > 20 {
                // Likely a continuation
                if currentReason.isEmpty {
                    currentReason = trimmed
                } else {
                    currentSteps.append(trimmed)
                }
            }
        }

        // Add final recommendation
        if !currentTitle.isEmpty {
            recommendations.append(SecurityRecommendation(
                title: currentTitle,
                priority: priority,
                reason: currentReason.isEmpty ? "Security improvement" : currentReason,
                steps: currentSteps.isEmpty ? [currentTitle] : currentSteps,
                impact: currentImpact.isEmpty ? "Improved security posture" : currentImpact
            ))
        }

        return recommendations
    }

    private func parseDeviceRecommendations(_ response: String) -> [SecurityRecommendation] {
        var recommendations: [SecurityRecommendation] = []
        var currentTitle = ""
        var currentPriority: SecurityPriority = .medium
        var currentReason = ""
        var currentSteps: [String] = []
        var currentImpact = ""

        let lines = response.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.lowercased().starts(with: "title:") {
                // Save previous recommendation
                if !currentTitle.isEmpty {
                    recommendations.append(SecurityRecommendation(
                        title: currentTitle,
                        priority: currentPriority,
                        reason: currentReason,
                        steps: currentSteps,
                        impact: currentImpact
                    ))
                }

                currentTitle = extractValue(from: trimmed)
                currentPriority = .medium
                currentReason = ""
                currentSteps = []
                currentImpact = ""
            } else if trimmed.lowercased().starts(with: "priority:") {
                let priorityStr = extractValue(from: trimmed).lowercased()
                if priorityStr.contains("critical") {
                    currentPriority = .critical
                } else if priorityStr.contains("high") {
                    currentPriority = .high
                } else if priorityStr.contains("low") {
                    currentPriority = .low
                } else {
                    currentPriority = .medium
                }
            } else if trimmed.lowercased().starts(with: "reason:") {
                currentReason = extractValue(from: trimmed)
            } else if trimmed.lowercased().starts(with: "steps:") {
                currentSteps.append(extractValue(from: trimmed))
            } else if trimmed.lowercased().starts(with: "impact:") {
                currentImpact = extractValue(from: trimmed)
            }
        }

        // Add final recommendation
        if !currentTitle.isEmpty {
            recommendations.append(SecurityRecommendation(
                title: currentTitle,
                priority: currentPriority,
                reason: currentReason,
                steps: currentSteps,
                impact: currentImpact
            ))
        }

        return recommendations
    }

    private func extractValue(from line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return line
        }

        let valueStart = line.index(after: colonIndex)
        return line[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models

struct SecurityRecommendationSet {
    let critical: [SecurityRecommendation]
    let high: [SecurityRecommendation]
    let medium: [SecurityRecommendation]
    let low: [SecurityRecommendation]
    let generatedDate: Date
    let networkSize: Int
    let fullResponse: String

    var totalCount: Int {
        critical.count + high.count + medium.count + low.count
    }

    static func unavailable() -> SecurityRecommendationSet {
        SecurityRecommendationSet(
            critical: [],
            high: [],
            medium: [],
            low: [SecurityRecommendation(
                title: "Install MLX AI Toolkit",
                priority: .high,
                reason: "AI-powered security recommendations require MLX on Apple Silicon",
                steps: ["Run: pip3 install mlx mlx-lm"],
                impact: "Enable advanced security analysis"
            )],
            generatedDate: Date(),
            networkSize: 0,
            fullResponse: ""
        )
    }

    static func error(_ message: String) -> SecurityRecommendationSet {
        SecurityRecommendationSet(
            critical: [],
            high: [],
            medium: [],
            low: [],
            generatedDate: Date(),
            networkSize: 0,
            fullResponse: "Error: \(message)"
        )
    }
}

struct SecurityRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let priority: SecurityPriority
    let reason: String
    let steps: [String]
    let impact: String
}

enum SecurityPriority {
    case critical
    case high
    case medium
    case low

    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    var displayName: String {
        switch self {
        case .critical: return "CRITICAL"
        case .high: return "HIGH"
        case .medium: return "MEDIUM"
        case .low: return "LOW"
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "lightbulb.fill"
        }
    }
}

// MARK: - Security Recommendations View

struct SecurityRecommendationsView: View {
    @ObservedObject var recommendations = MLXSecurityRecommendations.shared
    let devices: [EnhancedDevice]

    @State private var showingFullReport = false
    @State private var selectedPriority: SecurityPriority? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("Security Recommendations")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                if recommendations.isGenerating {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Button("Generate") {
                        Task {
                            await recommendations.generateRecommendations(devices: devices)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }

            if let recommendationSet = recommendations.currentRecommendations {
                // Summary
                HStack(spacing: 20) {
                    prioritySummaryCard(
                        count: recommendationSet.critical.count,
                        priority: .critical,
                        label: "Critical"
                    )

                    prioritySummaryCard(
                        count: recommendationSet.high.count,
                        priority: .high,
                        label: "High"
                    )

                    prioritySummaryCard(
                        count: recommendationSet.medium.count,
                        priority: .medium,
                        label: "Medium"
                    )

                    prioritySummaryCard(
                        count: recommendationSet.low.count,
                        priority: .low,
                        label: "Low"
                    )
                }

                // Recommendations List
                ScrollView {
                    VStack(spacing: 16) {
                        if !recommendationSet.critical.isEmpty {
                            recommendationSection(
                                title: "Critical Priority",
                                recommendations: recommendationSet.critical,
                                priority: .critical
                            )
                        }

                        if !recommendationSet.high.isEmpty {
                            recommendationSection(
                                title: "High Priority",
                                recommendations: recommendationSet.high,
                                priority: .high
                            )
                        }

                        if !recommendationSet.medium.isEmpty {
                            recommendationSection(
                                title: "Medium Priority",
                                recommendations: recommendationSet.medium,
                                priority: .medium
                            )
                        }

                        if !recommendationSet.low.isEmpty {
                            recommendationSection(
                                title: "Low Priority",
                                recommendations: recommendationSet.low,
                                priority: .low
                            )
                        }
                    }
                }

                Button("View Full Report") {
                    showingFullReport = true
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .sheet(isPresented: $showingFullReport) {
            if let recommendationSet = recommendations.currentRecommendations {
                FullRecommendationsReportView(recommendationSet: recommendationSet)
            }
        }
    }

    private func prioritySummaryCard(count: Int, priority: SecurityPriority, label: String) -> some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(priority.color)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(priority.color.opacity(0.1))
        )
    }

    private func recommendationSection(title: String, recommendations: [SecurityRecommendation], priority: SecurityPriority) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: priority.icon)
                    .foregroundColor(priority.color)

                Text(title)
                    .font(.system(size: 24, weight: .semibold))
            }

            ForEach(recommendations) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: SecurityRecommendation
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: recommendation.priority.icon)
                    .foregroundColor(recommendation.priority.color)
                    .font(.system(size: 20))

                Text(recommendation.title)
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                Divider()

                // Reason
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why This Matters")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(recommendation.reason)
                        .font(.system(size: 14))
                }

                // Steps
                if !recommendation.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Implementation Steps")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach(Array(recommendation.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(recommendation.priority.color)

                                Text(step)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }

                // Impact
                VStack(alignment: .leading, spacing: 6) {
                    Text("Expected Impact")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(recommendation.impact)
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(recommendation.priority.color.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

struct FullRecommendationsReportView: View {
    let recommendationSet: SecurityRecommendationSet
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(recommendationSet.fullResponse)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(20)
            }
            .navigationTitle("Full Security Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
