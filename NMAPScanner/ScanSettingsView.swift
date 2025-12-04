//
//  ScanSettingsView.swift
//  NMAP Scanner - Scan Configuration
//
//  Created by Jordan Koch on 2025-11-23.
//

import SwiftUI

struct ScanSettingsView: View {
    @ObservedObject var scanner: SimpleNetworkScanner
    @Environment(\.dismiss) var dismiss

    @State private var subnet = "192.168.1"
    @State private var scanType: ScanType = .quick
    @State private var includeVulnerabilityCheck = true
    @State private var includeServiceDetection = true

    enum ScanType: String, CaseIterable {
        case quick = "Quick Scan"
        case standard = "Standard Scan"
        case comprehensive = "Comprehensive Scan"

        var ports: [Int] {
            switch self {
            case .quick:
                return [22, 80, 443, 3389, 5900]  // SSH, HTTP, HTTPS, RDP, VNC
            case .standard:
                return [21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 3306, 3389, 5432, 5900, 8080]
            case .comprehensive:
                return Array(1...1024) + [3306, 3389, 5432, 5900, 8080, 8443]
            }
        }

        var description: String {
            switch self {
            case .quick:
                return "Scans 5 most common ports (~30 seconds)"
            case .standard:
                return "Scans 16 common services (~2 minutes)"
            case .comprehensive:
                return "Scans 1024+ ports (~15 minutes)"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                HStack {
                    Text("Scan Settings")
                        .font(.system(size: 50, weight: .bold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 28))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }

                // Network configuration
                NetworkConfigCard(subnet: $subnet)

                // Scan type selection
                ScanTypeCard(scanType: $scanType)

                // Options
                ScanOptionsCard(
                    includeVulnerabilityCheck: $includeVulnerabilityCheck,
                    includeServiceDetection: $includeServiceDetection
                )

                // Start scan button
                Button(action: startScan) {
                    HStack {
                        if scanner.isScanning {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Scanning...")
                                .font(.system(size: 32, weight: .bold))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                            Text("Start Scan")
                                .font(.system(size: 32, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(scanner.isScanning ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(scanner.isScanning)
            }
            .padding(40)
        }
    }

    private func startScan() {
        Task {
            // TODO: Update to use correct scanning method
            await scanner.scanPingSweep(subnet: subnet)
            dismiss()
        }
    }
}

struct NetworkConfigCard: View {
    @Binding var subnet: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Configuration")
                .font(.system(size: 36, weight: .semibold))

            VStack(alignment: .leading, spacing: 12) {
                Text("Subnet (Class C /24)")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    TextField("192.168.1", text: $subnet)
                        .font(.system(size: 28, design: .monospaced))
                        .padding(16)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)

                    Text(".0/24")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text("Will scan 254 hosts: \(subnet).1 through \(subnet).254")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

struct ScanTypeCard: View {
    @Binding var scanType: ScanSettingsView.ScanType

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Scan Type")
                .font(.system(size: 36, weight: .semibold))

            VStack(spacing: 16) {
                ForEach(ScanSettingsView.ScanType.allCases, id: \.self) { type in
                    Button(action: {
                        scanType = type
                    }) {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(scanType == type ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)

                                if scanType == type {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(type.rawValue)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(type.description)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(type.ports.count) ports")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(20)
                        .background(scanType == type ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(scanType == type ? Color.blue : Color.clear, lineWidth: 3)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
}

struct ScanOptionsCard: View {
    @Binding var includeVulnerabilityCheck: Bool
    @Binding var includeServiceDetection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Scan Options")
                .font(.system(size: 36, weight: .semibold))

            VStack(spacing: 16) {
                OptionToggle(
                    title: "Vulnerability Check",
                    description: "Scan for common security vulnerabilities",
                    icon: "exclamationmark.shield",
                    isOn: $includeVulnerabilityCheck
                )

                OptionToggle(
                    title: "Service Detection",
                    description: "Identify services running on open ports",
                    icon: "server.rack",
                    isOn: $includeServiceDetection
                )
            }
        }
        .padding(24)
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }
}

struct OptionToggle: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isOn ? .green : .gray)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isOn ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 80, height: 48)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .offset(x: isOn ? 16 : -16)
                }
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
