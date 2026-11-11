//
//  AIKitAdoptionTests.swift
//  NMAPScannerTests
//
//  NMAPScanner's contract with NovaAIKit 1.0.0, in the repo's seven categories: unit, security, retry,
//  integration, functional, performance and frame (UI state). No real Keychain and no real network: every NovaAI
//  here uses in-memory settings/keys and a stub URLProtocol.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
import SwiftUI
import NovaAIKit
@testable import NMAPScanner

// MARK: - Test support

/// Answers like a local Ollama server. `reply` decides the chat text (nil = connection refused).
final class StubOllamaProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _reply: ((String) -> String?)?
    private static var _chatCount = 0

    static func respond(_ reply: ((String) -> String?)?) {
        lock.lock(); _reply = reply; _chatCount = 0; lock.unlock()
    }
    static var chatCount: Int { lock.lock(); defer { lock.unlock() }; return _chatCount }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buf = [UInt8](repeating: 0, count: 65_536)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                body.append(buf, count: n)
            }
            stream.close()
        }
        Self.lock.lock()
        let handler = Self._reply
        if path.hasSuffix("/api/chat") { Self._chatCount += 1 }
        Self.lock.unlock()

        guard let handler else { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)); return }
        let json: String
        if path.hasSuffix("/api/chat") {
            guard let text = handler(String(decoding: body, as: UTF8.self)) else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)); return
            }
            let quoted = String(data: try! JSONSerialization.data(withJSONObject: [text]), encoding: .utf8)!.dropFirst().dropLast()
            json = #"{"model":"qwen3:8b","message":{"role":"assistant","content":"# + quoted + #"},"done":true}"#
        } else {
            json = #"{"models":[{"name":"qwen3:8b"}]}"#
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((json + "\n").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Fails every request (all backends down).
final class RefuseAllProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)) }
    override func stopLoading() {}
}

enum AITestSupport {
    static let config = NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName)

    @MainActor
    static func makeAI(_ s: NovaAISettings = NovaAISettings(), protocolClass: AnyClass = RefuseAllProtocol.self,
                       keys: NovaAIMemoryKeyStore = NovaAIMemoryKeyStore()) -> NovaAI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [protocolClass]
        return NovaAI(configuration: config, storage: NovaAIMemoryStorage(s), keyStore: keys,
                      session: URLSession(configuration: cfg), sleep: { _ in })
    }

    /// AI on, Ollama only, answered by `StubOllamaProtocol`.
    @MainActor
    static func stubbedOllama(_ reply: @escaping (String) -> String?) -> NovaAI {
        StubOllamaProtocol.respond(reply)
        return makeAI(NovaAISettings(backend: .ollama), protocolClass: StubOllamaProtocol.self)
    }

    static func port(_ p: Int, _ service: String) -> PortInfo {
        PortInfo(port: p, service: service, version: nil, state: .open, protocolType: "TCP", banner: nil)
    }

    static func device(_ ip: String, mac: String? = nil, name: String? = nil, ports: [PortInfo] = [],
                       known: Bool = true, type: EnhancedDevice.DeviceType = .unknown) -> EnhancedDevice {
        EnhancedDevice(ipAddress: ip, macAddress: mac, hostname: name, manufacturer: nil, deviceType: type,
                       openPorts: ports, isOnline: true, firstSeen: known ? Date(timeIntervalSinceNow: -86_400) : Date(),
                       lastSeen: Date(), isKnownDevice: known, operatingSystem: nil, deviceName: nil)
    }

    /// A small network: a router, a box with telnet + a backdoor port (rogue), a printer.
    static var network: [EnhancedDevice] {
        [device("192.168.1.1", mac: testMAC("01"), name: "router", ports: [port(443, "https")], type: .router),
         device("192.168.1.50", mac: testMAC("50"), name: "mystery-box",
                ports: [port(23, "telnet"), port(31337, "BackOrifice")], known: false),
         device("192.168.1.80", mac: testMAC("80"), name: "office-printer", ports: [port(9100, "jetdirect")], type: .printer)]
    }
}

