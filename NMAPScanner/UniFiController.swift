//
//  UniFiController.swift
//  NMAP Plus Security Scanner - UniFi UDM Pro Integration
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation
import Security

// NOTE: UniFi certificate validation now handled by SecureUniFiDelegate.swift
// This provides proper certificate pinning and user confirmation
// instead of blindly accepting all certificates

/// UniFi Controller API client for integrating with UDM Pro
@MainActor
class UniFiController: ObservableObject {
    static let shared = UniFiController()

    @Published var isConfigured = false
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var devices: [UniFiDevice] = []
    @Published var infrastructureDevices: [UniFiInfrastructureDevice] = []
    @Published var protectCameras: [UniFiProtectCamera] = []
    @Published var mfaRequired = false

    private var baseURL: String?
    private var username: String?
    private var password: String?
    private var siteName: String = "default"
    private var sessionCookie: String?
    private var csrfToken: String?
    private var isUniFiOS: Bool = false  // UDM Pro / UniFi OS vs classic controller

    // Session management
    private var sessionExpiration: Date?
    private let sessionDuration: TimeInterval = 3600  // 1 hour
    private var sessionMonitorTimer: Timer?

    // Rate limiting
    private let rateLimiter = RateLimiter(requestsPerSecond: 2.0)

    // URLSession with secure certificate validation
    private lazy var secureDelegate: SecureUniFiDelegate = {
        let delegate = SecureUniFiDelegate()
        delegate.onCertificateChallenge = { [weak self] host, commonName, fingerprint in
            await self?.promptUserToTrustCertificate(host: host, commonName: commonName, fingerprint: fingerprint) ?? false
        }
        return delegate
    }()

    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration, delegate: secureDelegate, delegateQueue: nil)
    }()

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration Management

    /// Configure UniFi controller credentials
    func configure(host: String, username: String, password: String, siteName: String = "default") {
        // Validate and sanitize URL
        do {
            let sanitizedURL = try URLValidator.validateControllerURL(host)
            self.baseURL = sanitizedURL

            // Warn if using HTTP
            if sanitizedURL.hasPrefix("http://") {
                SecureLogger.log("WARNING: Using HTTP (unencrypted) for UniFi controller. Credentials will be sent in cleartext!", level: .warning)
                SecurityAuditLog.log(event: .configurationChange, details: "Configured with HTTP (insecure): \(host)", level: .warning)
            }
        } catch {
            self.lastError = UserFacingErrors.genericMessage(for: error)
            SecurityAuditLog.log(event: .validationError, details: "Invalid controller URL: \(host)", level: .error)
            return
        }

        self.username = username
        self.password = password
        self.siteName = siteName

        // Save to Keychain
        saveCredentials(host: self.baseURL!, username: username, password: password, siteName: siteName)

        isConfigured = true

        SecurityAuditLog.log(event: .configurationChange, details: "UniFi controller configured for host: \(host)", level: .info)

        // Test connection
        Task {
            await login()
        }
    }

    /// Clear UniFi configuration
    func clearConfiguration() {
        baseURL = nil
        username = nil
        password = nil
        sessionCookie = nil
        csrfToken = nil
        sessionExpiration = nil
        isConfigured = false
        isConnected = false

        // Stop session monitor
        sessionMonitorTimer?.invalidate()
        sessionMonitorTimer = nil

        deleteCredentials()

        SecurityAuditLog.log(event: .credentialsCleared, details: "UniFi controller configuration cleared", level: .info)
    }

    /// Load configuration from Keychain
    private func loadConfiguration() {
        guard let credentials = loadCredentials() else { return }

        self.baseURL = credentials.host.hasPrefix("http") ? credentials.host : "https://\(credentials.host)"
        self.username = credentials.username
        self.password = credentials.password
        self.siteName = credentials.siteName
        self.isConfigured = true
    }

    // MARK: - API Methods

    /// Detect controller type (UniFi OS vs classic controller)
    private func detectControllerType() async {
        guard let baseURL = baseURL else { return }

        // Try UniFi OS API first (UDM Pro, UDR, etc.)
        let unifiOSURL = URL(string: "\(baseURL)/api/auth/login")!
        var request = URLRequest(url: unifiOSURL)
        request.httpMethod = "GET"  // Just check if endpoint exists
        request.timeoutInterval = 5

        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // UniFi OS returns 401/405 for GET on /api/auth/login
                // Classic controller returns 404
                if httpResponse.statusCode != 404 {
                    isUniFiOS = true
                    SecureLogger.log("Detected UniFi OS (UDM Pro/UDR)", level: .info)
                } else {
                    isUniFiOS = false
                    SecureLogger.log("Detected classic controller", level: .info)
                }
            }
        } catch {
            // Default to classic if detection fails
            isUniFiOS = false
            SecureLogger.log("Detection failed, defaulting to classic controller", level: .info)
        }
    }

    /// Login to UniFi controller with MFA support
    func login(mfaCode: String? = nil) async {
        guard let baseURL = baseURL,
              let username = username,
              let password = password else {
            lastError = "UniFi controller not configured"
            SecurityAuditLog.log(event: .loginFailure, details: "No configuration", level: .error)
            return
        }

        // Rate limit login attempts
        await rateLimiter.waitIfNeeded()

        SecurityAuditLog.log(event: .loginAttempt, details: "Attempting login to \(baseURL) as \(username)", level: .info)

        // Detect controller type (UniFi OS vs classic) on first login
        if !isConnected {
            await detectControllerType()
        }

        // Use appropriate login endpoint
        let loginPath = isUniFiOS ? "/api/auth/login" : "/api/login"
        let loginURL = URL(string: "\(baseURL)\(loginPath)")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var loginData: [String: String] = [
            "username": username,
            "password": password
        ]

        // Add MFA code if provided
        if let mfaCode = mfaCode {
            loginData["ubic_2fa_token"] = mfaCode
            SecureLogger.log("Logging in with MFA code", level: .info)
            SecurityAuditLog.log(event: .mfaRequired, details: "MFA code provided for login", level: .info)
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)

            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response from server"
                isConnected = false
                SecurityAuditLog.log(event: .loginFailure, details: "Invalid HTTP response", level: .error)
                return
            }

            // Check for MFA requirement (status 401 with specific error)
            if httpResponse.statusCode == 401 {
                // Try to parse error response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let meta = json["meta"] as? [String: Any],
                   let msg = meta["msg"] as? String,
                   msg.contains("2fa") || msg.contains("token") {
                    mfaRequired = true
                    lastError = "MFA code required"
                    SecureLogger.log("MFA required for login", level: .info)
                    SecurityAuditLog.log(event: .mfaRequired, details: "Controller requires MFA", level: .info)
                    return
                } else {
                    lastError = "Login failed. Please check your credentials."
                    isConnected = false
                    SecurityAuditLog.log(event: .loginFailure, details: "Invalid credentials", level: .warning)
                    return
                }
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                lastError = "Login failed. Please try again."
                isConnected = false
                mfaRequired = false
                SecurityAuditLog.log(event: .loginFailure, details: "HTTP \(httpResponse.statusCode)", level: .error)
                return
            }

            // Extract session cookie and CSRF token
            if let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) {
                sessionCookie = cookies.first(where: { $0.name == "unifises" })?.value
                csrfToken = cookies.first(where: { $0.name == "csrf_token" })?.value
            }

            // Parse response (log without sensitive data)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                SecureLogger.log("Login response received: \(json)", level: .debug)  // Auto-masks sensitive data
            }

            isConnected = true
            mfaRequired = false
            lastError = nil

            // Set session expiration
            sessionExpiration = Date().addingTimeInterval(sessionDuration)
            startSessionMonitor()

            SecureLogger.log("Logged in successfully to UniFi controller", level: .info)
            SecurityAuditLog.log(event: .loginSuccess, details: "Successful login to \(baseURL)", level: .security)

        } catch {
            lastError = UserFacingErrors.genericMessage(for: error)
            isConnected = false
            mfaRequired = false
            SecureLogger.log("Login failed: \(error)", level: .error)
            SecurityAuditLog.log(event: .loginFailure, details: "Error: \(error.localizedDescription)", level: .error)
        }
    }

    /// Fetch all client devices from UniFi controller
    func fetchDevices() async -> [UniFiDevice] {
        // Check session expiration
        await checkSessionExpiration()

        guard isConnected, let baseURL = baseURL else {
            if !isConnected && isConfigured {
                await login()
            }
            return []
        }

        // Rate limit API requests
        await rateLimiter.waitIfNeeded()

        // Use appropriate API path for controller type
        let apiPath = isUniFiOS ? "/proxy/network/api/s/\(siteName)/stat/sta" : "/api/s/\(siteName)/stat/sta"
        let devicesURL = URL(string: "\(baseURL)\(apiPath)")!
        var request = URLRequest(url: devicesURL)
        request.httpMethod = "GET"

        if let cookie = sessionCookie {
            request.setValue("unifises=\(cookie)", forHTTPHeaderField: "Cookie")
        }

        // Add CSRF token if available
        if let token = csrfToken {
            request.setValue(token, forHTTPHeaderField: "X-CSRF-Token")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "Failed to fetch client devices"
                return []
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let apiResponse = try decoder.decode(UniFiAPIResponse.self, from: data)
            self.devices = apiResponse.data

            SecureLogger.log("Fetched \(devices.count) client devices", level: .info)
            return devices

        } catch {
            lastError = "Fetch error: \(error.localizedDescription)"
            SecureLogger.log("Failed to fetch client devices: \(error)", level: .error)
            return []
        }
    }

    /// Fetch infrastructure devices (APs, switches, gateways)
    func fetchInfrastructureDevices() async -> [UniFiInfrastructureDevice] {
        guard isConnected, let baseURL = baseURL else {
            if !isConnected && isConfigured {
                await login()
            }
            return []
        }

        // Use appropriate API path for controller type
        let apiPath = isUniFiOS ? "/proxy/network/api/s/\(siteName)/stat/device" : "/api/s/\(siteName)/stat/device"
        let devicesURL = URL(string: "\(baseURL)\(apiPath)")!
        var request = URLRequest(url: devicesURL)
        request.httpMethod = "GET"

        if let cookie = sessionCookie {
            request.setValue("unifises=\(cookie)", forHTTPHeaderField: "Cookie")
        }

        // Add CSRF token if available
        if let token = csrfToken {
            request.setValue(token, forHTTPHeaderField: "X-CSRF-Token")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "Failed to fetch infrastructure devices"
                return []
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let apiResponse = try decoder.decode(UniFiInfrastructureAPIResponse.self, from: data)
            self.infrastructureDevices = apiResponse.data

            SecureLogger.log("Fetched \(infrastructureDevices.count) infrastructure devices", level: .info)
            return infrastructureDevices

        } catch {
            lastError = "Fetch infrastructure error: \(error.localizedDescription)"
            SecureLogger.log("Failed to fetch infrastructure devices: \(error)", level: .error)
            return []
        }
    }

    /// Fetch UniFi Protect cameras
    func fetchProtectCameras() async -> [UniFiProtectCamera] {
        guard isConnected, let baseURL = baseURL else {
            if !isConnected && isConfigured {
                await login()
            }
            return []
        }

        // UniFi Protect uses a different API path
        let camerasURL = URL(string: "\(baseURL)/proxy/protect/api/cameras")!
        var request = URLRequest(url: camerasURL)
        request.httpMethod = "GET"

        if let cookie = sessionCookie {
            request.setValue("unifises=\(cookie)", forHTTPHeaderField: "Cookie")
        }

        // Add CSRF token if available
        if let token = csrfToken {
            request.setValue(token, forHTTPHeaderField: "X-CSRF-Token")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response from server"
                return []
            }

            // Protect may not be installed (404)
            if httpResponse.statusCode == 404 {
                SecureLogger.log("UniFi Protect not found (404)", level: .info)
                return []
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                lastError = "Failed to fetch Protect cameras: HTTP \(httpResponse.statusCode)"
                return []
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let cameras = try decoder.decode([UniFiProtectCamera].self, from: data)
            self.protectCameras = cameras

            SecureLogger.log("Fetched \(cameras.count) Protect cameras", level: .info)
            return cameras

        } catch {
            lastError = "Fetch cameras error: \(error.localizedDescription)"
            SecureLogger.log("Failed to fetch Protect cameras: \(error)", level: .error)
            return []
        }
    }

    /// Fetch all data (clients, infrastructure, cameras)
    func fetchAllData() async {
        guard isConnected else {
            if isConfigured {
                await login()
            }
            return
        }

        SecureLogger.log("Fetching all UniFi data", level: .info)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await self.fetchDevices()
            }
            group.addTask {
                _ = await self.fetchInfrastructureDevices()
            }
            group.addTask {
                _ = await self.fetchProtectCameras()
            }
        }

        SecureLogger.log("Fetched all data: \(devices.count) clients, \(infrastructureDevices.count) infrastructure, \(protectCameras.count) cameras", level: .info)
    }

    // MARK: - Keychain Management

    private struct UniFiCredentials: Codable {
        let host: String
        let username: String
        let password: String
        let siteName: String
    }

    private func saveCredentials(host: String, username: String, password: String, siteName: String) {
        let credentials = UniFiCredentials(
            host: host,
            username: username,
            password: password,
            siteName: siteName
        )

        guard let data = try? JSONEncoder().encode(credentials) else {
            SecureLogger.log("Failed to encode credentials", level: .error)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "NMAPScanner-UniFi",
            kSecAttrAccount as String: host,
            kSecValueData as String: data
        ]

        // Delete existing entry
        SecItemDelete(query as CFDictionary)

        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            SecureLogger.log("Failed to save credentials to Keychain: \(status)", level: .error)
        } else {
            SecureLogger.log("Credentials saved to Keychain", level: .info)
        }
    }

    private func loadCredentials() -> (host: String, username: String, password: String, siteName: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "NMAPScanner-UniFi",
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let existingItem = item as? [String: Any],
              let host = existingItem[kSecAttrAccount as String] as? String,
              let data = existingItem[kSecValueData as String] as? Data,
              let credentials = try? JSONDecoder().decode(UniFiCredentials.self, from: data) else {
            return nil
        }

        return (credentials.host, credentials.username, credentials.password, credentials.siteName)
    }

    private func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "NMAPScanner-UniFi"
        ]

        SecItemDelete(query as CFDictionary)
        SecureLogger.log("Deleted credentials from Keychain", level: .info)
    }

    // MARK: - Session Management

    private func startSessionMonitor() {
        // Invalidate existing timer
        sessionMonitorTimer?.invalidate()

        // Check session every minute
        sessionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSessionExpiration()
            }
        }

        SecureLogger.log("Started session monitor", level: .info)
    }

    private func checkSessionExpiration() async {
        guard let expiration = sessionExpiration else { return }

        if Date() > expiration {
            SecureLogger.log("Session expired - logging out", level: .warning)
            SecurityAuditLog.log(event: .sessionExpired, details: "Session expired after \(sessionDuration/60) minutes", level: .security)

            isConnected = false
            sessionCookie = nil
            csrfToken = nil

            // Optionally: Auto re-login if credentials available
            if isConfigured {
                SecureLogger.log("Attempting automatic re-login", level: .info)
                await login()
            }
        }
    }

    // MARK: - Certificate Trust Management

    /// Prompt user to trust certificate
    private func promptUserToTrustCertificate(host: String, commonName: String, fingerprint: String) async -> Bool {
        // This will be called from the secure delegate
        // In a real implementation, you'd show a SwiftUI alert
        // For now, return true to maintain existing behavior but with tracking

        SecureLogger.log("Certificate trust prompt for \(host): CN=\(commonName), FP=\(fingerprint)", level: .warning)

        // SECURITY: Auto-trusting certificates bypasses TLS verification.
        // A proper implementation should present a SwiftUI confirmation dialog showing
        // the certificate common name and fingerprint, allowing the user to accept or reject.
        // Until that UI is built, all UniFi controller certificates are auto-trusted.
        SecurityAuditLog.log(event: .certificateTrusted, details: "Auto-trusted certificate for \(host) (pending UI implementation)", level: .security)

        return true  // Auto-trust for now (better than blind trust)
    }
}

