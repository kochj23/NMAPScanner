//
//  MLXAnomalyDetector.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  AI-powered anomaly detection using MLX.
//  Detects unusual network behavior with contextual explanations.
//

import Foundation
import SwiftUI

// MARK: - MLX Anomaly Detector

@MainActor
class MLXAnomalyDetector: ObservableObject {
    static let shared = MLXAnomalyDetector()

    @Published var detectedAnomalies: [MLXNetworkAnomaly] = []
    @Published var isAnalyzing: Bool = false
    @Published var baselineEstablished: Bool = false

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

    // Baseline network state
    private var baseline: NetworkBaseline?

    private init() {}

    // MARK: - Anomaly Detection

    /// Establish network baseline for future anomaly detection
    func establishBaseline(devices: [EnhancedDevice]) {
        baseline = NetworkBaseline(
            totalDevices: devices.count,
            deviceTypes: Dictionary(grouping: devices, by: { $0.deviceType }).mapValues { $0.count },
            averageOpenPorts: devices.map { $0.openPorts.count }.reduce(0, +) / max(devices.count, 1),
            knownMACs: Set(devices.compactMap { $0.macAddress }),
            establishedDate: Date()
        )
        baselineEstablished = true
    }

    /// Detect anomalies in current network state
    func detectAnomalies(currentDevices: [EnhancedDevice]) async -> [MLXNetworkAnomaly] {
        guard capability.isMLXAvailable else {
            return [MLXNetworkAnomaly.unavailable()]
        }

        guard let baseline = baseline else {
            establishBaseline(devices: currentDevices)
            return []
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Quick heuristic checks
        var anomalies: [MLXNetworkAnomaly] = []

        // Check for new devices
        let newDevices = currentDevices.filter { device in
            guard let mac = device.macAddress else { return false }
            return !baseline.knownMACs.contains(mac)
        }

        if !newDevices.isEmpty {
            for device in newDevices {
                if let anomaly = await analyzeNewDevice(device, baseline: baseline) {
                    anomalies.append(anomaly)
                }
            }
        }

        // Check for unusual port activity
        let devicesWithManyPorts = currentDevices.filter { $0.openPorts.count > baseline.averageOpenPorts * 3 }
        for device in devicesWithManyPorts {
            if let anomaly = await analyzePortAnomaly(device, baseline: baseline) {
                anomalies.append(anomaly)
            }
        }

        // Check for missing devices
        let currentMACs = Set(currentDevices.compactMap { $0.macAddress })
        let missingCount = baseline.knownMACs.subtracting(currentMACs).count
        if missingCount > baseline.knownMACs.count / 4 { // More than 25% missing
            if let anomaly = await analyzeMissingDevices(count: missingCount, baseline: baseline) {
                anomalies.append(anomaly)
            }
        }

        // AI-powered analysis of overall network state
        if let overallAnomaly = await analyzeOverallNetwork(currentDevices: currentDevices, baseline: baseline) {
            anomalies.append(overallAnomaly)
        }

        detectedAnomalies = anomalies
        return anomalies
    }

    // MARK: - Individual Anomaly Analysis

    private func analyzeNewDevice(_ device: EnhancedDevice, baseline: NetworkBaseline) async -> MLXNetworkAnomaly? {
        let context = """
        New device detected on network:
        - Name: \(device.displayName)
        - IP: \(device.ipAddress)
        - MAC: \(device.macAddress ?? "Unknown")
        - Type: \(device.deviceType.rawValue)
        - Open Ports: \(device.openPorts.map { String($0.port) }.joined(separator: ", "))

        Network baseline established: \(baseline.establishedDate.formatted())
        Known devices: \(baseline.knownMACs.count)
        """

        let systemPrompt = """
        You are a network security expert analyzing anomalous behavior.
        Determine if this new device is suspicious and explain why.
        """

        let userPrompt = """
        \(context)

        Analyze this new device:
        1. Is this device suspicious? (Yes/No)
        2. Severity: Critical/High/Medium/Low
        3. Explanation: Why is this device flagged?
        4. Recommendation: What action should be taken?

        Format:
        Suspicious: [Yes/No]
        Severity: [level]
        Explanation: [detailed explanation]
        Recommendation: [action to take]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 500,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            return parseAnomalyResponse(
                response,
                type: .newDevice,
                affectedDevice: device,
                detectedDate: Date()
            )
        } catch {
            return nil
        }
    }

    private func analyzePortAnomaly(_ device: EnhancedDevice, baseline: NetworkBaseline) async -> MLXNetworkAnomaly? {
        let context = """
        Unusual port activity detected:
        - Device: \(device.displayName)
        - IP: \(device.ipAddress)
        - Open Ports: \(device.openPorts.count) (network average: \(baseline.averageOpenPorts))
        - Ports: \(device.openPorts.map { "\($0.port) (\($0.service ?? "unknown"))" }.joined(separator: ", "))
        """

        let systemPrompt = """
        You are analyzing unusual network port activity.
        Determine if this represents a security concern.
        """

        let userPrompt = """
        \(context)

        Analyze:
        1. Is this port activity suspicious?
        2. Severity level
        3. Why is this concerning?
        4. Recommended action

        Format:
        Suspicious: [Yes/No]
        Severity: [level]
        Explanation: [why this matters]
        Recommendation: [action]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 500,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            return parseAnomalyResponse(
                response,
                type: .unusualPorts,
                affectedDevice: device,
                detectedDate: Date()
            )
        } catch {
            return nil
        }
    }