// MARK: - Unit

final class AIKitUnitTests: XCTestCase {
    func testKeychainServiceNames() {
        let c = AITestSupport.config
        XCTAssertEqual(c.appID, "nmapscanner")
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.nmapscanner.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.nmapscanner.openai")
        XCTAssertEqual(NovaAIConfiguration.keychainAccount, "apiKey")
    }

    func testTextValidatorRejectsEmptyShortAndThinkOnly() {
        XCTAssertThrowsError(try AppAI.validText(""))
        XCTAssertThrowsError(try AppAI.validText("   \n "))
        XCTAssertThrowsError(try AppAI.validText("ok"))
        XCTAssertThrowsError(try AppAI.validText("<think>reasoning only</think>"))
        XCTAssertEqual(try AppAI.validText("<think>x</think>The router exposes HTTPS only."), "The router exposes HTTPS only.")
    }

    func testTextValidatorCapsLength() throws {
        let long = String(repeating: "a", count: AppAI.maxReplyCharacters + 500)
        XCTAssertEqual(try AppAI.validText(long).count, AppAI.maxReplyCharacters)
    }

    func testQueryValidatorRejectsInventedDeviceNumbers() {
        let v = AppAI.validQueryReply(deviceCount: 3)
        XCTAssertNoThrow(try v("Matches: 1, 3\nExplanation: printers and routers\nSummary: two"))
        XCTAssertNoThrow(try v("Matches: none\nExplanation: nothing matches the query\nSummary: zero"))
        XCTAssertThrowsError(try v("Matches: 2, 7\nExplanation: device seven is risky\nSummary: two"))
        XCTAssertThrowsError(try v("Matches: 0\nExplanation: device zero is invalid\nSummary: one"))
        XCTAssertThrowsError(try v("The printers are devices one and three, I think."))
    }

    func testAnomalyValidatorNeedsVerdictAndKnownSeverity() {
        XCTAssertNoThrow(try AppAI.validAnomalyVerdict("Suspicious: Yes\nSeverity: High\nExplanation: unknown vendor"))
        XCTAssertThrowsError(try AppAI.validAnomalyVerdict("Severity: High\nExplanation: no verdict line here"))
        XCTAssertThrowsError(try AppAI.validAnomalyVerdict("Suspicious: Yes\nSeverity: Apocalyptic\nExplanation: x"))
    }

    func testRiskValidatorNeedsRiskLevel() {
        XCTAssertNoThrow(try AppAI.validRiskReply("Risk level: Medium — telnet is open."))
        XCTAssertThrowsError(try AppAI.validRiskReply("This device is a printer made by a vendor."))
    }

    func testRequiringValidator() {
        let v = AppAI.requiring(["Title:", "Priority:"])
        XCTAssertNoThrow(try v("Title: Disable telnet\nPriority: High\nReason: cleartext"))
        XCTAssertThrowsError(try v("Title: Disable telnet\nReason: cleartext logins"))
    }

    func testClassificationValidatorClampsFields() throws {
        let d = AITestSupport.device("10.0.0.2", name: "host")
        let reply = "Type: Printer\nManufacturer: \(String(repeating: "X", count: 500))\nModel: **LaserJet**\nName: Office\nConfidence: High\nReasoning: port 9100"
        let c = try MLXDeviceClassifier.validatedClassification(reply, device: d)
        XCTAssertEqual(c.identifiedType, "Printer")
        XCTAssertEqual(c.manufacturer.count, 80)
        XCTAssertEqual(c.model, "LaserJet")
        XCTAssertEqual(c.confidence, .high)
        XCTAssertThrowsError(try MLXDeviceClassifier.validatedClassification("I think it is a printer.", device: d))
    }

