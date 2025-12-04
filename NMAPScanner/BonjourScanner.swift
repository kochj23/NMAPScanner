//
//  BonjourScanner.swift
//  NMAP Plus Security Scanner - Bonjour/mDNS Network Discovery
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import Network

// MARK: - Device Metadata from mDNS TXT Records

/// Metadata extracted from HomeKit/Bonjour TXT records
struct BonjourDeviceMetadata {
    let ipAddress: String
    let services: Set<String>
    let model: String?           // TXT: md=
    let protocolVersion: String? // TXT: pv=
    let categoryID: String?      // TXT: ci=
    let statusFlags: String?     // TXT: sf=
    let featureFlags: String?    // TXT: ff=
    let deviceID: String?        // TXT: id=
    let configNumber: String?    // TXT: c#=
    let stateNumber: String?     // TXT: s#=
    let setupHash: String?       // TXT: sh=

    var displayName: String {
        return model ?? ipAddress
    }

    var category: String {
        guard let catID = categoryID, let id = Int(catID) else {
            return "Unknown"
        }

        // HomeKit category IDs from HAP specification
        switch id {
        case 1: return "Other"
        case 2: return "Bridge"
        case 3: return "Fan"
        case 4: return "Garage Door Opener"
        case 5: return "Lightbulb"
        case 6: return "Door Lock"
        case 7: return "Outlet"
        case 8: return "Switch"
        case 9: return "Thermostat"
        case 10: return "Sensor"
        case 11: return "Security System"
        case 12: return "Door"
        case 13: return "Window"
        case 14: return "Window Covering"
        case 15: return "Programmable Switch"
        case 16: return "Range Extender"
        case 17: return "IP Camera"
        case 18: return "Video Doorbell"
        case 19: return "Air Purifier"
        case 20: return "Heater"
        case 21: return "Air Conditioner"
        case 22: return "Humidifier"
        case 23: return "Dehumidifier"
        case 28: return "Sprinkler"
        case 29: return "Faucet"
        case 30: return "Shower System"
        case 31: return "Television"
        case 32: return "Speaker"
        default: return "Accessory"
        }
    }
}

// MARK: - Bonjour Scanner