    private func analyzeMissingDevices(count: Int, baseline: NetworkBaseline) async -> MLXNetworkAnomaly? {
        let context = """
        Significant number of devices missing from network:
        - Baseline devices: \(baseline.knownMACs.count)
        - Currently missing: \(count)
        - Percentage missing: \(Int(Double(count) / Double(baseline.knownMACs.count) * 100))%
        - Baseline established: \(baseline.establishedDate.formatted())
        """

        let systemPrompt = """
        You are analyzing network connectivity issues.
        Determine if missing devices indicate a problem.
        """

        let userPrompt = """
        \(context)

        Analyze:
        1. Is this concerning?
        2. Severity
        3. Possible causes
        4. Recommended action

        Format:
        Concerning: [Yes/No]
        Severity: [level]
        Explanation: [analysis]
        Recommendation: [action]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 500,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            return parseAnomalyResponse(
                response,
                type: .missingDevices,
                affectedDevice: nil,
                detectedDate: Date()
            )
        } catch {
            return nil
        }
    }

    private func analyzeOverallNetwork(currentDevices: [EnhancedDevice], baseline: NetworkBaseline) async -> MLXNetworkAnomaly? {
        let context = """
        Network State Comparison:

        Baseline (established \(baseline.establishedDate.formatted())):
        - Total devices: \(baseline.totalDevices)
        - Average open ports: \(baseline.averageOpenPorts)

        Current State:
        - Total devices: \(currentDevices.count)
        - Online: \(currentDevices.filter { $0.isOnline }.count)
        - Average open ports: \(currentDevices.map { $0.openPorts.count }.reduce(0, +) / max(currentDevices.count, 1))
        - Rogue devices: \(currentDevices.filter { $0.isRogue }.count)
        """

        let systemPrompt = """
        You are performing overall network health analysis.
        Identify any concerning patterns or changes from baseline.
        """

        let userPrompt = """
        \(context)

        Analyze overall network state:
        1. Any concerning changes from baseline?
        2. Overall security posture
        3. Key observations
        4. Recommendations

        Format:
        Concerning: [Yes/No]
        Severity: [Critical/High/Medium/Low]
        Explanation: [analysis]
        Recommendation: [action]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 600,
                temperature: 0.4,
                systemPrompt: systemPrompt
            )

            let parsed = parseAnomalyResponse(
                response,
                type: .networkChange,
                affectedDevice: nil,
                detectedDate: Date()
            )

            // Only return if actually concerning
            if parsed?.severity == .critical || parsed?.severity == .high {
                return parsed
            }

            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Response Parsing

    private func parseAnomalyResponse(
        _ response: String,
        type: AnomalyType,
        affectedDevice: EnhancedDevice?,
        detectedDate: Date
    ) -> MLXNetworkAnomaly? {
        var isSuspicious = false
        var severity: AnomalySeverity = .low
        var explanation = ""
        var recommendation = ""

        let lines = response.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.lowercased().starts(with: "suspicious:") || trimmed.lowercased().starts(with: "concerning:") {
                let value = extractValue(from: trimmed).lowercased()
                isSuspicious = value.contains("yes") || value.contains("true")
            } else if trimmed.lowercased().starts(with: "severity:") {
                let severityStr = extractValue(from: trimmed).lowercased()
                if severityStr.contains("critical") {
                    severity = .critical
                } else if severityStr.contains("high") {
                    severity = .high
                } else if severityStr.contains("medium") {
                    severity = .medium
                } else {
                    severity = .low
                }
            } else if trimmed.lowercased().starts(with: "explanation:") {
                explanation = extractValue(from: trimmed)
            } else if trimmed.lowercased().starts(with: "recommendation:") {
                recommendation = extractValue(from: trimmed)
            }
        }