    func testQueryParserMapsDeviceNumbers() {
        let devices = AITestSupport.network
        let r = MLXQueryInterface.parseQueryResponse("Matches: 1, 3\nExplanation: e\nSummary: s", devices: devices, query: "q")
        XCTAssertEqual(r.matchingDevices.map(\.ipAddress), ["192.168.1.1", "192.168.1.80"])
    }

    func testAnomalyParserIgnoresNonSuspicious() {
        XCTAssertNil(MLXAnomalyDetector.parseAnomalyResponse("Suspicious: No\nSeverity: Low", type: .newDevice,
                                                             affectedDevice: nil, detectedDate: Date()))
        let a = MLXAnomalyDetector.parseAnomalyResponse("Suspicious: Yes\nSeverity: Critical\nExplanation: e\nRecommendation: r",
                                                        type: .newDevice, affectedDevice: nil, detectedDate: Date())
        XCTAssertEqual(a?.severity, .critical)
    }

    @MainActor
    func testChatMessagesKeepRolesAndOrder() {
        let history = [ChatMessage(role: .assistant, content: "Hi", timestamp: Date()),
                       ChatMessage(role: .user, content: "Is telnet bad?", timestamp: Date()),
                       ChatMessage(role: .assistant, content: "", timestamp: Date())]
        let m = MLXSecurityAssistant.chatMessages(system: "sys", history: history, user: "Why?")
        XCTAssertEqual(m.map(\.role), [.system, .assistant, .user, .user])
        XCTAssertEqual(m.last?.content, "Why?")
    }
}

// MARK: - Security

