//
//  MLXInferenceEngine.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Core MLX inference engine for on-device AI features.
//  Handles model loading, prompt engineering, and response generation.
//

import Foundation
import SwiftUI

// MARK: - MLX Inference Engine

@MainActor
class MLXInferenceEngine: ObservableObject {
    static let shared = MLXInferenceEngine()

    @Published var isModelLoaded: Bool = false
    @Published var isInferencing: Bool = false
    @Published var lastError: String? = nil

    private let modelPath: String
    private let pythonPath: String
    private let capabilityDetector = MLXCapabilityDetector.shared

    private init() {
        self.modelPath = NSHomeDirectory() + "/.mlx/models/phi-3.5-mini"
        self.pythonPath = capabilityDetector.getPythonPath()
    }

    // MARK: - Core Inference

    /// Generate text completion using MLX
    func generate(
        prompt: String,
        maxTokens: Int = 1000,
        temperature: Float = 0.7,
        systemPrompt: String? = nil
    ) async throws -> String {
        guard capabilityDetector.isMLXAvailable else {
            throw MLXError.notAvailable
        }

        isInferencing = true
        defer { isInferencing = false }

        let fullPrompt = buildPrompt(user: prompt, system: systemPrompt)

        // Create Python script for inference
        let script = """
        import sys
        import mlx_lm

        model_path = "\(modelPath)"
        prompt = '''
        \(fullPrompt)
        '''

        try:
            model, tokenizer = mlx_lm.load(model_path)
            response = mlx_lm.generate(
                model,
                tokenizer,
                prompt=prompt,
                max_tokens=\(maxTokens),
                verbose=False
            )
            print(response)
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)
        """

        return try await runPythonScript(script)
    }

    /// Stream text generation (for chat interfaces)
    func generateStream(
        prompt: String,
        maxTokens: Int = 1000,
        temperature: Float = 0.7,
        systemPrompt: String? = nil,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard capabilityDetector.isMLXAvailable else {
            throw MLXError.notAvailable
        }

        isInferencing = true
        defer { isInferencing = false }

        let fullPrompt = buildPrompt(user: prompt, system: systemPrompt)

        let script = """
        import sys
        import mlx_lm

        model_path = "\(modelPath)"
        prompt = '''
        \(fullPrompt)
        '''

        try:
            model, tokenizer = mlx_lm.load(model_path)
            for response in mlx_lm.stream_generate(model, tokenizer, prompt=prompt, max_tokens=\(maxTokens)):
                print(response.text, end='', flush=True)
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)
        """

        try await runPythonScriptStreaming(script, onToken: onToken)
    }

    // MARK: - Prompt Engineering

    private func buildPrompt(user: String, system: String?) -> String {
        if let system = system {
            return """
            <|system|>
            \(system)

            <|user|>
            \(user)

            <|assistant|>
            """
        } else {
            return """
            <|user|>
            \(user)

            <|assistant|>
            """
        }
    }

    // MARK: - Python Execution

    private func runPythonScript(_ script: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if process.terminationStatus != 0 {
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw MLXError.inferenceError(errorMessage)
            }

            guard let output = String(data: outputData, encoding: .utf8) else {
                throw MLXError.decodingError
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw MLXError.executionError(error.localizedDescription)
        }
    }

    private func runPythonScriptStreaming(_ script: String, onToken: @escaping (String) -> Void) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                Task { @MainActor in
                    onToken(text)
                }
            }
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw MLXError.inferenceError(errorMessage)
        }
    }
}

// MARK: - MLX Errors

enum MLXError: LocalizedError {
    case notAvailable
    case modelNotFound
    case inferenceError(String)
    case decodingError
    case executionError(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "MLX is not available on this system. Apple Silicon (M1/M2/M3/M4) required."
        case .modelNotFound:
            return "MLX model not found. Please download a model first."
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .decodingError:
            return "Failed to decode model output"
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