/// Network discovery using Bonjour/mDNS service discovery
/// Much more reliable on tvOS than TCP/ICMP scanning
@MainActor
class BonjourScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var discoveredDevices: [String: Set<String>] = [:] // IP -> Set of service types
    @Published var deviceMetadata: [String: BonjourDeviceMetadata] = [:] // IP -> Metadata

    private var browsers: [NWBrowser] = []
    private let browserQueue = DispatchQueue(label: "com.nmapscanner.bonjour")
    private var timeoutObserver: NSObjectProtocol?

    /// Common service types to discover on the network
    private let serviceTypes = [
        // Apple Devices
        "_airplay._tcp",        // AirPlay devices
        "_raop._tcp",          // Remote Audio Output Protocol (AirPlay audio)
        "_homekit._tcp",       // HomeKit devices
        "_hap._tcp",           // HomeKit Accessory Protocol
        "_companion-link._tcp", // Apple Companion Link
        "_sleep-proxy._udp",   // Sleep Proxy
        "_dacp._tcp",          // Digital Audio Control Protocol
        "_touch-able._tcp",    // iTunes Remote

        // Google Devices
        "_googlecast._tcp",    // Google Cast / Chromecast devices
        "_googlezone._tcp",    // Google Home devices
        "_google-home._tcp",   // Google Home speakers

        // Amazon Devices
        "_amzn-wplay._tcp",    // Amazon Echo devices
        "_amzn-alexa._tcp",    // Amazon Alexa
        "_amazon-echo._tcp",   // Amazon Echo

        // UniFi / Ubiquiti Devices
        "_ubnt-discover._udp", // UniFi Discovery Protocol (all devices)
        "_ubnt-camera._tcp",   // UniFi Protect cameras
        "_ubnt-protect._tcp",  // UniFi Protect NVR
        "_ubnt-ap._tcp",       // UniFi Access Points
        "_ubiquiti._tcp",      // Ubiquiti devices general
        "_unifi._tcp",         // UniFi Network Application
        "_rtsp._tcp",          // RTSP streams (cameras)

        // Network Services
        "_http._tcp",          // HTTP servers
        "_smb._tcp",           // SMB/CIFS file sharing
        "_afpovertcp._tcp",    // AFP file sharing
        "_ssh._tcp",           // SSH servers
        "_telnet._tcp",        // Telnet servers
        "_ftp._tcp",           // FTP servers
        "_printer._tcp",       // Network printers
        "_ipp._tcp",           // Internet Printing Protocol
        "_device-info._tcp",   // Device information
        "_workstation._tcp",   // Windows workstations

        // Smart Home / IoT
        "_spotify-connect._tcp", // Spotify Connect
        "_sonos._tcp",         // Sonos speakers
        "_mqtt._tcp",          // MQTT brokers
        "_iot._tcp"            // IoT devices
    ]

    /// Start Bonjour/mDNS discovery scan with detailed progress
    func startScan() async {
        print("🔍 BonjourScanner: Starting scan...")
        await MainActor.run {
            isScanning = true
            progress = 0
            status = "Starting Bonjour/mDNS discovery..."
            discoveredDevices = [:]

            // Start watchdog monitoring
            ScanWatchdog.shared.startMonitoring(operation: "Bonjour Discovery")

            // Listen for timeout notifications
            timeoutObserver = NotificationCenter.default.addObserver(
                forName: .scanWatchdogTimeout,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    print("🚨 BonjourScanner: Received timeout notification - forcing stop")
                    await self?.forceStop()
                }
            }
        }

        // Create browsers for each service type with progress
        await MainActor.run {
            status = "Initializing \(serviceTypes.count) service type scanners..."
            progress = 0.1
        }
        print("🔍 BonjourScanner: Creating browsers for \(serviceTypes.count) service types")
        await createBrowsers()
        await MainActor.run {
            ScanWatchdog.shared.updateProgress()
            progress = 0.2
        }

        // Wait for discovery to complete (10 seconds) with progress updates
        await MainActor.run {
            status = "Scanning for HomeKit, Google Home, Alexa devices..."
        }
        print("🔍 BonjourScanner: Waiting 10 seconds for discovery...")

        // OPTIMIZED: Smart early termination when discovery stabilizes
        var previousDeviceCount = 0
        var stableCount = 0
        let maxWaitSeconds = 10
        let earlyExitThreshold = 3 // Exit if no new devices for 3 seconds

        print("🔍 BonjourScanner: Starting smart discovery (max \(maxWaitSeconds)s, early exit after \(earlyExitThreshold)s stability)")

        for i in 1...maxWaitSeconds {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            await MainActor.run {
                let currentDeviceCount = discoveredDevices.count
                let currentProgress = 0.2 + (Double(i) / Double(maxWaitSeconds) * 0.7) // 20-90%
                progress = currentProgress
                status = "Discovering devices... (\(currentDeviceCount) found, \(i)/\(maxWaitSeconds)s)"
                ScanWatchdog.shared.updateProgress()
            }

            // Check for stability (no new devices discovered)
            let currentCount = await MainActor.run { discoveredDevices.count }
            if currentCount == previousDeviceCount {
                stableCount += 1
                if stableCount >= earlyExitThreshold {
                    print("🔍 BonjourScanner: ✅ EARLY EXIT - No new devices for \(earlyExitThreshold)s (found \(currentCount) devices in \(i)s)")
                    await MainActor.run {
                        status = "Discovery stabilized - \(currentCount) devices found in \(i)s"
                    }
                    break
                }
            } else {
                print("🔍 BonjourScanner: 📱 New devices found (\(previousDeviceCount) → \(currentCount))")
                previousDeviceCount = currentCount
                stableCount = 0
            }
        }

        // Log completion
        let finalCount = await MainActor.run { discoveredDevices.count }
        print("🔍 BonjourScanner: Discovery complete - \(finalCount) devices found")

        // Stop all browsers
        await MainActor.run {
            status = "Finalizing discovery..."
            progress = 0.95
        }
        print("🔍 BonjourScanner: Stopping browsers...")
        await stopBrowsers()

        await MainActor.run {
            let deviceCount = discoveredDevices.count
            let serviceCount = discoveredDevices.values.reduce(0) { $0 + $1.count }
            print("🔍 BonjourScanner: Discovery complete - \(deviceCount) devices, \(serviceCount) services found")
            status = "Discovery complete - \(deviceCount) devices found"
            progress = 1.0
            isScanning = false

            // Stop watchdog
            ScanWatchdog.shared.stopMonitoring()

            // Remove timeout observer
            if let observer = timeoutObserver {
                NotificationCenter.default.removeObserver(observer)
                timeoutObserver = nil
            }
        }
    }

    /// Force stop scanning (called by watchdog)
    private func forceStop() async {
        print("🚨 BonjourScanner: Force stopping all operations")
        await stopBrowsers()

        isScanning = false
        status = "Scan terminated (timeout)"
        progress = 1.0

        if let observer = timeoutObserver {
            NotificationCenter.default.removeObserver(observer)
            timeoutObserver = nil
        }
    }

    /// Create NWBrowser instances for all service types
    private func createBrowsers() async {
        await MainActor.run {
            browsers = []
        }

        for (index, serviceType) in serviceTypes.enumerated() {
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)

            browser.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    switch state {
                    case .ready:
                        self.progress = Double(index + 1) / Double(self.serviceTypes.count)
                        self.status = "Scanning for \(serviceType)..."
                    case .failed(let error):
                        print("Browser failed for \(serviceType): \(error)")
                    default:
                        break
                    }
                }
            }

            browser.browseResultsChangedHandler = { [weak self] results, changes in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    print("🔍 BonjourScanner: Found \(results.count) results for \(serviceType)")
                    for result in results {
                        if case .service(let name, let type, let domain, let interface) = result.endpoint {
                            // Resolve endpoint to get IP address and TXT records
                            print("🔍 BonjourScanner: Resolving endpoint for \(name)")
                            self.resolveEndpoint(result.endpoint, serviceType: type, serviceName: name)
                        }
                    }
                }
            }

            browser.start(queue: browserQueue)

            await MainActor.run {
                browsers.append(browser)
            }
        }
    }

    /// Resolve a Bonjour endpoint to extract IP address
    private func resolveEndpoint(_ endpoint: NWEndpoint, serviceType: String, serviceName: String) {
        print("🔍 BonjourScanner: Creating connection for resolution...")
        // Create a connection to resolve the endpoint
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    print("🔍 BonjourScanner: Connection ready, extracting IP...")
                    // Extract IP address from endpoint
                    if case .hostPort(let host, _) = connection.currentPath?.remoteEndpoint {
                        let ipAddress: String?
                        switch host {
                        case .ipv4(let addr):
                            ipAddress = self.ipv4ToString(addr)
                            print("🔍 BonjourScanner: Found IPv4: \(ipAddress ?? "nil")")
                        case .ipv6(let addr):
                            ipAddress = self.ipv6ToString(addr)
                            print("🔍 BonjourScanner: Found IPv6: \(ipAddress ?? "nil")")
                        case .name(let hostname, _):
                            // Try to resolve hostname
                            print("🔍 BonjourScanner: Resolving hostname: \(hostname)")
                            ipAddress = self.resolveHostname(hostname)
                            print("🔍 BonjourScanner: Hostname resolved to: \(ipAddress ?? "nil")")
                        @unknown default:
                            ipAddress = nil
                        }

                        if let ip = ipAddress {
                            if self.discoveredDevices[ip] == nil {
                                self.discoveredDevices[ip] = []
                            }
                            self.discoveredDevices[ip]?.insert(serviceType)

                            // Parse TXT records for HomeKit devices
                            if serviceType.contains("_hap._tcp") {
                                print("🔍 BonjourScanner: Parsing TXT records for HomeKit device: \(serviceName)")
                                self.parseTXTRecords(for: serviceName, serviceType: serviceType, ipAddress: ip)
                            }

                            print("🔍 BonjourScanner: Added device \(ip) with service \(serviceType). Total: \(self.discoveredDevices.count)")
                            self.status = "Found device: \(ip) (\(self.discoveredDevices.count) total)"

                            // Update watchdog - we're making progress
                            ScanWatchdog.shared.updateProgress()
                        }
                    }

                    connection.cancel()

                case .failed(let error):
                    print("🔍 BonjourScanner: Connection failed: \(error)")
                    connection.cancel()

                case .cancelled:
                    print("🔍 BonjourScanner: Connection cancelled")
                    connection.cancel()

                default:
                    break
                }
            }
        }

        connection.start(queue: browserQueue)

        // Cancel connection after short timeout (reduced to 1 second to prevent hanging)
        browserQueue.asyncAfter(deadline: .now() + 1.0) {
            print("🔍 BonjourScanner: Connection timeout, cancelling...")
            connection.cancel()
        }
    }

    /// Stop all browsers
    private func stopBrowsers() async {
        await MainActor.run {
            for browser in browsers {
                browser.cancel()
            }
            browsers = []
        }
    }

    /// Convert IPv4 address to string
    private func ipv4ToString(_ addr: IPv4Address) -> String {
        return addr.debugDescription
    }

    /// Convert IPv6 address to string
    private func ipv6ToString(_ addr: IPv6Address) -> String {
        return addr.debugDescription
    }

    /// Resolve hostname to IP address
    private func resolveHostname(_ hostname: String) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        defer {
            if let result = result {
                freeaddrinfo(result)
            }
        }

        guard getaddrinfo(hostname, nil, &hints, &result) == 0,
              let addr = result?.pointee.ai_addr else {
            return nil
        }

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(addr, socklen_t(result!.pointee.ai_addrlen),
                         &hostBuffer, socklen_t(hostBuffer.count),
                         nil, 0, NI_NUMERICHOST) == 0 else {
            return nil
        }

        return String(cString: hostBuffer)
    }

    /// Get discovered IP addresses
    func getDiscoveredIPs() -> Set<String> {
        return Set(discoveredDevices.keys)
    }

    /// Get services for a specific IP
    func getServices(for ip: String) -> Set<String> {
        return discoveredDevices[ip] ?? []
    }

    /// Get metadata for a specific IP
    func getMetadata(for ip: String) -> BonjourDeviceMetadata? {
        return deviceMetadata[ip]
    }

    /// Parse TXT records for HomeKit device using dns-sd
    private func parseTXTRecords(for serviceName: String, serviceType: String, ipAddress: String) {
        // Use Process to run dns-sd command to get TXT records
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        process.arguments = ["-L", serviceName, serviceType, "local."]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Set a timeout
        var timedOut = false
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if process.isRunning {
                process.terminate()
                timedOut = true
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            timer.invalidate()

            guard !timedOut else {
                print("🔍 BonjourScanner: TXT record lookup timed out for \(serviceName)")
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return
            }

            print("🔍 BonjourScanner: TXT record output for \(serviceName):\n\(output)")

            // Parse TXT records from output
            let txtRecords = self.extractTXTRecords(from: output)
            print("🔍 BonjourScanner: Parsed TXT records: \(txtRecords)")

            // Create metadata
            let metadata = BonjourDeviceMetadata(
                ipAddress: ipAddress,
                services: self.discoveredDevices[ipAddress] ?? [],
                model: txtRecords["md"],
                protocolVersion: txtRecords["pv"],
                categoryID: txtRecords["ci"],
                statusFlags: txtRecords["sf"],
                featureFlags: txtRecords["ff"],
                deviceID: txtRecords["id"],
                configNumber: txtRecords["c#"],
                stateNumber: txtRecords["s#"],
                setupHash: txtRecords["sh"]
            )

            Task { @MainActor in
                self.deviceMetadata[ipAddress] = metadata
                print("🔍 BonjourScanner: Stored metadata for \(ipAddress): \(metadata.displayName) (\(metadata.category))")
            }

        } catch {
            print("🔍 BonjourScanner: Error running dns-sd: \(error)")
        }
    }

    /// Extract TXT records from dns-sd output
    private func extractTXTRecords(from output: String) -> [String: String] {
        var records: [String: String] = [:]

        // Look for lines containing TXT record data
        // Format: key=value or just text
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // TXT records are typically on lines after "TXT" keyword
            if line.contains("=") {
                // Split on first = only
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)

                    // Clean up key (remove quotes, spaces, etc)
                    let cleanKey = key.replacingOccurrences(of: "\"", with: "")
                                      .trimmingCharacters(in: .whitespaces)

                    // Clean up value
                    let cleanValue = value.replacingOccurrences(of: "\"", with: "")
                                          .trimmingCharacters(in: .whitespaces)

                    if !cleanKey.isEmpty {
                        records[cleanKey] = cleanValue
                    }
                }
            }
        }

        return records
    }
}
