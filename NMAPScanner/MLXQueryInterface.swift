//
//  MLXQueryInterface.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Natural language query interface using MLX.
//  Allows users to query network devices using plain English.
//

import Foundation
import SwiftUI

// MARK: - MLX Query Interface

@MainActor
class MLXQueryInterface: ObservableObject {
    static let shared = MLXQueryInterface()

    @Published var queryResults: [EnhancedDevice] = []
    @Published var queryExplanation: String = ""
    @Published var isQuerying: Bool = false
    @Published var queryHistory: [QueryHistoryItem] = []

    private let inference = MLXInferenceEngine.shared
    private let capability = MLXCapabilityDetector.shared

    private init() {}

    // MARK: - Natural Language Query

    /// Process natural language query and return matching devices
    func query(_ naturalLanguageQuery: String, devices: [EnhancedDevice]) async -> QueryResult? {
        guard capability.isMLXAvailable else {
            return QueryResult.unavailable()
        }

        isQuerying = true
        defer { isQuerying = false }

        let context = buildQueryContext(devices: devices, query: naturalLanguageQuery)

        let systemPrompt = """
        You are a network query assistant that translates natural language queries into device filters.
        Analyze the user's question and determine which devices match their criteria.
        Be precise and explain your reasoning.
        """

        let userPrompt = """
        User Query: "\(naturalLanguageQuery)"

        Available Devices:
        \(context)

        Analyze the query and provide:
        1. Which device numbers match the query (comma-separated list)
        2. Clear explanation of why these devices match
        3. Summary of findings

        Format your response as:
        Matches: [comma-separated device numbers, e.g., "1, 3, 5"]
        Explanation: [why these devices match]
        Summary: [brief summary of results]
        """

        do {
            let response = try await inference.generate(
                prompt: userPrompt,
                maxTokens: 800,
                temperature: 0.3,
                systemPrompt: systemPrompt
            )

            let result = parseQueryResponse(response, devices: devices, query: naturalLanguageQuery)

            // Update state
            queryResults = result.matchingDevices
            queryExplanation = result.explanation

            // Add to history
            queryHistory.insert(QueryHistoryItem(
                query: naturalLanguageQuery,
                resultCount: result.matchingDevices.count,
                timestamp: Date()
            ), at: 0)

            return result
        } catch {
            print("Query error: \(error)")
            return QueryResult.error(error.localizedDescription)
        }
    }

    /// Get suggested queries based on network
    func getSuggestedQueries(devices: [EnhancedDevice]) -> [String] {
        var suggestions: [String] = [
            "Show me all devices with open ports",
            "Which devices are IoT devices?",
            "Find all offline devices",
            "Show me devices connected in the last 24 hours"
        ]

        // Add contextual suggestions based on network
        if devices.contains(where: { $0.isRogue }) {
            suggestions.insert("Show me all rogue devices", at: 0)
        }

        if devices.contains(where: { $0.deviceType == .iot }) {
            suggestions.append("Show me all IoT devices")
        }

        if devices.contains(where: { !$0.openPorts.isEmpty }) {
            suggestions.append("Which devices have port 22 open?")
        }

        return Array(suggestions.prefix(6))
    }

    // MARK: - Context Building

    private func buildQueryContext(devices: [EnhancedDevice], query: String) -> String {
        var context = ""

        // Limit to 30 devices to stay within token limits
        let limitedDevices = devices.prefix(30)

        for (index, device) in limitedDevices.enumerated() {
            context += "Device \(index + 1):\n"
            context += "- Name: \(device.displayName)\n"
            context += "- IP: \(device.ipAddress)\n"
            context += "- Type: \(device.deviceType.rawValue)\n"
            context += "- Manufacturer: \(device.manufacturer ?? "Unknown")\n"
            context += "- Status: \(device.isOnline ? "Online" : "Offline")\n"

            if !device.openPorts.isEmpty {
                context += "- Open Ports: \(device.openPorts.map { String($0.port) }.joined(separator: ", "))\n"
            }

            if let os = device.operatingSystem {
                context += "- OS: \(os)\n"
            }

            if device.isRogue {
                context += "- Status: ROGUE DEVICE\n"
            }

            context += "- Last Seen: \(device.lastSeen.formatted())\n"
            context += "\n"
        }

        if devices.count > 30 {
            context += "... and \(devices.count - 30) more devices\n"
        }

        return context
    }

    // MARK: - Response Parsing

