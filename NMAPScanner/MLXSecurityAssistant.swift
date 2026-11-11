//
//  MLXSecurityAssistant.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  Conversational AI security assistant using MLX.
//  Chat interface for network security questions and guidance.
//

import Foundation
import SwiftUI
import NovaAIKit

// MARK: - MLX Security Assistant

@MainActor
class MLXSecurityAssistant: ObservableObject {
    static let shared = MLXSecurityAssistant()

    @Published var messages: [ChatMessage] = []
    @Published var isResponding: Bool = false

    /// Where the last answer came from ("AI · Ollama (qwen3:8b)" / "Built-in").
    @Published var lastSource: NovaAISource?

    // Context about current network
    private var networkContext: String = ""

    private init() {
        // Add welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hello! I'm your AI security assistant. Ask me anything about your network security, device analysis, or best practices.",
            timestamp: Date()
        ))
    }

    // MARK: - Chat Interface

    /// Send a message and get a (streamed) AI response. Same as `sendMessageStreaming`.
    func sendMessage(_ userMessage: String, networkDevices: [EnhancedDevice]) async {
        await sendMessageStreaming(userMessage, networkDevices: networkDevices)
    }

    /// Stream a response token-by-token (for real-time chat). When AI is off or unreachable the transcript gets the
    /// reason plus the built-in rule-based summary of the network, and the chat stays usable.
    func sendMessageStreaming(_ userMessage: String, networkDevices: [EnhancedDevice]) async {
        let history = Array(messages.suffix(10))
        messages.append(ChatMessage(role: .user, content: userMessage, timestamp: Date()))
        messages.append(ChatMessage(role: .assistant, content: "", timestamp: Date()))
        let index = messages.count - 1

        isResponding = true
        defer { isResponding = false }

        networkContext = buildNetworkContext(devices: networkDevices)
        let request = NovaAIRequest(messages: Self.chatMessages(system: systemPrompt(), history: history, user: userMessage),
                                    temperature: 0.7, maxTokens: 1500)
        do {
            for try await delta in AppAI.current.stream(request) {
                messages[index].content += delta
            }
            if messages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw NovaAIValidationError("the AI returned an empty reply")
            }
            let status = AppAI.current.status
            lastSource = .ai(backend: status.activeBackend ?? AppAI.current.settings.backend, model: status.activeModel ?? "")
        } catch {
            messages[index].content = Self.builtInAnswer(reason: error, devices: networkDevices)
            lastSource = .fallback(.unavailable((error as? LocalizedError)?.errorDescription ?? "\(error)"))
        }
    }

    /// The conversation as NovaAIKit messages: system prompt, the recent turns, then the new question.
    static func chatMessages(system: String, history: [ChatMessage], user: String) -> [NovaAIMessage] {
        [.system(system)]
            + history.filter { !$0.content.isEmpty }.map { $0.role == .user ? .user($0.content) : .assistant($0.content) }
            + [.user(user)]
    }

    /// Chat fallback: why AI didn't answer, then the built-in analysis of the current scan.
    static func builtInAnswer(reason: Error, devices: [EnhancedDevice]) -> String {
        let why = (reason as? LocalizedError)?.errorDescription ?? reason.localizedDescription
        let analysis = BuiltInSecurityAnalysis.threatAnalysis(devices: devices)
        var text = "AI is unavailable (\(why)). Here is the built-in analysis of your last scan instead:\n\n\(analysis.summary)"
        if !analysis.recommendations.isEmpty {
            text += "\n\nTop actions:\n" + analysis.recommendations.prefix(5).map { "• \($0)" }.joined(separator: "\n")
        }
        text += "\n\nTurn AI on or pick a backend in Settings › AI to chat."
        return text
    }

    private func systemPrompt() -> String {
        """
        You are an expert network security assistant with deep knowledge of:
        - Network security best practices
        - Device security and hardening
        - Threat analysis and risk assessment
        - NMAP scanning and port analysis
        - Common vulnerabilities and exploits

        The user is using NMAP Plus Security Scanner on their network.

        Current Network Context:
        \(networkContext)

        Provide helpful, accurate, and actionable security advice.
        Be conversational but professional.
        Explain technical concepts clearly.
        """
    }

    /// Get suggested questions
    func getSuggestedQuestions() -> [String] {
        return [
            "What security risks should I be aware of?",
            "How can I secure my IoT devices?",
            "Explain what port scanning tells me",
            "What does it mean if a device is rogue?",
            "How do I improve my network security?",
            "What are common network vulnerabilities?"
        ]
    }

    /// Clear conversation
    func clearConversation() {
        messages.removeAll()
        messages.append(ChatMessage(
            role: .assistant,
            content: "Conversation cleared. How can I help you with network security?",
            timestamp: Date()
        ))
    }

    // MARK: - Context Building

    private func buildNetworkContext(devices: [EnhancedDevice]) -> String {
        var context = ""
        context += "Total devices: \(devices.count)\n"
        context += "Online: \(devices.filter { $0.isOnline }.count)\n"
        context += "Rogue devices: \(devices.filter { $0.isRogue }.count)\n"

        let typeCounts = Dictionary(grouping: devices, by: { $0.deviceType }).mapValues { $0.count }
        context += "Device types: \(typeCounts.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", "))\n"

        let devicesWithPorts = devices.filter { !$0.openPorts.isEmpty }.count
        context += "Devices with open ports: \(devicesWithPorts)\n"

        return context
    }

}

// MARK: - Data Models

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var content: String
    let timestamp: Date

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageRole {
    case user
    case assistant
}

// MARK: - Security Assistant View

struct SecurityAssistantView: View {
    @ObservedObject var assistant = MLXSecurityAssistant.shared
    let devices: [EnhancedDevice]

    @State private var inputText: String = ""
    @State private var showingSuggestions = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("Security Assistant")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                Button("Clear Chat") {
                    assistant.clearConversation()
                    showingSuggestions = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }
            .padding(20)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(assistant.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if assistant.isResponding {
                            HStack {
                                ProgressView()
                                Text("Thinking...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: assistant.messages.count) { _, _ in
                    if let lastMessage = assistant.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Suggested Questions
            if showingSuggestions && assistant.messages.count == 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested Questions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(assistant.getSuggestedQuestions(), id: \.self) { suggestion in
                                Button(suggestion) {
                                    inputText = suggestion
                                    sendMessage()
                                    showingSuggestions = false
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 12)
            }

            Divider()

            // Input
            HStack(spacing: 12) {
                TextField("Ask about network security...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || assistant.isResponding)
            }
            .padding(20)
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let message = inputText
        inputText = ""
        showingSuggestions = false

        Task {
            await assistant.sendMessage(message, networkDevices: devices)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.blue : Color.secondary.opacity(0.2))
                    )

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 600, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Compact Assistant View (for embedding in other views)

struct CompactSecurityAssistantView: View {
    @ObservedObject var assistant = MLXSecurityAssistant.shared
    let devices: [EnhancedDevice]

    @State private var inputText: String = ""
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                Text("Ask Security Assistant")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button(isExpanded ? "Collapse" : "Expand") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
            }

            // Quick input
            HStack(spacing: 12) {
                TextField("Ask a question...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .onSubmit {
                        sendMessage()
                    }

                Button("Ask") {
                    sendMessage()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(inputText.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
                .disabled(inputText.isEmpty)
            }

            // Last response preview
            if isExpanded, let lastResponse = assistant.messages.last(where: { $0.role == .assistant }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest Response:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(lastResponse.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
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

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let message = inputText
        inputText = ""

        Task {
            await assistant.sendMessage(message, networkDevices: devices)
        }
    }
}