final class AIKitSecurityTests: XCTestCase {
    private func suite() -> UserDefaults {
        let name = "nmapscanner.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    /// The old AIBackendManager left a plaintext OpenAI key and removed-cloud secrets in UserDefaults.
    @MainActor
    func testLegacyPlaintextKeysLeaveUserDefaults() {
        let defaults = suite()
        defaults.set("sk-test-not-real", forKey: "AIBackend_OpenAI_Key")
        defaults.set("gcloud-not-real", forKey: "AIBackend_GoogleCloud_Key")
        defaults.set("[]", forKey: "AIGuardian_UsageLog")
        let keys = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(keys: keys)
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: "AIBackend_OpenAI_Key"))
        XCTAssertNil(defaults.object(forKey: "AIBackend_GoogleCloud_Key"))
        XCTAssertNil(defaults.object(forKey: "AIGuardian_UsageLog"))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        XCTAssertNotNil(keys.read(service: "com.jkoch.nmapscanner.openai", account: "apiKey"))
    }

    @MainActor
    func testLegacySettingsMigrateOnce() {
        let defaults = suite()
        defaults.set("Ollama", forKey: "AIBackendManager_SelectedBackend")
        defaults.set("llama3.2:3b", forKey: "AIBackendManager_OllamaModel")
        defaults.set("http://tiny.local:9000", forKey: "AIBackendManager_TinyLLMServerURL")
        defaults.set("http://nova-core.digitalnoise.net:37475", forKey: "AIBackendManager_NovaGatewayURL")
        defaults.set("openai/gpt-4o", forKey: "AIBackendManager_SelectedOpenRouterModel")
        defaults.set("/opt/homebrew/bin/python3", forKey: "AIBackendManager_PythonPath")
        let ai = AITestSupport.makeAI()
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertEqual(ai.settings.backend, .ollama)
        XCTAssertEqual(ai.settings.model(for: .ollama), "llama3.2:3b")
        XCTAssertEqual(ai.settings.url(for: .tinyLLM), "http://tiny.local:9000")
        XCTAssertEqual(ai.settings.url(for: .novaGateway), "http://nova-core.digitalnoise.net:37475")
        XCTAssertEqual(ai.settings.model(for: .openRouter), "openai/gpt-4o")
        XCTAssertNil(defaults.object(forKey: "AIBackendManager_PythonPath"))
        XCTAssertNil(defaults.object(forKey: "AIBackendManager_TinyLLMServerURL"))
        XCTAssertTrue(defaults.bool(forKey: AppAI.legacyMarkerKey))

        // Second launch: the user's new choice is not overwritten.
        ai.settings.backend = .openRouter
        defaults.set("Ollama", forKey: "AIBackendManager_SelectedBackend")
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertEqual(ai.settings.backend, .openRouter)
    }

    /// Removed backends' Keychain secrets are deleted without being read out.
    @MainActor
    func testObsoleteKeychainItemsAreDeleted() {
        let keys = NovaAIMemoryKeyStore()
        _ = keys.write("x", service: "com.digitalnoise.nmapscanner", account: "awsSecretKey")
        _ = keys.write("y", service: "com.digitalnoise.nmapscanner", account: "unrelated")
        let ai = AITestSupport.makeAI(keys: keys)
        AppAI.migrateLegacy(ai, defaults: suite())
        XCTAssertNil(keys.read(service: "com.digitalnoise.nmapscanner", account: "awsSecretKey"))
        XCTAssertEqual(keys.read(service: "com.digitalnoise.nmapscanner", account: "unrelated"), "y")
    }

    /// A key is never sent over plain http.
    @MainActor
    func testKeyRefusedOverPlainHTTP() async {
        let keys = NovaAIMemoryKeyStore()
        var s = NovaAISettings(backend: .openAI)
        s.setURL("http://api.example.com/v1", for: .openAI)
        let ai = AITestSupport.makeAI(s, keys: keys)
        XCTAssertTrue(ai.setAPIKey("sk-test-not-real", for: .openAI))
        do {
            _ = try await ai.complete(NovaAIRequest(prompt: "hello"))
            XCTFail("must refuse")
        } catch {
            XCTAssertTrue("\(error)".contains("insecure") || (error as? NovaAIError).map {
                if case .insecureTransport = $0 { return true } else { return false } } ?? false
                || "\(error)".contains("http"), "\(error)")
        }
    }

    /// No old AI client code or environment-variable keys remain in the app's sources.
    func testNoLegacyAIClientInSources() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let banned = ["AIBackendManager", "EthicalAIGuardian", "AIBackendStatusMenu", "OPENAI_API_KEY",
                      "AIBackend_OpenAI_Key\"", "OpenRouterProvider", "KeychainStore(", "/api/generate", "chat/completions"]
        var hits: [String] = []
        for dir in ["NMAPScanner", "NMAPScanner Widget", "NMAPScanner LiveActivity"] {
            let url = root.appendingPathComponent(dir)
            guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let f as URL in e where f.pathExtension == "swift" {
                let text = try String(contentsOf: f, encoding: .utf8)
                for b in banned where text.contains(b) && !text.contains("migrateFromLegacyAIBackendManager") {
                    hits.append("\(f.lastPathComponent): \(b)")
                }
            }
        }
        XCTAssertEqual(hits, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("AIBackendManager.swift").path))
    }
}

// MARK: - Retry

final class AIKitRetryTests: XCTestCase {
    /// A reply that fails validation is re-asked once with the complaint; a second bad reply → built-in result.
    @MainActor
    func testRejectedReplyIsRetriedOnceThenFallsBack() async {
        let ai = AITestSupport.stubbedOllama { _ in "Matches: 42\nExplanation: invented device\nSummary: one" }
        AppAI.testOverride = ai
        defer { AppAI.testOverride = nil }
        let r = await MLXQueryInterface.shared.query("telnet", devices: AITestSupport.network)
        XCTAssertEqual(StubOllamaProtocol.chatCount, 2, "ask + one corrective retry")
        XCTAssertEqual(r?.matchingDevices.map(\.ipAddress), ["192.168.1.50"], "built-in keyword search")
        XCTAssertEqual(ai.status.lastSource?.isAI, false)
    }

