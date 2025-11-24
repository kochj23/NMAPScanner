//
//  PacketCaptureManager.swift
//  NMAP Scanner - Packet Capture & Analysis
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import Foundation
import Network

/// Represents a captured network packet
struct CapturedPacket: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sourceIP: String
    let destinationIP: String
    let sourcePort: Int?
    let destinationPort: Int?
    let protocolType: PacketProtocol
    let size: Int
    let flags: [String]
    let payload: Data?
    let direction: PacketDirection

    enum PacketProtocol: String {
        case tcp = "TCP"
        case udp = "UDP"
        case icmp = "ICMP"
        case arp = "ARP"
        case dns = "DNS"
        case http = "HTTP"
        case https = "HTTPS"
        case unknown = "Unknown"
    }

    enum PacketDirection {
        case incoming
        case outgoing
        case local

        var symbol: String {
            switch self {
            case .incoming: return "↓"
            case .outgoing: return "↑"
            case .local: return "↔"
            }
        }
    }

    var summary: String {
        let portInfo: String
        if let sport = sourcePort, let dport = destinationPort {
            portInfo = ":\(sport) → :\(dport)"
        } else {
            portInfo = ""
        }

        return "\(direction.symbol) \(sourceIP)\(portInfo) → \(destinationIP) [\(protocolType.rawValue)] \(size)B"
    }

    var detailedDescription: String {
        var details = [String]()

        details.append("Time: \(formatTimestamp())")
        details.append("Protocol: \(protocolType.rawValue)")
        details.append("Source: \(sourceIP)\(sourcePort.map { ":\($0)" } ?? "")")
        details.append("Destination: \(destinationIP)\(destinationPort.map { ":\($0)" } ?? "")")
        details.append("Size: \(size) bytes")
        details.append("Direction: \(direction.symbol)")

        if !flags.isEmpty {
            details.append("Flags: \(flags.joined(separator: ", "))")
        }

        return details.joined(separator: "\n")
    }

    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

/// Packet capture filters
struct PacketFilter {
    var protocols: Set<CapturedPacket.PacketProtocol> = []
    var sourceIP: String?
    var destinationIP: String?
    var port: Int?
    var direction: CapturedPacket.PacketDirection?

    func matches(_ packet: CapturedPacket) -> Bool {
        if !protocols.isEmpty && !protocols.contains(packet.protocolType) {
            return false
        }

        if let sourceIP = sourceIP, !packet.sourceIP.contains(sourceIP) {
            return false
        }

        if let destinationIP = destinationIP, !packet.destinationIP.contains(destinationIP) {
            return false
        }

        if let port = port {
            if packet.sourcePort != port && packet.destinationPort != port {
                return false
            }
        }

        if let direction = direction, packet.direction != direction {
            return false
        }

        return true
    }

    var isActive: Bool {
        !protocols.isEmpty || sourceIP != nil || destinationIP != nil || port != nil || direction != nil
    }
}

/// Packet capture statistics
struct CaptureStatistics {
    var totalPackets: Int = 0
    var droppedPackets: Int = 0
    var bytesProcessed: Int64 = 0
    var protocolCounts: [CapturedPacket.PacketProtocol: Int] = [:]
    var captureStartTime: Date?

    var captureRuntime: TimeInterval? {
        guard let start = captureStartTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    var packetsPerSecond: Double {
        guard let runtime = captureRuntime, runtime > 0 else { return 0 }
        return Double(totalPackets) / runtime
    }
}

/// Manages packet capture and analysis
@MainActor
class PacketCaptureManager: ObservableObject {
    @Published var isCapturing = false
    @Published var capturedPackets: [CapturedPacket] = []
    @Published var statistics = CaptureStatistics()
    @Published var filter = PacketFilter()

    private let maxPackets = 1000 // Ring buffer size
    private var captureQueue: DispatchQueue?
    private var activeConnections: [UUID: NWConnection] = [:]

    /// Start packet capture
    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        statistics.captureStartTime = Date()

        captureQueue = DispatchQueue(label: "PacketCapture", qos: .userInitiated)

        // Start monitoring common protocols
        startProtocolMonitoring()
    }

    /// Stop packet capture
    func stopCapture() {
        guard isCapturing else { return }
        isCapturing = false

        // Cancel all connections
        activeConnections.values.forEach { $0.cancel() }
        activeConnections.removeAll()

        captureQueue = nil
    }

    /// Start monitoring specific protocols
    private func startProtocolMonitoring() {
        // Monitor DNS queries (UDP 53)
        startUDPListener(port: 53, protocolType: .dns)

        // Monitor HTTP (TCP 80)
        startTCPListener(port: 80, protocolType: .http)

        // Monitor HTTPS (TCP 443)
        startTCPListener(port: 443, protocolType: .https)

        // Note: Full packet capture requires privileged access not available in tvOS sandbox
        // This implementation simulates packet capture by monitoring connection attempts
    }

