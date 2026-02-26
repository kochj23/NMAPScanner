//
//  AISecurityAnalyzer.swift
//  NMAPScanner - AI/ML Service Security Analysis
//
//  Created by Jordan Koch on 2026-02-02.
//
//  Detects and flags AI/ML services with security vulnerabilities.
//  These services often run without authentication by default.
//

import Foundation
import Network
import SwiftUI

// MARK: - AI Security Warning Model

/// Represents a security warning for an AI/ML service
struct AISecurityWarning: Identifiable, Codable {
    let id: UUID
    let severity: AISecuritySeverity
    let service: String
    let host: String
    let port: Int
    let title: String
    let description: String
    let remediation: String
    let cveReferences: [String]?
    let detectedAt: Date
    let probeResult: AIProbeResult?

    /// Whether the vulnerability was actively verified
    var isVerified: Bool {
        probeResult?.isVulnerable ?? false
    }

    init(id: UUID = UUID(),
         severity: AISecuritySeverity,
         service: String,
         host: String,
         port: Int,
         title: String,
         description: String,
         remediation: String,
         cveReferences: [String]? = nil,
         detectedAt: Date = Date(),
         probeResult: AIProbeResult? = nil) {
        self.id = id
        self.severity = severity
        self.service = service
        self.host = host
        self.port = port
        self.title = title
        self.description = description
        self.remediation = remediation
        self.cveReferences = cveReferences
        self.detectedAt = detectedAt
        self.probeResult = probeResult
    }
}

/// Severity levels for AI security warnings
enum AISecuritySeverity: String, Codable, CaseIterable, Comparable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    var score: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }

    static func < (lhs: AISecuritySeverity, rhs: AISecuritySeverity) -> Bool {
        lhs.score > rhs.score // Higher score = more severe = should come first
    }
}

/// Result of probing an AI service for vulnerabilities
struct AIProbeResult: Codable {
    let isVulnerable: Bool
    let responseReceived: Bool
    let authRequired: Bool
    let details: String
    let probedAt: Date
}

// MARK: - AI Service Definition

/// Definition of a known AI/ML service and its security characteristics
struct AIServiceDefinition {
    let port: Int
    let serviceName: String
    let defaultSeverity: AISecuritySeverity
    let title: String
    let description: String
    let remediation: String
    let cveReferences: [String]
    let probeEndpoint: String?  // HTTP endpoint to probe
    let expectedResponse: String?  // Expected response indicating vulnerability

    /// Alternative ports this service might run on
    var alternativePorts: [Int] {
        switch port {
        case 11434: return [11434, 11435]  // Ollama
        case 8888: return [8888, 8889, 8890]  // Jupyter
        case 7860: return [7860, 7861, 7862]  // Gradio
        case 8080: return [8080, 8081, 8082, 3000]  // Various web UIs
        case 6333: return [6333, 6334]  // Qdrant
        case 8000: return [8000, 8001]  // FastAPI/uvicorn
        default: return [port]
        }
    }
}

// MARK: - AI Security Analyzer

/// Analyzes network devices for AI/ML service security vulnerabilities
@MainActor
class AISecurityAnalyzer: ObservableObject {
    static let shared = AISecurityAnalyzer()

    @Published var warnings: [AISecurityWarning] = []
    @Published var isAnalyzing = false
    @Published var lastAnalysisDate: Date?
    @Published var analysisProgress: Double = 0
    @Published var analysisStatus: String = ""

    // MARK: - AI Service Database

