//
//  AIBackendManager+LoadBalancer.swift
//  NMAPScanner
//
//  Extends the existing AIBackendManager with the shared multi-model LLM load
//  balancer ported from AIStudio: OpenRouter frontier models, the optional Nova
//  Gateway backend, and balanced dispatch across every installed local model
//  (Ollama + MLX). Mirrors AIStudio's `LLMBackendManager` balanced-dispatch wiring.
//
//  Hard invariant: Nova is NEVER required. Nova Gateway is one optional backend; a
//  failed health check simply drops it from the pool and everything else works. The
//  original Ollama / MLX / TinyLLM / TinyChat / OpenWebUI paths are untouched.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

extension AIBackendManager {

    // MARK: - Balancing state

    /// True when any load-balancing toggle is on, so a request should be dispatched
    /// through the balanced path rather than the single-backend path.
    var isBalancingEnabled: Bool {
        useAllLocalModels || enableAllFrontierModels || useNovaGateway
    }

    // MARK: - OpenRouter key (Keychain — never UserDefaults)

    /// Store (or clear) the OpenRouter API key in the login Keychain.
    func setOpenRouterAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            openRouterKeychain.delete()
        } else {
            openRouterKeychain.set(trimmed)
        }
    }

    /// The stored OpenRouter API key, if any.
    func openRouterAPIKey() -> String? {
        openRouterKeychain.get()
    }

    /// True if a non-empty OpenRouter key is stored.
    var hasOpenRouterKey: Bool {
        openRouterKeychain.hasValue
    }

    // MARK: - Availability (OpenRouter + Nova Gateway)

    /// OpenRouter is available when a key is stored and the `/models` listing
    /// responds 200. Any failure → unavailable (never throws).
    func checkOpenRouterAvailability() async -> Bool {
        guard let key = openRouterAPIKey(), !key.isEmpty,
              let url = URL(string: OpenRouterProvider.modelsURL) else { return false }
        var request = URLRequest(url: url)
        for (header, value) in OpenRouterProvider.authHeaders(apiKey: key) {
            request.setValue(value, forHTTPHeaderField: header)
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Nova Gateway is available when its OpenAI-compatible `/v1/models` (or base
    /// URL) responds 200. Any failure → unavailable — Nova is never required.
    func checkNovaGatewayAvailability() async -> Bool {
        let base = novaGatewayURL.isEmpty ? ModelRegistry.novaGatewayDefaultURL : novaGatewayURL
        let candidates = ["\(base)/v1/models", "\(base)/"].compactMap { URL(string: $0) }
        for url in candidates {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 { return true }
            } catch {
                continue
            }
        }
        return false
    }

    /// Fetch the OpenRouter model list for the picker; falls back to the hardcoded
    /// popular-models list if the fetch fails.
    func fetchOpenRouterModels() async {
        guard let key = openRouterAPIKey(), !key.isEmpty,
              let url = URL(string: OpenRouterProvider.modelsURL) else {
            openRouterModels = OpenRouterProvider.fallbackModels
            return
        }
        var request = URLRequest(url: url)
        for (header, value) in OpenRouterProvider.authHeaders(apiKey: key) {
            request.setValue(value, forHTTPHeaderField: header)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                openRouterModels = OpenRouterProvider.fallbackModels
                return
            }
            let models = OpenRouterProvider.parseModels(data)
            openRouterModels = models.isEmpty ? OpenRouterProvider.fallbackModels : models
            if !openRouterModels.contains(selectedOpenRouterModel) {
                selectedOpenRouterModel = openRouterModels.first ?? OpenRouterProvider.defaultModel
            }
        } catch {
            openRouterModels = OpenRouterProvider.fallbackModels
        }
    }

    // MARK: - Multi-model load balancing

    /// Live availability for a single backend, used to build the health map.
    private func backendAvailable(_ backend: AIBackend) -> Bool {
        switch backend {
        case .ollama: return isOllamaAvailable
        case .mlx: return isMLXAvailable
        case .tinyLLM: return isTinyLLMAvailable
        case .tinyChat: return isTinyChatAvailable
        case .openWebUI: return isOpenWebUIAvailable
        case .openRouter: return isOpenRouterAvailable
        case .novaGateway: return isNovaGatewayAvailable
        case .auto: return false
        }
    }

    /// Discover the enabled balancer pool honoring the three toggles. Resilient:
    /// any unreachable source contributes zero models.
    func discoverEnabledPool() async -> [DiscoveredModel] {
        var ollama: [DiscoveredModel] = []
        var mlx: [DiscoveredModel] = []
        var frontier: [DiscoveredModel] = []

        if useAllLocalModels {
            ollama = await ModelRegistry.discoverOllama()
            mlx = ModelRegistry.discoverMLX()
        }
        if enableAllFrontierModels {
            // Reuse the already-fetched OpenRouter list (falls back to the popular set).
            frontier = ModelRegistry.frontierModels(from: openRouterModels)
        }
        let novaURL = novaGatewayURL.isEmpty ? ModelRegistry.novaGatewayDefaultURL : novaGatewayURL
        let nova = useNovaGateway ? ModelRegistry.novaGatewayModel(url: novaURL) : nil

        return ModelRegistry.assemblePool(
            ollama: ollama,
            mlx: mlx,
            frontier: frontier,
            novaGateway: nova,
            useAllLocalModels: useAllLocalModels,
            enableAllFrontierModels: enableAllFrontierModels,
            useNovaGateway: useNovaGateway
        )
    }

    /// Build a `[modelId: Bool]` health map for `pool` from the current per-backend
    /// availability flags (health-gating, composed with `FailoverPlanner` semantics).
    private func healthMap(for pool: [DiscoveredModel]) -> [String: Bool] {
        var map: [String: Bool] = [:]
        for model in pool {
            map[model.id] = backendAvailable(model.backend)
        }
        return map
    }

    /// Balanced dispatch: refresh availability, pick a model via the `LoadBalancer`
    /// over the healthy enabled pool, and route it through the appropriate backend.
    /// Returns nil when no pool/healthy model exists so the caller can fall back.
    func generateBalanced(
        prompt: String,
        systemPrompt: String?,
        temperature: Float,
        maxTokens: Int
    ) async throws -> String? {
        // Refresh availability so the health map reflects live reachability.
        await checkBackendAvailability()

        let pool = await discoverEnabledPool()
        guard !pool.isEmpty else { return nil }

        let health = healthMap(for: pool)
        var remaining = pool
        var lastError: Error?

        // Try balancer-selected models, falling through on failure.
        while let choice = balancer.next(pool: remaining, health: health, policy: balancerPolicy) {
            balancer.checkOut(choice.id)
            do {
                let result = try await dispatchBalanced(
                    model: choice,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens
                )
                balancer.checkIn(choice.id)
                return result
            } catch {
                balancer.checkIn(choice.id)
                lastError = error
                remaining.removeAll { $0.id == choice.id }
                continue
            }
        }

        // Nothing healthy in the pool — let the caller fall back cleanly.
        if let lastError = lastError { throw lastError }
        return nil
    }

    /// Route a single balancer-selected model through the appropriate backend
    /// implementation (all OpenAI-compatible backends ride the generic path).
    private func dispatchBalanced(
        model: DiscoveredModel,
        prompt: String,
        systemPrompt: String?,
        temperature: Float,
        maxTokens: Int
    ) async throws -> String {
        switch model.backend {
        case .ollama:
            return try await generateWithOllama(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                model: model.modelName
            )
        case .mlx:
            return try await generateWithMLX(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        case .openRouter:
            return try await generateWithOpenRouter(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                model: model.modelName,
                endpoint: model.endpoint
            )
        case .novaGateway:
            return try await generateWithNovaGateway(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                endpoint: model.endpoint
            )
        default:
            throw AIBackendError.noBackendAvailable
        }
    }

    // MARK: - OpenAI-compatible backends (OpenRouter + Nova Gateway)

    /// Non-streaming generation against a full OpenAI-compatible endpoint URL.
    private func generateOpenAICompatible(
        endpoint: String,
        model: String,
        headers: [String: String],
        prompt: String,
        systemPrompt: String?,
        temperature: Float,
        maxTokens: Int
    ) async throws -> String {
        let apiMessages = OpenAICompatibleRequest.chatMessages(prompt: prompt, systemPrompt: systemPrompt)
        var request = try OpenAICompatibleRequest.build(
            endpoint: endpoint,
            model: model,
            messages: apiMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false,
            headers: headers
        )
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return apiResponse.choices.first?.message.content ?? ""
    }

    /// Generate against OpenRouter (frontier models). Uses the balancer-selected
    /// model + endpoint when provided, else the picker selection.
    func generateWithOpenRouter(
        prompt: String,
        systemPrompt: String?,
        temperature: Float,
        maxTokens: Int,
        model: String? = nil,
        endpoint: String? = nil
    ) async throws -> String {
        guard let key = openRouterAPIKey(), !key.isEmpty else {
            throw AIBackendError.noBackendAvailable
        }
        return try await generateOpenAICompatible(
            endpoint: endpoint ?? OpenRouterProvider.chatCompletionsURL,
            model: model ?? selectedOpenRouterModel,
            headers: OpenRouterProvider.authHeaders(apiKey: key),
            prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Generate against the optional Nova Gateway (OpenAI-compatible; Nova inherits
    /// her own internal routing). Never required — fails cleanly when unreachable.
    func generateWithNovaGateway(
        prompt: String,
        systemPrompt: String?,
        temperature: Float,
        maxTokens: Int,
        endpoint: String? = nil
    ) async throws -> String {
        let base = novaGatewayURL.isEmpty ? ModelRegistry.novaGatewayDefaultURL : novaGatewayURL
        return try await generateOpenAICompatible(
            endpoint: endpoint ?? "\(base)/v1/chat/completions",
            model: "nova",
            headers: [:],
            prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
