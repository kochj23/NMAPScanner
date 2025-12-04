//
//  MLXDocumentationGenerator.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  AI-powered network documentation generator using MLX.
//  Creates comprehensive, professional network documentation.
//

import Foundation
import SwiftUI

// MARK: - MLX Documentation Generator

@MainActor
class MLXDocumentationGenerator: ObservableObject {
    static let shared = MLXDocumentationGenerator()

    @Published var currentDocumentation: NetworkDocumentation?
    @Published var isGenerating: Bool = false

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

    private init() {}

    // MARK: - Documentation Generation

    /// Generate comprehensive network documentation
    func generateDocumentation(
        devices: [EnhancedDevice],
        includeSecurityAnalysis: Bool = true,
        includeTopology: Bool = true,
        includeRecommendations: Bool = true
    ) async -> NetworkDocumentation? {
        guard capability.isMLXAvailable else {
            return NetworkDocumentation.unavailable()
        }

        isGenerating = true
        defer { isGenerating = false }

        // Build comprehensive context
        let context = buildDocumentationContext(
            devices: devices,
            includeSecurityAnalysis: includeSecurityAnalysis,
            includeTopology: includeTopology
        )

        let systemPrompt = """
        You are a professional network documentation specialist.
        Generate clear, comprehensive, and well-structured network documentation.
        Use proper formatting with sections and subsections.
        Be technical but accessible.
        Include all relevant details while maintaining readability.
        """

        let userPrompt = """
        Generate professional network documentation for the following network:

        \(context)

        Please create comprehensive documentation with these sections:

        # Network Documentation

        ## Executive Summary
        - High-level overview of the network
        - Key statistics and observations
        - Overall health assessment

        ## Network Topology
        - Network architecture overview
        - Subnet information
        - Device distribution

        ## Device Inventory
        - Complete list of all network devices
        - Categorized by type
        - Include IP, MAC, manufacturer, status

        \(includeSecurityAnalysis ? """
        ## Security Analysis
        - Security posture assessment
        - Identified vulnerabilities
        - Open ports analysis
        - Rogue device detection
        """ : "")

        \(includeRecommendations ? """
        ## Recommendations
        - Security improvements
        - Network optimization suggestions
        - Best practices to implement
        """ : "")

        ## Appendices
        - Detailed port listings
        - Device specifications
        - Scan metadata

        Format with clear Markdown headings and structure.
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 3000,
                temperature: 0.5,
                systemPrompt: systemPrompt
            )

            let documentation = NetworkDocumentation(
                title: "Network Documentation - \(Date().formatted(date: .long, time: .omitted))",
                content: response,
                generatedDate: Date(),
                deviceCount: devices.count,
                includesSecurityAnalysis: includeSecurityAnalysis,
                includesTopology: includeTopology,
                includesRecommendations: includeRecommendations
            )

            currentDocumentation = documentation
            return documentation
        } catch {
            print("Documentation generation error: \(error)")
            return NetworkDocumentation.error(error.localizedDescription)
        }
    }

    /// Generate device-specific documentation
    func generateDeviceDocumentation(_ device: EnhancedDevice) async -> String? {
        guard capability.isMLXAvailable else { return nil }

        let context = buildDeviceDocumentationContext(device: device)

        let systemPrompt = """
        You are documenting a specific network device.
        Provide detailed technical documentation in a professional format.
        """

        let userPrompt = """
        Generate detailed documentation for this device:

        \(context)

        Include:
        - Device overview
        - Technical specifications
        - Network configuration
        - Security assessment
        - Operational status
        - Recommendations

        Use clear Markdown formatting.
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 1200,
                temperature: 0.4,
                systemPrompt: systemPrompt
            )

