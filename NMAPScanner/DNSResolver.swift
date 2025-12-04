//
//  DNSResolver.swift
//  NMAP Scanner - DNS Resolution Utilities
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation

/// DNS resolution utilities for reverse DNS lookups
@MainActor
class DNSResolver: ObservableObject {
    static let shared = DNSResolver()

    @Published var resolvedNames: [String: String] = [:]
    private var resolutionTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    /// Resolve IP address to hostname
    func resolveIP(_ ipAddress: String) async -> String? {
        // Check cache first
        if let cached = resolvedNames[ipAddress] {
            return cached
        }

        // Perform reverse DNS lookup
        if let hostname = await performReverseDNS(ipAddress) {
            resolvedNames[ipAddress] = hostname
            return hostname
        }

        return nil
    }

    /// Resolve multiple IP addresses in parallel
    func resolveIPs(_ ipAddresses: [String]) async {
        await withTaskGroup(of: (String, String?).self) { group in
            for ip in ipAddresses where resolvedNames[ip] == nil {
                group.addTask {
                    let hostname = await self.performReverseDNS(ip)
                    return (ip, hostname)
                }
            }

            for await (ip, hostname) in group {
                if let hostname = hostname {
                    resolvedNames[ip] = hostname
                }
            }
        }
    }

    /// Perform reverse DNS lookup using host command
    private func performReverseDNS(_ ipAddress: String) async -> String? {
        return await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/host")
            process.arguments = [ipAddress]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()

                // Set timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let hostname = parseHostOutput(output)
                    continuation.resume(returning: hostname)
                    return
                }
            } catch {
                print("❌ DNS Resolver: Error executing host command: \(error)")
            }

            continuation.resume(returning: nil)
        }
    }

    /// Parse host command output
    private func parseHostOutput(_ output: String) -> String? {
        // Output format: "1.0.168.192.in-addr.arpa domain name pointer hostname.local."
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            if line.contains("domain name pointer") {
                let parts = line.components(separatedBy: "domain name pointer")
                if parts.count > 1 {
                    var hostname = parts[1].trimmingCharacters(in: .whitespaces)

                    // Remove trailing dot
                    if hostname.hasSuffix(".") {
                        hostname = String(hostname.dropLast())
                    }

                    return hostname
                }
            }
        }

        return nil
    }

    /// Get hostname for IP (returns cached value if available)
    func getHostname(for ipAddress: String) -> String? {
        return resolvedNames[ipAddress]
    }

    /// Clear cache
    func clearCache() {
        resolvedNames.removeAll()
    }
}

// MARK: - Extension for Device Display

extension EnhancedDevice {
    /// Get display name with DNS if available
    @MainActor
    func displayNameWithDNS(resolver: DNSResolver = .shared) -> String {
        if let hostname = hostname {
            return hostname
        } else if let dnsName = resolver.getHostname(for: ipAddress) {
            return dnsName
        } else {
            return ipAddress
        }
    }

    /// Get full display string with both IP and DNS
    @MainActor
    func fullDisplayString(resolver: DNSResolver = .shared) -> String {
        if let hostname = hostname {
            return "\(hostname) (\(ipAddress))"
        } else if let dnsName = resolver.getHostname(for: ipAddress) {
            return "\(dnsName) (\(ipAddress))"
        } else {
            return ipAddress
        }
    }
}
