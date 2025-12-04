//
//  MLXSecurityAssistant.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Conversational AI security assistant using MLX.
//  Chat interface for network security questions and guidance.
//

import Foundation
import SwiftUI

// MARK: - MLX Security Assistant

@MainActor
class MLXSecurityAssistant: ObservableObject {
    static let shared = MLXSecurityAssistant()

    @Published var messages: [ChatMessage] = []
    @Published var isResponding: Bool = false

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

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

    /// Send a message and get AI response
    func sendMessage(_ userMessage: String, networkDevices: [EnhancedDevice]) async {
        guard capability.isMLXAvailable else {
            let errorMsg = ChatMessage(
                role: .assistant,
                content: "I'm sorry, but I require the MLX AI toolkit to function. Please install MLX on Apple Silicon to use the security assistant.",
                timestamp: Date()
            )
            messages.append(errorMsg)
            return
        }

        // Add user message
        let userMsg = ChatMessage(
            role: .user,
            content: userMessage,
            timestamp: Date()
        )
        messages.append(userMsg)

        isResponding = true
        defer { isResponding = false }

        // Update network context
        networkContext = buildNetworkContext(devices: networkDevices)

        // Build conversation history
        let conversationHistory = buildConversationHistory()

        let systemPrompt = """
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

        let userPrompt = """
        Conversation:
        \(conversationHistory)

        User: \(userMessage)

        Assistant:
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 1500,
                temperature: 0.7,
                systemPrompt: systemPrompt
            )

            let assistantMsg = ChatMessage(
                role: .assistant,
                content: response,
                timestamp: Date()
            )
            messages.append(assistantMsg)
        } catch {
            let errorMsg = ChatMessage(
                role: .assistant,
                content: "I apologize, but I encountered an error: \(error.localizedDescription). Please try again.",
                timestamp: Date()
            )
            messages.append(errorMsg)
        }
    }

    /// Stream a response token-by-token (for real-time chat)
    func sendMessageStreaming(_ userMessage: String, networkDevices: [EnhancedDevice]) async {
        guard capability.isMLXAvailable else {
            await sendMessage(userMessage, networkDevices: networkDevices)
            return
        }

        // Add user message
        let userMsg = ChatMessage(
            role: .user,
            content: userMessage,
            timestamp: Date()
        )
        messages.append(userMsg)

        // Create placeholder for assistant response
        let assistantMsg = ChatMessage(
            role: .assistant,
            content: "",
            timestamp: Date()
        )
        messages.append(assistantMsg)

        isResponding = true
        defer { isResponding = false }

        // Update network context
        networkContext = buildNetworkContext(devices: networkDevices)

        let conversationHistory = buildConversationHistory()

        let systemPrompt = """
        You are an expert network security assistant.

        Current Network Context:
        \(networkContext)

        Provide helpful security advice.
        """

        let userPrompt = """
        Conversation:
        \(conversationHistory)

        User: \(userMessage)

        Assistant:
        """

        do {
            try await inference.generateStream(
                prompt: userPrompt,
                maxTokens: 1500,
                temperature: 0.7,
                systemPrompt: systemPrompt
            ) { token in
                // Update the last message with new token
                if var lastMsg = self.messages.last {
                    lastMsg.content += token
                    self.messages[self.messages.count - 1] = lastMsg
                }
            }
        } catch {
            if var lastMsg = messages.last {
                lastMsg.content = "Error: \(error.localizedDescription)"
                messages[messages.count - 1] = lastMsg
            }
        }
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

    private func buildConversationHistory() -> String {
        // Include last 5 message pairs to keep context manageable
        let recentMessages = messages.suffix(10)

        return recentMessages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n\n")
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
                .onChange(of: assistant.messages.count) { _ in
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