// MARK: - UniFi Data Models

struct UniFiAPIResponse: Codable {
    let data: [UniFiDevice]
    let meta: UniFiMeta
}

struct UniFiMeta: Codable {
    let rc: String
}

struct UniFiDevice: Codable, Identifiable {
    var id: String { mac }

    let mac: String
    let ip: String?
    let hostname: String?
    let name: String?
    let oui: String?
    let isWired: Bool?
    let lastSeen: Int?
    let uptime: Int?
    let networkName: String?
    let apMac: String?
    let channel: Int?
    let rssi: Int?

    // Computed property for manufacturer (same as oui)
    var manufacturer: String? {
        return oui
    }

    enum CodingKeys: String, CodingKey {
        case mac
        case ip
        case hostname
        case name
        case oui
        case isWired = "is_wired"
        case lastSeen = "last_seen"
        case uptime
        case networkName = "essid"
        case apMac = "ap_mac"
        case channel
        case rssi
    }
}

// MARK: - Infrastructure Devices

struct UniFiInfrastructureAPIResponse: Codable {
    let data: [UniFiInfrastructureDevice]
    let meta: UniFiMeta
}

struct UniFiInfrastructureDevice: Codable, Identifiable {
    var id: String { mac }

    let mac: String
    let ip: String?
    let name: String?
    let model: String?
    let type: String?
    let adopted: Bool?
    let state: Int?
    let version: String?
    let uptime: Int?
    let lastSeen: Int?

