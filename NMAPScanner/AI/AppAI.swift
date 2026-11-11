//
//  AppAI.swift
//  NMAPScanner
//
//  The app's one AI object (NovaAIKit 1.0.0). Settings persist in UserDefaults (no secrets); API keys live only in
//  the Keychain under com.jkoch.nmapscanner.<backend>. Backends: Auto, Ollama, MLX, TinyLLM, TinyChat, OpenWebUI,
//  Nova Gateway, OpenRouter, OpenAI. Every AI feature has a built-in (rule-based) result for when AI is off,
//  unreachable, or its reply fails validation — see BuiltInSecurityAnalysis.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    nonisolated static let appID = "nmapscanner"
    nonisolated static let appName = "NMAPScanner"

    static let shared: NovaAI = {
        let ai = NovaAI(configuration: NovaAIConfiguration(appID: appID, appName: appName))
        AppAI.migrateLegacy(ai)
        return ai
    }()

    /// Unit tests swap in a NovaAI with in-memory storage and a stub URLSession. Production code never sets it.
    static var testOverride: NovaAI?

    /// The NovaAI every feature calls.
    static var current: NovaAI { testOverride ?? shared }

    /// Shown under the AI settings.
    static let settingsFooter = "When AI is off or unreachable, NMAPScanner uses its built-in rule-based analysis: "
        + "threat findings from open ports, backdoor/remote-access/database port rules, rogue-device detection, "
        + "keyword device search and a template network report. Scan data is only sent to the backend you choose."
}

// MARK: - Asking

extension AppAI {
    /// Validated AI reply text, or nil when the caller must use its built-in result (AI off, every backend down,
    /// or the reply failed `validate` twice). Never throws, never hangs past the configured timeouts.
    static func reply(prompt: String, system: String?, temperature: Double, maxTokens: Int,
                      validate: @escaping @Sendable (String) throws -> String = AppAI.validText) async -> String? {
        let request = NovaAIRequest(prompt: prompt, system: system, temperature: temperature, maxTokens: maxTokens)
        let result = await current.text(request, validate: validate) { "" }
        return result.isAI ? result.value : nil
    }

    /// Where the last AI-feature value came from ("AI · Ollama (qwen3:8b)" / "Built-in").
    static var lastSourceLabel: String { current.status.lastSource?.label ?? "—" }
}

// MARK: - Validators (pure, testable)

extension AppAI {
    /// Longest reply any feature accepts (characters).
    nonisolated static let maxReplyCharacters = 16_000

    /// Default validator for prose (reports, analysis, documentation, chat): non-empty, at least a sentence long,
    /// no leftover reasoning, capped length.
    nonisolated static let validText: @Sendable (String) throws -> String = { raw in
        guard let text = NovaAIText.clean(raw, max: maxReplyCharacters) else {
            throw NovaAIValidationError("empty reply")
        }
        guard text.count >= 20 else { throw NovaAIValidationError("reply too short to be useful") }
        return text
    }

    /// Validator for replies that must contain labelled lines (e.g. `Severity:`), case-insensitive.
    nonisolated static func requiring(_ labels: [String]) -> @Sendable (String) throws -> String {
        { raw in
            let text = try validText(raw)
            let lower = text.lowercased()
            for label in labels where !lower.contains(label.lowercased()) {
                throw NovaAIValidationError("reply must include a '\(label)' line")
            }
            return text
        }
    }

    /// Device risk: must state a risk level (Critical/High/Medium/Low/Safe).
    nonisolated static let validRiskReply: @Sendable (String) throws -> String = { raw in
        let text = try validText(raw)
        let lower = text.lowercased()
        guard ["critical", "high", "medium", "low", "safe"].contains(where: { lower.contains($0) }) else {
            throw NovaAIValidationError("reply must state a risk level: Critical, High, Medium, Low or Safe")
        }
        return text
    }

