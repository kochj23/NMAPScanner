//
//  CloudShadowITDetector.swift
//  NMAPScanner - Cloud Service & Shadow IT Detection
//
//  Created by Jordan Koch & Claude Code on 2025-11-27.
//

import Foundation

struct ShadowITFinding: Identifiable, Codable {
    let id = UUID()
    let sourceIP: String
    let service: CloudService
    let destination: String
    let severity: Severity
    let description: String
    let recommendation: String
    let timestamp: Date

    enum CloudService: String, Codable {
        case dropbox = "Dropbox"
        case googleDrive = "Google Drive"
        case oneDrive = "Microsoft OneDrive"
        case personalVPN = "Personal VPN"
        case fileSharing = "File Sharing Service"
        case remoteDesktop = "Remote Desktop Service"
        case cloudDatabase = "Unauthorized Cloud Database"
    }

    enum Severity: String, Codable {
        case high, medium, low
    }
}

@MainActor
class CloudShadowITDetector: ObservableObject {
    static let shared = CloudShadowITDetector()

    @Published var findings: [ShadowITFinding] = []
    @Published var isScanning = false

    private let cloudServiceIndicators: [String: ShadowITFinding.CloudService] = [
        "dropbox.com": .dropbox,
        "drive.google.com": .googleDrive,
        "onedrive.live.com": .oneDrive,
        "box.com": .fileSharing,
        "wetransfer.com": .fileSharing,
        "teamviewer.com": .remoteDesktop,
        "anydesk.com": .remoteDesktop,
        "nordvpn.com": .personalVPN,
        "expressvpn.com": .personalVPN
    ]

    private init() {}

    func detectShadowIT(dnsQueries: [(domain: String, ip: String)]) async {
        isScanning = true
        findings.removeAll()

        for (domain, ip) in dnsQueries {
            for (serviceDomain, serviceType) in cloudServiceIndicators {
                if domain.contains(serviceDomain) {
                    findings.append(ShadowITFinding(
                        sourceIP: ip,
                        service: serviceType,
                        destination: domain,
                        severity: .medium,
                        description: "Unauthorized use of \(serviceType.rawValue)",
                        recommendation: "Review acceptable use policy. Block if unauthorized. Provide approved alternative.",
                        timestamp: Date()
                    ))
                }
            }
        }

        isScanning = false
    }
}