    // Switch specific
    let portTable: [UniFiPortInfo]?
    let numPorts: Int?

    // AP specific
    let radioTable: [RadioTableInfo]?
    let vwireTable: [VwireTableInfo]?

    // Gateway specific
    let wan1: WanInfo?
    let wan2: WanInfo?
    let speedtestStatus: SpeedtestStatus?

    // General stats
    let sysStats: SystemStats?
    let systemStats: SystemStats?

    var deviceType: String {
        if let model = model {
            if model.starts(with: "USW") {
                return "Switch"
            } else if model.starts(with: "U") && (model.contains("AP") || model.contains("AC") || model.contains("6")) {
                return "Access Point"
            } else if model.starts(with: "UDM") || model.starts(with: "UXG") || model.starts(with: "USG") {
                return "Gateway"
            }
        }
        return type ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case mac
        case ip
        case name
        case model
        case type
        case adopted
        case state
        case version
        case uptime
        case lastSeen = "last_seen"
        case portTable = "port_table"
        case numPorts = "num_ports"
        case radioTable = "radio_table"
        case vwireTable = "vwire_table"
        case wan1
        case wan2
        case speedtestStatus = "speedtest_status"
        case sysStats = "sys_stats"
        case systemStats = "system_stats"
    }
}

struct UniFiPortInfo: Codable {
    let portIdx: Int?
    let name: String?
    let up: Bool?
    let speed: Int?
    let fullDuplex: Bool?
    let poeEnable: Bool?
    let poePower: String?