    /// Known AI/ML services and their security characteristics
    private let aiServices: [Int: AIServiceDefinition] = [
        // Ollama - Local LLM Server
        11434: AIServiceDefinition(
            port: 11434,
            serviceName: "Ollama",
            defaultSeverity: .high,
            title: "Ollama LLM Server - No Authentication",
            description: "Ollama provides no authentication by default. Anyone on the network can run inference, download models, and consume compute resources. Potential for prompt injection, data exfiltration via model responses, and resource abuse.",
            remediation: "1. Bind Ollama to localhost only (OLLAMA_HOST=127.0.0.1)\n2. Use an authentication proxy (nginx/traefik with auth)\n3. Enable firewall rules to restrict access\n4. Consider running behind VPN",
            cveReferences: [],
            probeEndpoint: "/api/tags",
            expectedResponse: "models"
        ),

        // Jupyter Notebook/Lab
        8888: AIServiceDefinition(
            port: 8888,
            serviceName: "Jupyter",
            defaultSeverity: .critical,
            title: "Jupyter Notebook - Remote Code Execution Risk",
            description: "Jupyter notebooks allow arbitrary code execution. If exposed without authentication, attackers can execute any code on the server, access files, install malware, pivot to other systems, or exfiltrate data.",
            remediation: "1. NEVER expose Jupyter directly to network\n2. Enable token authentication (--NotebookApp.token)\n3. Use JupyterHub with proper authentication\n4. Run behind SSH tunnel or VPN\n5. Enable HTTPS with valid certificates",
            cveReferences: ["CVE-2019-10255", "CVE-2019-10856", "CVE-2020-26215"],
            probeEndpoint: "/api",
            expectedResponse: "version"
        ),

        // Gradio Web UI
        7860: AIServiceDefinition(
            port: 7860,
            serviceName: "Gradio",
            defaultSeverity: .medium,
            title: "Gradio ML Interface - Public Model Access",
            description: "Gradio provides web interfaces for ML models. Default configuration allows anyone to interact with models, potentially exposing proprietary models, enabling prompt injection, or abusing compute resources.",
            remediation: "1. Add authentication via auth parameter\n2. Use Gradio's built-in authentication\n3. Place behind reverse proxy with auth\n4. Restrict to localhost for development",
            cveReferences: ["CVE-2023-51449"],
            probeEndpoint: "/config",
            expectedResponse: "version"
        ),

        // text-generation-webui
        7861: AIServiceDefinition(
            port: 7861,
            serviceName: "text-generation-webui",
            defaultSeverity: .medium,
            title: "Text Generation WebUI - Unrestricted Model Access",
            description: "Text generation web interface exposed without authentication. Allows interaction with loaded LLM models, potential prompt injection, and compute resource abuse.",
            remediation: "1. Bind to localhost (--listen-host 127.0.0.1)\n2. Add authentication via extensions\n3. Use reverse proxy with authentication\n4. Enable API key authentication",
            cveReferences: [],
            probeEndpoint: "/",
            expectedResponse: "text-generation"
        ),

        // ComfyUI
        8188: AIServiceDefinition(
            port: 8188,
            serviceName: "ComfyUI",
            defaultSeverity: .medium,
            title: "ComfyUI - Workflow Execution Risk",
            description: "ComfyUI Stable Diffusion interface allows creation and execution of image generation workflows. Exposed instances can be abused for unauthorized image generation and compute resource consumption.",
            remediation: "1. Bind to localhost only (--listen 127.0.0.1)\n2. Use reverse proxy with authentication\n3. Implement firewall rules\n4. Run behind VPN for remote access",
            cveReferences: [],
            probeEndpoint: "/system_stats",
            expectedResponse: "system"
        ),

        // Automatic1111 Stable Diffusion WebUI
        7870: AIServiceDefinition(
            port: 7870,
            serviceName: "Stable Diffusion WebUI",
            defaultSeverity: .medium,
            title: "Stable Diffusion WebUI - Unrestricted Image Generation",
            description: "Automatic1111 Stable Diffusion web interface. Exposed instances allow unauthorized image generation, potential NSFW content creation, and compute abuse.",
            remediation: "1. Add --gradio-auth username:password\n2. Bind to localhost (--server-name 127.0.0.1)\n3. Use reverse proxy with authentication\n4. Enable --api-auth for API access",
            cveReferences: [],
            probeEndpoint: "/sdapi/v1/options",
            expectedResponse: "sd_model"
        ),

        // Qdrant Vector Database
        6333: AIServiceDefinition(
            port: 6333,
            serviceName: "Qdrant",
            defaultSeverity: .high,
            title: "Qdrant Vector DB - Embedding Data Exposure",
            description: "Qdrant vector database exposed without authentication. Attackers can read, modify, or delete embedding vectors, potentially exposing sensitive data encoded in embeddings (documents, user data, etc.).",
            remediation: "1. Enable API key authentication\n2. Configure TLS encryption\n3. Use network segmentation\n4. Bind to internal network only\n5. Implement firewall rules",
            cveReferences: [],
            probeEndpoint: "/collections",
            expectedResponse: "collections"
        ),

        // ChromaDB
        8000: AIServiceDefinition(
            port: 8000,
            serviceName: "ChromaDB",
            defaultSeverity: .high,
            title: "ChromaDB Vector DB - Data Exposure Risk",
            description: "ChromaDB vector database has no authentication by default. Embedding data, which may contain sensitive information from documents or user interactions, can be accessed by anyone.",
            remediation: "1. Deploy behind authentication proxy\n2. Use network segmentation\n3. Bind to localhost only\n4. Implement firewall rules\n5. Use Chroma's authentication when available",
            cveReferences: [],
            probeEndpoint: "/api/v1/heartbeat",
            expectedResponse: "nanosecond"
        ),

        // Weaviate Vector Database
        8080: AIServiceDefinition(
            port: 8080,
            serviceName: "Weaviate",
            defaultSeverity: .high,
            title: "Weaviate Vector DB - Unauthorized Data Access",
            description: "Weaviate vector database may be exposed without authentication. Contains embedding vectors that could reveal sensitive information from indexed documents.",
            remediation: "1. Enable API key authentication\n2. Configure OIDC authentication\n3. Enable TLS\n4. Use network segmentation\n5. Implement proper access control",
            cveReferences: [],
            probeEndpoint: "/v1/schema",
            expectedResponse: "classes"
        ),

        // Milvus Vector Database
        19530: AIServiceDefinition(
            port: 19530,
            serviceName: "Milvus",
            defaultSeverity: .high,
            title: "Milvus Vector DB - Embedding Exposure",
            description: "Milvus vector database exposed to network. Without proper authentication, attackers can access or manipulate vector embeddings containing potentially sensitive data.",
            remediation: "1. Enable authentication\n2. Configure TLS encryption\n3. Use network segmentation\n4. Deploy behind firewall\n5. Implement role-based access control",
            cveReferences: [],
            probeEndpoint: nil,
            expectedResponse: nil
        ),

        // MinIO Object Storage
        9000: AIServiceDefinition(
            port: 9000,
            serviceName: "MinIO",
            defaultSeverity: .high,
            title: "MinIO Object Storage - Data Exposure",
            description: "MinIO S3-compatible storage often used for ML model storage, datasets, and artifacts. Default credentials or misconfiguration can expose sensitive ML assets.",
            remediation: "1. Change default access/secret keys immediately\n2. Enable TLS encryption\n3. Configure bucket policies properly\n4. Use IAM policies for access control\n5. Enable audit logging",
            cveReferences: ["CVE-2023-28432", "CVE-2021-21362"],
            probeEndpoint: "/minio/health/live",
            expectedResponse: nil
        ),

        // MLflow
        5000: AIServiceDefinition(
            port: 5000,
            serviceName: "MLflow",
            defaultSeverity: .high,
            title: "MLflow Tracking Server - Experiment Data Exposure",
            description: "MLflow tracking server exposed without authentication. Exposes ML experiment data, model artifacts, metrics, and potentially sensitive hyperparameters or dataset information.",
            remediation: "1. Enable authentication via reverse proxy\n2. Use MLflow's built-in auth (v2.5+)\n3. Restrict network access\n4. Deploy behind VPN\n5. Enable artifact storage encryption",
            cveReferences: ["CVE-2023-6831", "CVE-2024-27132"],
            probeEndpoint: "/api/2.0/mlflow/experiments/list",
            expectedResponse: "experiments"
        ),

        // TensorBoard
        6006: AIServiceDefinition(
            port: 6006,
            serviceName: "TensorBoard",
            defaultSeverity: .medium,
            title: "TensorBoard - Training Data Visibility",
            description: "TensorBoard visualization server exposed. May reveal model architecture, training progress, hyperparameters, and potentially sensitive training data samples.",
            remediation: "1. Bind to localhost only\n2. Use SSH tunnel for remote access\n3. Deploy behind authentication proxy\n4. Restrict network access\n5. Review logged data for sensitivity",
            cveReferences: [],
            probeEndpoint: "/data/runs",
            expectedResponse: nil
        ),

        // Triton Inference Server
        8001: AIServiceDefinition(
            port: 8001,
            serviceName: "Triton Inference Server",
            defaultSeverity: .high,
            title: "NVIDIA Triton - Model Serving Exposure",
            description: "Triton inference server grpc endpoint exposed. Allows unauthorized model inference, potential model extraction attacks, and compute resource abuse.",
            remediation: "1. Enable authentication\n2. Use TLS for communication\n3. Implement rate limiting\n4. Deploy behind API gateway\n5. Use model encryption",
            cveReferences: [],
            probeEndpoint: nil,
            expectedResponse: nil
        ),

        // LocalAI
        8081: AIServiceDefinition(
            port: 8081,
            serviceName: "LocalAI",
            defaultSeverity: .high,
            title: "LocalAI - Unrestricted LLM Access",
            description: "LocalAI provides OpenAI-compatible API without authentication by default. Allows unrestricted access to local LLM models.",
            remediation: "1. Bind to localhost\n2. Enable API key authentication\n3. Use reverse proxy with auth\n4. Implement rate limiting",
            cveReferences: [],
            probeEndpoint: "/v1/models",
            expectedResponse: "data"
        ),

        // LM Studio
        1234: AIServiceDefinition(
            port: 1234,
            serviceName: "LM Studio",
            defaultSeverity: .high,
            title: "LM Studio Server - Local LLM Exposure",
            description: "LM Studio local inference server. Provides OpenAI-compatible API without authentication, allowing network access to local LLM models.",
            remediation: "1. Only run server when needed\n2. Bind to localhost only\n3. Use firewall to restrict access\n4. Consider authentication proxy",
            cveReferences: [],
            probeEndpoint: "/v1/models",
            expectedResponse: "data"
        ),

        // vLLM (Note: shares port 8000 with ChromaDB - identified by service banner)
        8005: AIServiceDefinition(
            port: 8005,
            serviceName: "vLLM",
            defaultSeverity: .high,
            title: "vLLM Inference Server - Model Access Risk",
            description: "vLLM high-performance inference server. Default configuration allows unrestricted API access for LLM inference.",
            remediation: "1. Enable API key authentication (--api-key)\n2. Bind to localhost\n3. Use reverse proxy with authentication\n4. Implement rate limiting",
            cveReferences: [],
            probeEndpoint: "/v1/models",
            expectedResponse: "data"
        ),

        // Ray Serve/Dashboard
        8265: AIServiceDefinition(
            port: 8265,
            serviceName: "Ray Dashboard",
            defaultSeverity: .critical,
            title: "Ray Dashboard - Cluster Control Exposure",
            description: "Ray cluster dashboard exposed. Provides visibility into cluster state and potentially allows job submission, representing a critical security risk.",
            remediation: "1. Enable authentication\n2. Bind dashboard to localhost\n3. Use SSH tunnel for access\n4. Configure TLS\n5. Implement network policies",
            cveReferences: ["CVE-2023-48022", "CVE-2023-48023"],
            probeEndpoint: "/api/cluster_status",
            expectedResponse: nil
        ),

        // Hugging Face Text Generation Inference
        3000: AIServiceDefinition(
            port: 3000,
            serviceName: "HF TGI",
            defaultSeverity: .high,
            title: "Hugging Face TGI - Inference Endpoint Exposed",
            description: "Hugging Face Text Generation Inference server. Provides high-performance LLM inference without authentication by default.",
            remediation: "1. Deploy behind authentication gateway\n2. Bind to internal network\n3. Use API key authentication when available\n4. Implement rate limiting",
            cveReferences: [],
            probeEndpoint: "/info",
            expectedResponse: "model_id"
        )
    ]