    /// Start TCP listener for a specific port
    private func startTCPListener(port: UInt16, protocolType: CapturedPacket.PacketProtocol) {
        let listener = try? NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.handleNewConnection(connection, protocolType: protocolType)
            }
        }

        listener?.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("Listener failed: \(error)")
            }
        }

        guard let queue = captureQueue else { return }
        listener?.start(queue: queue)
    }

    /// Start UDP listener for a specific port
    private func startUDPListener(port: UInt16, protocolType: CapturedPacket.PacketProtocol) {
        let listener = try? NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.handleNewConnection(connection, protocolType: protocolType)
            }
        }

        guard let queue = captureQueue else { return }
        listener?.start(queue: queue)
    }

    /// Handle new connection (simulated packet)
    private func handleNewConnection(_ connection: NWConnection, protocolType: CapturedPacket.PacketProtocol) {
        let connectionId = UUID()
        activeConnections[connectionId] = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleConnectionState(state, connection: connection, protocolType: protocolType, id: connectionId)
            }
        }

        connection.start(queue: captureQueue ?? .main)
    }

    /// Handle connection state changes
    private func handleConnectionState(_ state: NWConnection.State, connection: NWConnection, protocolType: CapturedPacket.PacketProtocol, id: UUID) {
        switch state {
        case .ready:
            capturePacketFromConnection(connection, protocolType: protocolType)

        case .cancelled, .failed:
            activeConnections.removeValue(forKey: id)

        default:
            break
        }
    }

    /// Capture packet data from connection
    private func capturePacketFromConnection(_ connection: NWConnection, protocolType: CapturedPacket.PacketProtocol) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self = self, let data = data else { return }

                let packet = self.parsePacket(data: data, protocolType: protocolType, connection: connection)
                self.addPacket(packet)
            }
        }
    }

    /// Parse packet data
    private func parsePacket(data: Data, protocolType: CapturedPacket.PacketProtocol, connection: NWConnection) -> CapturedPacket {
        // Extract endpoint information
        let sourceIP = extractIP(from: connection.currentPath?.localEndpoint) ?? "0.0.0.0"
        let destinationIP = extractIP(from: connection.currentPath?.remoteEndpoint) ?? "0.0.0.0"
        let sourcePort = extractPort(from: connection.currentPath?.localEndpoint)
        let destinationPort = extractPort(from: connection.currentPath?.remoteEndpoint)

        // Determine direction
        let direction: CapturedPacket.PacketDirection = .incoming // Simplified

        // Extract flags (TCP flags if applicable)
        var flags: [String] = []
        if protocolType == .tcp {
            flags = extractTCPFlags(from: data)
        }

        return CapturedPacket(
            timestamp: Date(),
            sourceIP: sourceIP,
            destinationIP: destinationIP,
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            protocolType: protocolType,
            size: data.count,
            flags: flags,
            payload: data.count <= 128 ? data : data.prefix(128),
            direction: direction
        )
    }

    /// Simulate packet capture for testing (since we can't capture real packets without root)
    func simulatePacketCapture(host: String, port: Int) {
        let protocols: [CapturedPacket.PacketProtocol] = [.tcp, .udp, .http, .https, .dns]
        let randomProtocol = protocols.randomElement() ?? .tcp

        let packet = CapturedPacket(
            timestamp: Date(),
            sourceIP: "192.168.1.\(Int.random(in: 1...254))",
            destinationIP: host,
            sourcePort: Int.random(in: 49152...65535),
            destinationPort: port,
            protocolType: randomProtocol,
            size: Int.random(in: 64...1500),
            flags: randomProtocol == .tcp ? ["SYN"] : [],
            payload: nil,
            direction: .outgoing
        )

        addPacket(packet)
    }

    /// Add packet to capture buffer
    private func addPacket(_ packet: CapturedPacket) {
        guard filter.matches(packet) else {
            statistics.droppedPackets += 1
            return
        }

        capturedPackets.insert(packet, at: 0)

        // Ring buffer: keep only most recent packets
        if capturedPackets.count > maxPackets {
            capturedPackets.removeLast()
        }

        // Update statistics
        statistics.totalPackets += 1
        statistics.bytesProcessed += Int64(packet.size)
        statistics.protocolCounts[packet.protocolType, default: 0] += 1
    }

    /// Clear captured packets
    func clearCapture() {
        capturedPackets.removeAll()
        statistics = CaptureStatistics()
        statistics.captureStartTime = Date()
    }

    /// Export captured packets
    func exportCapture() -> String {
        var output = "# Packet Capture Export\n"
        output += "# Captured: \(statistics.totalPackets) packets\n"
        output += "# Total bytes: \(statistics.bytesProcessed)\n\n"

        for packet in capturedPackets.reversed() {
            output += "\(packet.summary)\n"
            output += "\(packet.detailedDescription)\n\n"
        }

        return output
    }

    // MARK: - Helper Methods

    private func extractIP(from endpoint: NWEndpoint?) -> String? {
        guard case .hostPort(let host, _)? = endpoint else { return nil }
        return "\(host)"
    }

    private func extractPort(from endpoint: NWEndpoint?) -> Int? {
        guard case .hostPort(_, let port)? = endpoint else { return nil }
        return Int(port.rawValue)
    }

    private func extractTCPFlags(from data: Data) -> [String] {
        // Simplified TCP flag extraction
        // In a real implementation, this would parse the TCP header
        guard data.count >= 14 else { return [] }

        var flags: [String] = []
        // This is a placeholder - real TCP flag parsing would require proper header parsing
        flags.append("SYN")
        return flags
    }
}