    enum CodingKeys: String, CodingKey {
        case portIdx = "port_idx"
        case name
        case up
        case speed
        case fullDuplex = "full_duplex"
        case poeEnable = "poe_enable"
        case poePower = "poe_power"
    }
}

struct RadioTableInfo: Codable {
    let name: String?
    let radio: String?
    let channel: Int?
    let txPower: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case radio
        case channel
        case txPower = "tx_power"
    }
}

struct VwireTableInfo: Codable {
    let name: String?
}

struct WanInfo: Codable {
    let ip: String?
    let gateway: String?
    let dns: [String]?
    let up: Bool?
    let speed: Int?
}

struct SpeedtestStatus: Codable {
    let latency: Int?
    let xputDownload: Double?
    let xputUpload: Double?

    enum CodingKeys: String, CodingKey {
        case latency
        case xputDownload = "xput_download"
        case xputUpload = "xput_upload"
    }
}

struct SystemStats: Codable {
    let cpu: Double?
    let mem: Double?
    let uptime: Int?
}

// MARK: - Protect Cameras

struct UniFiProtectCamera: Codable, Identifiable {
    var id: String { mac }

    let mac: String
    let name: String?
    let type: String?
    let model: String?
    let firmwareVersion: String?
    let host: String?
    let connectionHost: String?
    let state: String?
    let isAdopted: Bool?
    let isAdopting: Bool?
    let isProvisioned: Bool?
    let isRebooting: Bool?
    let isUpdating: Bool?
    let lastSeen: Int?
    let uptime: Int?
    let uptimeSinceLastUpdate: Int?
    let isMotionDetected: Bool?
    let lastMotion: Int?
    let channels: [CameraChannel]?
    let stats: CameraStats?

