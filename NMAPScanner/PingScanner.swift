//
//  PingScanner.swift
//  NMAP Plus Security Scanner - ICMP Ping Scanner
//
//  Created by Jordan Koch on 2025-11-23.
//

import Foundation
import Network

// MARK: - Ping Scanner

/// Fast network scanner using ICMP echo requests (real ping) for host discovery
/// Uses Apple's Network framework with UDP ICMP implementation for tvOS compatibility
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

        // Process hosts sequentially - no batching needed for Class C network
        // tvOS has very strict networking limits, so we avoid concurrent connections entirely
        for (_, host) in hosts.enumerated() {
            let isAlive = await pingHost(host)

            hostsScanned += 1
            progress = Double(hostsScanned) / Double(hosts.count)

            if isAlive {
                hostsAlive.insert(host)
                status = "Found: \(host) (\(hostsAlive.count) alive, \(hostsScanned)/\(hosts.count))"
            } else {
                // Update status every 10 hosts to avoid too frequent UI updates
                if hostsScanned % 10 == 0 {
                    status = "Scanning \(subnet).0/24... (\(hostsScanned)/\(hosts.count), \(hostsAlive.count) alive)"
                }
            }
        }

        status = "Ping scan complete - \(hostsAlive.count) hosts alive"
        isScanning = false

        return hostsAlive
    }

    /// Ping a single host using ICMP echo request
    /// Returns true if host responds to ping
    private func pingHost(_ host: String) async -> Bool {
        // Use actual ICMP ping with 1 second timeout
        // Much more reliable than TCP connection attempts
        return await sendICMPPing(to: host, timeout: 1.0)
    }

    /// Send ICMP echo request using BSD sockets
    private func sendICMPPing(to host: String, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            var resolved = false

            // Resolve hostname to IP address
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_DGRAM

            var result: UnsafeMutablePointer<addrinfo>?
            defer {
                if let result = result {
                    freeaddrinfo(result)
                }
            }

            guard getaddrinfo(host, nil, &hints, &result) == 0,
                  let addr = result?.pointee.ai_addr else {
                continuation.resume(returning: false)
                return
            }

            // Create ICMP socket
            let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
            guard sock >= 0 else {
                continuation.resume(returning: false)
                return
            }

            defer { close(sock) }

            // Set socket timeout
            var tv = timeval()
            tv.tv_sec = Int(timeout)
            tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

            // Create ICMP echo request packet
            var packet = [UInt8](repeating: 0, count: 64)
            packet[0] = 8  // ICMP Echo Request
            packet[1] = 0  // Code 0

            // Identifier and sequence number
            let identifier = UInt16(getpid() & 0xFFFF)
            packet[4] = UInt8(identifier >> 8)
            packet[5] = UInt8(identifier & 0xFF)
            packet[6] = 0  // Sequence number
            packet[7] = 1

            // Calculate checksum
            var sum: UInt32 = 0
            for i in stride(from: 0, to: packet.count, by: 2) {
                sum += UInt32(packet[i]) << 8 | UInt32(packet[i+1])
            }
            while sum >> 16 != 0 {
                sum = (sum & 0xFFFF) + (sum >> 16)
            }
            let checksum = ~UInt16(sum & 0xFFFF)
            packet[2] = UInt8(checksum >> 8)
            packet[3] = UInt8(checksum & 0xFF)

            // Send ping
            let sent = packet.withUnsafeBytes { packetPtr in
                sendto(sock, packetPtr.baseAddress, packet.count, 0,
                       addr, socklen_t(result!.pointee.ai_addrlen))
            }

            guard sent > 0 else {
                continuation.resume(returning: false)
                return
            }

            // Wait for reply
            var buffer = [UInt8](repeating: 0, count: 1024)
            var fromAddr = sockaddr_storage()
            var fromLen = socklen_t(MemoryLayout<sockaddr_storage>.size)

            let bufferCount = buffer.count
            let received = withUnsafeMutableBytes(of: &fromAddr) { addrPtr in
                buffer.withUnsafeMutableBytes { bufferPtr in
                    recvfrom(sock, bufferPtr.baseAddress, bufferCount, 0,
                             addrPtr.baseAddress?.assumingMemoryBound(to: sockaddr.self),
                             &fromLen)
                }
            }

            // Check if we received a reply (ICMP Echo Reply = type 0)
            if received > 20 && buffer[20] == 0 {
                continuation.resume(returning: true)
            } else {
                continuation.resume(returning: false)
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
        print("🔌 PortScanner.scanPorts: Starting scan of \(host) with \(ports.count) ports")
        var openPorts: [PortInfo] = []

        for (index, port) in ports.enumerated() {
            progress = Double(index + 1) / Double(ports.count)
            status = "Scanning \(host):\(port)..."

            if await testPort(host: host, port: port) {
                print("🔌 PortScanner.scanPorts: OPEN PORT \(port) on \(host)")
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

        print("🔌 PortScanner.scanPorts: Completed scan of \(host) - found \(openPorts.count) open ports")
        return openPorts
    }

    /// Test if a specific port is open
    private func testPort(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
                print("🔌 PortScanner.testPort: Invalid port number \(port)")
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
                    print("🔌 PortScanner.testPort: Port \(port) on \(host) is OPEN")
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed(let error):
                    print("🔌 PortScanner.testPort: Port \(port) on \(host) FAILED: \(error.localizedDescription)")
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                case .cancelled:
                    if !hasResumed {
                        print("🔌 PortScanner.testPort: Port \(port) on \(host) CANCELLED")
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // 0.5 second timeout (more reliable than 0.3s)
            queue.asyncAfter(deadline: .now() + 0.5) {
                lock.lock()
                defer { lock.unlock() }

                if !hasResumed {
                    print("🔌 PortScanner.testPort: Port \(port) on \(host) TIMEOUT")
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

    /// Standard scan - COMPREHENSIVE common services (120+ ports)
    /// Includes SSH, HTTP, databases, smart home devices, network equipment, and legacy services
    static let standard: [Int] = {
        var ports: [Int] = []

        // === CORE NETWORK SERVICES (10 ports) ===
        ports.append(contentsOf: [
            20,    // FTP Data
            21,    // FTP Control
            22,    // SSH
            23,    // Telnet
            25,    // SMTP (Email)
            53,    // DNS
            67,    // DHCP Server
            68,    // DHCP Client
            69,    // TFTP
            110,   // POP3
        ])

        // === WEB SERVICES (12 ports) ===
        ports.append(contentsOf: [
            80,    // HTTP
            443,   // HTTPS
            8000,  // HTTP Alternate
            8008,  // HTTP Alternate
            8080,  // HTTP Proxy/Alternate
            8081,  // HTTP Alternate
            8082,  // HTTP Alternate
            8443,  // HTTPS Alternate
            8888,  // HTTP Alternate
            9000,  // HTTP Alternate
            9090,  // HTTP Alternate
            9443,  // HTTPS Alternate
        ])

        // === WINDOWS/SMB SERVICES (8 ports) ===
        ports.append(contentsOf: [
            135,   // MS RPC
            137,   // NetBIOS Name Service
            138,   // NetBIOS Datagram
            139,   // NetBIOS Session (SMB)
            445,   // SMB over TCP
            3389,  // Remote Desktop (RDP)
            5985,  // WinRM HTTP
            5986,  // WinRM HTTPS
        ])

        // === EMAIL SERVICES (6 ports) ===
        ports.append(contentsOf: [
            143,   // IMAP
            465,   // SMTPS
            587,   // SMTP Submission
            993,   // IMAPS
            995,   // POP3S
            2525,  // SMTP Alternate
        ])

        // === DATABASE SERVICES (10 ports) ===
        ports.append(contentsOf: [
            1433,  // MS SQL Server
            1434,  // MS SQL Monitor
            3306,  // MySQL/MariaDB
            5432,  // PostgreSQL
            5984,  // CouchDB
            6379,  // Redis
            7000,  // Cassandra
            7001,  // Cassandra SSL
            9042,  // Cassandra CQL
            27017, // MongoDB
        ])

        // === HOMEKIT / APPLE SERVICES (8 ports) ===
        ports.append(contentsOf: [
            5353,  // mDNS/Bonjour
            62078, // HomeKit Accessory Protocol (HAP)
            3689,  // iTunes/DAAP
            5000,  // AirPlay
            7000,  // AirPlay
            49152, // AirPlay (dynamic range start)
            49153, // AirPlay
            49154, // AirPlay
        ])

        // === GOOGLE HOME / CHROMECAST (6 ports) ===
        ports.append(contentsOf: [
            8008,  // Chromecast
            8009,  // Chromecast
            8443,  // Google Home
            9000,  // Google Cast
            10001, // Google Home
            55443, // Google Home
        ])

        // === AMAZON ALEXA / ECHO (4 ports) ===
        ports.append(contentsOf: [
            4070,  // Amazon Echo
            33434, // Amazon Echo Discovery
            55442, // Amazon Alexa
            55443, // Amazon Alexa
        ])

        // === UNIFI / UBIQUITI DEVICES (12 ports) ===
        ports.append(contentsOf: [
            10001, // UniFi Discovery
            8080,  // UniFi Controller (HTTP)
            8443,  // UniFi Controller (HTTPS)
            8880,  // UniFi Controller
            8843,  // UniFi Controller
            6789,  // UniFi Mobile Speed Test
            3478,  // UniFi STUN
            7004,  // UniFi Protect RTSP
            7441,  // UniFi Protect RTSPS
            7442,  // UniFi Protect HTTP
            7443,  // UniFi Protect HTTPS
            7080,  // UniFi Protect HTTP
        ])

        // === NETWORK CAMERAS / RTSP (8 ports) ===
        ports.append(contentsOf: [
            554,   // RTSP
            555,   // RTSP Alternate
            8554,  // RTSP Alternate
            1935,  // RTMP (streaming)
            6667,  // Camera/IRC
            37777, // Dahua DVR
            34567, // Hikvision
            9010,  // Camera
        ])

        // === NETWORK MANAGEMENT (10 ports) ===
        ports.append(contentsOf: [
            161,   // SNMP
            162,   // SNMP Trap
            514,   // Syslog
            515,   // LPR/LPD (Printing)
            631,   // IPP (Printing)
            9100,  // HP JetDirect
            10000, // Webmin
            19999, // Netdata
            32400, // Plex
            51827, // HomeKit pairing
        ])

        // === VNC / REMOTE ACCESS (6 ports) ===
        ports.append(contentsOf: [
            5800,  // VNC HTTP
            5900,  // VNC
            5901,  // VNC
            5902,  // VNC
            5903,  // VNC
            22222, // SSH Alternate
        ])

        // === GAMING / MEDIA (8 ports) ===
        ports.append(contentsOf: [
            27015, // Steam/Source
            27016, // Steam
            3074,  // Xbox Live
            9001,  // Media Server
            32400, // Plex Media Server
            32469, // Plex DLNA
            50000, // Media
            50001, // Media
        ])

        // === LEGACY / BACKDOOR DETECTION (12 ports) ===
        ports.append(contentsOf: [
            31337, // Back Orifice
            12345, // NetBus
            12346, // NetBus
            1243,  // BackDoor
            6668,  // IRC
            6669,  // IRC
            27374, // SubSeven
            2001,  // Trojan
            1999,  // BackDoor
            30100, // NetSphere
            30101, // NetSphere
            30102, // NetSphere
        ])

        // === MQTT / IoT (4 ports) ===
        ports.append(contentsOf: [
            1883,  // MQTT
            8883,  // MQTT over SSL
            1884,  // MQTT alternate
            8884,  // MQTT alternate
        ])

        return Array(Set(ports)).sorted() // Remove duplicates and sort
    }()

    /// Full scan - comprehensive port list (200+ ports)
    static let full: [Int] = {
        var ports = standard

        // Add additional uncommon but useful ports
        ports.append(contentsOf: [
            119,   // NNTP
            123,   // NTP
            389,   // LDAP
            636,   // LDAPS
            1521,  // Oracle DB
            2049,  // NFS
            3690,  // SVN
            5222,  // XMPP Client
            5223,  // XMPP Client SSL
            5269,  // XMPP Server
            6000,  // X11
            6001,  // X11
            8086,  // InfluxDB
            9200,  // Elasticsearch
            9300,  // Elasticsearch
            11211, // Memcached
        ])

        return Array(Set(ports)).sorted() // Remove duplicates and sort
    }()

    /// Backdoor-only scan - known malware ports
    static let backdoorsOnly: [Int] = [
        31337, 12345, 12346, 1243, 6667, 6668, 6669, 27374,
        2001, 1999, 30100, 30101, 30102, 5000, 5001, 5002
    ]

    /// HomeKit/Apple device-specific ports (OPTIMIZED - only 6 ports)
    /// Much faster scanning for HomeKit discovery without sacrificing device detection
    static let homeKit: [Int] = [
        80,     // HTTP (HomeKit Accessory Protocol - HAP)
        443,    // HTTPS (Secure HAP)
        5353,   // mDNS (Bonjour discovery)
        8080,   // Alternate HTTP (common for HAP)
        8443,   // Alternate HTTPS
        62078   // HAP (HomeKit Accessory Protocol default port)
    ]
}
