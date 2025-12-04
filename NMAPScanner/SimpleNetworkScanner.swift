//
//  SimpleNetworkScanner.swift
//  NMAP Plus Security Scanner - Simple, Reliable Network Scanner
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation
import Network

/// Simple, reliable network scanner using system commands
/// Much more stable than complex NWBrowser/NWConnection approaches
@MainActor
class SimpleNetworkScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var discoveredIPs: [String] = []

    /// Scan using ARP table (instant results!)
    func scanARP() async {
        print("📡 SimpleNetworkScanner: ========== STARTING ARP SCAN ==========")
        print("📡 SimpleNetworkScanner: Setting isScanning = true")
        isScanning = true

        print("📡 SimpleNetworkScanner: Setting status message")
        status = "Reading ARP table..."
        progress = 0
        print("📡 SimpleNetworkScanner: Status set, progress = 0")

        // Start watchdog
        print("📡 SimpleNetworkScanner: Starting watchdog...")
        ScanWatchdog.shared.startMonitoring(operation: "ARP Scan")
        print("📡 SimpleNetworkScanner: Watchdog started")

        // Execute arp command
        print("📡 SimpleNetworkScanner: About to execute /usr/sbin/arp -a")
        let arpOutput = await executeCommand("/usr/sbin/arp", arguments: ["-a"])
        print("📡 SimpleNetworkScanner: ARP command completed, output length = \(arpOutput.count) chars")

        print("📡 SimpleNetworkScanner: Updating watchdog progress...")
        ScanWatchdog.shared.updateProgress()
        print("📡 SimpleNetworkScanner: Watchdog updated")

        // Parse ARP output
        print("📡 SimpleNetworkScanner: About to parse ARP output...")
        discoveredIPs = parseARPOutput(arpOutput)
        print("📡 SimpleNetworkScanner: Parsing complete, found \(discoveredIPs.count) IPs: \(discoveredIPs)")

        print("📡 SimpleNetworkScanner: Updating UI status...")
        status = "Found \(discoveredIPs.count) devices in ARP table"
        progress = 1.0
        isScanning = false
        print("📡 SimpleNetworkScanner: UI updated, isScanning = false")

        // Stop watchdog
        print("📡 SimpleNetworkScanner: Stopping watchdog...")
        ScanWatchdog.shared.stopMonitoring()
        print("📡 SimpleNetworkScanner: Watchdog stopped")

        print("📡 SimpleNetworkScanner: ========== ARP SCAN COMPLETE ==========")
    }

    /// Scan using ping sweep (reliable, sequential)
    func scanPingSweep(subnet: String) async {
        print("📡 SimpleNetworkScanner: Starting ping sweep of \(subnet).0/24...")
        isScanning = true
        status = "Starting ping sweep..."
        progress = 0
        discoveredIPs = []

        // Start watchdog
        ScanWatchdog.shared.startMonitoring(operation: "Ping Sweep")

        // Ping each host sequentially with short timeout
        for i in 1...254 {
            let ip = "\(subnet).\(i)"

            // Ping with 0.2 second timeout
            let result = await executeCommand("/sbin/ping", arguments: ["-c", "1", "-W", "200", ip])

            if result.contains("1 packets received") {
                discoveredIPs.append(ip)
                print("📡 Found: \(ip)")
            }

            progress = Double(i) / 254.0
            status = "Scanning \(subnet).\(i)... (\(discoveredIPs.count) found)"

            // Update watchdog every 10 hosts
            if i % 10 == 0 {
                ScanWatchdog.shared.updateProgress()
            }
        }

        status = "Ping sweep complete - \(discoveredIPs.count) devices found"
        progress = 1.0
        isScanning = false

        // Stop watchdog
        ScanWatchdog.shared.stopMonitoring()

        print("📡 SimpleNetworkScanner: Ping sweep complete - \(discoveredIPs.count) devices")
    }

    /// Execute system command and return output (runs on background thread to avoid blocking main thread)
    private func executeCommand(_ command: String, arguments: [String]) async -> String {
        // CRITICAL: Run on background thread since @MainActor class would otherwise block UI
        return await Task.detached {
            await withCheckedContinuation { continuation in
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    print("📡 Error executing \(command): \(error)")
                    continuation.resume(returning: "")
                }
            }
        }.value
    }

    /// Parse ARP command output
    private func parseARPOutput(_ output: String) -> [String] {
        var ips: [String] = []

        // Parse lines like: "? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]"
        let lines = output.split(separator: "\n")

        for line in lines {
            // Extract IP address between parentheses
            if let startIndex = line.firstIndex(of: "("),
               let endIndex = line.firstIndex(of: ")"),
               startIndex < endIndex {
                let ipString = String(line[line.index(after: startIndex)..<endIndex])

                // Validate it's an IP address
                if isValidIP(ipString) {
                    ips.append(ipString)
                }
            }
        }

        return ips.sorted { compareIPs($0, $1) }
    }

    /// Check if string is valid IP address
    private func isValidIP(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let num = Int(part), num >= 0 && num <= 255 else {
                return false
            }
        }

        return true
    }

    /// Compare IPs numerically
    private func compareIPs(_ ip1: String, _ ip2: String) -> Bool {
        let parts1 = ip1.split(separator: ".").compactMap { Int($0) }
        let parts2 = ip2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<4 {
            if parts1[i] != parts2[i] {
                return parts1[i] < parts2[i]
            }
        }

        return false
    }
}