            return response
        } catch {
            return nil
        }
    }

    /// Export documentation to file
    func exportDocumentation(_ documentation: NetworkDocumentation, format: DocumentationFormat) -> URL? {
        let filename = "network_documentation_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            let content: String
            switch format {
            case .markdown:
                content = documentation.content
            case .html:
                content = markdownToHTML(documentation.content)
            case .plainText:
                content = stripMarkdown(documentation.content)
            }

            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }

    // MARK: - Context Building

    private func buildDocumentationContext(
        devices: [EnhancedDevice],
        includeSecurityAnalysis: Bool,
        includeTopology: Bool
    ) -> String {
        var context = ""

        // Network Overview
        context += "Network Statistics:\n"
        context += "- Total Devices: \(devices.count)\n"
        context += "- Online Devices: \(devices.filter { $0.isOnline }.count)\n"
        context += "- Offline Devices: \(devices.filter { !$0.isOnline }.count)\n"

        if includeSecurityAnalysis {
            context += "- Rogue Devices: \(devices.filter { $0.isRogue }.count)\n"
            context += "- Devices with Open Ports: \(devices.filter { !$0.openPorts.isEmpty }.count)\n"
        }

        context += "\n"

        // Device Types
        let deviceTypes = Dictionary(grouping: devices, by: { $0.deviceType })
        context += "Device Type Distribution:\n"
        for (type, devicesOfType) in deviceTypes.sorted(by: { $0.value.count > $1.value.count }) {
            context += "- \(type.rawValue): \(devicesOfType.count)\n"
        }
        context += "\n"

        // Device Details
        context += "Device Inventory:\n"
        for (index, device) in devices.enumerated() {
            context += "\nDevice \(index + 1):\n"
            context += "- Name: \(device.displayName)\n"
            context += "- IP Address: \(device.ipAddress)\n"
            context += "- MAC Address: \(device.macAddress ?? "Unknown")\n"
            context += "- Type: \(device.deviceType.rawValue)\n"
            context += "- Manufacturer: \(device.manufacturer ?? "Unknown")\n"
            context += "- Status: \(device.isOnline ? "Online" : "Offline")\n"

            if let os = device.operatingSystem {
                context += "- OS: \(os)\n"
            }

            if !device.openPorts.isEmpty {
                context += "- Open Ports: \(device.openPorts.map { "\($0.port)/\($0.service ?? "unknown")" }.prefix(5).joined(separator: ", "))\n"
            }

            if device.isRogue {
                context += "- ⚠️ FLAGGED AS ROGUE\n"
            }

            // Limit to 30 devices for token management
            if index >= 29 && devices.count > 30 {
                context += "\n... and \(devices.count - 30) more devices\n"
                break
            }
        }

        return context
    }

    private func buildDeviceDocumentationContext(device: EnhancedDevice) -> String {
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
                context += "- Port \(port.port): \(port.service ?? "unknown")\n"
                if let version = port.version {
                    context += "  Version: \(version)\n"
                }
            }
        }

        if device.isRogue {
            context += "\n⚠️ This device is flagged as potentially rogue.\n"
        }

        return context
    }

    // MARK: - Format Conversion

    private func markdownToHTML(_ markdown: String) -> String {
        var html = "<html><head><style>"
        html += "body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 40px; max-width: 900px; margin: 0 auto; }"
        html += "h1 { color: #1a1a1a; border-bottom: 2px solid #007AFF; }"
        html += "h2 { color: #333; margin-top: 30px; }"
        html += "h3 { color: #555; }"
        html += "code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }"
        html += "ul { line-height: 1.6; }"
        html += "</style></head><body>"

        // Simple markdown to HTML conversion
        let lines = markdown.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("### ") {
                html += "<h3>\(line.dropFirst(4))</h3>"
            } else if line.hasPrefix("## ") {
                html += "<h2>\(line.dropFirst(3))</h2>"
            } else if line.hasPrefix("# ") {
                html += "<h1>\(line.dropFirst(2))</h1>"
            } else if line.hasPrefix("- ") {
                html += "<li>\(line.dropFirst(2))</li>"
            } else if !line.isEmpty {
                html += "<p>\(line)</p>"
            }
        }

        html += "</body></html>"
        return html
    }

    private func stripMarkdown(_ markdown: String) -> String {
        var text = markdown
        text = text.replacingOccurrences(of: "###", with: "")
        text = text.replacingOccurrences(of: "##", with: "")
        text = text.replacingOccurrences(of: "#", with: "")
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        return text
    }
}

