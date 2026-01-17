//
//  MLXInferenceEngine.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//  Updated by Jordan Koch on 2025-01-17 - Added multi-backend support
//
//  Core AI inference engine for on-device security features.
//  Now supports Ollama, MLX Toolkit, and TinyLLM (by Jason Cox).
//

import Foundation
import SwiftUI

// MARK: - AI Inference Engine

@MainActor
class MLXInferenceEngine: ObservableObject {
    static let shared = MLXInferenceEngine()

    @Published var isModelLoaded: Bool = false
    @Published var isInferencing: Bool = false
    @Published var lastError: String? = nil

    private let aiBackend = AIBackendManager.shared
    private let capabilityDetector = MLXCapabilityDetector.shared

    private init() {
        // Check backend availability
        Task {
            await aiBackend.checkBackendAvailability()
            self.isModelLoaded = aiBackend.activeBackend != nil
        }
    }

    // MARK: - Core Inference

    /// Generate text completion using AI Backend (Ollama, MLX, or TinyLLM by Jason Cox)
    func generate(
        prompt: String,
        maxTokens: Int = 1000,
        temperature: Float = 0.7,
        systemPrompt: String? = nil
    ) async throws -> String {
        guard aiBackend.activeBackend != nil else {
            throw MLXError.notAvailable
        }

        isInferencing = true
        defer { isInferencing = false }

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
            return response
        } catch {
            lastError = error.localizedDescription
            throw MLXError.inferenceError(error.localizedDescription)
        }
    }

    /// Stream text generation (for chat interfaces)
    /// Note: Streaming not yet implemented in AIBackendManager
    func generateStream(
        prompt: String,
        maxTokens: Int = 1000,
        temperature: Float = 0.7,
        systemPrompt: String? = nil,
        onToken: @escaping (String) -> Void
    ) async throws {
        // For now, use non-streaming generate and call onToken once
        let response = try await generate(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature,
            systemPrompt: systemPrompt
        )

        // Call onToken with full response
        onToken(response)

        // TODO: Add streaming support to AIBackendManager for real-time tokens
    }
}

// MARK: - AI Errors

enum MLXError: LocalizedError {
    case notAvailable
    case modelNotFound
    case inferenceError(String)
    case decodingError
    case executionError(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "No AI backend available. Install Ollama, TinyLLM (by Jason Cox), or MLX Toolkit."
        case .modelNotFound:
            return "AI model not found. Please configure a backend in Settings (⌘⌥A)."
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .decodingError:
            return "Failed to decode AI output"
        case .executionError(let message):
            return "Execution error: \(message)"
        }
    }
}

// MARK: - Inference Response

struct InferenceResponse {
    let text: String
    let tokensGenerated: Int
    let inferenceTime: TimeInterval
}