    /// The retry carries the validator's complaint, and a good second answer is used.
    @MainActor
    func testCorrectedReplyIsAccepted() async {
        let ai = AITestSupport.stubbedOllama { body in
            body.contains("previous reply was rejected")
                ? "Matches: 3\nExplanation: the printer\nSummary: one printer"
                : "Matches: 9\nExplanation: wrong\nSummary: wrong"
        }
        AppAI.testOverride = ai
        defer { AppAI.testOverride = nil }
        let r = await MLXQueryInterface.shared.query("printer", devices: AITestSupport.network)
        XCTAssertEqual(StubOllamaProtocol.chatCount, 2)
        XCTAssertEqual(r?.matchingDevices.map(\.ipAddress), ["192.168.1.80"])
        XCTAssertEqual(ai.status.lastSource?.isAI, true)
    }
}

// MARK: - Integration (stubbed backend → feature)

final class AIKitIntegrationTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { AppAI.testOverride = nil }
        super.tearDown()
    }

    @MainActor
    func testThreatAnalysisUsesAIReply() async {
        AppAI.testOverride = AITestSupport.stubbedOllama { _ in
            "Summary: one rogue host exposes telnet.\n\nCritical / high priority threats:\n- 192.168.1.50 exposes telnet on port 23 in cleartext\n\nRecommendations:\n- Disable telnet on 192.168.1.50 and use SSH."
        }
        let r = await MLXThreatAnalyzer.shared.analyzeNetwork(devices: AITestSupport.network)
        XCTAssertTrue(r?.fullResponse.contains("telnet") ?? false)
        XCTAssertFalse(r?.threats.isEmpty ?? true)
        XCTAssertEqual(AppAI.current.status.lastSource?.isAI, true)
    }

    @MainActor
    func testDeviceClassificationUsesAIReplyAndCaches() async {
        AppAI.testOverride = AITestSupport.stubbedOllama { _ in
            "Type: Printer\nManufacturer: HP\nModel: LaserJet\nName: Office Printer\nConfidence: High\nReasoning: port 9100"
        }
        let d = AITestSupport.device("192.168.1.81", mac: testMAC("81"), ports: [AITestSupport.port(9100, "jetdirect")])
        let c = await MLXDeviceClassifier.shared.classifyDevice(d)
        XCTAssertEqual(c?.identifiedType, "Printer")
        XCTAssertEqual(MLXDeviceClassifier.shared.lastSource?.isAI, true)
        _ = await MLXDeviceClassifier.shared.classifyDevice(d)
        XCTAssertEqual(StubOllamaProtocol.chatCount, 1, "second call served from cache")
    }

    @MainActor
    func testChatStreamsAIReply() async {
        AppAI.testOverride = AITestSupport.stubbedOllama { _ in "Telnet sends passwords in cleartext; use SSH instead." }
        let a = MLXSecurityAssistant.shared
        a.clearConversation()
        await a.sendMessage("Is telnet safe?", networkDevices: AITestSupport.network)
        XCTAssertEqual(a.messages.last?.content, "Telnet sends passwords in cleartext; use SSH instead.")
        XCTAssertEqual(a.lastSource?.isAI, true)
    }

    @MainActor
    func testReportMixesAISections() async {
        AppAI.testOverride = AITestSupport.stubbedOllama { _ in "The network has one rogue device exposing telnet; overall risk is high." }
        let g = LLMSecurityReportGenerator.shared
        await g.generateReport(from: AITestSupport.network)
        XCTAssertEqual(g.aiSectionCount, 4)
        XCTAssertTrue(g.reportContent.contains("4 of 4 sections from AI"))
    }
}

// MARK: - Functional (AI off / every backend down → built-in results)