    /// Anomaly verdicts: a Suspicious/Concerning yes-no line and a Severity line with a known level.
    nonisolated static let validAnomalyVerdict: @Sendable (String) throws -> String = { raw in
        let text = try validText(raw).lowercased()
        guard text.contains("suspicious:") || text.contains("concerning:") else {
            throw NovaAIValidationError("reply must include 'Suspicious: Yes/No'")
        }
        guard let line = text.components(separatedBy: .newlines).first(where: { $0.contains("severity:") }),
              ["critical", "high", "medium", "low"].contains(where: { line.contains($0) }) else {
            throw NovaAIValidationError("Severity must be Critical, High, Medium or Low")
        }
        return try validText(raw)
    }

    /// Device query: the `Matches:` line may only name device numbers 1...deviceCount (or none).
    nonisolated static func validQueryReply(deviceCount: Int) -> @Sendable (String) throws -> String {
        { raw in
            let text = try requiring(["Matches:"])(raw)
            guard let line = text.components(separatedBy: .newlines)
                .first(where: { $0.lowercased().trimmingCharacters(in: .whitespaces).hasPrefix("matches:") }) else {
                throw NovaAIValidationError("reply must start a line with 'Matches:'")
            }
            let numbers = line.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            if let bad = numbers.first(where: { $0 < 1 || $0 > deviceCount }) {
                throw NovaAIValidationError("device number \(bad) does not exist (valid: 1-\(deviceCount))")
            }
            return text
        }
    }
}

// MARK: - One-time migration of the old AIBackendManager settings and keys

extension AppAI {
    /// Old NMAPScanner-only UserDefaults keys (the kit migrates the shared ones itself).
    nonisolated static let legacyURLKeys: [String: NovaAIBackend] = [
        "AIBackendManager_TinyLLMServerURL": .tinyLLM,
        "AIBackendManager_TinyChatServerURL": .tinyChat,
        "AIBackendManager_OpenWebUIServerURL": .openWebUI,
        "AIBackendManager_NovaGatewayURL": .novaGateway,
    ]
    nonisolated static let legacyOpenRouterModelKey = "AIBackendManager_SelectedOpenRouterModel"
    /// Settings of the removed MLX-Python / load-balancer code. No successor; deleted.
    nonisolated static let legacyObsoleteKeys = [
        "AIBackendManager_PythonPath", "AIBackendManager_MLXScriptPath", "AIBackendManager_UseAllLocalModels",
        "AIBackendManager_EnableAllFrontierModels", "AIBackendManager_UseNovaGateway",
    ]
    nonisolated static let legacyMarkerKey = "NMAPScanner.legacyAIMigrated"

    static func migrateLegacy(_ ai: NovaAI, defaults: UserDefaults = .standard) {
        // 3a. Shared AIBackendManager keys: backend, Ollama model, on/off, plaintext OpenAI key → Keychain,
        //     removed Google/Azure/AWS/IBM secrets and the guardian prompt log → deleted (security fix).
        ai.migrateFromLegacyAIBackendManager(defaults: defaults)

        // NMAPScanner's own key names, once.
        if !defaults.bool(forKey: legacyMarkerKey) {
            var s = ai.settings
            for (key, backend) in legacyURLKeys {
                if let v = defaults.string(forKey: key), !v.isEmpty, v != backend.defaultURL { s.setURL(v, for: backend) }
            }
            if let m = defaults.string(forKey: legacyOpenRouterModelKey), !m.isEmpty { s.setModel(m, for: .openRouter) }
            ai.settings = s
            for key in Array(legacyURLKeys.keys) + [legacyOpenRouterModelKey] + legacyObsoleteKeys
                + ["AIBackendManager_SelectedBackend", "AIBackendManager_OllamaModel"] {
                defaults.removeObject(forKey: key)
            }
            defaults.set(true, forKey: legacyMarkerKey)
        }

        // 3b. The OpenRouter key already lives at com.jkoch.nmapscanner.openrouter / apiKey — the kit's own name,
        //     so nothing moves. The old AIBackendManager kept no other Keychain items.
        // 3c. Delete removed backends' secrets if an old build ever wrote them (deletes only; never reads values out).
        //     The shared AIBackendManager template used the bundle id as its service.
        ai.keys.deleteObsoleteLegacyItems(service: "com.digitalnoise.nmapscanner")
    }
}
