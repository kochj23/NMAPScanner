//
//  AIServiceHealthChecker.swift
//  NMAP Plus Security Scanner v8.3.0
//
//  Created by Jordan Koch on 2026-02-02.
//
//  AI Service Auto-Discovery and Health Monitoring
//  Queries detected AI endpoints for status including:
//  - Ollama (11434): /api/tags, /api/ps
//  - OpenWebUI (3000): /api/models
//  - text-generation-webui (5001): /api/v1/model
//  - vLLM (8000): /v1/models
//  - ComfyUI (8188): /system_stats
//

import Foundation
import SwiftUI

// MARK: - AI Service Type

/// Types of AI services that can be detected on the network
enum AIHealthServiceType: String, CaseIterable, Identifiable {
    case ollama = "Ollama"
    case openWebUI = "Open WebUI"
    case textGenerationWebUI = "Text Generation WebUI"
    case vLLM = "vLLM"
    case comfyUI = "ComfyUI"
    case localAI = "LocalAI"
    case llamaCpp = "llama.cpp"
    case unknown = "Unknown AI Service"

    var id: String { rawValue }

    /// Default port for the service
    var defaultPort: Int {
        switch self {
        case .ollama: return 11434
        case .openWebUI: return 3000
        case .textGenerationWebUI: return 5001
        case .vLLM: return 8000
        case .comfyUI: return 8188
        case .localAI: return 8080
        case .llamaCpp: return 8081
        case .unknown: return 0
        }
    }

    /// API endpoint for checking service status
    var statusEndpoint: String {
        switch self {
        case .ollama: return "/api/tags"
        case .openWebUI: return "/api/models"
        case .textGenerationWebUI: return "/api/v1/model"
        case .vLLM: return "/v1/models"
        case .comfyUI: return "/system_stats"
        case .localAI: return "/models"
        case .llamaCpp: return "/health"
        case .unknown: return "/"
        }
    }

    /// Additional endpoint for detailed info (if available)
    var detailEndpoint: String? {
        switch self {
        case .ollama: return "/api/ps"
        case .comfyUI: return "/history"
        case .vLLM: return "/v1/completions"
        default: return nil
        }
    }

    /// Icon for the service type
    var icon: String {
        switch self {
        case .ollama: return "brain.head.profile"
        case .openWebUI: return "globe"
        case .textGenerationWebUI: return "text.bubble"
        case .vLLM: return "bolt.fill"
        case .comfyUI: return "paintbrush.fill"
        case .localAI: return "cpu"
        case .llamaCpp: return "terminal"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Color for the service type
    var color: Color {
        switch self {
        case .ollama: return .blue
        case .openWebUI: return .green
        case .textGenerationWebUI: return .purple
        case .vLLM: return .orange
        case .comfyUI: return .pink
        case .localAI: return .cyan
        case .llamaCpp: return .yellow
        case .unknown: return .gray
        }
    }

    /// Try to detect service type from port number
    static func from(port: Int) -> AIHealthServiceType {
        switch port {
        case 11434: return .ollama
        case 3000: return .openWebUI
        case 5001: return .textGenerationWebUI
        case 8000: return .vLLM
        case 8188: return .comfyUI
        case 8080: return .localAI
        case 8081: return .llamaCpp
        default: return .unknown
        }
    }

    /// Known AI service ports
    static var knownPorts: Set<Int> {
        Set(allCases.compactMap { $0 != .unknown ? $0.defaultPort : nil })
    }
}

// MARK: - AI Service Status

/// Status information for an AI service
struct AIServiceStatus: Identifiable, Equatable {
    let id = UUID()
    let host: String
    let port: Int
    let serviceType: AIHealthServiceType
    let isOnline: Bool
    let models: [String]?
    let loadedModel: String?
    let gpuMemoryUsed: Int64?
    let gpuMemoryTotal: Int64?
    let cpuUsage: Double?
    let responseTime: TimeInterval
    let lastChecked: Date
    let version: String?
    let error: String?

    /// Health status based on service status
    var healthStatus: HealthStatus {
        if !isOnline {
            return .offline
        }
        if error != nil {
            return .warning
        }
        if responseTime > 5.0 {
            return .warning
        }
        return .healthy
    }

    /// GPU memory usage percentage
    var gpuMemoryPercentage: Double? {
        guard let used = gpuMemoryUsed, let total = gpuMemoryTotal, total > 0 else {
            return nil
        }
        return Double(used) / Double(total) * 100.0
    }

    /// Formatted GPU memory string
    var gpuMemoryString: String? {
        guard let used = gpuMemoryUsed, let total = gpuMemoryTotal else {
            return nil
        }
        let usedGB = Double(used) / 1_073_741_824 // Convert to GB
        let totalGB = Double(total) / 1_073_741_824
        return String(format: "%.1f / %.1f GB", usedGB, totalGB)
    }

    enum HealthStatus: String {
        case healthy = "Healthy"
        case warning = "Warning"
        case offline = "Offline"

        var color: Color {
            switch self {
            case .healthy: return .green
            case .warning: return .yellow
            case .offline: return .red
            }
        }

        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .offline: return "xmark.circle.fill"
            }
        }
    }

