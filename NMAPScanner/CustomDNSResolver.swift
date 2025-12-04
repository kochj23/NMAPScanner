//
//  CustomDNSResolver.swift
//  NMAP Plus Security Scanner - Custom DNS Resolution
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation
import Network

/// Custom DNS resolver supporting multiple DNS servers
@MainActor
class CustomDNSResolver: ObservableObject {
    static let shared = CustomDNSResolver()

    @Published var dnsServers: [String] = []
    @Published var useCustomDNS = false

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    /// Configure custom DNS servers
    func configure(servers: [String], enabled: Bool) {
        self.dnsServers = servers.filter { !$0.isEmpty }
        self.useCustomDNS = enabled

        saveConfiguration()
    }

    /// Get default DNS servers from system
    func getSystemDNSServers() -> [String] {
        var servers: [String] = []

        // Try reading from /etc/resolv.conf
        if let resolvConf = try? String(contentsOfFile: "/etc/resolv.conf") {
            let lines = resolvConf.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("nameserver ") {
                    let server = line.replacingOccurrences(of: "nameserver ", with: "").trimmingCharacters(in: .whitespaces)
                    servers.append(server)
                }
            }
        }

        return servers
    }

    // MARK: - DNS Resolution

    /// Resolve hostname for IP address using custom or system DNS
    func resolveHostname(for ipAddress: String) async -> String? {
        if useCustomDNS && !dnsServers.isEmpty {
            // Try custom DNS servers
            for dnsServer in dnsServers {
                if let hostname = await queryDNS(ipAddress: ipAddress, dnsServer: dnsServer) {
                    print("✅ DNS: Resolved \(ipAddress) → \(hostname) via \(dnsServer)")
                    return hostname
                }
            }
        }

        // Fall back to system DNS
        return await systemResolveHostname(for: ipAddress)
    }

    /// Query a specific DNS server for PTR record (reverse DNS)
    private func queryDNS(ipAddress: String, dnsServer: String) async -> String? {
        // Convert IP to reverse DNS format (e.g., 192.168.1.1 -> 1.1.168.192.in-addr.arpa)
        let _ = reverseIPAddress(ipAddress)

        // Use dig command for custom DNS query
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
        task.arguments = [
            "@\(dnsServer)",
            "-x",
            ipAddress,
            "+short",
            "+time=2",
            "+tries=1"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                return nil
            }

            // Remove trailing dot from hostname
            let hostname = output.hasSuffix(".") ? String(output.dropLast()) : output

            return hostname

        } catch {
            print("❌ DNS: Failed to query \(dnsServer) for \(ipAddress) - \(error)")
            return nil
        }
    }

    /// System DNS resolution (fallback)
    private func systemResolveHostname(for ipAddress: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo()
                hints.ai_family = AF_INET  // IPv4
                hints.ai_socktype = SOCK_STREAM
                hints.ai_flags = AI_NUMERICHOST

                var result: UnsafeMutablePointer<addrinfo>?

                // Convert IP string to address
                guard getaddrinfo(ipAddress, nil, &hints, &result) == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                defer {
                    if let result = result {
                        freeaddrinfo(result)
                    }
                }

                // Get hostname from address
                if let addr = result?.pointee.ai_addr {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                    if getnameinfo(addr, socklen_t(result!.pointee.ai_addrlen),
                                  &hostBuffer, socklen_t(hostBuffer.count),
                                  nil, 0, NI_NAMEREQD) == 0 {
                        let hostname = String(cString: hostBuffer)
                        continuation.resume(returning: hostname)
                        return
                    }
                }

                continuation.resume(returning: nil)
            }
        }
    }

    /// Convert IP address to reverse DNS format
    private func reverseIPAddress(_ ip: String) -> String {
        let octets = ip.split(separator: ".").map(String.init)
        return octets.reversed().joined(separator: ".") + ".in-addr.arpa"
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        UserDefaults.standard.set(dnsServers, forKey: "customDNSServers")
        UserDefaults.standard.set(useCustomDNS, forKey: "useCustomDNS")
    }

    private func loadConfiguration() {
        if let servers = UserDefaults.standard.array(forKey: "customDNSServers") as? [String] {
            self.dnsServers = servers
        }
        self.useCustomDNS = UserDefaults.standard.bool(forKey: "useCustomDNS")
    }
}
