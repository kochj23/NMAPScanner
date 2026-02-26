//
//  ShadowAIDetector.swift
//  NMAPScanner - Shadow AI Detection & Monitoring
//
//  Detects unauthorized AI deployments on the network by scanning for common
//  AI/LLM service ports and monitoring for changes over time.
//
//  Created by Jordan Koch on 2025-02-02.
//

import Foundation
import SwiftUI
import Network

// MARK: - Data Models

/// Information about a detected AI service
struct AIServiceInfo: Identifiable, Codable, Hashable {
    let id: UUID
    let host: String
    let port: Int
    let serviceName: String
    let serviceType: AIServiceType
    var modelInfo: String?
    var version: String?
    var isAuthorized: Bool
    var firstSeen: Date
    var lastSeen: Date
    var isOnline: Bool
    var responseTime: TimeInterval?
    var additionalInfo: [String: String]

    init(
        host: String,
        port: Int,
        serviceName: String,
        serviceType: AIServiceType,
        modelInfo: String? = nil,
        version: String? = nil,
        isAuthorized: Bool = false,
        firstSeen: Date = Date(),
        lastSeen: Date = Date(),
        isOnline: Bool = true,
        responseTime: TimeInterval? = nil,
        additionalInfo: [String: String] = [:]
    ) {
        self.id = UUID()
        self.host = host
        self.port = port
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.modelInfo = modelInfo
        self.version = version
        self.isAuthorized = isAuthorized
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.isOnline = isOnline
        self.responseTime = responseTime
        self.additionalInfo = additionalInfo
    }

    /// Unique key for this service (host:port)
    var serviceKey: String {
        "\(host):\(port)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
    }

    static func == (lhs: AIServiceInfo, rhs: AIServiceInfo) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
}

/// Types of AI services that can be detected
enum AIServiceType: String, Codable, CaseIterable {
    case ollama = "Ollama"
    case openWebUI = "Open WebUI"
    case gradio = "Gradio"
    case localAI = "LocalAI"
    case textGenWebUI = "Text Generation WebUI"
    case vLLM = "vLLM"
    case triton = "Triton Inference Server"
    case stableDiffusion = "Stable Diffusion"
    case comfyUI = "ComfyUI"
    case qdrant = "Qdrant"
    case chroma = "Chroma"
    case milvus = "Milvus"
    case weaviate = "Weaviate"
    case tensorflowServing = "TensorFlow Serving"
    case mlflow = "MLflow"
    case jupyter = "Jupyter Notebook"
    case langServe = "LangServe"
    case n8n = "n8n"
    case anythingLLM = "AnythingLLM"
    case lmStudio = "LM Studio"
    case unknown = "Unknown AI Service"

    var icon: String {
        switch self {
        case .ollama: return "brain"
        case .openWebUI: return "bubble.left.and.bubble.right"
        case .gradio: return "sparkles"
        case .localAI: return "cpu"
        case .textGenWebUI: return "text.bubble"
        case .vLLM: return "bolt.fill"
        case .triton: return "server.rack"
        case .stableDiffusion: return "photo.artframe"
        case .comfyUI: return "paintbrush"
        case .qdrant, .chroma, .milvus, .weaviate: return "cylinder.split.1x2"
        case .tensorflowServing: return "chart.bar.xaxis"
        case .mlflow: return "arrow.triangle.branch"
        case .jupyter: return "doc.text"
        case .langServe: return "link"
        case .n8n: return "arrow.triangle.2.circlepath"
        case .anythingLLM: return "questionmark.circle"
        case .lmStudio: return "desktopcomputer"
        case .unknown: return "questionmark.diamond"
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .ollama, .localAI, .vLLM, .triton, .tensorflowServing:
            return .high // Can run arbitrary models
        case .textGenWebUI, .stableDiffusion, .comfyUI, .lmStudio:
            return .high // Full model access
        case .openWebUI, .gradio, .langServe, .anythingLLM:
            return .medium // Frontend interfaces
        case .jupyter:
            return .critical // Can execute arbitrary code
        case .n8n:
            return .medium // Workflow automation
        case .qdrant, .chroma, .milvus, .weaviate:
            return .low // Vector databases (data storage)
        case .mlflow:
            return .medium // MLOps tracking
        case .unknown:
            return .medium
        }
    }