final class AIKitFunctionalTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { AppAI.testOverride = nil }
        super.tearDown()
    }

    @MainActor
    private func runAllFeatures(file: StaticString = #filePath, line: UInt = #line) async {
        let net = AITestSupport.network
        let threat = await MLXThreatAnalyzer.shared.analyzeNetwork(devices: net)
        XCTAssertTrue(threat?.summary.contains("Built-in") ?? false, file: file, line: line)
        XCTAssertTrue(threat?.threats.contains { $0.severity == .critical } ?? false, "backdoor port is critical", file: file, line: line)

        let dev = await MLXThreatAnalyzer.shared.analyzeDevice(net[1])
        XCTAssertEqual(dev?.riskLevel, .critical, file: file, line: line)

        let recs = await MLXSecurityRecommendations.shared.generateRecommendations(devices: net)
        XCTAssertGreaterThan(recs?.totalCount ?? 0, 1, file: file, line: line)
        XCTAssertFalse(recs?.critical.isEmpty ?? true, file: file, line: line)
        let devRecs = await MLXSecurityRecommendations.shared.generateDeviceRecommendations(net[1])
        XCTAssertFalse(devRecs.isEmpty, file: file, line: line)

        let q = await MLXQueryInterface.shared.query("printer", devices: net)
        XCTAssertEqual(q?.matchingDevices.map(\.ipAddress), ["192.168.1.80"], file: file, line: line)
        let rogue = await MLXQueryInterface.shared.query("rogue devices", devices: net)
        XCTAssertEqual(rogue?.matchingDevices.map(\.ipAddress), ["192.168.1.50"], file: file, line: line)

        let doc = await MLXDocumentationGenerator.shared.generateDocumentation(devices: net)
        XCTAssertTrue(doc?.content.contains("192.168.1.50") ?? false, file: file, line: line)
        XCTAssertTrue(doc?.content.contains("## Device Inventory") ?? false, file: file, line: line)
        let devDoc = await MLXDocumentationGenerator.shared.generateDeviceDocumentation(net[2])
        XCTAssertTrue(devDoc?.contains("9100") ?? false, file: file, line: line)

        let c = await MLXDeviceClassifier.shared.classifyDevice(AITestSupport.device("10.9.9.9", name: "nas"))
        XCTAssertEqual(c?.suggestedName, "nas", file: file, line: line)
        XCTAssertEqual(c?.confidence, .low, file: file, line: line)

        let detector = MLXAnomalyDetector.shared
        detector.establishBaseline(devices: [net[0], net[2]])
        let anomalies = await detector.detectAnomalies(currentDevices: net)
        XCTAssertTrue(anomalies.contains { $0.type == .newDevice && $0.severity == .critical }, file: file, line: line)

        let chat = MLXSecurityAssistant.shared
        chat.clearConversation()
        await chat.sendMessage("What should I fix first?", networkDevices: net)
        XCTAssertTrue(chat.messages.last?.content.contains("built-in analysis") ?? false, file: file, line: line)
        XCTAssertFalse(chat.isResponding, file: file, line: line)

        let report = LLMSecurityReportGenerator.shared
        await report.generateReport(from: net)
        XCTAssertEqual(report.aiSectionCount, 0, file: file, line: line)
        XCTAssertTrue(report.reportContent.contains("# Remediation Plan"), file: file, line: line)
        XCTAssertTrue(report.reportContent.contains("Built-in Security Assessment"), file: file, line: line)
    }

    /// Feature 1+2: AI off → every AI feature still produces its built-in result, and nothing is sent.
    @MainActor
    func testEveryFeatureWorksWithAIOff() async {
        StubOllamaProtocol.respond { _ in "should never be asked" }
        AppAI.testOverride = AITestSupport.makeAI(NovaAISettings(enabled: false), protocolClass: StubOllamaProtocol.self)
        await runAllFeatures()
        XCTAssertEqual(StubOllamaProtocol.chatCount, 0)
        XCTAssertEqual(AppAI.current.status.state, .off)
    }

    /// Feature 2+7: every backend down → built-in result, no hang.
    @MainActor
    func testEveryFeatureFallsBackWhenOffline() async {
        AppAI.testOverride = AITestSupport.makeAI()   // Auto, RefuseAllProtocol
        await runAllFeatures()
    }
}

// MARK: - Performance

