//
//  NovaAPIServer.swift
//  NMAPScanner
//
//  Nova/Claude API — port 37423
//
//  Endpoints:
//    GET  /api/status                  → app status, scan state
//    GET  /api/devices                 → all discovered devices
//    GET  /api/devices/:ip             → single device detail
//    POST /api/scan                    → start scan {"target":"192.168.1.0/24","mode":"quick|full|port"}
//    POST /api/scan/stop               → stop current scan
//    GET  /api/scan/results            → latest scan results
//    GET  /api/security/warnings       → AI security warnings
//    GET  /api/security/report         → full security report
//    POST /api/security/analyze        → trigger AI analysis
//    GET  /api/wifi                    → WiFi networks
//    GET  /api/topology                → network topology data
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
            let disc = ComprehensiveDiscovery.shared
            return json(200, [
                "status": "running", "app": "NMAPScanner", "version": "1.0", "port": "\(port)",
                "isScanning": disc.isScanning,
                "deviceCount": disc.discoveredDevices.count,
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ])

        case ("GET", "/api/devices"):
            let disc = ComprehensiveDiscovery.shared
            let devices = disc.discoveredDevices.map { d -> [String: Any] in
                var info: [String: Any] = [
                    "ip": d.ipAddress,
                    "hostname": d.hostname ?? "",
                    "mac": d.macAddress ?? "",
                    "vendor": d.vendor ?? "",
                    "isOnline": d.isOnline
                ]
                if !d.openPorts.isEmpty { info["openPorts"] = d.openPorts.map { $0.port } }
                return info
            }
            return jsonArray(200, devices)

        case ("GET", _) where req.path.hasPrefix("/api/devices/"):
            let ip = req.path.replacingOccurrences(of: "/api/devices/", with: "")
            let disc = ComprehensiveDiscovery.shared
            guard let device = disc.discoveredDevices.first(where: { $0.ipAddress == ip }) else {
                return json(404, ["error": "Device not found: \(ip)"])
            }
            return json(200, [
                "ip": device.ipAddress,
                "hostname": device.hostname ?? "",
                "mac": device.macAddress ?? "",
                "vendor": device.vendor ?? "",
                "isOnline": device.isOnline,
                "openPorts": device.openPorts.map { p -> [String: Any] in
                    ["port": p.port, "service": p.service ?? "", "protocol": p.proto]
                }
            ] as [String: Any])

        case ("POST", "/api/scan"):
            guard let body = req.bodyJSON(),
                  let target = body["target"] as? String else {
                return json(400, ["error": "'target' required"])
            }
            let disc = ComprehensiveDiscovery.shared
            disc.startDiscovery(target: target)
            return json(200, ["status": "scanning", "target": target])

        case ("POST", "/api/scan/stop"):
            let disc = ComprehensiveDiscovery.shared
            disc.stopDiscovery()
            return json(200, ["status": "stopped"])

        case ("GET", "/api/scan/results"):
            let disc = ComprehensiveDiscovery.shared
            return json(200, [
                "isScanning": disc.isScanning,
                "deviceCount": disc.discoveredDevices.count,
                "devices": disc.discoveredDevices.map { ["ip": $0.ipAddress, "hostname": $0.hostname ?? ""] }
            ] as [String: Any])

        case ("GET", "/api/security/warnings"):
            let analyzer = AISecurityAnalyzer.shared
            let warnings = analyzer.warnings.map { w -> [String: Any] in
                ["id": w.id.uuidString, "severity": w.severity.rawValue,
                 "title": w.title, "description": w.description,
                 "device": w.deviceIP ?? ""]
            }
            return jsonArray(200, warnings)

        case ("POST", "/api/security/analyze"):
            let disc = ComprehensiveDiscovery.shared
            let analyzer = AISecurityAnalyzer.shared
            await analyzer.analyze(devices: disc.discoveredDevices)
            return json(200, ["status": "analysis complete", "warningCount": analyzer.warnings.count])

        case ("GET", "/api/wifi"):
            let scanner = WiFiNetworkScanner.shared
            let networks = scanner.networks.map { n -> [String: Any] in
                ["ssid": n.ssid, "bssid": n.bssid, "rssi": n.rssi, "security": n.security]
            }
            return jsonArray(200, networks)

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
            var hdrs: [String: String] = []; for l in lines.dropFirst() { let kv = l.components(separatedBy: ": "); if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") } }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]; path = tokens[1].components(separatedBy: "?").first ?? tokens[1]; body = rawBody
        }
    }
    private func json(_ s: Int, _ d: [String: Any]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String { let st = [200:"OK",201:"Created",400:"Bad Request",404:"Not Found",500:"Internal Server Error"][s] ?? "Unknown"; return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)" }
}