    private func parseQueryResponse(_ response: String, devices: [EnhancedDevice], query: String) -> QueryResult {
        var matchingDevices: [EnhancedDevice] = []
        var explanation = ""
        var summary = ""

        let lines = response.components(separatedBy: "\n")

        for line in lines {
            if line.lowercased().starts(with: "matches:") {
                let matchesStr = extractValue(from: line)
                let deviceNumbers = matchesStr.components(separatedBy: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

                // Convert device numbers to actual devices (1-indexed)
                for num in deviceNumbers {
                    if num > 0 && num <= devices.count {
                        matchingDevices.append(devices[num - 1])
                    }
                }
            } else if line.lowercased().starts(with: "explanation:") {
                explanation = extractValue(from: line)
            } else if line.lowercased().starts(with: "summary:") {
                summary = extractValue(from: line)
            }
        }

        // If parsing failed, try fuzzy matching
        if matchingDevices.isEmpty && explanation.isEmpty {
            explanation = response
            summary = "Found \(matchingDevices.count) matching devices"
        }

        return QueryResult(
            query: query,
            matchingDevices: matchingDevices,
            explanation: explanation.isEmpty ? "No explanation provided" : explanation,
            summary: summary.isEmpty ? "Query completed" : summary,
            timestamp: Date()
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

struct QueryResult {
    let query: String
    let matchingDevices: [EnhancedDevice]
    let explanation: String
    let summary: String
    let timestamp: Date

    static func unavailable() -> QueryResult {
        QueryResult(
            query: "",
            matchingDevices: [],
            explanation: "Natural language queries require MLX AI. Please install MLX to use this feature.",
            summary: "Feature unavailable",
            timestamp: Date()
        )
    }

    static func error(_ message: String) -> QueryResult {
        QueryResult(
            query: "",
            matchingDevices: [],
            explanation: "Error: \(message)",
            summary: "Query failed",
            timestamp: Date()
        )
    }
}

struct QueryHistoryItem: Identifiable {
    let id = UUID()
    let query: String
    let resultCount: Int
    let timestamp: Date
}

// MARK: - Natural Language Query View

struct NaturalLanguageQueryView: View {
    @ObservedObject var queryInterface = MLXQueryInterface.shared
    let devices: [EnhancedDevice]

    @State private var queryText: String = ""
    @State private var currentResult: QueryResult?
    @State private var showingHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("Natural Language Query")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                Button("History") {
                    showingHistory.toggle()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }

            // Query Input
            HStack(spacing: 12) {
                TextField("Ask about your network...", text: $queryText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 18))
                    .onSubmit {
                        executeQuery()
                    }

                if queryInterface.isQuerying {
                    ProgressView()
                } else {
                    Button("Search") {
                        executeQuery()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(queryText.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(queryText.isEmpty)
                }
            }

            // Suggested Queries
            if currentResult == nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested Queries")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(queryInterface.getSuggestedQueries(devices: devices), id: \.self) { suggestion in
                                Button(suggestion) {
                                    queryText = suggestion
                                    executeQuery()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            // Results
            if let result = currentResult {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 24))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.summary)
                                    .font(.system(size: 20, weight: .semibold))

                                Text("Found \(result.matchingDevices.count) devices")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Clear") {
                                currentResult = nil
                                queryText = ""
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                        }

                        Divider()

                        Text("Explanation")
                            .font(.system(size: 16, weight: .semibold))

                        Text(result.explanation)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )

                    // Matching Devices
                    if !result.matchingDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Matching Devices")
                                .font(.system(size: 20, weight: .semibold))

                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(result.matchingDevices) { device in
                                        QueryResultDeviceCard(device: device)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No devices match your query")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(20)
        .sheet(isPresented: $showingHistory) {
            QueryHistoryView(queryInterface: queryInterface, onSelectQuery: { query in
                queryText = query
                showingHistory = false
                executeQuery()
            })
        }
    }

    private func executeQuery() {
        guard !queryText.isEmpty else { return }

        Task {
            currentResult = await queryInterface.query(queryText, devices: devices)
        }
    }
}

// MARK: - Query Result Device Card

struct QueryResultDeviceCard: View {
    let device: EnhancedDevice

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status Indicator
            Circle()
                .fill(device.isOnline ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            // Device Info
            VStack(alignment: .leading, spacing: 6) {
                Text(device.displayName)
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 12) {
                    Label(device.ipAddress, systemImage: "network")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Label(device.deviceType.rawValue, systemImage: "tag")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                if !device.openPorts.isEmpty {
                    Text("Open Ports: \(device.openPorts.map { String($0.port) }.prefix(5).joined(separator: ", "))")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            // Rogue Badge
            if device.isRogue {
                Text("ROGUE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Query History View

struct QueryHistoryView: View {
    @ObservedObject var queryInterface: MLXQueryInterface
    let onSelectQuery: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(queryInterface.queryHistory) { item in
                    Button(action: {
                        onSelectQuery(item.query)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.query)
                                .font(.system(size: 16, weight: .medium))

                            HStack {
                                Text("\(item.resultCount) results")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Query History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All") {
                        queryInterface.queryHistory.removeAll()
                    }
                    .disabled(queryInterface.queryHistory.isEmpty)
                }
            }
        }
    }
}
