//
//  AIAssistantTabView.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  Comprehensive AI Assistant tab integrating all 9 MLX-powered features.
//  Provides intelligent network analysis, threat detection, and security guidance.
//

import SwiftUI
import NovaAIKit

// MARK: - AI Assistant Tab View

struct AIAssistantTabView: View {
    @StateObject private var scanner = IntegratedScannerV3.shared
    @ObservedObject var ai = AppAI.current
    @ObservedObject var threatAnalyzer = MLXThreatAnalyzer.shared
    @ObservedObject var deviceClassifier = MLXDeviceClassifier.shared
    @ObservedObject var securityAssistant = MLXSecurityAssistant.shared
    @ObservedObject var queryInterface = MLXQueryInterface.shared
    @ObservedObject var anomalyDetector = MLXAnomalyDetector.shared
    @ObservedObject var docGenerator = MLXDocumentationGenerator.shared
    @ObservedObject var recommendationsEngine = MLXSecurityRecommendations.shared

    @State private var selectedFeature: AIFeature = .overview

    enum AIFeature: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case threatAnalysis = "Threat Analysis"
        case deviceClassification = "Device Classification"
        case securityAssistant = "Security Assistant"
        case queryInterface = "Natural Language Query"
        case anomalyDetection = "Anomaly Detection"
        case recommendations = "Security Recommendations"
        case documentation = "Network Documentation"
        case capabilities = "AI Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "brain.head.profile"
            case .threatAnalysis: return "exclamationmark.shield.fill"
            case .deviceClassification: return "tag.fill"
            case .securityAssistant: return "message.fill"
            case .queryInterface: return "text.bubble.fill"
            case .anomalyDetection: return "waveform.path.ecg"
            case .recommendations: return "checklist"
            case .documentation: return "doc.text.fill"
            case .capabilities: return "cpu.fill"
            }
        }

        var description: String {
            switch self {
            case .overview:
                return "AI-powered network security overview"
            case .threatAnalysis:
                return "Comprehensive threat analysis and risk assessment"
            case .deviceClassification:
                return "Automatic device identification and categorization"
            case .securityAssistant:
                return "Chat with AI security expert"
            case .queryInterface:
                return "Ask questions in plain English"
            case .anomalyDetection:
                return "Detect unusual network behavior"
            case .recommendations:
                return "Prioritized security improvement roadmap"
            case .documentation:
                return "Generate professional network documentation"
            case .capabilities:
                return "Backend, model, keys and the AI on/off switch"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar with feature list
            List(AIFeature.allCases, selection: $selectedFeature) { feature in
                NavigationLink(value: feature) {
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.rawValue)
                                .font(.system(size: 14, weight: .medium))
                            Text(feature.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("AI Features")
            .frame(minWidth: 250)

        } detail: {
            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerView

                    // Feature content
                    // Every feature works without AI (built-in rule-based results), so nothing is gated.
                    featureContent
                }
                .padding(24)
            }
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
        }
        .task {
            await ai.refreshStatus()
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: selectedFeature.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedFeature.rawValue)
                        .font(.system(size: 28, weight: .bold))

                    Text(selectedFeature.description)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // AI status indicator
                aiStatusBadge
            }

            Divider()
        }
    }

    @ViewBuilder
    private var aiStatusBadge: some View {
        NovaAIStatusIndicator(ai: ai)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
    }

    // MARK: - Feature Content

    @ViewBuilder
    private var featureContent: some View {
        switch selectedFeature {
        case .overview:
            overviewContent

        case .threatAnalysis:
            ThreatAnalysisView(devices: scanner.devices)

        case .deviceClassification:
            BatchDeviceClassificationView(devices: scanner.devices)

        case .securityAssistant:
            SecurityAssistantView(devices: scanner.devices)

        case .queryInterface:
            NaturalLanguageQueryView(devices: scanner.devices)

        case .anomalyDetection:
            AnomalyDetectionView(devices: scanner.devices)

        case .recommendations:
            SecurityRecommendationsView(devices: scanner.devices)

        case .documentation:
            DocumentationGeneratorView(devices: scanner.devices)

        case .capabilities:
            NovaAISettingsView(ai: ai, footer: AppAI.settingsFooter)
        }
    }

    // MARK: - Overview Content

    @ViewBuilder
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Welcome section
            VStack(alignment: .leading, spacing: 12) {
                Text("🤖 AI-Powered Network Security")
                    .font(.system(size: 24, weight: .bold))

                Text("Intelligent network analysis with the AI backend you choose: local Ollama, MLX, TinyLLM, TinyChat, OpenWebUI or Nova Gateway, or OpenRouter/OpenAI with your own key. With AI off, every feature uses NMAPScanner's built-in rule-based analysis.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.1))
            )

            // Feature cards grid
            featureCardsGrid

            // Quick actions
            quickActionsSection
        }
    }

    @ViewBuilder
    private var featureCardsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Features")
                .font(.system(size: 20, weight: .bold))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(AIFeature.allCases.filter { $0 != .overview && $0 != .capabilities }) { feature in
                    FeatureCard(
                        feature: feature,
                        action: {
                            selectedFeature = feature
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold))

            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Analyze Network",
                    icon: "exclamationmark.shield.fill",
                    color: .red,
                    action: {
                        selectedFeature = .threatAnalysis
                        Task {
                            await threatAnalyzer.analyzeNetwork(devices: scanner.devices)
                        }
                    }
                )

                QuickActionButton(
                    title: "Classify Devices",
                    icon: "tag.fill",
                    color: .orange,
                    action: {
                        selectedFeature = .deviceClassification
                        Task {
                            await deviceClassifier.classifyDevices(scanner.devices)
                        }
                    }
                )

                QuickActionButton(
                    title: "Get Recommendations",
                    icon: "checklist",
                    color: .green,
                    action: {
                        selectedFeature = .recommendations
                        Task {
                            await recommendationsEngine.generateRecommendations(devices: scanner.devices)
                        }
                    }
                )

                QuickActionButton(
                    title: "Generate Documentation",
                    icon: "doc.text.fill",
                    color: .blue,
                    action: {
                        selectedFeature = .documentation
                    }
                )
            }
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let feature: AIAssistantTabView.AIFeature
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: feature.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                    Spacer()
                }

                Text(feature.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Text(feature.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Click to open \(feature.rawValue)")
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

// MARK: - Preview

#Preview {
    AIAssistantTabView()
        .frame(width: 1400, height: 900)
}
