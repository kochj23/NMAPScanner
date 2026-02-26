//
//  ServiceDependencyTracker.swift
//  NMAPScanner - Service Dependency Mapping
//
//  Created by Jordan Koch on 2026-02-02.
//  Tracks and visualizes service dependencies across network devices
//

import Foundation
import SwiftUI
import Combine

// MARK: - Connection Type

/// Type of connection between services
enum ConnectionType: String, CaseIterable, Identifiable {
    case api = "API"
    case database = "Database"
    case storage = "Storage"
    case messaging = "Messaging"
    case streaming = "Streaming"
    case monitoring = "Monitoring"
    case inference = "AI/Inference"
    case webProxy = "Web Proxy"
    case cache = "Cache"
    case unknown = "Unknown"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .api: return "arrow.left.arrow.right"
        case .database: return "cylinder"
        case .storage: return "externaldrive"
        case .messaging: return "bubble.left.and.bubble.right"
        case .streaming: return "waveform"
        case .monitoring: return "chart.xyaxis.line"
        case .inference: return "brain"
        case .webProxy: return "network"
        case .cache: return "memorychip"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .api: return .blue
        case .database: return .purple
        case .storage: return .orange
        case .messaging: return .green
        case .streaming: return .cyan
        case .monitoring: return .yellow
        case .inference: return .pink
        case .webProxy: return .gray
        case .cache: return .red
        case .unknown: return .secondary
        }
    }
}

// MARK: - Service Category

/// Category of service for visualization grouping
enum ServiceCategory: String, CaseIterable, Identifiable {
    case aiMl = "AI/ML"
    case database = "Database"
    case webServer = "Web Server"
    case mediaServer = "Media Server"
    case devOps = "DevOps"
    case messaging = "Messaging"
    case storage = "Storage"
    case network = "Network"
    case monitoring = "Monitoring"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .aiMl: return "brain.head.profile"
        case .database: return "cylinder.split.1x2"
        case .webServer: return "globe"
        case .mediaServer: return "play.rectangle"
        case .devOps: return "gearshape.2"
        case .messaging: return "bubble.left.and.bubble.right"
        case .storage: return "externaldrive.fill"
        case .network: return "network"
        case .monitoring: return "chart.bar.xaxis"
        case .other: return "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .aiMl: return .purple
        case .database: return .blue
        case .webServer: return .green
        case .mediaServer: return .orange
        case .devOps: return .cyan
        case .messaging: return .pink
        case .storage: return .yellow
        case .network: return .gray
        case .monitoring: return .red
        case .other: return .secondary
        }
    }
}

// MARK: - Service Connection

/// Represents a connection between two services
struct ServiceConnection: Identifiable, Hashable {
    let id = UUID()
    let sourceHost: String
    let sourcePort: Int
    let sourceService: String
    let destHost: String
    let destPort: Int
    let destService: String
    let connectionType: ConnectionType
    let confidence: Double // 0.0 to 1.0 - how confident we are about this connection
    let isInferred: Bool // True if inferred from known patterns, false if observed
    let description: String

    var connectionKey: String {
        "\(sourceHost):\(sourcePort)->\(destHost):\(destPort)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sourceHost)
        hasher.combine(sourcePort)
        hasher.combine(destHost)
        hasher.combine(destPort)
    }

    static func == (lhs: ServiceConnection, rhs: ServiceConnection) -> Bool {
        lhs.sourceHost == rhs.sourceHost &&
        lhs.sourcePort == rhs.sourcePort &&
        lhs.destHost == rhs.destHost &&
        lhs.destPort == rhs.destPort
    }
}

// MARK: - Service Node

/// Represents a service on a network device
struct ServiceNode: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let port: Int
    let serviceName: String
    let category: ServiceCategory
    let isRunning: Bool
    let version: String?
    let deviceName: String?

    var displayName: String {
        if let name = deviceName {
            return "\(name) (\(serviceName))"
        }
        return "\(host):\(port) - \(serviceName)"
    }

    var uniqueKey: String {
        "\(host):\(port)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
    }

    static func == (lhs: ServiceNode, rhs: ServiceNode) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
}

