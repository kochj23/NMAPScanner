//
//  MLXThreatAnalyzer.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  AI-powered threat analysis using MLX.
//  Analyzes network devices and identifies security risks.
//

import Foundation
import SwiftUI

// MARK: - MLX Threat Analyzer

@MainActor
class MLXThreatAnalyzer: ObservableObject {
    static let shared = MLXThreatAnalyzer()

    @Published var currentAnalysis: ThreatAnalysisResult?
    @Published var isAnalyzing: Bool = false

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

    private init() {}

    // MARK: - Threat Analysis

    /// Analyze network devices for security threats
    func analyzeNetwork(devices: [EnhancedDevice]) async -> ThreatAnalysisResult? {
        guard capability.isMLXAvailable else {
            return ThreatAnalysisResult.unavailable()
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let context = buildNetworkContext(devices: devices)

        let systemPrompt = """
        You are a cybersecurity expert specializing in network security analysis.
        Analyze the provided network scan data and identify security risks.
        Be specific, actionable, and prioritize threats by severity.
        Format your response with clear sections: Summary, High Priority Threats, Medium Priority, Low Priority, and Recommendations.
        """

        let userPrompt = """
        Analyze this network scan for security threats:

        \(context)

        Provide a comprehensive security analysis with:
        1. Executive summary
        2. Critical/high-priority threats (if any)
        3. Medium-priority concerns
        4. Low-priority observations
        5. Actionable recommendations prioritized by impact
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 2000,
                temperature: 0.4, // Lower temp for more focused analysis
                systemPrompt: systemPrompt
            )

            let result = parseAnalysisResponse(response, devices: devices)
            currentAnalysis = result
            return result
        } catch {
            print("Threat analysis error: \(error)")
            return ThreatAnalysisResult.error(error.localizedDescription)
        }
    }

    /// Analyze a specific device
    func analyzeDevice(_ device: EnhancedDevice) async -> DeviceThreatAnalysis? {
        guard capability.isMLXAvailable else { return nil }

        let context = buildDeviceContext(device: device)

        let systemPrompt = """
        You are a network security expert. Analyze this specific device for security risks.
        Consider open ports, services, manufacturer, device type, and behavior patterns.
        """

        let userPrompt = """
        Analyze this device for security threats:

        \(context)

        Provide:
        1. Risk level (Critical/High/Medium/Low/Safe)
        2. Specific vulnerabilities found
        3. Why this device may be risky
        4. Recommended security actions
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 800,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            return parseDeviceAnalysis(response, device: device)
        } catch {
            print("Device analysis error: \(error)")
            return nil
        }
    }

    // MARK: - Context Building

    private func buildNetworkContext(devices: [EnhancedDevice]) -> String {
        var context = "Network Overview:\n"
        context += "- Total devices: \(devices.count)\n"
        context += "- Online devices: \(devices.filter { $0.isOnline }.count)\n"
        context += "- Device types: \(Set(devices.map { $0.deviceType.rawValue }).joined(separator: ", "))\n\n"

        context += "Device Details:\n"
        for (index, device) in devices.prefix(20).enumerated() { // Limit to 20 devices to stay within token limits
            context += "\nDevice \(index + 1):\n"
            context += "- Name: \(device.displayName)\n"
            context += "- IP: \(device.ipAddress)\n"
            context += "- Type: \(device.deviceType.rawValue)\n"
            context += "- Manufacturer: \(device.manufacturer ?? "Unknown")\n"
            context += "- Status: \(device.isOnline ? "Online" : "Offline")\n"

            if !device.openPorts.isEmpty {
                context += "- Open ports: \(device.openPorts.map { "\($0.port) (\($0.service ?? "unknown"))" }.joined(separator: ", "))\n"
            }

            if device.isRogue {
                context += "- ⚠️ FLAGGED AS ROGUE DEVICE\n"
            }
        }

        if devices.count > 20 {
            context += "\n... and \(devices.count - 20) more devices\n"
        }

        return context
    }

    private func buildDeviceContext(device: EnhancedDevice) -> String {
        var context = ""
        context += "Device Name: \(device.displayName)\n"
        context += "IP Address: \(device.ipAddress)\n"
        context += "MAC Address: \(device.macAddress ?? "Unknown")\n"
        context += "Device Type: \(device.deviceType.rawValue)\n"
        context += "Manufacturer: \(device.manufacturer ?? "Unknown")\n"
        context += "Operating System: \(device.operatingSystem ?? "Unknown")\n"
        context += "Status: \(device.isOnline ? "Online" : "Offline")\n"
        context += "First Seen: \(device.firstSeen.formatted())\n"
        context += "Last Seen: \(device.lastSeen.formatted())\n"

        if !device.openPorts.isEmpty {
            context += "\nOpen Ports:\n"
            for port in device.openPorts {
                context += "- Port \(port.port): \(port.service ?? "unknown service")\n"
                if let version = port.version {
                    context += "  Version: \(version)\n"
                }
            }
        }

        if device.isRogue {
            context += "\n⚠️ This device was recently discovered and flagged as potentially rogue.\n"
        }

        return context
    }

    // MARK: - Response Parsing

