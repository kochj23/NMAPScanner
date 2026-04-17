//
//  NovaAPIServer.swift
//  NMAPScanner
//
//  Nova/Claude API — port 37423
//
//  Endpoints:
//    GET  /api/status              → scan state, counts, uptime
//    GET  /api/scan/results        → AdvancedPortScanner results (ip, ports, os)
//    POST /api/scan/start          → start a port scan {"ip":"192.168.1.1"}
//    GET  /api/security/warnings   → AI security warnings (severity, title, host, port)
//    GET  /api/wifi                → discovered WiFi networks
//    GET  /api/unifi/devices       → UniFi managed devices
//
//  Created by Jordan Koch on 2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()
    let port: UInt16 = 37423
    private var listener: NWListener?
    private let startTime = Date()

    /// Local-only anti-CSRF bearer token (not a secret — just prevents drive-by POST from browser JS)
    private let apiToken: String = {
        let key = "NovaAPIToken"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: key)
        return token
    }()

    private init() {}

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.handle(conn) } }
            listener?.stateUpdateHandler = { if case .ready = $0 { print("NovaAPI [NMAPScanner]: port \(self.port)") } }
            listener?.start(queue: .main)
        } catch { print("NovaAPI [NMAPScanner]: failed — \(error)") }
    }
    func stop() { listener?.cancel(); listener = nil }

    private func handle(_ c: NWConnection) { c.start(queue: .main); receive(c, Data()) }
    private func receive(_ c: NWConnection, _ buf: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var b = buf; if let d = data { b.append(d) }
                if let req = NovaRequest(b) {
                    let resp = await self.route(req)
                    c.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in c.cancel() })
                } else if !done { self.receive(c, b) } else { c.cancel() }
            }
        }
    }

    private func route(_ req: NovaRequest) async -> String {
        if req.method == "OPTIONS" { return http(200, "") }

        // Require bearer token for all POST requests (anti-CSRF)
        if req.method == "POST" {
            guard let auth = req.headers["authorization"], auth == "Bearer \(apiToken)" else {
                return json(401, ["error": "Unauthorized — missing or invalid Bearer token"] as [String: Any])
            }
        }

        switch (req.method, req.path) {

        case ("GET", "/api/status"):
            let portScanner = AdvancedPortScanner.shared
            return json(200, [
                "status": "running", "app": "NMAPScanner", "version": "1.0", "port": "\(self.port)",
                "scanResultCount": portScanner.scanResults.count,
                "securityWarningCount": AISecurityAnalyzer.shared.warnings.count,
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ] as [String: Any])

        case ("GET", "/api/ping"):
            return json(200, ["pong": "true"] as [String: Any])

        case ("GET", "/api/scan/results"):
            let results = AdvancedPortScanner.shared.scanResults.map { r -> [String: Any] in
                var info: [String: Any] = [
                    "ip": r.ipAddress,
                    "hostname": r.hostname ?? "",
                    "tcpPorts": r.tcpPorts,
                    "udpPorts": r.udpPorts
                ]
                if let osName = r.osDetection.osName { info["os"] = osName }
                if !r.serviceVersions.isEmpty {
                    info["services"] = r.serviceVersions.map { "\($0.key): \($0.value)" }
                }
                return info
            }
            return jsonArray(200, results)

        case ("POST", "/api/scan/start"):
            guard let body = req.bodyJSON(), let ip = body["ip"] as? String else {
                return json(400, ["error": "'ip' required"] as [String: Any])
            }
            // SECURITY: Validate IP/CIDR format to prevent command injection.
            // Only allow IPv4 addresses with optional CIDR notation (e.g. 192.168.1.0/24).
            let ipRegex = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$/
            guard ip.wholeMatch(of: ipRegex) != nil else {
                return json(400, ["error": "Invalid IP address format. Expected: x.x.x.x or x.x.x.x/n"] as [String: Any])
            }
            // Additionally validate each octet is 0-255
            let octets = ip.components(separatedBy: "/").first!.components(separatedBy: ".")
            let validOctets = octets.allSatisfy { if let n = Int($0) { return n >= 0 && n <= 255 } else { return false } }
            guard validOctets else {
                return json(400, ["error": "Invalid IP address: octets must be 0-255"] as [String: Any])
            }
            if let cidrPart = ip.components(separatedBy: "/").last, ip.contains("/"),
               let cidr = Int(cidrPart), (cidr < 0 || cidr > 32) {
                return json(400, ["error": "Invalid CIDR prefix: must be 0-32"] as [String: Any])
            }
            // Scan via nmap subprocess — arguments passed as array, never through shell
            Task {
                let nmapProcess = Process()
                nmapProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/nmap")
                nmapProcess.arguments = ["-sV", "--open", ip]
                try? nmapProcess.run()
            }
            return json(200, ["status": "scan_started", "ip": ip] as [String: Any])

        case ("GET", "/api/security/warnings"):
            let warnings = AISecurityAnalyzer.shared.warnings.map { w -> [String: Any] in
                ["id": w.id.uuidString,
                 "severity": w.severity.rawValue,
                 "title": w.title,
                 "description": w.description,
                 "host": w.host,
                 "port": w.port,
                 "service": w.service,
                 "isVerified": w.isVerified,
                 "remediation": w.remediation]
            }
            return jsonArray(200, warnings)

        case ("GET", "/api/wifi"):
            let networks = WiFiNetworkScanner.shared.discoveredNetworks.map { n -> [String: Any] in
                ["ssid": n.ssid, "bssid": n.bssid, "rssi": n.rssi,
                 "channel": n.channel, "band": n.channelBand, "security": n.securityType]
            }
            return jsonArray(200, networks)

        case ("GET", "/api/unifi/devices"):
            let devices = UniFiController.shared.devices.map { d -> [String: Any] in
                var info: [String: Any] = ["mac": d.mac]
                if let ip = d.ip { info["ip"] = ip }
                if let name = d.name ?? d.hostname { info["name"] = name }
                if let isWired = d.isWired { info["isWired"] = isWired }
                if let lastSeen = d.lastSeen { info["lastSeen"] = lastSeen }
                return info
            }
            return jsonArray(200, devices)

        // ── Threat Intelligence ───────────────────────────────────────────────

        case ("GET", "/api/threats/ioc"):
            // STIX 2.1 Bundle — machine-readable IoC export
            let warnings = AISecurityAnalyzer.shared.warnings
            let iso = ISO8601DateFormatter()
            let objects: [[String: Any]] = warnings.map { w -> [String: Any] in [
                "type": "indicator",
                "spec_version": "2.1",
                "id": "indicator--\(w.id.uuidString.lowercased())",
                "created": iso.string(from: w.detectedAt),
                "modified": iso.string(from: w.detectedAt),
                "name": w.title,
                "description": w.description,
                "indicator_types": [stixType(w.severity.rawValue)],
                "pattern_type": "stix",
                "pattern": "[network-traffic:dst_port = \(w.port) AND network-traffic:dst_ref.value = '\(w.host)']",
                "valid_from": iso.string(from: w.detectedAt),
                "labels": [w.severity.rawValue.lowercased()],
                "extensions": ["x-nova-scanner": [
                    "host": w.host, "port": w.port, "service": w.service,
                    "remediation": w.remediation, "isVerified": w.isVerified,
                    "cveReferences": w.cveReferences ?? []
                ] as [String: Any]]
            ]}
            return json(200, [
                "type": "bundle",
                "id": "bundle--\(UUID().uuidString.lowercased())",
                "spec_version": "2.1",
                "objects": objects
            ] as [String: Any])

        case ("GET", "/api/threats/export"):
            // Full structured export for SIEM / dashboards
            let warnings = AISecurityAnalyzer.shared.warnings
            let iso = ISO8601DateFormatter()
            let scanResults = AdvancedPortScanner.shared.scanResults
            let severityCount = { (sev: String) in warnings.filter { $0.severity.rawValue.lowercased() == sev }.count }
            let findings = warnings.map { w -> [String: Any] in [
                "id": w.id.uuidString, "severity": w.severity.rawValue,
                "title": w.title, "description": w.description,
                "host": w.host, "port": w.port, "service": w.service,
                "isVerified": w.isVerified, "remediation": w.remediation,
                "cveReferences": w.cveReferences ?? [],
                "detectedAt": iso.string(from: w.detectedAt)
            ]}
            let devices = scanResults.map { r -> [String: Any] in [
                "ip": r.ipAddress, "hostname": r.hostname ?? "",
                "openPorts": r.tcpPorts, "os": r.osDetection.osName ?? "unknown"
            ]}
            return json(200, [
                "exportedAt": iso.string(from: Date()),
                "source": "NMAPScanner", "host": ProcessInfo.processInfo.hostName,
                "summary": ["total": warnings.count, "critical": severityCount("critical"),
                            "high": severityCount("high"), "medium": severityCount("medium"),
                            "low": severityCount("low"), "devicesScanned": scanResults.count],
                "findings": findings, "devices": devices
            ] as [String: Any])

        case ("POST", "/api/threats/import"):
            // Accept STIX 2.1 bundle from external threat feed
            guard let body = req.bodyJSON(),
                  (body["type"] as? String) == "bundle",
                  let objects = body["objects"] as? [[String: Any]] else {
                return json(400, ["error": "Expected STIX 2.1 bundle {\"type\":\"bundle\",\"objects\":[...]}"])
            }
            let count = objects.filter { ($0["type"] as? String) == "indicator" }.count
            print("[NMAPScanner] Imported \(count) IoC indicators")
            return json(200, ["imported": count, "status": "accepted",
                              "note": "Indicators accepted. Live scan correlation is a planned feature."])

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.path)"] as [String: Any])
        }
    }

    private struct NovaRequest {
        let method: String; let path: String; let body: String; let headers: [String: String]
        func bodyJSON() -> [String: Any]? { guard let d = body.data(using: .utf8) else { return nil }; return try? JSONSerialization.jsonObject(with: d) as? [String: Any] }
        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n"); let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }; let tokens = rl.components(separatedBy: " "); guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = [:]; for l in lines.dropFirst() { let kv = l.components(separatedBy: ": "); if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") } }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]; path = tokens[1].components(separatedBy: "?").first ?? tokens[1]; body = rawBody; headers = hdrs
        }
    }
    // Map severity to STIX 2.1 indicator type
    private func stixType(_ severity: String) -> String {
        switch severity.lowercased() {
        case "critical", "high": return "malicious-activity"
        case "medium":           return "anomalous-activity"
        default:                 return "benign"
        }
    }

    private func json(_ s: Int, _ d: [String: Any]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String { let st = [200:"OK",201:"Created",400:"Bad Request",401:"Unauthorized",404:"Not Found",500:"Internal Server Error"][s] ?? "Unknown"; return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)" }
}
