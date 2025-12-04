//
//  ComprehensiveDiscovery.swift
//  NMAP Plus Security Scanner - Comprehensive Device Discovery
//
//  Created by Jordan Koch & Claude Code on 2025-12-01.
//
//  Ensures ALL devices on the network are discovered using multiple methods
//

import Foundation
import SwiftUI

/// Comprehensive network discovery using multiple detection methods
@MainActor
class ComprehensiveDiscovery: ObservableObject {
    static let shared = ComprehensiveDiscovery()

    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var discoveredIPs: Set<String> = []

    private let simpleScanner = SimpleNetworkScanner()

    private init() {}

    /// Perform comprehensive discovery using ALL available methods
    /// This ensures maximum device detection
    func discoverAllDevices(subnet: String = "192.168.1") async -> [String] {
        print("🔍 ComprehensiveDiscovery: ========== STARTING COMPREHENSIVE DISCOVERY ==========")
        print("🔍 Target subnet: \(subnet).0/24")

        isScanning = true
        progress = 0
        status = "Starting comprehensive discovery..."
        discoveredIPs = []

        // PHASE 1: ARP Table Scan (Fast - 0-20%)
        print("🔍 Phase 1/4: Scanning ARP table...")
        status = "Phase 1/4: Reading ARP table (fast)"
        progress = 0.05

        let arpIPs = await scanARPTable()
        discoveredIPs.formUnion(arpIPs)
        progress = 0.20
        print("🔍 Phase 1 complete: Found \(arpIPs.count) devices via ARP")

        // PHASE 2: Known Device List (Instant - 20-25%)
        print("🔍 Phase 2/4: Checking known devices...")
        status = "Phase 2/4: Pinging known devices"
        progress = 0.22

        let knownIPs = await pingKnownDevices(subnet: subnet)
        discoveredIPs.formUnion(knownIPs)
        progress = 0.25
        print("🔍 Phase 2 complete: Verified \(knownIPs.count) known devices")

        // PHASE 3: Targeted Ping of Common IPs (Medium - 25-50%)
        print("🔍 Phase 3/4: Pinging common device IPs...")
        status = "Phase 3/4: Scanning common device addresses"
        progress = 0.30

        let commonIPs = await pingCommonIPs(subnet: subnet)
        discoveredIPs.formUnion(commonIPs)
        progress = 0.50
        print("🔍 Phase 3 complete: Found \(commonIPs.count) devices at common IPs")

        // PHASE 4: Full Subnet Ping Sweep (Slow but thorough - 50-100%)
        print("🔍 Phase 4/4: Full subnet ping sweep...")
        status = "Phase 4/4: Scanning entire subnet (this may take a few minutes)"
        progress = 0.52

        let sweepIPs = await pingSweepSubnet(subnet: subnet)
        discoveredIPs.formUnion(sweepIPs)
        progress = 1.0
        print("🔍 Phase 4 complete: Found \(sweepIPs.count) additional devices")

        let sortedIPs = Array(discoveredIPs).sorted { compareIPs($0, $1) }

        status = "Discovery complete - \(sortedIPs.count) devices found"
        isScanning = false

        print("🔍 ========== COMPREHENSIVE DISCOVERY COMPLETE ==========")
        print("🔍 Total unique devices: \(sortedIPs.count)")
        print("🔍 Device list: \(sortedIPs)")

        return sortedIPs
    }

    // MARK: - Discovery Methods

    /// Phase 1: Scan ARP table for recently active devices
    private func scanARPTable() async -> Set<String> {
        await simpleScanner.scanARP()
        return Set(simpleScanner.discoveredIPs)
    }