    enum RiskLevel: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .critical: return .purple
            case .high: return .red
            case .medium: return .orange
            case .low: return .yellow
            }
        }
    }
}

/// Event types for AI service changes
enum AIEventType: String, Codable {
    case appeared = "New Service Detected"
    case disappeared = "Service Went Offline"
    case modelChanged = "Model Changed"
    case configChanged = "Configuration Changed"
    case authorized = "Service Authorized"
    case unauthorized = "Authorization Revoked"
    case versionChanged = "Version Changed"
}

/// An event representing a change in AI service state
struct AIServiceEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let eventType: AIEventType
    let host: String
    let port: Int
    let serviceName: String
    let serviceType: AIServiceType
    let isAuthorized: Bool
    let details: String?
    let previousValue: String?
    let newValue: String?

    init(
        eventType: AIEventType,
        host: String,
        port: Int,
        serviceName: String,
        serviceType: AIServiceType,
        isAuthorized: Bool,
        details: String? = nil,
        previousValue: String? = nil,
        newValue: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.eventType = eventType
        self.host = host
        self.port = port
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.isAuthorized = isAuthorized
        self.details = details
        self.previousValue = previousValue
        self.newValue = newValue
    }

    var severity: NotificationManager.AppNotification.Severity {
        switch eventType {
        case .appeared:
            return isAuthorized ? .medium : .high
        case .disappeared:
            return isAuthorized ? .high : .low
        case .modelChanged, .configChanged, .versionChanged:
            return .medium
        case .authorized:
            return .info
        case .unauthorized:
            return .high
        }
    }

    var icon: String {
        switch eventType {
        case .appeared: return "plus.circle.fill"
        case .disappeared: return "minus.circle.fill"
        case .modelChanged: return "brain.head.profile"
        case .configChanged: return "gearshape.fill"
        case .authorized: return "checkmark.shield.fill"
        case .unauthorized: return "xmark.shield.fill"
        case .versionChanged: return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch eventType {
        case .appeared: return isAuthorized ? .green : .red
        case .disappeared: return isAuthorized ? .orange : .gray
        case .modelChanged: return .blue
        case .configChanged: return .purple
        case .authorized: return .green
        case .unauthorized: return .red
        case .versionChanged: return .cyan
        }
    }
}

// MARK: - Port to Service Type Mapping

/// Maps ports to their likely AI service type
struct AIPortMapping {
    static let portToService: [Int: (name: String, type: AIServiceType)] = [
        // Ollama
        11434: ("Ollama API", .ollama),
        11435: ("Ollama (Alternate)", .ollama),

        // Chat Interfaces
        3000: ("Open WebUI", .openWebUI),
        7860: ("Gradio", .gradio),
        5000: ("LocalAI / Flask AI", .localAI),

        // Text Generation
        5001: ("Text Generation WebUI", .textGenWebUI),
        5005: ("Text Generation API", .textGenWebUI),
        8000: ("vLLM / FastAPI", .vLLM),
        8001: ("Triton HTTP", .triton),
        8002: ("Triton gRPC", .triton),
        8080: ("LM Studio", .lmStudio),

        // Image Generation
        7861: ("Stable Diffusion", .stableDiffusion),
        8188: ("ComfyUI", .comfyUI),

        // Vector Databases
        6333: ("Qdrant", .qdrant),
        6334: ("Weaviate", .weaviate),
        8765: ("Chroma", .chroma),
        19530: ("Milvus", .milvus),

        // MLOps
        8501: ("TensorFlow Serving", .tensorflowServing),
        8500: ("TensorFlow gRPC", .tensorflowServing),
        5050: ("MLflow", .mlflow),

        // Other
        8081: ("LangServe", .langServe),
        3001: ("n8n", .n8n),
        4000: ("AnythingLLM", .anythingLLM),
        8888: ("Jupyter Notebook", .jupyter),
        9090: ("SwarmUI", .stableDiffusion),
    ]

    static func getServiceInfo(for port: Int) -> (name: String, type: AIServiceType) {
        return portToService[port] ?? ("Unknown AI Service", .unknown)
    }