// MARK: - Known AI Service Patterns

/// Known patterns for AI service dependencies
struct AIServicePattern {
    let sourcePorts: Set<Int>
    let sourceServices: Set<String>
    let destPorts: Set<Int>
    let destServices: Set<String>
    let connectionType: ConnectionType
    let description: String
}

// MARK: - Service Dependency Tracker

/// Tracks and infers service dependencies across network devices
@MainActor
class ServiceDependencyTracker: ObservableObject {
    // MARK: - Published Properties

    @Published var connections: [ServiceConnection] = []
    @Published var serviceNodes: [ServiceNode] = []
    @Published var isAnalyzing = false
    @Published var lastAnalysisTime: Date?
    @Published var singlePointsOfFailure: [ServiceNode] = []

    // MARK: - Singleton

    static let shared = ServiceDependencyTracker()

    // MARK: - Known Port Mappings

    /// Port to service category mapping
    private let portCategories: [Int: ServiceCategory] = [
        // AI/ML Services
        11434: .aiMl,    // Ollama
        8188: .aiMl,     // ComfyUI
        7860: .aiMl,     // Gradio/Automatic1111
        5000: .aiMl,     // MLflow, Flask AI APIs
        8080: .webServer, // General web/API
        3000: .webServer, // OpenWebUI, Node.js apps

        // Databases
        3306: .database,  // MySQL
        5432: .database,  // PostgreSQL
        27017: .database, // MongoDB
        6379: .database,  // Redis
        6333: .database,  // Qdrant vector DB
        8765: .database,  // Chroma vector DB
        19530: .database, // Milvus vector DB
        9200: .database,  // Elasticsearch

        // Web Servers
        80: .webServer,
        443: .webServer,
        8000: .webServer,
        8443: .webServer,

        // Media Servers
        8096: .mediaServer, // Jellyfin
        32400: .mediaServer, // Plex
        8989: .mediaServer, // Sonarr
        7878: .mediaServer, // Radarr

        // DevOps
        9000: .devOps,   // Portainer, SonarQube
        8081: .devOps,   // Nexus
        8084: .devOps,   // Various CI/CD
        2375: .devOps,   // Docker API
        2376: .devOps,   // Docker API (TLS)

        // Messaging
        5672: .messaging, // RabbitMQ
        9092: .messaging, // Kafka
        4222: .messaging, // NATS

        // Storage
        9000: .storage,  // MinIO (conflicts with Portainer)
        8082: .storage,  // MinIO Console

        // Monitoring
        9090: .monitoring, // Prometheus
        3001: .monitoring, // Grafana
        5601: .monitoring, // Kibana

        // Development
        8888: .devOps,   // Jupyter
    ]

    /// Known service names to categories
    private let serviceCategories: [String: ServiceCategory] = [
        "ollama": .aiMl,
        "comfyui": .aiMl,
        "stable-diffusion": .aiMl,
        "automatic1111": .aiMl,
        "openwebui": .aiMl,
        "open-webui": .aiMl,
        "vllm": .aiMl,
        "text-generation-webui": .aiMl,
        "localai": .aiMl,
        "mlx": .aiMl,

        "mysql": .database,
        "postgresql": .database,
        "postgres": .database,
        "mongodb": .database,
        "redis": .database,
        "qdrant": .database,
        "chroma": .database,
        "milvus": .database,
        "elasticsearch": .database,
        "opensearch": .database,
        "neo4j": .database,

        "nginx": .webServer,
        "apache": .webServer,
        "httpd": .webServer,
        "caddy": .webServer,
        "traefik": .webServer,

        "jellyfin": .mediaServer,
        "plex": .mediaServer,
        "emby": .mediaServer,
        "sonarr": .mediaServer,
        "radarr": .mediaServer,
        "lidarr": .mediaServer,

        "docker": .devOps,
        "portainer": .devOps,
        "jenkins": .devOps,
        "gitlab": .devOps,
        "jupyter": .devOps,

        "rabbitmq": .messaging,
        "kafka": .messaging,
        "nats": .messaging,
        "mosquitto": .messaging,

        "minio": .storage,
        "nextcloud": .storage,
        "synology": .storage,

        "prometheus": .monitoring,
        "grafana": .monitoring,
        "kibana": .monitoring,
        "uptime-kuma": .monitoring,
    ]

