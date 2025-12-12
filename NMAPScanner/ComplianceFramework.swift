//
//  ComplianceFramework.swift
//  NMAPScanner - Compliance Reporting (NIST, CIS, PCI-DSS)
//
//  Enterprise compliance validation and reporting
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation

// MARK: - Compliance Framework

enum ComplianceFramework: String, CaseIterable, Codable {
    case nist = "NIST Cybersecurity Framework"
    case cis = "CIS Critical Security Controls"
    case pciDss = "PCI-DSS"
    case hipaa = "HIPAA Security Rule"
    case soc2 = "SOC 2 Type II"
    case iso27001 = "ISO 27001"

    var shortName: String {
        switch self {
        case .nist: return "NIST CSF"
        case .cis: return "CIS Controls"
        case .pciDss: return "PCI-DSS"
        case .hipaa: return "HIPAA"
        case .soc2: return "SOC 2"
        case .iso27001: return "ISO 27001"
        }
    }

    var description: String {
        switch self {
        case .nist: return "NIST Cybersecurity Framework for critical infrastructure"
        case .cis: return "Center for Internet Security's 18 Critical Controls"
        case .pciDss: return "Payment Card Industry Data Security Standard"
        case .hipaa: return "Health Insurance Portability and Accountability Act"
        case .soc2: return "Service Organization Control 2 - Trust Services Criteria"
        case .iso27001: return "International information security management standard"
        }
    }
}

// MARK: - Compliance Check

struct ComplianceCheck: Identifiable, Codable {
    let id: String
    let framework: ComplianceFramework
    let controlNumber: String
    let title: String
    let description: String
    let requirement: String
    let category: String

    // Result will be populated during audit
    var result: ComplianceResult?
}

struct ComplianceResult: Codable {
    let status: ComplianceStatus
    let score: Int  // 0-100
    let findings: [String]
    let evidence: [String]
    let recommendations: [String]
    let testedAt: Date

    enum ComplianceStatus: String, Codable {
        case pass = "Pass"
        case fail = "Fail"
        case partial = "Partial"
        case notApplicable = "N/A"
        case notTested = "Not Tested"

        var color: String {
            switch self {
            case .pass: return "green"
            case .fail: return "red"
            case .partial: return "orange"
            case .notApplicable: return "gray"
            case .notTested: return "gray"
            }
        }
    }
}

// MARK: - Compliance Report

struct ComplianceReport: Identifiable, Codable {
    let id: UUID
    let framework: ComplianceFramework
    let generatedAt: Date
    let checks: [ComplianceCheck]
    let overallScore: Int  // 0-100
    let passCount: Int
    let failCount: Int
    let partialCount: Int
    let networkSnapshot: NetworkSnapshot

    var status: String {
        if overallScore >= 90 {
            return "Compliant"
        } else if overallScore >= 75 {
            return "Mostly Compliant"
        } else if overallScore >= 50 {
            return "Partially Compliant"
        } else {
            return "Non-Compliant"
        }
    }

    var grade: String {
        if overallScore >= 90 { return "A" }
        else if overallScore >= 80 { return "B" }
        else if overallScore >= 70 { return "C" }
        else if overallScore >= 60 { return "D" }
        else { return "F" }
    }
}

struct NetworkSnapshot: Codable {
    let totalDevices: Int
    let onlineDevices: Int
    let serversCount: Int
    let workstationsCount: Int
    let iotCount: Int
    let totalOpenPorts: Int
    let uniqueServices: Int
}

// MARK: - Compliance Engine

@MainActor
class ComplianceEngine: ObservableObject {
    static let shared = ComplianceEngine()

    @Published var reports: [ComplianceReport] = []
    @Published var isAuditing: Bool = false

    private init() {
        loadReports()
    }

    /// Run compliance audit
    func runAudit(framework: ComplianceFramework, devices: [EnhancedDevice]) async -> ComplianceReport {
        isAuditing = true
        defer { isAuditing = false }

        SecureLogger.log("Starting \(framework.rawValue) compliance audit", level: .info)
        SecurityAuditLog.log(event: .scanStarted, details: "Compliance audit: \(framework.shortName)", level: .info)

        // Get checks for framework
        var checks = getChecksForFramework(framework)

        // Run each check
        for i in 0..<checks.count {
            checks[i].result = await runCheck(checks[i], devices: devices)
        }

        // Calculate overall score
        let passCount = checks.filter { $0.result?.status == .pass }.count
        let failCount = checks.filter { $0.result?.status == .fail }.count
        let partialCount = checks.filter { $0.result?.status == .partial }.count
        let applicableCount = checks.filter { $0.result?.status != .notApplicable }.count

        let overallScore = applicableCount > 0 ? (passCount * 100 + partialCount * 50) / applicableCount : 0

        // Create network snapshot
        let snapshot = NetworkSnapshot(
            totalDevices: devices.count,
            onlineDevices: devices.filter { $0.isOnline }.count,
            serversCount: devices.filter { $0.deviceType == .server }.count,
            workstationsCount: devices.filter { $0.deviceType == .workstation }.count,
            iotCount: devices.filter { $0.deviceType == .iot }.count,
            totalOpenPorts: devices.reduce(0) { $0 + $1.openPorts.count },
            uniqueServices: Set(devices.flatMap { $0.openPorts.map { $0.service } }).count
        )

        let report = ComplianceReport(
            id: UUID(),
            framework: framework,
            generatedAt: Date(),
            checks: checks,
            overallScore: overallScore,
            passCount: passCount,
            failCount: failCount,
            partialCount: partialCount,
            networkSnapshot: snapshot
        )

        reports.append(report)
        saveReports()

        SecureLogger.log("Compliance audit complete: \(framework.shortName) score = \(overallScore)/100", level: .security)

        return report
    }

    // MARK: - Check Execution

    private func runCheck(_ check: ComplianceCheck, devices: [EnhancedDevice]) async -> ComplianceResult {
        // Run specific check based on control number
        switch check.framework {
        case .nist:
            return runNISTCheck(check, devices: devices)
        case .cis:
            return runCISCheck(check, devices: devices)
        case .pciDss:
            return runPCIDSSCheck(check, devices: devices)
        case .hipaa:
            return runHIPAACheck(check, devices: devices)
        case .soc2:
            return runSOC2Check(check, devices: devices)
        case .iso27001:
            return runISO27001Check(check, devices: devices)
        }
    }

    // Will continue in next file part...