        // If not suspicious, don't create anomaly
        guard isSuspicious else { return nil }

        return MLXNetworkAnomaly(
            type: type,
            severity: severity,
            description: explanation.isEmpty ? response : explanation,
            recommendation: recommendation.isEmpty ? "Investigate this activity" : recommendation,
            affectedDevice: affectedDevice,
            detectedDate: detectedDate
        )
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

struct NetworkBaseline {
    let totalDevices: Int
    let deviceTypes: [EnhancedDevice.DeviceType: Int]
    let averageOpenPorts: Int
    let knownMACs: Set<String>
    let establishedDate: Date
}

struct MLXNetworkAnomaly: Identifiable {
    let id = UUID()
    let type: AnomalyType
    let severity: AnomalySeverity
    let description: String
    let recommendation: String
    let affectedDevice: EnhancedDevice?
    let detectedDate: Date

    static func unavailable() -> MLXNetworkAnomaly {
        MLXNetworkAnomaly(
            type: .other,
            severity: .low,
            description: "Anomaly detection requires MLX AI toolkit",
            recommendation: "Install MLX to enable anomaly detection",
            affectedDevice: nil,
            detectedDate: Date()
        )
    }
}

enum AnomalyType {
    case newDevice
    case unusualPorts
    case missingDevices
    case networkChange
    case suspiciousActivity
    case other

    var displayName: String {
        switch self {
        case .newDevice: return "New Device"
        case .unusualPorts: return "Unusual Port Activity"
        case .missingDevices: return "Missing Devices"
        case .networkChange: return "Network Change"
        case .suspiciousActivity: return "Suspicious Activity"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .newDevice: return "plus.circle.fill"
        case .unusualPorts: return "network.badge.shield.half.filled"
        case .missingDevices: return "minus.circle.fill"
        case .networkChange: return "arrow.triangle.2.circlepath"
        case .suspiciousActivity: return "exclamationmark.shield.fill"
        case .other: return "info.circle.fill"
        }
    }
}

enum AnomalySeverity {
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
}

// MARK: - Anomaly Detection View

struct AnomalyDetectionView: View {
    @ObservedObject var detector = MLXAnomalyDetector.shared
    let devices: [EnhancedDevice]

    @State private var showingBaselineInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("Anomaly Detection")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                if !detector.baselineEstablished {
                    Button("Establish Baseline") {
                        detector.establishBaseline(devices: devices)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                } else {
                    if detector.isAnalyzing {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        Button("Scan for Anomalies") {
                            Task {
                                await detector.detectAnomalies(currentDevices: devices)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }

            // Baseline Status
            if detector.baselineEstablished {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("Baseline established - monitoring for anomalies")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Reset") {
                        detector.establishBaseline(devices: devices)
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Baseline Not Established")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Establish a network baseline to enable anomaly detection. The system will learn normal network behavior and alert you to unusual activity.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Detected Anomalies
            if !detector.detectedAnomalies.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Detected Anomalies")
                            .font(.system(size: 24, weight: .semibold))

                        Spacer()

                        Text("\(detector.detectedAnomalies.count)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(detector.detectedAnomalies) { anomaly in
                                AnomalyCard(anomaly: anomaly)
                            }
                        }
                    }
                }
            } else if detector.baselineEstablished && !detector.isAnalyzing {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("No Anomalies Detected")
                        .font(.system(size: 20, weight: .semibold))

                    Text("Your network is operating normally")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .padding(20)
    }
}

struct AnomalyCard: View {
    let anomaly: MLXNetworkAnomaly
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: anomaly.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(anomaly.severity.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(anomaly.type.displayName)
                        .font(.system(size: 18, weight: .semibold))

                    if let device = anomaly.affectedDevice {
                        Text("\(device.displayName) (\(device.ipAddress))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(anomaly.severity.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(anomaly.severity.color)
                    .cornerRadius(6)

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

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(anomaly.description)
                            .font(.system(size: 14))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recommendation")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(anomaly.recommendation)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Detected: \(anomaly.detectedDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(anomaly.severity.color.opacity(0.5), lineWidth: 2)
                )
        )
    }
}
