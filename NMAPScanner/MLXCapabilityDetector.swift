//
//  MLXCapabilityDetector.swift
//  NMAP Plus Security Scanner v8.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Detects MLX availability and system capabilities for AI features.
//  Provides graceful degradation when MLX is unavailable.
//

import Foundation
import SwiftUI

// MARK: - MLX Capability Detector

@MainActor
class MLXCapabilityDetector: ObservableObject {
    static let shared = MLXCapabilityDetector()

    @Published var isMLXAvailable: Bool = false
    @Published var isPythonMLXAvailable: Bool = false
    @Published var isAppleSilicon: Bool = false
    @Published var capabilityStatus: CapabilityStatus = .unchecked
    @Published var errorMessage: String? = nil

    enum CapabilityStatus {
        case unchecked
        case checking
        case available
        case unavailable
        case degraded // Some features available
    }

    private init() {}

    /// Check all MLX capabilities on app launch
    func checkCapabilities() async {
        capabilityStatus = .checking

        // Check if running on Apple Silicon
        isAppleSilicon = await checkAppleSilicon()

        // Check if MLX Python is installed
        isPythonMLXAvailable = await checkPythonMLX()

        // Overall availability
        isMLXAvailable = isAppleSilicon && isPythonMLXAvailable

        // Update status
        if isMLXAvailable {
            capabilityStatus = .available
        } else if isAppleSilicon {
            capabilityStatus = .degraded
            errorMessage = "MLX Python toolkit not installed. Install with: pip3 install mlx mlx-lm"
        } else {
            capabilityStatus = .unavailable
            errorMessage = "MLX requires Apple Silicon (M1/M2/M3/M4). Intel Macs not supported."
        }
    }

    /// Check if running on Apple Silicon
    private func checkAppleSilicon() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", "machdep.cpu.brand_string"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("Apple") // Apple M1/M2/M3/M4
            }
        } catch {
            print("Error checking CPU: \(error)")
        }

        return false
    }

    /// Check if MLX Python is installed
    private func checkPythonMLX() async -> Bool {
        // Check virtual environment first
        let venvPath = "/Volumes/Data/xcode/NMAPScanner/.venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPath) {
            if await testMLXImport(pythonPath: venvPath) {
                return true
            }
        }

        // Check system Python
        if await testMLXImport(pythonPath: "/usr/bin/python3") {
            return true
        }

        return false
    }

    /// Test if MLX can be imported in Python
    private func testMLXImport(pythonPath: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", "import mlx.core; import mlx_lm; print('OK')"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("OK")
            }
        } catch {
            return false
        }

        return false
    }

    /// Get Python path (prioritize venv)
    func getPythonPath() -> String {
        let venvPath = "/Volumes/Data/xcode/NMAPScanner/.venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPath) {
            return venvPath
        }
        return "/usr/bin/python3"
    }

    /// Get user-friendly capability message
    func getCapabilityMessage() -> String {
        switch capabilityStatus {
        case .unchecked:
            return "AI capabilities not yet checked"
        case .checking:
            return "Checking AI capabilities..."
        case .available:
            return "✅ All AI features available (MLX + Apple Silicon)"
        case .degraded:
            return "⚠️ AI features disabled: \(errorMessage ?? "Unknown error")"
        case .unavailable:
            return "❌ AI features unavailable: \(errorMessage ?? "Unknown error")"
        }
    }
}

// MARK: - Capability Status View

struct MLXCapabilityStatusView: View {
    @ObservedObject var detector = MLXCapabilityDetector.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Capabilities")
                .font(.system(size: 24, weight: .bold))

            HStack(spacing: 12) {
                statusIcon
                Text(detector.getCapabilityMessage())
                    .font(.system(size: 16))
            }

            if detector.capabilityStatus == .available {
                VStack(alignment: .leading, spacing: 8) {
                    checkmarkRow("Apple Silicon detected")
                    checkmarkRow("MLX Python toolkit installed")
                    checkmarkRow("Metal GPU acceleration enabled")
                    checkmarkRow("All AI features ready")
                }
            } else if detector.capabilityStatus == .degraded {
                VStack(alignment: .leading, spacing: 8) {
                    checkmarkRow("Apple Silicon detected")
                    xmarkRow("MLX Python toolkit not installed")

                    Button("Install MLX") {
                        installMLX()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if detector.capabilityStatus == .unavailable {
                VStack(alignment: .leading, spacing: 8) {
                    xmarkRow("Apple Silicon required (M1/M2/M3/M4)")
                    Text("Intel Macs are not supported for on-device AI")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .task {
            await detector.checkCapabilities()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch detector.capabilityStatus {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
        case .degraded:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
        case .checking:
            ProgressView()
        case .unchecked:
            Image(systemName: "questionmark.circle")
                .font(.system(size: 32))
        }
    }

    private func checkmarkRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 14))
        }
    }

    private func xmarkRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            Text(text)
                .font(.system(size: 14))
        }
    }

    private func installMLX() {
        let script = """
        #!/bin/bash
        cd /Volumes/Data/xcode/NMAPScanner
        python3 -m venv .venv
        source .venv/bin/activate
        pip install mlx mlx-lm
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

        do {
            try process.run()
            process.waitUntilExit()

            // Re-check capabilities
            Task {
                await detector.checkCapabilities()
            }
        } catch {
            print("Failed to install MLX: \(error)")
        }
    }
}