    /// Phase 2: Ping known device list with fast timeout
    private func pingKnownDevices(subnet: String) async -> Set<String> {
        // Your complete list of 46 known devices
        let knownDeviceIPs = [
            33, 161, 28, 78, 138, 50, 80, 193, 102, 122, 109, 155, 52, 1, 123, 54,
            9, 21, 22, 36, 51, 53, 57, 61, 63, 66, 67, 76, 81, 83, 98,
            118, 119, 128, 134, 135, 136, 141, 148, 154, 156, 160, 164, 179, 199, 200
        ]

        var foundIPs = Set<String>()

        for (index, lastOctet) in knownDeviceIPs.enumerated() {
            let ip = "\(subnet).\(lastOctet)"

            // Fast ping with 0.3 second timeout
            if await pingIP(ip, timeout: 300) {
                foundIPs.insert(ip)
            }

            // Update progress (20% → 25%)
            progress = 0.20 + (Double(index + 1) / Double(knownDeviceIPs.count) * 0.05)
        }

        print("🔍 Known devices: Pinged \(knownDeviceIPs.count) known IPs, found \(foundIPs.count) online")
        return foundIPs
    }

    /// Phase 3: Ping common device IP ranges
    private func pingCommonIPs(subnet: String) async -> Set<String> {
        var foundIPs = Set<String>()

        // Common ranges for network devices
        let commonRanges: [ClosedRange<Int>] = [
            1...10,      // Gateways, routers, network infrastructure
            20...100,    // Common DHCP range
            100...200,   // Extended DHCP range
            200...254    // Static IPs and high ranges
        ]

        var allCommonIPs: [Int] = []
        for range in commonRanges {
            allCommonIPs.append(contentsOf: range)
        }

        let totalToScan = allCommonIPs.count

        for (index, lastOctet) in allCommonIPs.enumerated() {
            let ip = "\(subnet).\(lastOctet)"

            // Medium-speed ping with 0.4 second timeout
            if await pingIP(ip, timeout: 400) {
                foundIPs.insert(ip)
            }

            // Update progress (25% → 50%)
            if index % 5 == 0 {  // Update every 5 IPs to avoid too frequent updates
                progress = 0.25 + (Double(index + 1) / Double(totalToScan) * 0.25)
                status = "Phase 3/4: Scanning \(subnet).\(lastOctet)... (\(foundIPs.count) found)"
            }
        }

        print("🔍 Common IPs: Scanned \(totalToScan) common IPs, found \(foundIPs.count) online")
        return foundIPs
    }

    /// Phase 4: Full subnet ping sweep (1-254)
    private func pingSweepSubnet(subnet: String) async -> Set<String> {
        var foundIPs = Set<String>()

        for i in 1...254 {
            let ip = "\(subnet).\(i)"

            // Standard ping with 0.5 second timeout
            if await pingIP(ip, timeout: 500) {
                foundIPs.insert(ip)
            }

            // Update progress (50% → 100%)
            progress = 0.50 + (Double(i) / 254.0 * 0.50)

            if i % 10 == 0 {
                status = "Phase 4/4: Scanning \(subnet).\(i)... (\(foundIPs.count) total found)"
            }
        }

        print("🔍 Full sweep: Scanned all 254 IPs, found \(foundIPs.count) online")
        return foundIPs
    }

    // MARK: - Helper Functions

    /// Ping a single IP address with specified timeout (in milliseconds)
    private func pingIP(_ ip: String, timeout: Int) async -> Bool {
        let result = await executeCommand("/sbin/ping", arguments: ["-c", "1", "-W", "\(timeout)", ip])
        return result.contains("1 packets received") || result.contains("1 received")
    }

    /// Execute shell command
    private func executeCommand(_ command: String, arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
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
                continuation.resume(returning: "")
            }
        }
    }

    /// Compare IP addresses numerically
    private func compareIPs(_ ip1: String, _ ip2: String) -> Bool {
        let parts1 = ip1.split(separator: ".").compactMap { Int($0) }
        let parts2 = ip2.split(separator: ".").compactMap { Int($0) }

        guard parts1.count == 4 && parts2.count == 4 else { return ip1 < ip2 }

        for i in 0..<4 {
            if parts1[i] != parts2[i] {
                return parts1[i] < parts2[i]
            }
        }

        return false
    }
}