    private func parseAnalysisResponse(_ response: String, devices: [EnhancedDevice]) -> ThreatAnalysisResult {
        // Extract sections from AI response
        let sections = response.components(separatedBy: "\n\n")

        var summary = ""
        var threats: [ThreatItem] = []
        var recommendations: [String] = []

        for section in sections {
            if section.lowercased().contains("summary") || section.lowercased().contains("overview") {
                summary = section
            } else if section.lowercased().contains("critical") || section.lowercased().contains("high priority") {
                threats.append(contentsOf: extractThreats(from: section, severity: .critical))
            } else if section.lowercased().contains("medium") {
                threats.append(contentsOf: extractThreats(from: section, severity: .medium))
            } else if section.lowercased().contains("recommendation") {
                recommendations.append(contentsOf: extractRecommendations(from: section))
            }
        }

        return ThreatAnalysisResult(
            summary: summary.isEmpty ? response.prefix(500).description : summary,
            threats: threats,
            recommendations: recommendations,
            analyzedDeviceCount: devices.count,
            analysisDate: Date(),
            fullResponse: response
        )
    }

    private func extractThreats(from text: String, severity: ThreatSeverity) -> [ThreatItem] {
        var threats: [ThreatItem] = []
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
                let threat = line.trimmingCharacters(in: CharacterSet(charactersIn: "-*• "))
                if !threat.isEmpty && threat.count > 10 {
                    threats.append(ThreatItem(description: threat, severity: severity))
                }
            }
        }

        return threats
    }

    private func extractRecommendations(from text: String) -> [String] {
        var recommendations: [String] = []
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") || line.contains(".") {
                let rec = line.trimmingCharacters(in: CharacterSet(charactersIn: "-*•0123456789. "))
                if !rec.isEmpty && rec.count > 10 {
                    recommendations.append(rec)
                }
            }
        }

        return recommendations
    }

    private func parseDeviceAnalysis(_ response: String, device: EnhancedDevice) -> DeviceThreatAnalysis {
        // Extract risk level
        let riskLevel: DeviceRiskLevel
        if response.lowercased().contains("critical") {
            riskLevel = .critical
        } else if response.lowercased().contains("high") {
            riskLevel = .high
        } else if response.lowercased().contains("medium") {
            riskLevel = .medium
        } else if response.lowercased().contains("low") {
            riskLevel = .low
        } else {
            riskLevel = .safe
        }

        return DeviceThreatAnalysis(
            device: device,
            riskLevel: riskLevel,
            analysis: response,
            analyzedDate: Date()
        )
    }
}

// MARK: - Data Models

struct ThreatAnalysisResult {
    let summary: String
    let threats: [ThreatItem]
    let recommendations: [String]
    let analyzedDeviceCount: Int
    let analysisDate: Date
    let fullResponse: String

    static func unavailable() -> ThreatAnalysisResult {
        ThreatAnalysisResult(
            summary: "AI threat analysis is not available. MLX requires Apple Silicon (M1/M2/M3/M4) and the MLX Python toolkit.",
            threats: [],
            recommendations: ["Install MLX to enable AI-powered threat analysis"],
            analyzedDeviceCount: 0,
            analysisDate: Date(),
            fullResponse: ""
        )
    }

    static func error(_ message: String) -> ThreatAnalysisResult {
        ThreatAnalysisResult(
            summary: "Error performing threat analysis: \(message)",
            threats: [],
            recommendations: ["Check MLX installation", "Verify Python environment"],
            analyzedDeviceCount: 0,
            analysisDate: Date(),
            fullResponse: ""
        )
    }
}

struct ThreatItem: Identifiable {
    let id = UUID()
    let description: String
    let severity: ThreatSeverity
}

// ThreatSeverity is defined in ThreatModel.swift

struct DeviceThreatAnalysis: Identifiable {
    let id = UUID()
    let device: EnhancedDevice
    let riskLevel: DeviceRiskLevel
    let analysis: String
    let analyzedDate: Date
}

enum DeviceRiskLevel: String {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case safe = "Safe"

    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .safe: return .green
        }
    }
}

// MARK: - Threat Analysis View

struct ThreatAnalysisView: View {
    @ObservedObject var analyzer = MLXThreatAnalyzer.shared
    let devices: [EnhancedDevice]

    @State private var showingFullReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("AI Threat Analysis")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                if analyzer.isAnalyzing {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Button("Analyze Now") {
                        Task {
                            await analyzer.analyzeNetwork(devices: devices)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }

            if let analysis = analyzer.currentAnalysis {
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Summary")
                        .font(.system(size: 24, weight: .semibold))

                    Text(analysis.summary)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    Text("Analyzed \(analysis.analyzedDeviceCount) devices on \(analysis.analysisDate.formatted())")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )

                // Threats
                if !analysis.threats.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Identified Threats")
                            .font(.system(size: 24, weight: .semibold))

                        ForEach(analysis.threats) { threat in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: threat.severity.icon)
                                    .foregroundColor(threat.severity.color)
                                    .font(.system(size: 20))

                                Text(threat.description)
                                    .font(.system(size: 15))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(threat.severity.color.opacity(0.1))
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }

                // Recommendations
                if !analysis.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.system(size: 24, weight: .semibold))

                        ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.blue)

                                Text(rec)
                                    .font(.system(size: 15))
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
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
            if let analysis = analyzer.currentAnalysis {
                FullThreatReportView(analysis: analysis)
            }
        }
    }
}

struct FullThreatReportView: View {
    let analysis: ThreatAnalysisResult
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(analysis.fullResponse)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(20)
            }
            .navigationTitle("Full Threat Analysis Report")
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
