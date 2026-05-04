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
        #if DEBUG
        print("SimpleNetworkScanner: ========== STARTING ARP SCAN ==========")
        print("SimpleNetworkScanner: Setting isScanning = true")
        #endif
        isScanning = true

        #if DEBUG
        print("SimpleNetworkScanner: Setting status message")
        #endif
        status = "Reading ARP table..."
        progress = 0
        #if DEBUG
        print("SimpleNetworkScanner: Status set, progress = 0")
        #endif

        // Start watchdog
        #if DEBUG
        print("SimpleNetworkScanner: Starting watchdog...")
        #endif
        ScanWatchdog.shared.startMonitoring(operation: "ARP Scan")
        #if DEBUG
        print("SimpleNetworkScanner: Watchdog started")
        #endif

        // Execute arp command
        #if DEBUG
        print("SimpleNetworkScanner: About to execute /usr/sbin/arp -a")
        #endif
        let arpOutput = await executeCommand("/usr/sbin/arp", arguments: ["-a"])
        #if DEBUG
        print("SimpleNetworkScanner: ARP command completed, output length = \(arpOutput.count) chars")
        #endif

        #if DEBUG
        print("SimpleNetworkScanner: Updating watchdog progress...")
        #endif
        ScanWatchdog.shared.updateProgress()
        #if DEBUG
        print("SimpleNetworkScanner: Watchdog updated")
        #endif

        // Parse ARP output
        #if DEBUG
        print("SimpleNetworkScanner: About to parse ARP output...")
        #endif
        discoveredIPs = parseARPOutput(arpOutput)
        #if DEBUG
        print("SimpleNetworkScanner: Parsing complete, found \(discoveredIPs.count) IPs: \(discoveredIPs)")
        #endif

        #if DEBUG
        print("SimpleNetworkScanner: Updating UI status...")
        #endif
        status = "Found \(discoveredIPs.count) devices in ARP table"
        progress = 1.0
        isScanning = false
        #if DEBUG
        print("SimpleNetworkScanner: UI updated, isScanning = false")
        #endif

        // Stop watchdog
        #if DEBUG
        print("SimpleNetworkScanner: Stopping watchdog...")
        #endif
        ScanWatchdog.shared.stopMonitoring()
        #if DEBUG
        print("SimpleNetworkScanner: Watchdog stopped")
        print("SimpleNetworkScanner: ========== ARP SCAN COMPLETE ==========")
        #endif
    }

    /// Scan using ping sweep with concurrent TaskGroup (max 20 in-flight)
    func scanPingSweep(subnet: String) async {
        // Validate subnet
        do {
            try IPValidator.validateSubnet(subnet)
        } catch {
            SecureLogger.log("Invalid subnet: \(subnet) - \(error)", level: .error)
            status = "Invalid subnet format"
            return
        }

        SecureLogger.log("Starting ping sweep of \(subnet).0/24", level: .info)
        SecurityAuditLog.log(event: .scanStarted, details: "Ping sweep of \(subnet).0/24", level: .info)

        isScanning = true
        status = "Starting ping sweep..."
        progress = 0
        discoveredIPs = []

        // Start watchdog
        ScanWatchdog.shared.startMonitoring(operation: "Ping Sweep")

        let maxConcurrency = 20
        var completed = 0

        // Use TaskGroup with bounded concurrency for parallel pings
        let foundIPs = await withTaskGroup(of: String?.self) { group in
            var results: [String] = []
            var pending = Array(1...254)[...]
            var inFlight = 0

            // Seed initial batch
            while inFlight < maxConcurrency, let i = pending.popFirst() {
                let ip = "\(subnet).\(i)"
                inFlight += 1
                group.addTask {
                    let result = await self.executeCommand("/sbin/ping", arguments: ["-c", "1", "-W", "200", ip])
                    return result.contains("1 packets received") ? ip : nil
                }
            }

            // Process results and keep concurrency pool full
            for await result in group {
                inFlight -= 1
                completed += 1

                if let ip = result {
                    results.append(ip)
                }

                // Update UI progress on main actor
                self.progress = Double(completed) / 254.0
                self.status = "Scanning \(subnet)... \(completed)/254 (\(results.count) found)"

                if completed % 10 == 0 {
                    ScanWatchdog.shared.updateProgress()
                }

                // Launch next ping if hosts remain
                if let i = pending.popFirst() {
                    let ip = "\(subnet).\(i)"
                    inFlight += 1
                    group.addTask {
                        let result = await self.executeCommand("/sbin/ping", arguments: ["-c", "1", "-W", "200", ip])
                        return result.contains("1 packets received") ? ip : nil
                    }
                }
            }

            return results
        }

        discoveredIPs = foundIPs.sorted { compareIPs($0, $1) }
        status = "Ping sweep complete - \(discoveredIPs.count) devices found"
        progress = 1.0
        isScanning = false

        // Stop watchdog
        ScanWatchdog.shared.stopMonitoring()

        #if DEBUG
        print("SimpleNetworkScanner: Ping sweep complete - \(discoveredIPs.count) devices")
        #endif
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
                    #if DEBUG
                    print("SimpleNetworkScanner: Error executing \(command): \(error)")
                    #endif
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
