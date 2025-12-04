//
//  MLXDeviceClassifier.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  AI-powered device classification using MLX.
//  Automatically identifies and categorizes unknown devices.
//

import Foundation
import SwiftUI

// MARK: - MLX Device Classifier

@MainActor
class MLXDeviceClassifier: ObservableObject {
    static let shared = MLXDeviceClassifier()

    @Published var isClassifying: Bool = false
    @Published var classificationCache: [String: DeviceClassification] = [:] // MAC -> Classification

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

    private init() {}

    // MARK: - Device Classification

    /// Classify a single device using AI
    func classifyDevice(_ device: EnhancedDevice) async -> DeviceClassification? {
        // Check cache first
        if let macAddress = device.macAddress, let cached = classificationCache[macAddress] {
            return cached
        }

        guard capability.isMLXAvailable else {
            return DeviceClassification.fallback(device)
        }

        isClassifying = true
        defer { isClassifying = false }

        let context = buildDeviceContext(device)

        let systemPrompt = """
        You are a network device identification expert.
        Analyze device information and provide accurate classification.
        Be specific about manufacturer, model, and device type.
        Format: DeviceType | Manufacturer | Model | Suggested Name
        """

        let userPrompt = """
        Identify this network device:

        \(context)

        Provide:
        1. Device Type (Router, Switch, Computer, Mobile, IoT Device, Printer, Server, Camera, Smart TV, Gaming Console, Smart Speaker, etc.)
        2. Manufacturer name
        3. Specific model if identifiable
        4. Suggested friendly name for the device
        5. Confidence level (High/Medium/Low)

        Format your response exactly as:
        Type: [device type]
        Manufacturer: [manufacturer]
        Model: [model or "Unknown"]
        Name: [suggested name]
        Confidence: [High/Medium/Low]
        Reasoning: [brief explanation]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 300,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            let classification = parseClassificationResponse(response, device: device)

            // Cache the result
            if let macAddress = device.macAddress {
                classificationCache[macAddress] = classification
            }

            return classification
        } catch {
            print("Classification error: \(error)")
            return DeviceClassification.fallback(device)
        }
    }

    /// Classify multiple devices in batch
    func classifyDevices(_ devices: [EnhancedDevice]) async -> [DeviceClassification] {
        var classifications: [DeviceClassification] = []

        for device in devices {
            if let classification = await classifyDevice(device) {
                classifications.append(classification)
            }
        }

        return classifications
    }

    /// Auto-suggest device name based on classification
    func suggestDeviceName(_ device: EnhancedDevice) async -> String? {
        guard let classification = await classifyDevice(device) else {
            return nil
        }

        return classification.suggestedName
    }

    // MARK: - Context Building

    private func buildDeviceContext(_ device: EnhancedDevice) -> String {
        var context = ""

        if let hostname = device.hostname {
            context += "Hostname: \(hostname)\n"
        }

        context += "IP Address: \(device.ipAddress)\n"

        if let mac = device.macAddress {
            context += "MAC Address: \(mac)\n"

            // Extract OUI (first 6 chars)
            let oui = String(mac.prefix(8)).replacingOccurrences(of: ":", with: "")
            context += "OUI (Manufacturer ID): \(oui)\n"
        }

        if let manufacturer = device.manufacturer {
            context += "Detected Manufacturer: \(manufacturer)\n"
        }

        context += "Current Device Type: \(device.deviceType.rawValue)\n"

        if let os = device.operatingSystem {
            context += "Operating System: \(os)\n"
        }

        if !device.openPorts.isEmpty {
            context += "\nOpen Ports:\n"
            for port in device.openPorts.prefix(10) {
                context += "- Port \(port.port): \(port.service ?? "unknown")"
                if let version = port.version {
                    context += " (\(version))"
                }
                context += "\n"
            }
        }

        return context
    }

    // MARK: - Response Parsing

    private func parseClassificationResponse(_ response: String, device: EnhancedDevice) -> DeviceClassification {
        var deviceType = device.deviceType.rawValue
        var manufacturer = device.manufacturer ?? "Unknown"
        var model = "Unknown"
        var suggestedName = device.displayName
        var confidence: ClassificationConfidence = .low
        var reasoning = ""

        let lines = response.components(separatedBy: "\n")

        for line in lines {
            if line.lowercased().starts(with: "type:") {
                deviceType = extractValue(from: line)
            } else if line.lowercased().starts(with: "manufacturer:") {
                manufacturer = extractValue(from: line)
            } else if line.lowercased().starts(with: "model:") {
                model = extractValue(from: line)
            } else if line.lowercased().starts(with: "name:") {
                suggestedName = extractValue(from: line)
            } else if line.lowercased().starts(with: "confidence:") {
                let confStr = extractValue(from: line).lowercased()
                if confStr.contains("high") {
                    confidence = .high
                } else if confStr.contains("medium") {
                    confidence = .medium
                } else {
                    confidence = .low
                }
            } else if line.lowercased().starts(with: "reasoning:") {
                reasoning = extractValue(from: line)
            }
        }

        return DeviceClassification(
            originalDevice: device,
            identifiedType: deviceType,
            manufacturer: manufacturer,
            model: model,
            suggestedName: suggestedName,
            confidence: confidence,
            reasoning: reasoning
        )
    }

    private func extractValue(from line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return ""
        }

        let valueStart = line.index(after: colonIndex)
        return line[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models

struct DeviceClassification: Identifiable {
    let id = UUID()
    let originalDevice: EnhancedDevice
    let identifiedType: String
    let manufacturer: String
    let model: String
    let suggestedName: String
    let confidence: ClassificationConfidence
    let reasoning: String

    static func fallback(_ device: EnhancedDevice) -> DeviceClassification {
        DeviceClassification(
            originalDevice: device,
            identifiedType: device.deviceType.rawValue,
            manufacturer: device.manufacturer ?? "Unknown",
            model: "Unknown",
            suggestedName: device.displayName,
            confidence: .low,
            reasoning: "AI classification unavailable - using basic detection"
        )
    }
}

enum ClassificationConfidence {
    case high
    case medium
    case low

    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }

    var description: String {
        switch self {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        }
    }
}

// MARK: - Device Classification View

struct DeviceClassificationView: View {
    @ObservedObject var classifier = MLXDeviceClassifier.shared
    let device: EnhancedDevice

    @State private var classification: DeviceClassification?
    @State private var showingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)

                Text("AI Device Classification")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                if classifier.isClassifying {
                    ProgressView()
                } else {
                    Button("Classify") {
                        Task {
                            classification = await classifier.classifyDevice(device)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }

            if let classification = classification {
                VStack(alignment: .leading, spacing: 12) {
                    // Confidence Badge
                    HStack {
                        Circle()
                            .fill(classification.confidence.color)
                            .frame(width: 12, height: 12)
                        Text(classification.confidence.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(classification.confidence.color)
                    }

                    Divider()

                    // Classification Details
                    classificationRow(label: "Device Type", value: classification.identifiedType)
                    classificationRow(label: "Manufacturer", value: classification.manufacturer)
                    classificationRow(label: "Model", value: classification.model)
                    classificationRow(label: "Suggested Name", value: classification.suggestedName)

                    if !classification.reasoning.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reasoning")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text(classification.reasoning)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Apply Suggested Name") {
                        applyClassification(classification)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
            } else {
                Text("Click 'Classify' to identify this device using AI")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func classificationRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 14))
        }
    }

    private func applyClassification(_ classification: DeviceClassification) {
        // Apply the suggested name to the device
        // This would update the device persistence manager
        print("Applied classification: \(classification.suggestedName)")
    }
}

// MARK: - Batch Classification View

struct BatchDeviceClassificationView: View {
    @ObservedObject var classifier = MLXDeviceClassifier.shared
    let devices: [EnhancedDevice]

    @State private var classifications: [DeviceClassification] = []
    @State private var isClassifying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Batch Device Classification")
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                if isClassifying {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Button("Classify All") {
                        Task {
                            isClassifying = true
                            classifications = await classifier.classifyDevices(devices)
                            isClassifying = false
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }

            if !classifications.isEmpty {
                ScrollView {
                    ForEach(classifications) { classification in
                        ClassificationResultCard(classification: classification)
                    }
                }
            }
        }
        .padding(20)
    }
}

struct ClassificationResultCard: View {
    let classification: DeviceClassification

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: deviceIcon)
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 50)

            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(classification.suggestedName)
                    .font(.system(size: 16, weight: .semibold))

                Text("\(classification.manufacturer) - \(classification.model)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text(classification.identifiedType)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(classification.confidence.color.opacity(0.2))
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private var deviceIcon: String {
        let type = classification.identifiedType.lowercased()
        if type.contains("router") {
            return "wifi.router"
        } else if type.contains("camera") {
            return "video.fill"
        } else if type.contains("phone") || type.contains("mobile") {
            return "iphone"
        } else if type.contains("computer") || type.contains("laptop") {
            return "desktopcomputer"
        } else if type.contains("tablet") {
            return "ipad"
        } else if type.contains("tv") {
            return "tv.fill"
        } else if type.contains("speaker") {
            return "hifispeaker.fill"
        } else if type.contains("printer") {
            return "printer.fill"
        } else {
            return "network"
        }
    }
}