    static var allPorts: [Int] {
        Array(portToService.keys).sorted()
    }
}

// MARK: - Shadow AI Detector

/// Main class for detecting and monitoring unauthorized AI services on the network
@MainActor
class ShadowAIDetector: ObservableObject {
    static let shared = ShadowAIDetector()

    // MARK: - Published Properties

    @Published var knownServices: [String: AIServiceInfo] = [:] // host:port -> info
    @Published var events: [AIServiceEvent] = []
    @Published var unauthorizedServices: [AIServiceInfo] = []
    @Published var authorizedHosts: Set<String> = []

    @Published var isMonitoring = false
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var currentStatus = ""
    @Published var lastScanDate: Date?

    // Alert settings
    @Published var alertSettings = AlertSettings()

    // MARK: - Private Properties

    private var monitoringTask: Task<Void, Never>?
    private let userDefaults = UserDefaults.standard
    private let servicesKey = "shadow_ai_services"
    private let eventsKey = "shadow_ai_events"
    private let authorizedKey = "shadow_ai_authorized_hosts"
    private let settingsKey = "shadow_ai_alert_settings"
    private let maxEvents = 500

    // MARK: - Alert Settings

    struct AlertSettings: Codable, Equatable {
        var notifyOnNewService: Bool = true
        var notifyOnServiceOffline: Bool = true
        var notifyOnUnauthorized: Bool = true
        var notifyOnModelChange: Bool = true
        var monitoringInterval: TimeInterval = 300 // 5 minutes default
    }

    // MARK: - Initialization

    private init() {
        loadPersistedData()
    }

    // MARK: - Monitoring Control