// MARK: - Data Models

struct NetworkDocumentation {
    let title: String
    let content: String
    let generatedDate: Date
    let deviceCount: Int
    let includesSecurityAnalysis: Bool
    let includesTopology: Bool
    let includesRecommendations: Bool

    static func unavailable() -> NetworkDocumentation {
        NetworkDocumentation(
            title: "Documentation Unavailable",
            content: "AI-powered documentation generation requires MLX toolkit on Apple Silicon.\n\nPlease install MLX to use this feature:\n```\npip3 install mlx mlx-lm\n```",
            generatedDate: Date(),
            deviceCount: 0,
            includesSecurityAnalysis: false,
            includesTopology: false,
            includesRecommendations: false
        )
    }

    static func error(_ message: String) -> NetworkDocumentation {
        NetworkDocumentation(
            title: "Documentation Generation Error",
            content: "Failed to generate documentation: \(message)",
            generatedDate: Date(),
            deviceCount: 0,
            includesSecurityAnalysis: false,
            includesTopology: false,
            includesRecommendations: false
        )
    }
}

enum DocumentationFormat {
    case markdown
    case html
    case plainText

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .html: return "html"
        case .plainText: return "txt"
        }
    }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .html: return "HTML"
        case .plainText: return "Plain Text"
        }
    }
}

// MARK: - Documentation Generator View

struct DocumentationGeneratorView: View {
    @ObservedObject var generator = MLXDocumentationGenerator.shared
    let devices: [EnhancedDevice]

    @State private var includeSecurityAnalysis = true
    @State private var includeTopology = true
    @State private var includeRecommendations = true
    @State private var selectedFormat: DocumentationFormat = .markdown
    @State private var showingExportAlert = false
    @State private var exportedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("Network Documentation")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                if generator.isGenerating {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Button("Generate") {
                        Task {
                            await generator.generateDocumentation(
                                devices: devices,
                                includeSecurityAnalysis: includeSecurityAnalysis,
                                includeTopology: includeTopology,
                                includeRecommendations: includeRecommendations
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }

            // Options
            VStack(alignment: .leading, spacing: 12) {
                Text("Documentation Options")
                    .font(.system(size: 18, weight: .semibold))

                Toggle("Include Security Analysis", isOn: $includeSecurityAnalysis)
                    .toggleStyle(.switch)

                Toggle("Include Network Topology", isOn: $includeTopology)
                    .toggleStyle(.switch)

                Toggle("Include Recommendations", isOn: $includeRecommendations)
                    .toggleStyle(.switch)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )

            // Documentation Preview
            if let documentation = generator.currentDocumentation {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(documentation.title)
                                .font(.system(size: 20, weight: .semibold))

                            Text("Generated: \(documentation.generatedDate.formatted(date: .long, time: .shortened))")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Export Button
                        Button("Export") {
                            exportDocumentation(format: .markdown)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    // Content Preview
                    ScrollView {
                        Text(documentation.content)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                    .frame(maxHeight: 600)
                }
            }
        }
        .padding(20)
        .alert("Documentation Exported", isPresented: $showingExportAlert) {
            Button("OK") {
                exportedURL = nil
            }
        } message: {
            if let url = exportedURL {
                Text("Documentation saved to:\n\(url.path)")
            }
        }
    }

    private func exportDocumentation(format: DocumentationFormat) {
        guard let documentation = generator.currentDocumentation else { return }

        if let url = generator.exportDocumentation(documentation, format: format) {
            exportedURL = url
            showingExportAlert = true
        }
    }
}

// MARK: - Compact Documentation View

struct CompactDocumentationView: View {
    @ObservedObject var generator = MLXDocumentationGenerator.shared
    let devices: [EnhancedDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                Text("Generate Documentation")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                if generator.isGenerating {
                    ProgressView()
                } else {
                    Button("Generate") {
                        Task {
                            await generator.generateDocumentation(
                                devices: devices,
                                includeSecurityAnalysis: true,
                                includeTopology: true,
                                includeRecommendations: true
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }

            Text("Create professional network documentation with AI-powered insights")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}