    /// Known AI dependency patterns
    private let aiDependencyPatterns: [AIServicePattern] = [
        // ComfyUI -> Ollama (for LLM nodes)
        AIServicePattern(
            sourcePorts: [8188],
            sourceServices: ["comfyui"],
            destPorts: [11434],
            destServices: ["ollama"],
            connectionType: .inference,
            description: "ComfyUI uses Ollama for LLM-based nodes"
        ),

        // OpenWebUI -> Ollama
        AIServicePattern(
            sourcePorts: [3000, 8080],
            sourceServices: ["openwebui", "open-webui"],
            destPorts: [11434],
            destServices: ["ollama"],
            connectionType: .inference,
            description: "OpenWebUI frontend connects to Ollama backend"
        ),

        // Automatic1111/Gradio -> Ollama (for interrogation)
        AIServicePattern(
            sourcePorts: [7860],
            sourceServices: ["automatic1111", "stable-diffusion", "gradio"],
            destPorts: [11434],
            destServices: ["ollama"],
            connectionType: .inference,
            description: "Stable Diffusion WebUI may use Ollama for prompt enhancement"
        ),

        // RAG apps -> Qdrant
        AIServicePattern(
            sourcePorts: [3000, 8080, 5000],
            sourceServices: ["rag", "langchain", "llamaindex"],
            destPorts: [6333],
            destServices: ["qdrant"],
            connectionType: .database,
            description: "RAG application uses Qdrant vector database"
        ),

        // RAG apps -> Chroma
        AIServicePattern(
            sourcePorts: [3000, 8080, 5000],
            sourceServices: ["rag", "langchain", "llamaindex"],
            destPorts: [8765],
            destServices: ["chroma", "chromadb"],
            connectionType: .database,
            description: "RAG application uses Chroma vector database"
        ),

        // Jupyter -> AI Services
        AIServicePattern(
            sourcePorts: [8888],
            sourceServices: ["jupyter", "jupyterlab"],
            destPorts: [11434, 8188, 7860],
            destServices: ["ollama", "comfyui", "automatic1111"],
            connectionType: .inference,
            description: "Jupyter notebook connects to AI inference services"
        ),

        // AI Services -> Redis (caching)
        AIServicePattern(
            sourcePorts: [11434, 8188, 7860, 3000],
            sourceServices: ["ollama", "comfyui", "automatic1111", "openwebui"],
            destPorts: [6379],
            destServices: ["redis"],
            connectionType: .cache,
            description: "AI service uses Redis for caching"
        ),

        // AI Services -> PostgreSQL (persistence)
        AIServicePattern(
            sourcePorts: [11434, 3000],
            sourceServices: ["ollama", "openwebui"],
            destPorts: [5432],
            destServices: ["postgresql", "postgres"],
            connectionType: .database,
            description: "AI service uses PostgreSQL for data persistence"
        ),

        // Media Services -> AI (transcription, tagging)
        AIServicePattern(
            sourcePorts: [8096, 32400],
            sourceServices: ["jellyfin", "plex"],
            destPorts: [11434, 5000],
            destServices: ["ollama", "whisper"],
            connectionType: .inference,
            description: "Media server uses AI for transcription or tagging"
        ),

        // Text Generation WebUI -> Ollama
        AIServicePattern(
            sourcePorts: [7860, 5000],
            sourceServices: ["text-generation-webui", "oobabooga"],
            destPorts: [11434],
            destServices: ["ollama"],
            connectionType: .inference,
            description: "Text Generation WebUI connects to Ollama backend"
        ),

        // vLLM -> Model Storage
        AIServicePattern(
            sourcePorts: [8000],
            sourceServices: ["vllm"],
            destPorts: [9000],
            destServices: ["minio", "s3"],
            connectionType: .storage,
            description: "vLLM loads models from object storage"
        ),
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Analyze devices and detect service dependencies
    func detectDependencies(devices: [EnhancedDevice]) {
        isAnalyzing = true

        // Build service nodes from devices
        var nodes: [ServiceNode] = []
        for device in devices where device.isOnline {
            for port in device.openPorts where port.state == .open {
                let category = categorizeService(port: port.port, service: port.service)
                let node = ServiceNode(
                    host: device.ipAddress,
                    port: port.port,
                    serviceName: port.service,
                    category: category,
                    isRunning: true,
                    version: port.version,
                    deviceName: device.hostname ?? device.deviceName
                )
                nodes.append(node)
            }
        }

        serviceNodes = nodes

        // Detect connections
        var detectedConnections: [ServiceConnection] = []

        // Infer AI-specific dependencies
        detectedConnections.append(contentsOf: inferAIDependencies())

        // Infer general service dependencies
        detectedConnections.append(contentsOf: inferGeneralDependencies())

        // Detect web service chains
        detectedConnections.append(contentsOf: inferWebServiceChains())

        // Remove duplicates
        connections = Array(Set(detectedConnections))

        // Identify single points of failure
        identifySinglePointsOfFailure()

        lastAnalysisTime = Date()
        isAnalyzing = false
    }

    /// Infer AI-specific dependencies based on known patterns
    func inferAIDependencies() -> [ServiceConnection] {
        var connections: [ServiceConnection] = []

        for pattern in aiDependencyPatterns {
            // Find source services matching the pattern
            let sources = serviceNodes.filter { node in
                pattern.sourcePorts.contains(node.port) ||
                pattern.sourceServices.contains(where: { node.serviceName.lowercased().contains($0) })
            }

            // Find destination services matching the pattern
            let destinations = serviceNodes.filter { node in
                pattern.destPorts.contains(node.port) ||
                pattern.destServices.contains(where: { node.serviceName.lowercased().contains($0) })
            }

            // Create connections between matching pairs
            for source in sources {
                for dest in destinations where source.host != dest.host || source.port != dest.port {
                    let connection = ServiceConnection(
                        sourceHost: source.host,
                        sourcePort: source.port,
                        sourceService: source.serviceName,
                        destHost: dest.host,
                        destPort: dest.port,
                        destService: dest.serviceName,
                        connectionType: pattern.connectionType,
                        confidence: 0.85,
                        isInferred: true,
                        description: pattern.description
                    )
                    connections.append(connection)
                }
            }
        }

        return connections
    }

    /// Infer general service dependencies
    private func inferGeneralDependencies() -> [ServiceConnection] {
        var connections: [ServiceConnection] = []

        // Web servers likely connect to databases on same or adjacent hosts
        let webServers = serviceNodes.filter { $0.category == .webServer }
        let databases = serviceNodes.filter { $0.category == .database }

        for webServer in webServers {
            // Look for databases on same host
            for db in databases where isSameNetwork(webServer.host, db.host) {
                let connectionType: ConnectionType = db.serviceName.lowercased().contains("redis") ? .cache : .database

                let connection = ServiceConnection(
                    sourceHost: webServer.host,
                    sourcePort: webServer.port,
                    sourceService: webServer.serviceName,
                    destHost: db.host,
                    destPort: db.port,
                    destService: db.serviceName,
                    connectionType: connectionType,
                    confidence: 0.6,
                    isInferred: true,
                    description: "Web server likely connects to \(db.serviceName)"
                )
                connections.append(connection)
            }
        }

        // DevOps services connect to web servers (reverse proxy)
        let devOps = serviceNodes.filter { $0.category == .devOps }
        for devOp in devOps {
            for webServer in webServers where isSameNetwork(devOp.host, webServer.host) {
                let connection = ServiceConnection(
                    sourceHost: webServer.host,
                    sourcePort: webServer.port,
                    sourceService: webServer.serviceName,
                    destHost: devOp.host,
                    destPort: devOp.port,
                    destService: devOp.serviceName,
                    connectionType: .webProxy,
                    confidence: 0.5,
                    isInferred: true,
                    description: "Web server may proxy to \(devOp.serviceName)"
                )
                connections.append(connection)
            }
        }

        return connections
    }

    /// Detect web service chains (nginx -> app -> database)
    private func inferWebServiceChains() -> [ServiceConnection] {
        var connections: [ServiceConnection] = []

        // Common web chain: reverse proxy -> app server -> database
        let proxies = serviceNodes.filter {
            $0.serviceName.lowercased().contains("nginx") ||
            $0.serviceName.lowercased().contains("traefik") ||
            $0.serviceName.lowercased().contains("caddy") ||
            $0.port == 80 || $0.port == 443
        }

        let appServers = serviceNodes.filter {
            $0.category == .webServer && $0.port != 80 && $0.port != 443
        }

        for proxy in proxies {
            for app in appServers where isSameNetwork(proxy.host, app.host) {
                let connection = ServiceConnection(
                    sourceHost: proxy.host,
                    sourcePort: proxy.port,
                    sourceService: proxy.serviceName,
                    destHost: app.host,
                    destPort: app.port,
                    destService: app.serviceName,
                    connectionType: .webProxy,
                    confidence: 0.7,
                    isInferred: true,
                    description: "Reverse proxy forwards to application server"
                )
                connections.append(connection)
            }
        }

        return connections
    }

    /// Identify single points of failure (services with many dependents)
    private func identifySinglePointsOfFailure() {
        var dependentCounts: [String: Int] = [:]

        for connection in connections {
            let destKey = "\(connection.destHost):\(connection.destPort)"
            dependentCounts[destKey, default: 0] += 1
        }

        // Services with 3+ dependents are single points of failure
        singlePointsOfFailure = serviceNodes.filter { node in
            let key = "\(node.host):\(node.port)"
            return (dependentCounts[key] ?? 0) >= 3
        }
    }

    // MARK: - Helper Methods

    /// Categorize a service based on port and service name
    private func categorizeService(port: Int, service: String) -> ServiceCategory {
        // Check service name first
        let lowerService = service.lowercased()
        for (key, category) in serviceCategories {
            if lowerService.contains(key) {
                return category
            }
        }

        // Fall back to port-based categorization
        return portCategories[port] ?? .other
    }

    /// Check if two hosts are on the same network (same /24 subnet)
    private func isSameNetwork(_ host1: String, _ host2: String) -> Bool {
        let components1 = host1.split(separator: ".")
        let components2 = host2.split(separator: ".")

        guard components1.count >= 3, components2.count >= 3 else { return false }

        return components1[0] == components2[0] &&
               components1[1] == components2[1] &&
               components1[2] == components2[2]
    }

    /// Get all connections for a specific service node
    func getConnections(for node: ServiceNode) -> (incoming: [ServiceConnection], outgoing: [ServiceConnection]) {
        let key = "\(node.host):\(node.port)"

        let incoming = connections.filter {
            "\($0.destHost):\($0.destPort)" == key
        }

        let outgoing = connections.filter {
            "\($0.sourceHost):\($0.sourcePort)" == key
        }

        return (incoming, outgoing)
    }

    /// Get services grouped by category
    func getServicesByCategory() -> [ServiceCategory: [ServiceNode]] {
        Dictionary(grouping: serviceNodes, by: { $0.category })
    }

    /// Get dependency chain starting from a service
    func getDependencyChain(from node: ServiceNode, maxDepth: Int = 5) -> [[ServiceNode]] {
        var chains: [[ServiceNode]] = []
        var visited = Set<String>()

        func traverse(current: ServiceNode, chain: [ServiceNode], depth: Int) {
            if depth > maxDepth { return }

            let key = current.uniqueKey
            if visited.contains(key) { return }
            visited.insert(key)

            var newChain = chain
            newChain.append(current)

            let (_, outgoing) = getConnections(for: current)

            if outgoing.isEmpty {
                chains.append(newChain)
            } else {
                for connection in outgoing {
                    if let nextNode = serviceNodes.first(where: {
                        $0.host == connection.destHost && $0.port == connection.destPort
                    }) {
                        traverse(current: nextNode, chain: newChain, depth: depth + 1)
                    }
                }
            }
        }

        traverse(current: node, chain: [], depth: 0)
        return chains
    }
}