    /// Start continuous monitoring for AI services
    func startMonitoring(interval: TimeInterval? = nil) {
        guard !isMonitoring else { return }

        let scanInterval = interval ?? alertSettings.monitoringInterval
        isMonitoring = true
        currentStatus = "Monitoring started (every \(formatInterval(scanInterval)))"

        print("ShadowAIDetector: Starting monitoring with interval \(scanInterval)s")
        SecureLogger.log("Shadow AI monitoring started with interval \(scanInterval)s", level: .info)

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await scanForAIServices()
                try? await Task.sleep(nanoseconds: UInt64(scanInterval * 1_000_000_000))
            }
        }
    }

    /// Stop continuous monitoring
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        currentStatus = "Monitoring stopped"

        print("ShadowAIDetector: Monitoring stopped")
        SecureLogger.log("Shadow AI monitoring stopped", level: .info)
    }

    // MARK: - AI Service Scanning

    /// Scan the network for AI services
    func scanForAIServices() async {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        currentStatus = "Scanning for AI services..."

        print("ShadowAIDetector: Starting AI service scan")
        SecureLogger.log("Starting shadow AI scan", level: .info)

        // Get current network subnet
        let subnet = await detectCurrentSubnet()

        var discoveredServices: [String: AIServiceInfo] = [:]
        let aiPorts = CommonPorts.aiServices
        let totalHosts = 254
        var scannedHosts = 0

        // Scan each host in the subnet
        for hostNum in 1...254 {
            let host = "\(subnet).\(hostNum)"

            // Scan AI ports on this host
            let servicesOnHost = await scanHostForAIServices(host: host, ports: aiPorts)

            for service in servicesOnHost {
                discoveredServices[service.serviceKey] = service
            }

            scannedHosts += 1
            scanProgress = Double(scannedHosts) / Double(totalHosts)

            // Update status periodically
            if scannedHosts % 50 == 0 {
                currentStatus = "Scanned \(scannedHosts)/\(totalHosts) hosts, found \(discoveredServices.count) services"
            }
        }

        // Also scan localhost
        currentStatus = "Scanning localhost..."
        let localServices = await scanHostForAIServices(host: "127.0.0.1", ports: aiPorts)
        for service in localServices {
            discoveredServices[service.serviceKey] = service
        }

        // Compare with previous scan and generate events
        await processDiscoveryResults(discoveredServices)

        lastScanDate = Date()
        isScanning = false
        scanProgress = 1.0
        currentStatus = "Scan complete - \(knownServices.count) services found"

        print("ShadowAIDetector: Scan complete, found \(knownServices.count) services")
        SecureLogger.log("Shadow AI scan complete: \(knownServices.count) services found", level: .info)

        savePersistedData()
    }

    /// Scan a specific host for AI services
    func scanHostForAIServices(host: String, ports: [Int]) async -> [AIServiceInfo] {
        var services: [AIServiceInfo] = []

        await withTaskGroup(of: AIServiceInfo?.self) { group in
            for port in ports {
                group.addTask {
                    await self.checkPort(host: host, port: port)
                }
            }

            for await service in group {
                if let service = service {
                    services.append(service)
                }
            }
        }

        return services
    }

    /// Check if a specific port is running an AI service
    private func checkPort(host: String, port: Int) async -> AIServiceInfo? {
        let startTime = Date()

        // Try to connect to the port
        guard await isPortOpen(host: host, port: port) else {
            return nil
        }

        let responseTime = Date().timeIntervalSince(startTime)
        let (serviceName, serviceType) = AIPortMapping.getServiceInfo(for: port)

        // Try to get additional info based on service type
        var modelInfo: String?
        var version: String?
        var additionalInfo: [String: String] = [:]

        // Query Ollama API for model info
        if serviceType == .ollama {
            let ollamaInfo = await queryOllamaAPI(host: host, port: port)
            modelInfo = ollamaInfo.models
            version = ollamaInfo.version
        }

        // Check if this host is authorized
        let isAuthorized = authorizedHosts.contains(host) || authorizedHosts.contains("\(host):\(port)")

        return AIServiceInfo(
            host: host,
            port: port,
            serviceName: serviceName,
            serviceType: serviceType,
            modelInfo: modelInfo,
            version: version,
            isAuthorized: isAuthorized,
            responseTime: responseTime,
            additionalInfo: additionalInfo
        )
    }

    /// Check if a port is open using TCP connection
    private func isPortOpen(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
            let connection = NWConnection(to: endpoint, using: .tcp)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if connection.state != .ready {
                    connection.cancel()
                }
            }
        }
    }

    /// Query Ollama API for model and version info
    private func queryOllamaAPI(host: String, port: Int) async -> (models: String?, version: String?) {
        guard let url = URL(string: "http://\(host):\(port)/api/tags") else {
            return (nil, nil)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let modelNames = models.compactMap { $0["name"] as? String }
                return (modelNames.joined(separator: ", "), nil)
            }
        } catch {
            // Silently fail - service might not support this endpoint
        }

        return (nil, nil)
    }

    // MARK: - Discovery Results Processing

    /// Process discovery results and generate events
    private func processDiscoveryResults(_ discoveredServices: [String: AIServiceInfo]) async {
        var newEvents: [AIServiceEvent] = []

        // Check for new services
        for (key, service) in discoveredServices {
            if let existingService = knownServices[key] {
                // Service exists - check for changes
                if existingService.modelInfo != service.modelInfo && service.modelInfo != nil {
                    let event = AIServiceEvent(
                        eventType: .modelChanged,
                        host: service.host,
                        port: service.port,
                        serviceName: service.serviceName,
                        serviceType: service.serviceType,
                        isAuthorized: service.isAuthorized,
                        details: "Model changed",
                        previousValue: existingService.modelInfo,
                        newValue: service.modelInfo
                    )
                    newEvents.append(event)

                    if alertSettings.notifyOnModelChange {
                        sendNotification(for: event)
                    }
                }

                // Update existing service
                var updatedService = service
                updatedService.firstSeen = existingService.firstSeen
                knownServices[key] = updatedService
            } else {
                // New service discovered
                knownServices[key] = service

                let event = AIServiceEvent(
                    eventType: .appeared,
                    host: service.host,
                    port: service.port,
                    serviceName: service.serviceName,
                    serviceType: service.serviceType,
                    isAuthorized: service.isAuthorized,
                    details: service.modelInfo
                )
                newEvents.append(event)

                if alertSettings.notifyOnNewService {
                    sendNotification(for: event)
                }

                // Add to unauthorized list if not authorized
                if !service.isAuthorized {
                    unauthorizedServices.append(service)

                    if alertSettings.notifyOnUnauthorized {
                        NotificationManager.shared.showNotification(
                            .rogueDevice,
                            title: "Unauthorized AI Service Detected",
                            message: "\(service.serviceName) on \(service.host):\(service.port)",
                            severity: .critical
                        )
                    }
                }
            }
        }

        // Check for disappeared services
        for (key, existingService) in knownServices {
            if discoveredServices[key] == nil {
                // Service went offline
                var offlineService = existingService
                offlineService.isOnline = false
                knownServices[key] = offlineService

                let event = AIServiceEvent(
                    eventType: .disappeared,
                    host: existingService.host,
                    port: existingService.port,
                    serviceName: existingService.serviceName,
                    serviceType: existingService.serviceType,
                    isAuthorized: existingService.isAuthorized,
                    details: "Service went offline"
                )
                newEvents.append(event)

                if alertSettings.notifyOnServiceOffline && existingService.isAuthorized {
                    sendNotification(for: event)
                }
            }
        }

        // Add events to history
        events.insert(contentsOf: newEvents, at: 0)

        // Trim events if too many
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }

        // Update unauthorized services list
        unauthorizedServices = knownServices.values.filter { !$0.isAuthorized && $0.isOnline }
    }

    // MARK: - Authorization Management

    /// Mark a host/service as authorized
    func markAsAuthorized(host: String, port: Int? = nil) {
        let key: String
        if let port = port {
            key = "\(host):\(port)"
        } else {
            key = host
        }

        authorizedHosts.insert(key)

        // Update all services from this host
        for (serviceKey, var service) in knownServices {
            if service.host == host && (port == nil || service.port == port) {
                service.isAuthorized = true
                knownServices[serviceKey] = service

                // Generate event
                let event = AIServiceEvent(
                    eventType: .authorized,
                    host: service.host,
                    port: service.port,
                    serviceName: service.serviceName,
                    serviceType: service.serviceType,
                    isAuthorized: true,
                    details: "Marked as authorized"
                )
                events.insert(event, at: 0)
            }
        }

        // Remove from unauthorized list
        unauthorizedServices.removeAll { $0.host == host && (port == nil || $0.port == port) }

        savePersistedData()

        print("ShadowAIDetector: Marked \(key) as authorized")
        SecureLogger.log("AI service authorized: \(key)", level: .info)
    }

    /// Remove authorization for a host/service
    func revokeAuthorization(host: String, port: Int? = nil) {
        let key: String
        if let port = port {
            key = "\(host):\(port)"
        } else {
            key = host
        }

        authorizedHosts.remove(key)

        // Update all services from this host
        for (serviceKey, var service) in knownServices {
            if service.host == host && (port == nil || service.port == port) {
                service.isAuthorized = false
                knownServices[serviceKey] = service

                // Generate event
                let event = AIServiceEvent(
                    eventType: .unauthorized,
                    host: service.host,
                    port: service.port,
                    serviceName: service.serviceName,
                    serviceType: service.serviceType,
                    isAuthorized: false,
                    details: "Authorization revoked"
                )
                events.insert(event, at: 0)

                // Add to unauthorized list if online
                if service.isOnline {
                    unauthorizedServices.append(service)
                }
            }
        }

        savePersistedData()

        print("ShadowAIDetector: Revoked authorization for \(key)")
        SecureLogger.log("AI service authorization revoked: \(key)", level: .warning)
    }

    /// Check if a host/service is authorized
    func isAuthorized(host: String, port: Int) -> Bool {
        return authorizedHosts.contains(host) || authorizedHosts.contains("\(host):\(port)")
    }

    // MARK: - Notifications

    private func sendNotification(for event: AIServiceEvent) {
        let notificationType: NotificationManager.AppNotification.NotificationType

        switch event.eventType {
        case .appeared:
            notificationType = event.isAuthorized ? .newDevice : .rogueDevice
        case .disappeared:
            notificationType = .deviceOffline
        case .modelChanged, .configChanged, .versionChanged:
            notificationType = .portChanged
        case .authorized, .unauthorized:
            notificationType = .systemAlert
        }

        NotificationManager.shared.showNotification(
            notificationType,
            title: event.eventType.rawValue,
            message: "\(event.serviceName) on \(event.host):\(event.port)",
            severity: event.severity
        )
    }

    // MARK: - Helper Methods

    /// Detect current network subnet
    private func detectCurrentSubnet() async -> String {
        // Try to get the default gateway's subnet
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse gateway from output
                for line in output.components(separatedBy: "\n") {
                    if line.contains("gateway:") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count >= 2 {
                            let gateway = parts[1].trimmingCharacters(in: .whitespaces)
                            let octets = gateway.components(separatedBy: ".")
                            if octets.count >= 3 {
                                return "\(octets[0]).\(octets[1]).\(octets[2])"
                            }
                        }
                    }
                }
            }
        } catch {
            print("ShadowAIDetector: Failed to detect subnet: \(error)")
        }

        // Default fallback
        return "192.168.1"
    }

    /// Format time interval for display
    private func formatInterval(_ interval: TimeInterval) -> String {
        if interval >= 3600 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else if interval >= 60 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(Int(interval)) seconds"
        }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        // Load known services
        if let data = userDefaults.data(forKey: servicesKey),
           let services = try? JSONDecoder().decode([String: AIServiceInfo].self, from: data) {
            knownServices = services
        }

        // Load events
        if let data = userDefaults.data(forKey: eventsKey),
           let loadedEvents = try? JSONDecoder().decode([AIServiceEvent].self, from: data) {
            events = loadedEvents
        }

        // Load authorized hosts
        if let data = userDefaults.data(forKey: authorizedKey),
           let hosts = try? JSONDecoder().decode(Set<String>.self, from: data) {
            authorizedHosts = hosts
        }

        // Load alert settings
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(AlertSettings.self, from: data) {
            alertSettings = settings
        }

        // Update unauthorized services list
        unauthorizedServices = knownServices.values.filter { !$0.isAuthorized && $0.isOnline }
    }

    private func savePersistedData() {
        // Save known services
        if let data = try? JSONEncoder().encode(knownServices) {
            userDefaults.set(data, forKey: servicesKey)
        }

        // Save events
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: eventsKey)
        }

        // Save authorized hosts
        if let data = try? JSONEncoder().encode(authorizedHosts) {
            userDefaults.set(data, forKey: authorizedKey)
        }

        // Save alert settings
        if let data = try? JSONEncoder().encode(alertSettings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    /// Save alert settings
    func saveAlertSettings() {
        savePersistedData()
    }

    // MARK: - Statistics

    /// Get statistics about AI services
    var statistics: AIServiceStatistics {
        let onlineServices = knownServices.values.filter { $0.isOnline }
        let authorizedOnline = onlineServices.filter { $0.isAuthorized }
        let unauthorizedOnline = onlineServices.filter { !$0.isAuthorized }

        let serviceTypeCount = Dictionary(grouping: onlineServices, by: { $0.serviceType })
            .mapValues { $0.count }

        let recentEvents = events.filter {
            $0.timestamp > Date().addingTimeInterval(-86400) // Last 24 hours
        }

        return AIServiceStatistics(
            totalServices: knownServices.count,
            onlineServices: onlineServices.count,
            offlineServices: knownServices.count - onlineServices.count,
            authorizedServices: authorizedOnline.count,
            unauthorizedServices: unauthorizedOnline.count,
            servicesByType: serviceTypeCount,
            eventsLast24Hours: recentEvents.count,
            lastScanDate: lastScanDate
        )
    }

    /// Clear all data
    func clearAllData() {
        knownServices.removeAll()
        events.removeAll()
        unauthorizedServices.removeAll()
        lastScanDate = nil
        savePersistedData()

        print("ShadowAIDetector: All data cleared")
        SecureLogger.log("Shadow AI detector data cleared", level: .warning)
    }
}

// MARK: - Statistics Model

struct AIServiceStatistics {
    let totalServices: Int
    let onlineServices: Int
    let offlineServices: Int
    let authorizedServices: Int
    let unauthorizedServices: Int
    let servicesByType: [AIServiceType: Int]
    let eventsLast24Hours: Int
    let lastScanDate: Date?
}
