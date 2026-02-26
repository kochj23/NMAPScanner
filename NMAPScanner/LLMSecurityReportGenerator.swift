//
//  LLMSecurityReportGenerator.swift
//  NMAPScanner - LLM-Powered Security Report Generation
//
//  Generates comprehensive, natural language security reports
//  using local Ollama LLM or other configured AI backends.
//
//  Created by Jordan Koch on 2026-02-02.
//

import Foundation
import SwiftUI
import Combine

// MARK: - LLM Security Report Generator

@MainActor
class LLMSecurityReportGenerator: ObservableObject {
    static let shared = LLMSecurityReportGenerator()

    // MARK: - Published Properties

    @Published var isGenerating = false
    @Published var reportContent = ""
    @Published var generationProgress: Double = 0.0
    @Published var currentSection = ""
    @Published var lastError: String?
    @Published var isLLMAvailable = false

    // Report sections
    @Published var executiveSummary = ""
    @Published var technicalDetails = ""
    @Published var remediationPlan = ""
    @Published var riskAssessment = ""

    // MARK: - Private Properties

    private let aiBackend = AIBackendManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Monitor AI backend availability
        aiBackend.$activeBackend
            .receive(on: DispatchQueue.main)
            .sink { [weak self] backend in
                self?.isLLMAvailable = backend != nil
            }
            .store(in: &cancellables)

        // Initial check
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Availability Check

    func checkAvailability() async {
        await aiBackend.checkBackendAvailability()
        isLLMAvailable = aiBackend.activeBackend != nil
    }

    // MARK: - Report Generation