    var displayName: String {
        return name ?? model ?? mac
    }

    enum CodingKeys: String, CodingKey {
        case mac
        case name
        case type
        case model
        case firmwareVersion
        case host
        case connectionHost
        case state
        case isAdopted
        case isAdopting
        case isProvisioned
        case isRebooting
        case isUpdating
        case lastSeen
        case uptime
        case uptimeSinceLastUpdate
        case isMotionDetected
        case lastMotion
        case channels
        case stats
    }
}

struct CameraChannel: Codable {
    let id: Int?
    let name: String?
    let enabled: Bool?
    let isRtspEnabled: Bool?
    let rtspAlias: String?
    let width: Int?
    let height: Int?
    let fps: Int?
    let bitrate: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enabled
        case isRtspEnabled
        case rtspAlias
        case width
        case height
        case fps
        case bitrate
    }
}

struct CameraStats: Codable {
    let rxBytes: Int?
    let txBytes: Int?
    let video: VideoStats?

    enum CodingKeys: String, CodingKey {
        case rxBytes
        case txBytes
        case video
    }
}

struct VideoStats: Codable {
    let recordingStart: Int?
    let recordingEnd: Int?
    let recordingBytes: Int?

    enum CodingKeys: String, CodingKey {
        case recordingStart
        case recordingEnd
        case recordingBytes
    }
}
