//
//  AdvancedPortScanner.swift
//  NMAP Scanner - Advanced Port Scanning (UDP, OS Detection, NSE Scripts)
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import SwiftUI

/// Advanced port scanning with UDP, OS fingerprinting, and script scanning
@MainActor
class AdvancedPortScanner: ObservableObject {
    static let shared = AdvancedPortScanner()

    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var currentOperation = ""
    @Published var scanResults: [AdvancedScanResult] = []

    // Scan profiles
    @Published var selectedProfile: ScanProfile = .standard

    private init() {}

    // MARK: - Scan Profiles

    enum ScanProfile: String, CaseIterable, Identifiable {
        case quick = "Quick Scan"
        case standard = "Standard Scan"
        case comprehensive = "Comprehensive Scan"
        case aggressive = "Aggressive Scan"
        case stealth = "Stealth Scan"
        case custom = "Custom Scan"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .quick: return "Fast TCP SYN scan of common ports"
            case .standard: return "TCP connect scan with service detection"
            case .comprehensive: return "Full TCP + UDP scan with OS detection"
            case .aggressive: return "All features: OS, service versions, scripts, traceroute"
            case .stealth: return "Low-profile scanning to avoid detection"
            case .custom: return "User-defined scan parameters"
            }
        }

        var nmapArgs: [String] {
            switch self {
            case .quick:
                return ["-T4", "-F"] // Fast timing, top 100 ports
            case .standard:
                return ["-sV", "-sC", "-T3"] // Service detection, default scripts, normal timing
            case .comprehensive:
                return ["-sS", "-sU", "-O", "-sV", "-T4", "-p-"] // TCP SYN, UDP, OS detection, all ports
            case .aggressive:
                return ["-A", "-T4"] // Aggressive (OS, version, script, traceroute)
            case .stealth:
                return ["-sS", "-T2", "-f"] // SYN scan, slow timing, fragment packets
            case .custom:
                return [] // User will configure
            }
        }
    }

    // MARK: - Advanced Scanning

    /// Perform advanced scan on device
    func scanDevice(_ device: EnhancedDevice, profile: ScanProfile) async {
        isScanning = true
        currentOperation = "Scanning \(device.ipAddress)"
        progress = 0.0

        print("🔍 AdvancedPortScanner: Starting \(profile.rawValue) on \(device.ipAddress)")

        var result = AdvancedScanResult(ipAddress: device.ipAddress, hostname: device.hostname, scanProfile: profile)

        // TCP Port Scan
        progress = 0.1
        currentOperation = "TCP port scanning..."
        result.tcpPorts = await scanTCPPorts(device.ipAddress)

        // UDP Port Scan
        progress = 0.3
        currentOperation = "UDP port scanning..."
        result.udpPorts = await scanUDPPorts(device.ipAddress)

        // OS Fingerprinting
        progress = 0.5
        currentOperation = "OS fingerprinting..."
        result.osDetection = await detectOS(device.ipAddress, openPorts: result.tcpPorts)

        // Service Version Detection
        progress = 0.7
        currentOperation = "Service version detection..."
        result.serviceVersions = await detectServiceVersions(device.ipAddress, ports: result.tcpPorts)

        // NSE Script Scanning
        progress = 0.9
        currentOperation = "Running NSE scripts..."
        result.scriptResults = await runNSEScripts(device.ipAddress, ports: result.tcpPorts)

        result.completionDate = Date()
        scanResults.append(result)

        progress = 1.0
        isScanning = false

        print("🔍 AdvancedPortScanner: Scan complete for \(device.ipAddress)")
    }

    // MARK: - TCP Port Scanning

    /// Scan TCP ports
    private func scanTCPPorts(_ ipAddress: String) async -> [Int] {
        // Use nmap for TCP scanning
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/nmap")
        process.arguments = ["-sT", "-T4", "--top-ports", "1000", ipAddress]

        let pipe = Pipe()
        process.standardOutput = pipe

        var openPorts: [Int] = []

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                openPorts = parseNmapPorts(output)
            }
        } catch {
            print("❌ AdvancedPortScanner: TCP scan failed: \(error)")
        }

        return openPorts
    }

    // MARK: - UDP Port Scanning

    /// Scan UDP ports
    private func scanUDPPorts(_ ipAddress: String) async -> [Int] {
        // UDP scanning requires root privileges
        // Using nmap with -sU flag
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/nmap")
        process.arguments = ["-sU", "--top-ports", "100", "-T4", ipAddress]

        let pipe = Pipe()
        process.standardOutput = pipe

        var openPorts: [Int] = []

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                openPorts = parseNmapPorts(output)
            }
        } catch {
            print("❌ AdvancedPortScanner: UDP scan failed (may require root): \(error)")
        }

        return openPorts
    }

    // MARK: - OS Fingerprinting

    /// Detect operating system
    private func detectOS(_ ipAddress: String, openPorts: [Int]) async -> OSDetectionResult {
        // Use nmap OS detection (-O flag)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/nmap")
        process.arguments = ["-O", ipAddress]

        let pipe = Pipe()
        process.standardOutput = pipe

        var osName: String?
        var osFamily: String?
        var accuracy: Int = 0

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                (osName, osFamily, accuracy) = parseOSDetection(output)
            }
        } catch {
            print("❌ AdvancedPortScanner: OS detection failed: \(error)")
        }

        return OSDetectionResult(osName: osName, osFamily: osFamily, accuracy: accuracy)
    }

    /// Parse OS detection output
    private func parseOSDetection(_ output: String) -> (String?, String?, Int) {
        let lines = output.components(separatedBy: "\n")

        var osName: String?
        var osFamily: String?
        var accuracy: Int = 0

        for line in lines {
            if line.contains("Running:") {
                osFamily = line.replacingOccurrences(of: "Running:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("OS details:") {
                osName = line.replacingOccurrences(of: "OS details:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("Aggressive OS guesses:") {
                let parts = line.components(separatedBy: "(")
                if parts.count > 1 {
                    let accuracyStr = parts[1].components(separatedBy: "%")[0]
                    accuracy = Int(accuracyStr) ?? 0
                    osName = parts[0].replacingOccurrences(of: "Aggressive OS guesses:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return (osName, osFamily, accuracy)
    }

    // MARK: - Service Version Detection

    /// Detect service versions
    private func detectServiceVersions(_ ipAddress: String, ports: [Int]) async -> [Int: String] {
        guard !ports.isEmpty else { return [:] }

        let portList = ports.map { String($0) }.joined(separator: ",")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/nmap")
        process.arguments = ["-sV", "-p", portList, ipAddress]

        let pipe = Pipe()
        process.standardOutput = pipe

        var versions: [Int: String] = [:]

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                versions = parseServiceVersions(output)
            }
        } catch {
            print("❌ AdvancedPortScanner: Service version detection failed: \(error)")
        }

        return versions
    }

    /// Parse service version output
    private func parseServiceVersions(_ output: String) -> [Int: String] {
        var versions: [Int: String] = [:]
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 3 && components[0].contains("/") {
                if let port = Int(components[0].components(separatedBy: "/")[0]) {
                    let version = components[2...].joined(separator: " ")
                    versions[port] = version
                }
            }
        }

        return versions
    }

    // MARK: - NSE Script Scanning

    /// Run NSE (Nmap Scripting Engine) scripts
    private func runNSEScripts(_ ipAddress: String, ports: [Int]) async -> [NSEScriptResult] {
        guard !ports.isEmpty else { return [] }

        let portList = ports.map { String($0) }.joined(separator: ",")

        // Run common vulnerability detection scripts
        let scripts = [
            "vuln",           // Vulnerability detection
            "exploit",        // Exploit checking
            "auth",           // Authentication testing
            "discovery",      // Service discovery
            "safe",           // Safe scripts only
            "default"         // Default NSE scripts
        ]

        var allResults: [NSEScriptResult] = []

        for script in scripts {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/nmap")
            process.arguments = ["--script", script, "-p", portList, ipAddress]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let results = parseNSEOutput(output, script: script)
                    allResults.append(contentsOf: results)
                }
            } catch {
                print("❌ AdvancedPortScanner: NSE script \(script) failed: \(error)")
            }
        }

        return allResults
    }

    /// Parse NSE script output
    private func parseNSEOutput(_ output: String, script: String) -> [NSEScriptResult] {
        var results: [NSEScriptResult] = []
        let lines = output.components(separatedBy: "\n")

        var currentScript: String?
        var currentOutput: [String] = []

        for line in lines {
            if line.hasPrefix("|") {
                if line.contains(":") {
                    // New script result
                    if let scriptName = currentScript, !currentOutput.isEmpty {
                        let result = NSEScriptResult(
                            scriptName: scriptName,
                            category: script,
                            output: currentOutput.joined(separator: "\n"),
                            severity: determineSeverity(currentOutput)
                        )
                        results.append(result)
                    }

                    currentScript = line.components(separatedBy: ":")[0].replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces)
                    currentOutput = [line]
                } else {
                    currentOutput.append(line)
                }
            }
        }

        // Add last result
        if let scriptName = currentScript, !currentOutput.isEmpty {
            let result = NSEScriptResult(
                scriptName: scriptName,
                category: script,
                output: currentOutput.joined(separator: "\n"),
                severity: determineSeverity(currentOutput)
            )
            results.append(result)
        }

        return results
    }

    /// Determine severity from script output
    private func determineSeverity(_ output: [String]) -> NSEScriptResult.Severity {
        let text = output.joined(separator: " ").lowercased()

        if text.contains("critical") || text.contains("exploit") || text.contains("vulnerable") {
            return .high
        } else if text.contains("warning") || text.contains("weak") || text.contains("insecure") {
            return .medium
        } else {
            return .info
        }
    }

    // MARK: - Utility Methods

    /// Parse nmap port output
    private func parseNmapPorts(_ output: String) -> [Int] {
        var ports: [Int] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 && components[0].contains("/") && components[1] == "open" {
                if let port = Int(components[0].components(separatedBy: "/")[0]) {
                    ports.append(port)
                }
            }
        }

        return ports
    }

    /// Export scan results
    func exportResults(_ result: AdvancedScanResult) -> String {
        var report = "# Advanced Scan Report\n"
        report += "IP Address: \(result.ipAddress)\n"
        if let hostname = result.hostname {
            report += "Hostname: \(hostname)\n"
        }
        report += "Scan Profile: \(result.scanProfile.rawValue)\n"
        report += "Scan Date: \(DateFormatter.localizedString(from: result.completionDate ?? Date(), dateStyle: .medium, timeStyle: .short))\n\n"

        report += "## TCP Ports (\(result.tcpPorts.count))\n"
        report += result.tcpPorts.map { String($0) }.joined(separator: ", ")
        report += "\n\n"

        report += "## UDP Ports (\(result.udpPorts.count))\n"
        report += result.udpPorts.map { String($0) }.joined(separator: ", ")
        report += "\n\n"

        if let os = result.osDetection.osName {
            report += "## OS Detection\n"
            report += "OS: \(os)\n"
            if let family = result.osDetection.osFamily {
                report += "Family: \(family)\n"
            }
            report += "Accuracy: \(result.osDetection.accuracy)%\n\n"
        }

        if !result.serviceVersions.isEmpty {
            report += "## Service Versions\n"
            for (port, version) in result.serviceVersions.sorted(by: { $0.key < $1.key }) {
                report += "Port \(port): \(version)\n"
            }
            report += "\n"
        }

        if !result.scriptResults.isEmpty {
            report += "## NSE Script Results\n"
            for scriptResult in result.scriptResults {
                report += "### \(scriptResult.scriptName) [\(scriptResult.severity.rawValue)]\n"
                report += scriptResult.output
                report += "\n\n"
            }
        }

        return report
    }
}

// MARK: - Data Models

/// Advanced scan result
struct AdvancedScanResult: Identifiable {
    let id = UUID()
    let ipAddress: String
    let hostname: String?
    let scanProfile: AdvancedPortScanner.ScanProfile
    var tcpPorts: [Int] = []
    var udpPorts: [Int] = []
    var osDetection: OSDetectionResult = OSDetectionResult()
    var serviceVersions: [Int: String] = [:]
    var scriptResults: [NSEScriptResult] = []
    var completionDate: Date?
}

/// OS detection result
struct OSDetectionResult {
    var osName: String?
    var osFamily: String?
    var accuracy: Int = 0
}

/// NSE script result
struct NSEScriptResult: Identifiable {
    let id = UUID()
    let scriptName: String
    let category: String
    let output: String
    let severity: Severity

    enum Severity: String {
        case info = "Info"
        case medium = "Medium"
        case high = "High"

        var color: Color {
            switch self {
            case .info: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}