    /// Generate a comprehensive security report from scan results
    func generateReport(from scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding] = []) async {
        guard isLLMAvailable else {
            lastError = "No AI backend available. Please configure Ollama or another LLM service."
            return
        }

        isGenerating = true
        generationProgress = 0.0
        reportContent = ""
        lastError = nil

        defer { isGenerating = false }

        do {
            // Generate each section
            currentSection = "Executive Summary"
            generationProgress = 0.1
            executiveSummary = try await generateExecutiveSummarySection(scanResults: scanResults, vulnerabilities: vulnerabilities)
            reportContent += "# Executive Summary\n\n\(executiveSummary)\n\n"
            generationProgress = 0.3

            currentSection = "Risk Assessment"
            riskAssessment = try await generateRiskAssessmentSection(scanResults: scanResults, vulnerabilities: vulnerabilities)
            reportContent += "# Risk Assessment\n\n\(riskAssessment)\n\n"
            generationProgress = 0.5

            currentSection = "Technical Details"
            technicalDetails = try await generateTechnicalDetailsSection(scanResults: scanResults, vulnerabilities: vulnerabilities)
            reportContent += "# Technical Details\n\n\(technicalDetails)\n\n"
            generationProgress = 0.7

            currentSection = "Remediation Plan"
            remediationPlan = try await generateRemediationPlanSection(scanResults: scanResults, vulnerabilities: vulnerabilities)
            reportContent += "# Remediation Plan\n\n\(remediationPlan)\n\n"
            generationProgress = 0.9

            // Add footer
            reportContent += generateReportFooter()
            generationProgress = 1.0
            currentSection = "Complete"

            ReportSecureLogger.log("LLM security report generated successfully", level: .info)

        } catch {
            lastError = "Report generation failed: \(error.localizedDescription)"
            ReportSecureLogger.log("LLM report generation failed: \(error)", level: .error)
        }
    }

    // MARK: - Executive Summary Generation

    func generateExecutiveSummary() async -> String {
        guard isLLMAvailable else {
            return "AI backend not available for generating executive summary."
        }

        return executiveSummary
    }

    private func generateExecutiveSummarySection(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) async throws -> String {
        let networkContext = buildNetworkContext(scanResults: scanResults, vulnerabilities: vulnerabilities)

        let systemPrompt = """
        You are a senior cybersecurity analyst preparing an executive summary for a network security assessment.
        Write in a professional, clear, and concise manner appropriate for C-level executives.
        Focus on business impact and risk, not technical jargon.
        Keep the summary to 3-5 paragraphs.
        """

        let userPrompt = """
        Generate an executive summary for the following network security scan results:

        \(networkContext)

        The executive summary should:
        1. Provide a high-level overview of the network's security posture
        2. Highlight the most critical findings
        3. Summarize the overall risk level
        4. Mention key recommendations at a high level

        Write in a professional tone suitable for executive leadership.
        """

        return try await aiBackend.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            temperature: 0.7,
            maxTokens: 1500
        )
    }

    // MARK: - Technical Details Generation

    func generateTechnicalDetails() async -> String {
        guard isLLMAvailable else {
            return "AI backend not available for generating technical details."
        }

        return technicalDetails
    }

    private func generateTechnicalDetailsSection(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) async throws -> String {
        let deviceDetails = buildDeviceDetails(scanResults: scanResults)
        let vulnerabilityDetails = buildVulnerabilityDetails(vulnerabilities: vulnerabilities)

        let systemPrompt = """
        You are a network security engineer writing the technical details section of a security assessment report.
        Be thorough and technically accurate.
        Use proper security terminology.
        Organize findings by severity and category.
        """

        let userPrompt = """
        Generate a detailed technical analysis of the following network scan results:

        DEVICE INVENTORY:
        \(deviceDetails)

        VULNERABILITIES DETECTED:
        \(vulnerabilityDetails)

        The technical details should include:
        1. Analysis of the network topology and device distribution
        2. Detailed breakdown of open ports and services
        3. Explanation of each vulnerability category
        4. Technical context for each finding
        5. Potential attack vectors identified

        Be specific and technical, but ensure the information is actionable.
        """

        return try await aiBackend.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            temperature: 0.5,
            maxTokens: 2500
        )
    }

    // MARK: - Remediation Plan Generation

    func generateRemediationPlan() async -> String {
        guard isLLMAvailable else {
            return "AI backend not available for generating remediation plan."
        }

        return remediationPlan
    }

    private func generateRemediationPlanSection(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) async throws -> String {
        let prioritizedFindings = buildPrioritizedFindings(vulnerabilities: vulnerabilities)
        let networkSummary = buildNetworkSummary(scanResults: scanResults)

        let systemPrompt = """
        You are a cybersecurity consultant creating an actionable remediation plan.
        Prioritize recommendations by risk and impact.
        Include both immediate actions and long-term improvements.
        Provide specific, implementable steps.
        Consider resource constraints and practicality.
        """

        let userPrompt = """
        Create a detailed remediation plan based on these security findings:

        NETWORK OVERVIEW:
        \(networkSummary)

        PRIORITIZED FINDINGS:
        \(prioritizedFindings)

        The remediation plan should include:

        1. IMMEDIATE ACTIONS (within 24-48 hours)
           - Critical vulnerabilities requiring immediate attention
           - Quick wins that reduce risk significantly

        2. SHORT-TERM REMEDIATION (within 1-2 weeks)
           - High-severity issues
           - Configuration changes

        3. MEDIUM-TERM IMPROVEMENTS (within 1-3 months)
           - Infrastructure improvements
           - Policy updates

        4. LONG-TERM SECURITY ENHANCEMENTS
           - Strategic security improvements
           - Monitoring and detection capabilities

        For each recommendation, include:
        - Specific steps to implement
        - Expected effort level (Low/Medium/High)
        - Impact on risk reduction
        """

        return try await aiBackend.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            temperature: 0.6,
            maxTokens: 2500
        )
    }

    // MARK: - Risk Assessment Generation

    private func generateRiskAssessmentSection(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) async throws -> String {
        let riskContext = buildRiskContext(scanResults: scanResults, vulnerabilities: vulnerabilities)

        let systemPrompt = """
        You are a risk assessment specialist evaluating network security.
        Use standard risk frameworks (NIST, ISO 27001) terminology where appropriate.
        Quantify risk where possible.
        Be objective and evidence-based.
        """

        let userPrompt = """
        Perform a risk assessment based on these network security findings:

        \(riskContext)

        The risk assessment should include:

        1. OVERALL RISK RATING
           - Provide a clear risk rating (Critical/High/Medium/Low)
           - Justify the rating based on findings

        2. RISK BREAKDOWN BY CATEGORY
           - Network perimeter security
           - Internal network security
           - Device security posture
           - Data exposure risk

        3. THREAT LANDSCAPE ANALYSIS
           - Potential threat actors
           - Attack surface assessment
           - Likelihood of exploitation

        4. BUSINESS IMPACT ASSESSMENT
           - Potential impact of security incidents
           - Compliance implications
           - Reputational risk factors

        5. RISK TRENDS
           - Compare to industry benchmarks
           - Note concerning patterns
        """

        return try await aiBackend.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            temperature: 0.5,
            maxTokens: 2000
        )
    }

    // MARK: - Context Building Helpers

    private func buildNetworkContext(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) -> String {
        let onlineDevices = scanResults.filter { $0.isOnline }
        let rogueDevices = scanResults.filter { $0.isRogue }
        let criticalVulns = vulnerabilities.filter { $0.severity == .critical }
        let highVulns = vulnerabilities.filter { $0.severity == .high }

        let deviceTypes = Dictionary(grouping: scanResults, by: { $0.deviceType })
        let typeBreakdown = deviceTypes.map { "\($0.key.rawValue): \($0.value.count)" }.joined(separator: ", ")

        let totalOpenPorts = scanResults.reduce(0) { $0 + $1.openPorts.count }

        return """
        NETWORK STATISTICS:
        - Total devices discovered: \(scanResults.count)
        - Online devices: \(onlineDevices.count)
        - Rogue/unknown devices: \(rogueDevices.count)
        - Device types: \(typeBreakdown)
        - Total open ports: \(totalOpenPorts)

        VULNERABILITY SUMMARY:
        - Total vulnerabilities: \(vulnerabilities.count)
        - Critical severity: \(criticalVulns.count)
        - High severity: \(highVulns.count)
        - Medium severity: \(vulnerabilities.filter { $0.severity == .medium }.count)
        - Low severity: \(vulnerabilities.filter { $0.severity == .low }.count)

        TOP CONCERNS:
        \(buildTopConcerns(scanResults: scanResults, vulnerabilities: vulnerabilities))
        """
    }

    private func buildTopConcerns(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) -> String {
        var concerns: [String] = []

        let rogueCount = scanResults.filter { $0.isRogue }.count
        if rogueCount > 0 {
            concerns.append("- \(rogueCount) rogue/unidentified devices detected on network")
        }

        let criticalCount = vulnerabilities.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            concerns.append("- \(criticalCount) critical vulnerabilities requiring immediate attention")
        }

        let telnetDevices = scanResults.filter { $0.openPorts.contains { $0.port == 23 } }
        if !telnetDevices.isEmpty {
            concerns.append("- \(telnetDevices.count) devices with insecure Telnet (port 23) enabled")
        }

        let smbDevices = scanResults.filter { $0.openPorts.contains { $0.port == 445 || $0.port == 139 } }
        if !smbDevices.isEmpty {
            concerns.append("- \(smbDevices.count) devices with exposed SMB file sharing")
        }

        let rdpDevices = scanResults.filter { $0.openPorts.contains { $0.port == 3389 } }
        if !rdpDevices.isEmpty {
            concerns.append("- \(rdpDevices.count) devices with exposed Remote Desktop (RDP)")
        }

        let dbPorts: Set<Int> = [3306, 5432, 1433, 27017, 6379]
        let exposedDatabases = scanResults.filter { device in
            device.openPorts.contains { dbPorts.contains($0.port) }
        }
        if !exposedDatabases.isEmpty {
            concerns.append("- \(exposedDatabases.count) devices with exposed database ports")
        }

        if concerns.isEmpty {
            concerns.append("- No critical concerns identified")
        }

        return concerns.joined(separator: "\n")
    }

    private func buildDeviceDetails(scanResults: [EnhancedDevice]) -> String {
        // Limit to top 30 devices to manage token usage
        let limitedDevices = Array(scanResults.prefix(30))

        var details = ""
        for (index, device) in limitedDevices.enumerated() {
            details += """

            Device \(index + 1):
            - IP: \(device.ipAddress)
            - Hostname: \(device.hostname ?? "Unknown")
            - Manufacturer: \(device.manufacturer ?? "Unknown")
            - Type: \(device.deviceType.rawValue)
            - Status: \(device.isOnline ? "Online" : "Offline")
            - Rogue: \(device.isRogue ? "YES" : "No")
            - Open Ports: \(device.openPorts.map { "\($0.port)/\($0.service)" }.joined(separator: ", "))

            """
        }

        if scanResults.count > 30 {
            details += "\n... and \(scanResults.count - 30) additional devices\n"
        }

        return details
    }

    private func buildVulnerabilityDetails(vulnerabilities: [ThreatFinding]) -> String {
        if vulnerabilities.isEmpty {
            return "No vulnerabilities detected during this scan."
        }

        var details = ""
        let sorted = vulnerabilities.sorted { $0.severity.sortOrder < $1.severity.sortOrder }

        // Limit to top 20 vulnerabilities
        for (index, vuln) in sorted.prefix(20).enumerated() {
            details += """

            Vulnerability \(index + 1):
            - Title: \(vuln.title)
            - Severity: \(vuln.severity.rawValue)
            - Category: \(vuln.category.rawValue)
            - Affected Host: \(vuln.affectedHost)
            - Port: \(vuln.affectedPort.map { String($0) } ?? "N/A")
            - CVSS Score: \(vuln.cvssScore.map { String(format: "%.1f", $0) } ?? "N/A")
            - Description: \(vuln.description)

            """
        }

        if vulnerabilities.count > 20 {
            details += "\n... and \(vulnerabilities.count - 20) additional vulnerabilities\n"
        }

        return details
    }

    private func buildPrioritizedFindings(vulnerabilities: [ThreatFinding]) -> String {
        // Single pass: group all vulnerabilities by severity instead of filtering once per level
        let grouped = Dictionary(grouping: vulnerabilities, by: { $0.severity })

        var findings = ""

        if let critical = grouped[.critical], !critical.isEmpty {
            findings += "\nCRITICAL (\(critical.count)):\n"
            for vuln in critical.sorted(by: { $0.severity.sortOrder < $1.severity.sortOrder }).prefix(5) {
                findings += "- \(vuln.title) [\(vuln.affectedHost)]: \(vuln.description)\n"
            }
        }

        if let high = grouped[.high], !high.isEmpty {
            findings += "\nHIGH (\(high.count)):\n"
            for vuln in high.sorted(by: { $0.severity.sortOrder < $1.severity.sortOrder }).prefix(5) {
                findings += "- \(vuln.title) [\(vuln.affectedHost)]: \(vuln.description)\n"
            }
        }

        if let medium = grouped[.medium], !medium.isEmpty {
            findings += "\nMEDIUM (\(medium.count)):\n"
            for vuln in medium.sorted(by: { $0.severity.sortOrder < $1.severity.sortOrder }).prefix(3) {
                findings += "- \(vuln.title) [\(vuln.affectedHost)]\n"
            }
        }

        if let low = grouped[.low], !low.isEmpty {
            findings += "\nLOW (\(low.count)):\n"
            findings += "- \(low.count) low-severity issues identified\n"
        }

        return findings
    }

    private func buildNetworkSummary(scanResults: [EnhancedDevice]) -> String {
        let onlineCount = scanResults.filter { $0.isOnline }.count
        let rogueCount = scanResults.filter { $0.isRogue }.count
        let deviceTypes = Dictionary(grouping: scanResults, by: { $0.deviceType })

        var summary = """
        Total Devices: \(scanResults.count)
        Online: \(onlineCount)
        Rogue/Unknown: \(rogueCount)

        Device Breakdown:
        """

        for (type, devices) in deviceTypes.sorted(by: { $0.value.count > $1.value.count }) {
            summary += "\n- \(type.rawValue): \(devices.count)"
        }

        // Common ports summary
        let portCounts = scanResults.flatMap { $0.openPorts }
            .reduce(into: [Int: Int]()) { counts, port in
                counts[port.port, default: 0] += 1
            }

        let commonPorts = portCounts.sorted { $0.value > $1.value }.prefix(10)

        summary += "\n\nMost Common Open Ports:"
        for (port, count) in commonPorts {
            summary += "\n- Port \(port): \(count) devices"
        }

        return summary
    }

    private func buildRiskContext(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) -> String {
        let networkContext = buildNetworkContext(scanResults: scanResults, vulnerabilities: vulnerabilities)

        // Calculate risk metrics
        let riskScore = calculateRiskScore(scanResults: scanResults, vulnerabilities: vulnerabilities)
        let exposureLevel = calculateExposureLevel(scanResults: scanResults)

        return """
        \(networkContext)

        RISK METRICS:
        - Calculated Risk Score: \(riskScore)/100
        - Network Exposure Level: \(exposureLevel)
        - Attack Surface: \(scanResults.reduce(0) { $0 + $1.openPorts.count }) open ports across \(scanResults.count) devices

        COMPLIANCE INDICATORS:
        - Devices using unencrypted protocols: \(countUnencryptedProtocols(scanResults: scanResults))
        - Devices with default/insecure configurations: \(vulnerabilities.filter { $0.category == .misconfiguration }.count)
        - Potential data exposure points: \(vulnerabilities.filter { $0.category == .dataExposure }.count)
        """
    }

    private func calculateRiskScore(scanResults: [EnhancedDevice], vulnerabilities: [ThreatFinding]) -> Int {
        var score = 100

        // Deduct for critical vulnerabilities
        score -= vulnerabilities.filter { $0.severity == .critical }.count * 15

        // Deduct for high vulnerabilities
        score -= vulnerabilities.filter { $0.severity == .high }.count * 8

        // Deduct for medium vulnerabilities
        score -= vulnerabilities.filter { $0.severity == .medium }.count * 3

        // Deduct for rogue devices
        score -= scanResults.filter { $0.isRogue }.count * 5

        // Deduct for excessive open ports
        let totalPorts = scanResults.reduce(0) { $0 + $1.openPorts.count }
        if totalPorts > 50 { score -= 5 }
        if totalPorts > 100 { score -= 10 }

        return max(0, min(100, score))
    }

    private func calculateExposureLevel(scanResults: [EnhancedDevice]) -> String {
        let totalPorts = scanResults.reduce(0) { $0 + $1.openPorts.count }
        let rogueCount = scanResults.filter { $0.isRogue }.count
        let exposedServices = scanResults.flatMap { $0.openPorts }
            .filter { [22, 23, 3389, 5900, 445, 3306, 5432].contains($0.port) }
            .count

        let exposureScore = exposedServices * 3 + rogueCount * 5 + (totalPorts / 10)

        switch exposureScore {
        case 0..<10: return "Low"
        case 10..<25: return "Moderate"
        case 25..<50: return "High"
        default: return "Critical"
        }
    }

    private func countUnencryptedProtocols(scanResults: [EnhancedDevice]) -> Int {
        let unencryptedPorts: Set<Int> = [21, 23, 69, 80, 110, 143, 389]
        return scanResults.filter { device in
            device.openPorts.contains { unencryptedPorts.contains($0.port) }
        }.count
    }

    private func generateReportFooter() -> String {
        return """
        ---

        ## Report Information

        **Generated:** \(Date().formatted(date: .long, time: .complete))
        **Scanner:** NMAPScanner v8.6.0
        **Report Type:** AI-Powered Security Assessment
        **AI Backend:** \(aiBackend.activeBackend?.rawValue ?? "Unknown")

        *This report was generated using AI-powered analysis. While the AI provides valuable insights and recommendations, all findings should be validated by qualified security professionals before implementing remediation actions.*

        **Report generated by NMAPScanner**
        **Created by Jordan Koch**
        """
    }

    // MARK: - Export Functions

    /// Export the generated report to markdown file
    func exportToMarkdown() throws -> URL {
        guard !reportContent.isEmpty else {
            throw ReportError.noContent
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "security_report_ai_\(timestamp).md"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        try reportContent.write(to: fileURL, atomically: true, encoding: .utf8)

        ReportSecureLogger.log("Exported AI security report to: \(fileURL.path)", level: .info)

        return fileURL
    }

    /// Get the full report as a single string
    func getFullReport() -> String {
        return reportContent
    }

    /// Clear the current report
    func clearReport() {
        reportContent = ""
        executiveSummary = ""
        technicalDetails = ""
        remediationPlan = ""
        riskAssessment = ""
        generationProgress = 0.0
        currentSection = ""
        lastError = nil
    }
}

// MARK: - Report Errors

enum ReportError: LocalizedError {
    case noContent
    case generationFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noContent:
            return "No report content available to export"
        case .generationFailed:
            return "Failed to generate report"
        case .exportFailed:
            return "Failed to export report"
        }
    }
}

// MARK: - Secure Logger Extension

/// Simple secure logger for report generation
struct ReportSecureLogger {
    enum Level: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    static func log(_ message: String, level: Level) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] \(message)")
    }
}
