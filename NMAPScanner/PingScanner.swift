//
//  PingScanner.swift
//  NMAP Plus Security Scanner - Fast ICMP Ping Scanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import Foundation
import Network

// MARK: - Ping Scanner

/// Fast network scanner using TCP SYN handshake (simulated ping) for host discovery
/// Note: True ICMP ping requires root privileges, so we use TCP connection to port 80/443 as a proxy
@MainActor
class PingScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var hostsScanned = 0
    @Published var hostsAlive: Set<String> = []

    /// Perform fast ping scan of entire subnet
    /// Returns set of IP addresses that responded
    func pingSubnet(_ subnet: String) async -> Set<String> {
        isScanning = true
        progress = 0
        status = "Starting ping scan..."
        hostsScanned = 0
        hostsAlive = []

        // Generate all hosts in /24 subnet (1-254)
        let hosts = (1...254).map { "\(subnet).\($0)" }

        status = "Pinging \(hosts.count) hosts in \(subnet).0/24..."

        // Ping in smaller batches for tvOS stability (reduced from 50 to 10)
        // This prevents overwhelming the network stack with too many concurrent connections
        let batchSize = 10
        for batchStart in stride(from: 0, to: hosts.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, hosts.count)
            let batch = Array(hosts[batchStart..<batchEnd])

            // Ping all hosts in batch concurrently
            await withTaskGroup(of: (String, Bool).self) { group in
                for host in batch {
                    group.addTask {
                        let isAlive = await self.pingHost(host)
                        return (host, isAlive)
                    }
                }

                // Collect results
                for await (host, isAlive) in group {
                    hostsScanned += 1
                    progress = Double(hostsScanned) / Double(hosts.count)

                    if isAlive {
                        hostsAlive.insert(host)
                        status = "Found: \(host) (\(hostsAlive.count) alive)"
                    } else {
                        // Update status even for failed hosts so UI shows progress
                        status = "Scanning \(subnet).0/24... (\(hostsScanned)/\(hosts.count))"
                    }
                }
            }

            // No delay needed with smaller batches
        }

        status = "Ping scan complete - \(hostsAlive.count) hosts alive"
        isScanning = false

        return hostsAlive
    }

    /// Ping a single host by attempting TCP connection to common ports
    /// Returns true if host responds on any port
    private func pingHost(_ host: String) async -> Bool {
        // For tvOS stability, only try port 80 (HTTP) with short timeout
        // This reduces connection attempts from 3 per host to 1
        // Priority: HTTP (80) - most common and fastest to respond
        if await testConnection(host: host, port: 80, timeout: 0.3) {
            return true
        }

        // If HTTP fails, try HTTPS (443) as fallback
        if await testConnection(host: host, port: 443, timeout: 0.3) {
            return true
        }

        return false
    }

    /// Test TCP connection to a host:port with timeout
    private func testConnection(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: portNumber,
                using: .tcp
            )

            let queue = DispatchQueue(label: "ping-\(host)-\(port)")
            var hasResumed = false
            let lock = NSLock()

            connection.stateUpdateHandler = { state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Timeout
            queue.asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

// MARK: - Port Scanner

/// Detailed port scanner for discovered hosts
@MainActor
class PortScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var currentHost = ""

    /// Scan specific ports on a host
    func scanPorts(host: String, ports: [Int]) async -> [PortInfo] {
        var openPorts: [PortInfo] = []

        for (index, port) in ports.enumerated() {
            progress = Double(index + 1) / Double(ports.count)
            status = "Scanning \(host):\(port)..."

            if await testPort(host: host, port: port) {
                let portInfo = PortInfo(
                    port: port,
                    service: serviceForPort(port),
                    version: nil,
                    state: .open,
                    protocolType: "TCP",
                    banner: nil
                )
                openPorts.append(portInfo)
            }

            // Small delay to avoid overwhelming the target
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        }

        return openPorts
    }

    /// Test if a specific port is open
    private func testPort(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: portNumber,
                using: .tcp
            )

            let queue = DispatchQueue(label: "port-scan-\(host)-\(port)")
            var hasResumed = false
            let lock = NSLock()

            connection.stateUpdateHandler = { state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // 1 second timeout
            queue.asyncAfter(deadline: .now() + 1.0) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Map port number to service name
    private func serviceForPort(_ port: Int) -> String {
        let services: [Int: String] = [
            21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
            80: "HTTP", 110: "POP3", 139: "NetBIOS", 143: "IMAP", 443: "HTTPS",
            445: "SMB", 3306: "MySQL", 3389: "RDP", 5432: "PostgreSQL",
            5900: "VNC", 8080: "HTTP-Alt",
            // Backdoor ports
            31337: "Back Orifice", 12345: "NetBus", 12346: "NetBus",
            1243: "SubSeven", 6667: "IRC", 6668: "IRC", 6669: "IRC",
            27374: "SubSeven", 2001: "Trojan.Latinus", 1999: "BackDoor",
            30100: "NetSphere", 30101: "NetSphere", 30102: "NetSphere",
            5000: "Back Door Setup", 5001: "Sockets de Troie", 5002: "Sockets de Troie"
        ]
        return services[port] ?? "Unknown"
    }
}

// MARK: - Common Port Sets

struct CommonPorts {
    /// Quick scan - most common ports (20 ports)
    static let quick: [Int] = [
        21, 22, 23, 25, 80, 110, 143, 443,
        3306, 3389, 5432, 5900, 8080, 8443,
        // Critical backdoor ports
        31337, 12345, 6667
    ]

    /// Standard scan - common services and backdoors (40 ports)
    static let standard: [Int] = [
        21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445,
        3306, 3389, 5432, 5900, 8080, 8443,
        // Backdoor ports
        31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374,
        2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002,
        // Additional services
        1433, 1434, 27017, 27018, 27019, 6379, 9042, 7000, 7001, 8086
    ]

    /// Full scan - comprehensive port list (100+ ports)
    static let full: [Int] = {
        var ports = standard

        // Add more common ports
        ports.append(contentsOf: [
            20, 119, 123, 135, 137, 138, 161, 162, 389, 636,
            1521, 2049, 3690, 5222, 5223, 5269, 5353, 6000, 6001,
            8000, 8008, 8081, 8082, 8888, 9000, 9001, 9090, 9091,
            9200, 9300, 11211, 27015, 27016, 50000, 50001
        ])

        return ports.sorted()
    }()

    /// Backdoor-only scan - known malware ports
    static let backdoorsOnly: [Int] = [
        31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374,
        2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002
    ]
}
