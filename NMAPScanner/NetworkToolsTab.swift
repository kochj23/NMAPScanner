//
//  NetworkToolsTab.swift
//  NMAP Plus Security Scanner - Network Diagnostic Tools
//
//  Created by Jordan Koch on 2025-12-01.
//
//  Classic network tools: ping, traceroute, ipconfig, nslookup, netstat, arp
//

import SwiftUI

// MARK: - Network Tools Tab View

struct NetworkToolsTabView: View {
    @StateObject private var toolsManager = NetworkToolsManager()
    @State private var selectedTool: NetworkTool = .ping

    enum NetworkTool: String, CaseIterable, Identifiable {
        case ping = "Ping"
        case traceroute = "Traceroute"
        case ipconfig = "Network Config"
        case nslookup = "DNS Lookup"
        case arp = "ARP Table"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .ping: return "network"
            case .traceroute: return "map"
            case .ipconfig: return "network.badge.shield.half.filled"
            case .nslookup: return "globe"
            case .arp: return "tablecells"
            }
        }

        var description: String {
            switch self {
            case .ping: return "Test reachability to a host on the network"
            case .traceroute: return "Show the path packets take to reach destination"
            case .ipconfig: return "Display TCP/IP network configuration"
            case .nslookup: return "Query DNS servers to resolve hostnames"
            case .arp: return "View IP-to-MAC address translation table"
            }
        }
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Left sidebar with tools
                VStack(alignment: .leading, spacing: 0) {
                    Text("Network Tools")
                        .font(.system(size: 22, weight: .bold))
                        .padding(20)

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(NetworkTool.allCases) { tool in
                                ToolSidebarButton(
                                    tool: tool,
                                    isSelected: selectedTool == tool
                                ) {
                                    selectedTool = tool
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    Spacer()
                }
                .frame(width: 220)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Right content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTool {
                        case .ping:
                            PingToolView(manager: toolsManager)
                        case .traceroute:
                            TracerouteToolView(manager: toolsManager)
                        case .ipconfig:
                            IPConfigToolView(manager: toolsManager)
                        case .nslookup:
                            NSLookupToolView(manager: toolsManager)
                        case .arp:
                            ARPToolView(manager: toolsManager)
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Sidebar Button

struct ToolSidebarButton: View {
    let tool: NetworkToolsTabView.NetworkTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 24)

                Text(tool.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ping Tool

struct PingToolView: View {
    @ObservedObject var manager: NetworkToolsManager
    @State private var targetHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ping")
                        .font(.system(size: 28, weight: .bold))
                    Text("Test reachability to a host on the network")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // Input field
            HStack(spacing: 12) {
                TextField("Enter hostname or IP address (e.g., google.com or 192.168.1.1)", text: $targetHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))

                Button(action: {
                    Task {
                        await manager.runPing(host: targetHost)
                    }
                }) {
                    HStack {
                        if manager.isRunning && manager.currentTool == .ping {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Run")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(targetHost.isEmpty || (manager.isRunning && manager.currentTool == .ping))
            }

            // Quick options
            HStack(spacing: 8) {
                Text("Quick:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                ForEach(["192.168.1.1", "8.8.8.8", "1.1.1.1", "google.com"], id: \.self) { host in
                    Button(host) {
                        targetHost = host
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }

            // Output
            if let output = manager.pingOutput {
                ToolOutputView(title: "Ping Results", output: output, isSuccess: output.contains("bytes from"))
            }
        }
    }
}

// MARK: - Traceroute Tool

struct TracerouteToolView: View {
    @ObservedObject var manager: NetworkToolsManager
    @State private var targetHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "map")
                    .font(.system(size: 32))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Traceroute")
                        .font(.system(size: 28, weight: .bold))
                    Text("Show the path packets take to reach destination")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                TextField("Enter hostname or IP address", text: $targetHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))

                Button(action: {
                    Task {
                        await manager.runTraceroute(host: targetHost)
                    }
                }) {
                    HStack {
                        if manager.isRunning && manager.currentTool == .traceroute {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Run")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(targetHost.isEmpty || (manager.isRunning && manager.currentTool == .traceroute))
            }

            HStack(spacing: 8) {
                Text("Quick:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                ForEach(["192.168.1.1", "8.8.8.8", "google.com"], id: \.self) { host in
                    Button(host) {
                        targetHost = host
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }

            if let output = manager.tracerouteOutput {
                ToolOutputView(title: "Traceroute Results", output: output, isSuccess: true)
            }
        }
    }
}

// MARK: - IPConfig Tool

struct IPConfigToolView: View {
    @ObservedObject var manager: NetworkToolsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Configuration")
                        .font(.system(size: 28, weight: .bold))
                    Text("Display TCP/IP network configuration settings")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                Task {
                    await manager.runIPConfig()
                }
            }) {
                HStack {
                    if manager.isRunning && manager.currentTool == .ipconfig {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh Configuration")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(manager.isRunning && manager.currentTool == .ipconfig)

            if let output = manager.ipconfigOutput {
                ToolOutputView(title: "Network Configuration", output: output, isSuccess: true)
            }
        }
        .onAppear {
            if manager.ipconfigOutput == nil {
                Task {
                    await manager.runIPConfig()
                }
            }
        }
    }
}

// MARK: - NSLookup Tool

struct NSLookupToolView: View {
    @ObservedObject var manager: NetworkToolsManager
    @State private var targetHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("DNS Lookup")
                        .font(.system(size: 28, weight: .bold))
                    Text("Query DNS servers to resolve hostnames")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                TextField("Enter hostname (e.g., google.com)", text: $targetHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))

                Button(action: {
                    Task {
                        await manager.runNSLookup(host: targetHost)
                    }
                }) {
                    HStack {
                        if manager.isRunning && manager.currentTool == .nslookup {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Lookup")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(targetHost.isEmpty || (manager.isRunning && manager.currentTool == .nslookup))
            }

            HStack(spacing: 8) {
                Text("Quick:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                ForEach(["google.com", "apple.com", "github.com", "192.168.1.1"], id: \.self) { host in
                    Button(host) {
                        targetHost = host
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }

            if let output = manager.nslookupOutput {
                ToolOutputView(title: "DNS Lookup Results", output: output, isSuccess: output.contains("Address:"))
            }
        }
    }
}

// MARK: - ARP Tool

struct ARPToolView: View {
    @ObservedObject var manager: NetworkToolsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "tablecells")
                    .font(.system(size: 32))
                    .foregroundColor(.indigo)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ARP Table")
                        .font(.system(size: 28, weight: .bold))
                    Text("View IP-to-MAC address translation table")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                Task {
                    await manager.runARP()
                }
            }) {
                HStack {
                    if manager.isRunning && manager.currentTool == .arp {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh ARP Table")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(manager.isRunning && manager.currentTool == .arp)

            if let output = manager.arpOutput {
                ToolOutputView(title: "ARP Table", output: output, isSuccess: true)
            }
        }
        .onAppear {
            if manager.arpOutput == nil {
                Task {
                    await manager.runARP()
                }
            }
        }
    }
}

// MARK: - Tool Output View

struct ToolOutputView: View {
    let title: String
    let output: String
    let isSuccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            ScrollView {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 300, maxHeight: 500)
            .padding()
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Network Tools Manager

@MainActor
class NetworkToolsManager: ObservableObject {
    @Published var isRunning = false
    @Published var currentTool: NetworkToolsTabView.NetworkTool?

    @Published var pingOutput: String?
    @Published var tracerouteOutput: String?
    @Published var ipconfigOutput: String?
    @Published var nslookupOutput: String?
    @Published var arpOutput: String?

    func runPing(host: String) async {
        isRunning = true
        currentTool = .ping

        let output = await executeCommand("/sbin/ping", arguments: ["-c", "5", host])
        pingOutput = output.isEmpty ? "Error: Unable to ping \(host)" : output

        isRunning = false
        currentTool = nil
    }

    func runTraceroute(host: String) async {
        isRunning = true
        currentTool = .traceroute

        let output = await executeCommand("/usr/sbin/traceroute", arguments: ["-m", "20", host])
        tracerouteOutput = output.isEmpty ? "Error: Unable to trace route to \(host)" : output

        isRunning = false
        currentTool = nil
    }

    func runIPConfig() async {
        isRunning = true
        currentTool = .ipconfig

        let output = await executeCommand("/sbin/ifconfig", arguments: [])
        ipconfigOutput = output.isEmpty ? "Error: Unable to retrieve network configuration" : output

        isRunning = false
        currentTool = nil
    }

    func runNSLookup(host: String) async {
        isRunning = true
        currentTool = .nslookup

        let output = await executeCommand("/usr/bin/nslookup", arguments: [host])
        nslookupOutput = output.isEmpty ? "Error: Unable to lookup \(host)" : output

        isRunning = false
        currentTool = nil
    }

    func runARP() async {
        isRunning = true
        currentTool = .arp

        let output = await executeCommand("/usr/sbin/arp", arguments: ["-a"])
        arpOutput = output.isEmpty ? "Error: Unable to retrieve ARP table" : output

        isRunning = false
        currentTool = nil
    }

    private func executeCommand(_ command: String, arguments: [String], timeout: TimeInterval = 60) async -> String {
        // Execute command in a background task to avoid blocking the main thread
        return await withCheckedContinuation { continuation in
            // Use a background task to run the process
            Task.detached {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                // Use an actor to safely manage the hasReturned state
                actor ProcessState {
                    var hasReturned = false

                    func markReturned() -> Bool {
                        if hasReturned {
                            return false
                        }
                        hasReturned = true
                        return true
                    }
                }

                let state = ProcessState()

                // Timeout handler in background
                Task.detached {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    // Only terminate if process is STILL running after timeout
                    if process.isRunning {
                        if await state.markReturned() {
                            process.terminate()
                            print("⏱️ Command timed out after \(timeout)s: \(command)")
                            continuation.resume(returning: "⏱️ Operation timed out after \(Int(timeout)) seconds")
                        }
                    }
                }

                do {
                    // Set terminationHandler BEFORE running to avoid race condition
                    process.terminationHandler = { terminatedProcess in
                        Task.detached {
                            if await state.markReturned() {
                                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                                let output = String(data: data, encoding: .utf8) ?? ""
                                continuation.resume(returning: output.isEmpty ? "No output" : output)
                            }
                        }
                    }

                    // Now start the process
                    try process.run()
                } catch {
                    Task.detached {
                        if await state.markReturned() {
                            continuation.resume(returning: "Error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NetworkToolsTabView()
}
