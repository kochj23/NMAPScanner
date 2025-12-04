//
//  ContentView.swift
//  NMAP Scanner - Main Interface
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

struct ToolsMenu: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Security & Monitoring Tools")
                .font(.system(size: 36, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                NavigationLink(destination: NetworkTrafficView()) {
                    ToolCard(
                        title: "Traffic Monitor",
                        icon: "chart.line.uptrend.xyaxis",
                        description: "Monitor network connections",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: PacketCaptureView()) {
                    ToolCard(
                        title: "Packet Capture",
                        icon: "network",
                        description: "Capture and analyze packets",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: VulnerabilityView()) {
                    ToolCard(
                        title: "Vulnerability Scan",
                        icon: "exclamationmark.shield",
                        description: "Detect security vulnerabilities",
                        color: .red
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SecurityAuditView()) {
                    ToolCard(
                        title: "Security Audit",
                        icon: "checkmark.shield",
                        description: "Comprehensive security audit",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(30)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(20)
    }
}

struct ToolCard: View {
    let title: String
    let icon: String
    let description: String
    let color: Color

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 18))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(color.opacity(0.1))
        .cornerRadius(15)
    }
}

struct HostResultCard: View {
    let result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(result.host)
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                Text("\(result.openPorts.count) open")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }

            ForEach(result.openPorts, id: \.port) { port in
                HStack {
                    Text("\(port.port)")
                        .font(.system(size: 24, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(width: 100)
                    Text(port.service ?? "Unknown")
                        .font(.system(size: 22))
                    Spacer()
                }
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct ScanResult {
    let host: String
    let openPorts: [PortResult]
}

struct PortResult {
    let port: Int
    let service: String?
}