    // Additional ports that might indicate AI services
    private let additionalAIPorts: Set<Int> = [
        5001,  // Flask ML apps
        8501,  // Streamlit
        8502,  // Streamlit
        8503,  // Streamlit
        4000,  // Phoenix LiveView (often ML dashboards)
        9001,  // MinIO console
        3001,  // Various ML apps
        7863,  // Gradio alternatives
        5555,  // Flower (Celery) - ML job monitoring
        6379,  // Redis (often used for ML caching)
        11211, // Memcached (ML caching)
    ]

    private init() {}

    // MARK: - Analysis Methods

    /// Analyze all devices for AI service vulnerabilities
    func analyzeAIServices(devices: [EnhancedDevice]) async {
        isAnalyzing = true
        warnings.removeAll()
        analysisProgress = 0
        analysisStatus = "Starting AI service analysis..."

        print("AI Security: Starting analysis of \(devices.count) devices")

        let onlineDevices = devices.filter { $0.isOnline }

        for (index, device) in onlineDevices.enumerated() {
            analysisProgress = Double(index) / Double(onlineDevices.count)
            analysisStatus = "Analyzing \(device.hostname ?? device.ipAddress)..."

            await analyzeDevice(device)

            // Small delay between devices
            do {
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            } catch is CancellationError {
                print("AISecurityAnalyzer: Analysis cancelled")
                break
            } catch {
                print("AISecurityAnalyzer: Sleep error: \(error.localizedDescription)")
            }
        }

        // Sort warnings by severity
        warnings.sort { $0.severity < $1.severity }

        analysisProgress = 1.0
        analysisStatus = "Analysis complete. Found \(warnings.count) AI security warnings."
        lastAnalysisDate = Date()
        isAnalyzing = false

        print("AI Security: Analysis complete - found \(warnings.count) warnings")

        // Send notification if critical warnings found
        let criticalCount = warnings.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            NotificationManager.shared.showNotification(
                .criticalThreat,
                title: "Critical AI Security Vulnerabilities",
                message: "Found \(criticalCount) critical AI/ML service security issues",
                severity: .critical
            )
        }
    }

    /// Analyze a single device for AI services
    private func analyzeDevice(_ device: EnhancedDevice) async {
        for port in device.openPorts {
            // Check if this port matches a known AI service
            if let serviceDefinition = aiServices[port.port] {
                let warning = await createWarning(for: serviceDefinition, device: device, port: port)
                warnings.append(warning)
            }
            // Also check alternative port mappings
            else if let matchedService = findServiceByAlternativePort(port.port) {
                let warning = await createWarning(for: matchedService, device: device, port: port)
                warnings.append(warning)
            }
            // Check for services by banner/service name
            else if let serviceByBanner = identifyServiceByBanner(port) {
                let warning = await createWarning(for: serviceByBanner, device: device, port: port)
                warnings.append(warning)
            }
        }
    }

    /// Find a service definition by checking alternative ports
    private func findServiceByAlternativePort(_ port: Int) -> AIServiceDefinition? {
        for (_, definition) in aiServices {
            if definition.alternativePorts.contains(port) {
                return definition
            }
        }
        return nil
    }

    /// Identify AI service by banner or service name
    private func identifyServiceByBanner(_ port: PortInfo) -> AIServiceDefinition? {
        let serviceLower = port.service.lowercased()
        let bannerLower = (port.banner ?? "").lowercased()

        // Check for Ollama
        if serviceLower.contains("ollama") || bannerLower.contains("ollama") {
            return aiServices[11434]
        }

        // Check for Jupyter
        if serviceLower.contains("jupyter") || bannerLower.contains("jupyter") ||
           serviceLower.contains("ipython") || bannerLower.contains("notebook") {
            return aiServices[8888]
        }

        // Check for Gradio
        if serviceLower.contains("gradio") || bannerLower.contains("gradio") {
            return aiServices[7860]
        }

        // Check for MLflow
        if serviceLower.contains("mlflow") || bannerLower.contains("mlflow") {
            return aiServices[5000]
        }

        // Check for vector databases
        if serviceLower.contains("qdrant") || bannerLower.contains("qdrant") {
            return aiServices[6333]
        }
        if serviceLower.contains("chroma") || bannerLower.contains("chroma") {
            return aiServices[8000]
        }
        if serviceLower.contains("weaviate") || bannerLower.contains("weaviate") {
            return aiServices[8080]
        }
        if serviceLower.contains("milvus") || bannerLower.contains("milvus") {
            return aiServices[19530]
        }

        // Check for MinIO
        if serviceLower.contains("minio") || bannerLower.contains("minio") {
            return aiServices[9000]
        }

        // Check for inference servers
        if serviceLower.contains("triton") || bannerLower.contains("triton") {
            return aiServices[8001]
        }
        if serviceLower.contains("localai") || bannerLower.contains("localai") {
            return aiServices[8081]
        }

        return nil
    }

    /// Create a warning for a detected AI service
    private func createWarning(for definition: AIServiceDefinition, device: EnhancedDevice, port: PortInfo) async -> AISecurityWarning {
        // Probe the service to verify vulnerability
        let probeResult = await probeService(host: device.ipAddress, definition: definition, actualPort: port.port)

        // Adjust severity based on probe result
        var severity = definition.defaultSeverity
        if let probe = probeResult, probe.isVulnerable {
            // Increase severity if vulnerability is confirmed
            if severity == .medium {
                severity = .high
            }
        } else if probeResult?.authRequired == true {
            // Decrease severity if authentication is required
            severity = .low
        }

        return AISecurityWarning(
            severity: severity,
            service: definition.serviceName,
            host: device.ipAddress,
            port: port.port,
            title: definition.title,
            description: definition.description,
            remediation: definition.remediation,
            cveReferences: definition.cveReferences.isEmpty ? nil : definition.cveReferences,
            probeResult: probeResult
        )
    }

    // MARK: - Service Probing

    /// Probe an AI service to verify vulnerability
    private func probeService(host: String, definition: AIServiceDefinition, actualPort: Int) async -> AIProbeResult? {
        guard let endpoint = definition.probeEndpoint else {
            return nil
        }

        // Try HTTP probe
        let urlString = "http://\(host):\(actualPort)\(endpoint)"
        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return AIProbeResult(
                    isVulnerable: false,
                    responseReceived: false,
                    authRequired: false,
                    details: "Invalid response",
                    probedAt: Date()
                )
            }

            // Check if authentication is required
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return AIProbeResult(
                    isVulnerable: false,
                    responseReceived: true,
                    authRequired: true,
                    details: "Service requires authentication (HTTP \(httpResponse.statusCode))",
                    probedAt: Date()
                )
            }

            // Check if we got a successful response
            if httpResponse.statusCode == 200 {
                let responseString = String(data: data, encoding: .utf8) ?? ""

                // Check for expected response pattern if defined
                var isVulnerable = true
                var details = "Service responded without authentication"

                if let expected = definition.expectedResponse {
                    isVulnerable = responseString.lowercased().contains(expected.lowercased())
                    if isVulnerable {
                        details = "Service confirmed accessible without authentication"
                    }
                }

                return AIProbeResult(
                    isVulnerable: isVulnerable,
                    responseReceived: true,
                    authRequired: false,
                    details: details,
                    probedAt: Date()
                )
            }

            return AIProbeResult(
                isVulnerable: false,
                responseReceived: true,
                authRequired: false,
                details: "Unexpected response (HTTP \(httpResponse.statusCode))",
                probedAt: Date()
            )

        } catch {
            return AIProbeResult(
                isVulnerable: false,
                responseReceived: false,
                authRequired: false,
                details: "Connection failed: \(error.localizedDescription)",
                probedAt: Date()
            )
        }
    }

    // MARK: - Statistics

    /// Get warnings for a specific device
    func getWarnings(for ipAddress: String) -> [AISecurityWarning] {
        return warnings.filter { $0.host == ipAddress }
    }

    /// Statistics about AI security warnings
    var stats: AISecurityStats {
        let critical = warnings.filter { $0.severity == .critical }.count
        let high = warnings.filter { $0.severity == .high }.count
        let medium = warnings.filter { $0.severity == .medium }.count
        let low = warnings.filter { $0.severity == .low }.count
        let verified = warnings.filter { $0.isVerified }.count

        return AISecurityStats(
            total: warnings.count,
            critical: critical,
            high: high,
            medium: medium,
            low: low,
            verified: verified
        )
    }

    /// Calculate security score impact from AI services
    var securityScoreImpact: Int {
        var impact = 0
        for warning in warnings {
            switch warning.severity {
            case .critical: impact += 15
            case .high: impact += 10
            case .medium: impact += 5
            case .low: impact += 2
            }
            // Additional penalty for verified vulnerabilities
            if warning.isVerified {
                impact += 5
            }
        }
        return min(impact, 50) // Cap at 50 points
    }
}

// MARK: - Statistics Model

struct AISecurityStats {
    let total: Int
    let critical: Int
    let high: Int
    let medium: Int
    let low: Int
    let verified: Int

    var hasIssues: Bool {
        total > 0
    }
}