final class AIKitPerformanceTests: XCTestCase {
    @MainActor
    func testBuiltInAnalysisOfLargeNetworkIsFast() {
        let devices = (0..<500).map { i in
            AITestSupport.device("10.0.\(i / 250).\(i % 250)", mac: String(format: "AA:BB:CC:00:%02X:%02X", i / 256, i % 256),
                                 ports: [AITestSupport.port(22, "ssh"), AITestSupport.port(i % 7 == 0 ? 23 : 443, "svc")])
        }
        let start = Date()
        let r = BuiltInSecurityAnalysis.threatAnalysis(devices: devices)
        _ = BuiltInSecurityAnalysis.recommendationSet(devices: devices)
        _ = BuiltInSecurityAnalysis.query("ssh", devices: devices)
        _ = BuiltInSecurityAnalysis.documentation(devices: devices, includeSecurityAnalysis: true,
                                                  includeTopology: true, includeRecommendations: true)
        XCTAssertEqual(r.analyzedDeviceCount, 500)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5.0)
    }

    func testValidatorsAreFastOnMaxSizeReplies() {
        let big = "Matches: 1\n" + String(repeating: "Explanation: lorem ipsum dolor sit amet.\n", count: 400)
        let start = Date()
        for _ in 0..<200 {
            _ = try? AppAI.validText(big)
            _ = try? AppAI.validQueryReply(deviceCount: 10)(big)
            _ = try? AppAI.validAnomalyVerdict(big)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    /// Offline fallback returns promptly (no long timeouts when every backend refuses).
    @MainActor
    func testOfflineFallbackIsPrompt() async {
        AppAI.testOverride = AITestSupport.makeAI()
        defer { AppAI.testOverride = nil }
        let start = Date()
        _ = await MLXThreatAnalyzer.shared.analyzeNetwork(devices: AITestSupport.network)
        XCTAssertLessThan(Date().timeIntervalSince(start), 10.0)
    }
}

// MARK: - Frame / UI state

final class AIKitFrameTests: XCTestCase {
    @MainActor
    func testStatusReflectsToggle() {
        let ai = AITestSupport.makeAI()
        XCTAssertTrue(ai.isEnabled)
        ai.isEnabled = false
        XCTAssertEqual(ai.status.state, .off)
        XCTAssertNotEqual(NovaAIStatusIndicator.color(.online), NovaAIStatusIndicator.color(.off))
    }

    @MainActor
    func testSettingsAndStatusViewsBuild() {
        let ai = AITestSupport.makeAI()
        let settings = NSHostingView(rootView: NovaAISettingsView(ai: ai, footer: AppAI.settingsFooter).frame(width: 600, height: 500))
        settings.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(settings.fittingSize.height, 0)
        let indicator = NSHostingView(rootView: NovaAIStatusIndicator(ai: ai, checksOnAppear: false))
        indicator.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(indicator.fittingSize.width, 0)
    }

    func testAIAssistantHasSettingsTab() {
        XCTAssertTrue(AIAssistantTabView.AIFeature.allCases.contains(.capabilities))
        XCTAssertEqual(AIAssistantTabView.AIFeature.capabilities.rawValue, "AI Settings")
    }

    @MainActor
    func testSourceLabels() {
        XCTAssertEqual(NovaAISource.fallback(.disabled).label, "Built-in")
        XCTAssertEqual(NovaAISource.ai(backend: .ollama, model: "qwen3:8b").label, "AI · Ollama (qwen3:8b)")
    }

    @MainActor
    func testFeatureBusyFlagsResetAfterFallback() async {
        AppAI.testOverride = AITestSupport.makeAI(NovaAISettings(enabled: false))
        defer { AppAI.testOverride = nil }
        _ = await MLXSecurityRecommendations.shared.generateRecommendations(devices: AITestSupport.network)
        XCTAssertFalse(MLXSecurityRecommendations.shared.isGenerating)
        _ = await MLXThreatAnalyzer.shared.analyzeNetwork(devices: AITestSupport.network)
        XCTAssertFalse(MLXThreatAnalyzer.shared.isAnalyzing)
    }
}