    static func == (lhs: AIServiceStatus, rhs: AIServiceStatus) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
}

// MARK: - AI Service Health Checker

/// Main class for checking health of AI services on the network
@MainActor
class AIServiceHealthChecker: ObservableObject {
    static let shared = AIServiceHealthChecker()

    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus: String = ""
    @Published var services: [AIServiceStatus] = []
    @Published var lastScanDate: Date?

    private let session: URLSession
    private let timeout: TimeInterval = 5.0

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    /// Check a specific host and port for AI service
    func checkService(host: String, port: Int) async -> AIServiceStatus? {
        let serviceType = AIHealthServiceType.from(port: port)
        let startTime = Date()

        let baseURL = "http://\(host):\(port)"
        let statusEndpoint = serviceType.statusEndpoint

        guard let url = URL(string: baseURL + statusEndpoint) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            let responseTime = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return AIServiceStatus(
                    host: host,
                    port: port,
                    serviceType: serviceType,
                    isOnline: false,
                    models: nil,
                    loadedModel: nil,
                    gpuMemoryUsed: nil,
                    gpuMemoryTotal: nil,
                    cpuUsage: nil,
                    responseTime: responseTime,
                    lastChecked: Date(),
                    version: nil,
                    error: "HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                )
            }

            // Parse response based on service type
            return parseServiceResponse(
                data: data,
                host: host,
                port: port,
                serviceType: serviceType,
                responseTime: responseTime
            )

        } catch {
            return AIServiceStatus(
                host: host,
                port: port,
                serviceType: serviceType,
                isOnline: false,
                models: nil,
                loadedModel: nil,
                gpuMemoryUsed: nil,
                gpuMemoryTotal: nil,
                cpuUsage: nil,
                responseTime: Date().timeIntervalSince(startTime),
                lastChecked: Date(),
                version: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Scan all detected AI services on the network
    func scanAllServices(hosts: [String]) async {
        isScanning = true
        scanProgress = 0
        scanStatus = "Starting AI service scan..."
        services = []

        let knownPorts = Array(AIHealthServiceType.knownPorts)
        let totalChecks = hosts.count * knownPorts.count
        var completedChecks = 0

        for host in hosts {
            for port in knownPorts {
                scanStatus = "Checking \(host):\(port)..."

                if let status = await checkService(host: host, port: port) {
                    if status.isOnline {
                        services.append(status)
                        SecureLogger.log("Found AI service: \(status.serviceType.rawValue) at \(host):\(port)", level: .info)
                    }
                }

                completedChecks += 1
                scanProgress = Double(completedChecks) / Double(totalChecks)
            }
        }

        lastScanDate = Date()
        scanStatus = "Scan complete. Found \(services.count) AI service(s)."
        scanProgress = 1.0
        isScanning = false

        SecureLogger.log("AI service scan complete. Found \(services.count) services.", level: .info)
    }

    /// Quick scan of known AI service ports on a single host
    func quickScan(host: String) async -> [AIServiceStatus] {
        var foundServices: [AIServiceStatus] = []

        for port in AIHealthServiceType.knownPorts {
            if let status = await checkService(host: host, port: port), status.isOnline {
                foundServices.append(status)
            }
        }

        return foundServices
    }

    /// Refresh status of a specific service
    func refreshService(_ service: AIServiceStatus) async -> AIServiceStatus? {
        return await checkService(host: service.host, port: service.port)
    }

    /// Refresh all known services
    func refreshAllServices() async {
        isScanning = true
        scanStatus = "Refreshing services..."

        var updatedServices: [AIServiceStatus] = []

        for (index, service) in services.enumerated() {
            scanProgress = Double(index) / Double(services.count)
            scanStatus = "Refreshing \(service.serviceType.rawValue)..."

            if let updated = await refreshService(service) {
                updatedServices.append(updated)
            }
        }

        services = updatedServices
        lastScanDate = Date()
        scanProgress = 1.0
        scanStatus = "Refresh complete."
        isScanning = false
    }

    // MARK: - Private Methods

    /// Parse response data based on service type
    private func parseServiceResponse(
        data: Data,
        host: String,
        port: Int,
        serviceType: AIHealthServiceType,
        responseTime: TimeInterval
    ) -> AIServiceStatus {

        switch serviceType {
        case .ollama:
            return parseOllamaResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .openWebUI:
            return parseOpenWebUIResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .textGenerationWebUI:
            return parseTextGenWebUIResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .vLLM:
            return parseVLLMResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .comfyUI:
            return parseComfyUIResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .localAI:
            return parseLocalAIResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .llamaCpp:
            return parseLlamaCppResponse(data: data, host: host, port: port, responseTime: responseTime)
        case .unknown:
            return AIServiceStatus(
                host: host,
                port: port,
                serviceType: serviceType,
                isOnline: true,
                models: nil,
                loadedModel: nil,
                gpuMemoryUsed: nil,
                gpuMemoryTotal: nil,
                cpuUsage: nil,
                responseTime: responseTime,
                lastChecked: Date(),
                version: nil,
                error: nil
            )
        }
    }

    // MARK: - Service-Specific Parsers

    /// Parse Ollama /api/tags response
    private func parseOllamaResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        struct OllamaModelsResponse: Codable {
            struct Model: Codable {
                let name: String
                let modified_at: String?
                let size: Int64?
            }
            let models: [Model]
        }

        var models: [String] = []
        var loadedModel: String? = nil

        if let response = try? JSONDecoder().decode(OllamaModelsResponse.self, from: data) {
            models = response.models.map { $0.name }
        }

        // Try to get currently loaded model from /api/ps
        Task {
            if let psData = await fetchOllamaPS(host: host, port: port) {
                // Parse /api/ps response
                struct OllamaPSResponse: Codable {
                    struct RunningModel: Codable {
                        let name: String
                        let size: Int64?
                        let size_vram: Int64?
                    }
                    let models: [RunningModel]
                }

                if let psResponse = try? JSONDecoder().decode(OllamaPSResponse.self, from: psData),
                   let running = psResponse.models.first {
                    loadedModel = running.name
                }
            }
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .ollama,
            isOnline: true,
            models: models,
            loadedModel: loadedModel,
            gpuMemoryUsed: nil,
            gpuMemoryTotal: nil,
            cpuUsage: nil,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: nil
        )
    }

    /// Fetch Ollama /api/ps endpoint
    private func fetchOllamaPS(host: String, port: Int) async -> Data? {
        guard let url = URL(string: "http://\(host):\(port)/api/ps") else { return nil }
        return try? await session.data(from: url).0
    }

    /// Parse OpenWebUI response
    private func parseOpenWebUIResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        var models: [String] = []

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let modelList = json["models"] as? [[String: Any]] {
                models = modelList.compactMap { $0["name"] as? String ?? $0["id"] as? String }
            }
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .openWebUI,
            isOnline: true,
            models: models.isEmpty ? nil : models,
            loadedModel: nil,
            gpuMemoryUsed: nil,
            gpuMemoryTotal: nil,
            cpuUsage: nil,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: nil
        )
    }

    /// Parse Text Generation WebUI response
    private func parseTextGenWebUIResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        var loadedModel: String? = nil

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            loadedModel = json["model_name"] as? String ?? json["result"] as? String
        } else if let text = String(data: data, encoding: .utf8) {
            loadedModel = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .textGenerationWebUI,
            isOnline: true,
            models: nil,
            loadedModel: loadedModel,
            gpuMemoryUsed: nil,
            gpuMemoryTotal: nil,
            cpuUsage: nil,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: nil
        )
    }

    /// Parse vLLM response
    private func parseVLLMResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        struct VLLMModelsResponse: Codable {
            struct ModelData: Codable {
                let id: String
                let object: String?
                let owned_by: String?
            }
            let data: [ModelData]?
            let object: String?
        }

        var models: [String] = []

        if let response = try? JSONDecoder().decode(VLLMModelsResponse.self, from: data),
           let modelData = response.data {
            models = modelData.map { $0.id }
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .vLLM,
            isOnline: true,
            models: models.isEmpty ? nil : models,
            loadedModel: models.first,
            gpuMemoryUsed: nil,
            gpuMemoryTotal: nil,
            cpuUsage: nil,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: nil
        )
    }

    /// Parse ComfyUI response
    private func parseComfyUIResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        var gpuMemoryUsed: Int64? = nil
        var gpuMemoryTotal: Int64? = nil
        var cpuUsage: Double? = nil

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // ComfyUI system_stats response structure
            if let devices = json["devices"] as? [[String: Any]], let gpu = devices.first {
                if let vramUsed = gpu["vram_used"] as? Int64 {
                    gpuMemoryUsed = vramUsed
                } else if let vramUsed = gpu["vram_used"] as? Int {
                    gpuMemoryUsed = Int64(vramUsed)
                }
                if let vramTotal = gpu["vram_total"] as? Int64 {
                    gpuMemoryTotal = vramTotal
                } else if let vramTotal = gpu["vram_total"] as? Int {
                    gpuMemoryTotal = Int64(vramTotal)
                }
            }

            if let system = json["system"] as? [String: Any] {
                cpuUsage = system["cpu_usage"] as? Double
            }
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .comfyUI,
            isOnline: true,
            models: nil,
            loadedModel: nil,
            gpuMemoryUsed: gpuMemoryUsed,
            gpuMemoryTotal: gpuMemoryTotal,
            cpuUsage: cpuUsage,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: nil
        )
    }

    /// Parse LocalAI response
    private func parseLocalAIResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        var models: [String] = []

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let modelList = json["data"] as? [[String: Any]] {
                models = modelList.compactMap { $0["id"] as? String }
            }
        } else if let modelArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            models = modelArray.compactMap { $0["name"] as? String ?? $0["id"] as? String }
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .localAI,
            isOnline: true,
            models: models.isEmpty ? nil : models,
            loadedModel: nil,
            gpuMemoryUsed: nil,
            gpuMemoryTotal: nil,
            cpuUsage: nil,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: nil
        )
    }

    /// Parse llama.cpp response
    private func parseLlamaCppResponse(data: Data, host: String, port: Int, responseTime: TimeInterval) -> AIServiceStatus {
        var isHealthy = false

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            isHealthy = json["status"] as? String == "ok"
        } else if let text = String(data: data, encoding: .utf8) {
            isHealthy = text.lowercased().contains("ok") || text.lowercased().contains("healthy")
        }

        return AIServiceStatus(
            host: host,
            port: port,
            serviceType: .llamaCpp,
            isOnline: isHealthy,
            models: nil,
            loadedModel: nil,
            gpuMemoryUsed: nil,
            gpuMemoryTotal: nil,
            cpuUsage: nil,
            responseTime: responseTime,
            lastChecked: Date(),
            version: nil,
            error: isHealthy ? nil : "Service unhealthy"
        )
    }
}

// MARK: - Utility Extensions

extension AIServiceHealthChecker {
    /// Get services grouped by type
    var servicesByType: [AIHealthServiceType: [AIServiceStatus]] {
        Dictionary(grouping: services, by: { $0.serviceType })
    }

    /// Get total number of available models
    var totalModels: Int {
        services.compactMap { $0.models?.count }.reduce(0, +)
    }

    /// Get services with loaded models
    var servicesWithLoadedModels: [AIServiceStatus] {
        services.filter { $0.loadedModel != nil }
    }

    /// Get healthy services
    var healthyServices: [AIServiceStatus] {
        services.filter { $0.healthStatus == .healthy }
    }

    /// Get services with GPU info
    var servicesWithGPUInfo: [AIServiceStatus] {
        services.filter { $0.gpuMemoryUsed != nil }
    }
}
