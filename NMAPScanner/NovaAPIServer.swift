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

        switch (req.method, req.path) {

        case ("GET", "/api/status"):
            let portScanner = AdvancedPortScanner.shared
            return json(200, [
                "status": "running", "app": "NMAPScanner", "version": "1.0", "port": "\(self.port)",
                "scanResultCount": portScanner.scanResults.count,
                "securityWarningCount": AISecurityAnalyzer.shared.warnings.count,
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ])

        case ("GET", "/api/ping"):
            return json(200, ["pong": true])

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
                return json(400, ["error": "'ip' required"])
            }
            // Scan via nmap subprocess
            Task {
                let result = Process()
                result.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                result.arguments = ["nmap", "-sV", "--open", ip]
                try? result.run()
            }
            return json(200, ["status": "scan_started", "ip": ip])

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

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.path)"])
        }
    }

    private struct NovaRequest {
        let method: String; let path: String; let body: String
        func bodyJSON() -> [String: Any]? { guard let d = body.data(using: .utf8) else { return nil }; return try? JSONSerialization.jsonObject(with: d) as? [String: Any] }
        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n"); let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }; let tokens = rl.components(separatedBy: " "); guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = [:]; for l in lines.dropFirst() { let kv = l.components(separatedBy: ": "); if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") } }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]; path = tokens[1].components(separatedBy: "?").first ?? tokens[1]; body = rawBody
        }
    }
    private func json(_ s: Int, _ d: [String: Any]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String { let st = [200:"OK",201:"Created",400:"Bad Request",404:"Not Found",500:"Internal Server Error"][s] ?? "Unknown"; return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)" }
}
