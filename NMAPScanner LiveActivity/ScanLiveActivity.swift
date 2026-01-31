//
//  ScanLiveActivity.swift
//  NMAPScanner
//
//  Live Activity for real-time network scan progress on lock screen
//  Shows scan progress, devices found, and threat alerts
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes

struct ScanActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state
        var scanProgress: Double // 0.0 to 1.0
        var devicesFound: Int
        var threatsFound: Int
        var currentHost: String?
        var scanStatus: ScanStatus
        var elapsedTime: TimeInterval

        enum ScanStatus: String, Codable {
            case scanning
            case analyzing
            case complete
            case paused
            case cancelled
        }
    }

    // Fixed attributes
    var scanType: ScanType
    var networkRange: String
    var startTime: Date

    enum ScanType: String, Codable {
        case quick
        case full
        case custom
    }
}

// MARK: - Live Activity Widget

struct ScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanActivityAttributes.self) { context in
            // Lock screen presentation
            ScanLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading) {
                            Text(context.attributes.scanType.rawValue.capitalized)
                                .font(.caption.bold())
                            Text("Scan")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        if context.state.threatsFound > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("\(context.state.threatsFound)")
                                    .font(.caption.bold())
                                    .foregroundColor(.red)
                            }
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        ProgressView(value: context.state.scanProgress)
                            .progressViewStyle(.linear)
                            .tint(progressColor(for: context.state))

                        Text("\(Int(context.state.scanProgress * 100))%")
                            .font(.caption.bold())
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.devicesFound)", systemImage: "desktopcomputer")
                            .font(.caption)

                        Spacer()

                        if let host = context.state.currentHost {
                            Text(host)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formatElapsedTime(context.state.elapsedTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .foregroundColor(.cyan)
                    if context.state.threatsFound > 0 {
                        Text("\(context.state.threatsFound)")
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                    }
                }
            } compactTrailing: {
                Text("\(Int(context.state.scanProgress * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(progressColor(for: context.state))
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.scanProgress)
                        .stroke(progressColor(for: context.state), lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)
            }
        }
    }

    private func progressColor(for state: ScanActivityAttributes.ContentState) -> Color {
        if state.threatsFound > 0 { return .red }
        if state.scanStatus == .complete { return .green }
        return .cyan
    }

    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Lock Screen View

struct ScanLockScreenView: View {
    let context: ActivityViewContext<ScanActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(.cyan)

                VStack(alignment: .leading) {
                    Text("\(context.attributes.scanType.rawValue.capitalized) Scan")
                        .font(.headline.bold())
                    Text(context.attributes.networkRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status badge
                statusBadge
            }

            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: context.state.scanProgress)
                    .progressViewStyle(.linear)
                    .tint(progressColor)

                HStack {
                    Text("\(Int(context.state.scanProgress * 100))%")
                        .font(.caption.bold())

                    Spacer()

                    if let host = context.state.currentHost {
                        Text("Scanning: \(host)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Stats row
            HStack(spacing: 16) {
                StatItem(icon: "desktopcomputer", value: "\(context.state.devicesFound)", label: "Devices", color: .blue)

                StatItem(
                    icon: context.state.threatsFound > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                    value: context.state.threatsFound > 0 ? "\(context.state.threatsFound)" : "0",
                    label: "Threats",
                    color: context.state.threatsFound > 0 ? .red : .green
                )

                StatItem(icon: "clock", value: formatElapsedTime(context.state.elapsedTime), label: "Elapsed", color: .secondary)
            }

            // Action buttons
            if context.state.scanStatus == .scanning {
                HStack(spacing: 12) {
                    Button(intent: PauseScanIntent()) {
                        Label("Pause", systemImage: "pause.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)

                    Button(intent: CancelScanIntent()) {
                        Label("Cancel", systemImage: "xmark")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(context.state.scanStatus.rawValue.capitalized)
                .font(.caption.bold())
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch context.state.scanStatus {
        case .scanning: return .cyan
        case .analyzing: return .orange
        case .complete: return .green
        case .paused: return .yellow
        case .cancelled: return .red
        }
    }

    private var progressColor: Color {
        if context.state.threatsFound > 0 { return .red }
        if context.state.scanStatus == .complete { return .green }
        return .cyan
    }

    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Live Activity Intents

struct PauseScanIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Scan"

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .pauseScanFromLiveActivity, object: nil)
        return .result()
    }
}

struct CancelScanIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Scan"

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .cancelScanFromLiveActivity, object: nil)
        return .result()
    }
}

// MARK: - Live Activity Manager

@MainActor
class ScanLiveActivityManager {
    static let shared = ScanLiveActivityManager()

    private var currentActivity: Activity<ScanActivityAttributes>?
    private var startTime: Date?

    private init() {}

    // Start a new scan activity
    func startScan(type: ScanActivityAttributes.ScanType, networkRange: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        startTime = Date()

        let attributes = ScanActivityAttributes(
            scanType: type,
            networkRange: networkRange,
            startTime: startTime!
        )

        let initialState = ScanActivityAttributes.ContentState(
            scanProgress: 0.0,
            devicesFound: 0,
            threatsFound: 0,
            currentHost: nil,
            scanStatus: .scanning,
            elapsedTime: 0
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start scan activity: \(error)")
        }
    }

    // Update scan progress
    func updateProgress(
        progress: Double,
        devicesFound: Int,
        threatsFound: Int,
        currentHost: String?
    ) async {
        guard let activity = currentActivity,
              let startTime = startTime else { return }

        let elapsedTime = Date().timeIntervalSince(startTime)

        let updatedState = ScanActivityAttributes.ContentState(
            scanProgress: progress,
            devicesFound: devicesFound,
            threatsFound: threatsFound,
            currentHost: currentHost,
            scanStatus: progress < 1.0 ? .scanning : .analyzing,
            elapsedTime: elapsedTime
        )

        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
    }

    // Complete scan
    func completeScan(devicesFound: Int, threatsFound: Int) async {
        guard let activity = currentActivity,
              let startTime = startTime else { return }

        let elapsedTime = Date().timeIntervalSince(startTime)

        let finalState = ScanActivityAttributes.ContentState(
            scanProgress: 1.0,
            devicesFound: devicesFound,
            threatsFound: threatsFound,
            currentHost: nil,
            scanStatus: .complete,
            elapsedTime: elapsedTime
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now + 10)
        )

        currentActivity = nil
        self.startTime = nil
    }

    // Pause scan
    func pauseScan() async {
        guard let activity = currentActivity else { return }

        var pausedState = activity.content.state
        pausedState.scanStatus = .paused

        await activity.update(
            ActivityContent(state: pausedState, staleDate: nil)
        )
    }

    // Resume scan
    func resumeScan() async {
        guard let activity = currentActivity else { return }

        var resumedState = activity.content.state
        resumedState.scanStatus = .scanning

        await activity.update(
            ActivityContent(state: resumedState, staleDate: nil)
        )
    }

    // Cancel scan
    func cancelScan() async {
        guard let activity = currentActivity else { return }

        var cancelledState = activity.content.state
        cancelledState.scanStatus = .cancelled

        await activity.end(
            ActivityContent(state: cancelledState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        startTime = nil
    }

    // End all activities
    func endAllActivities() async {
        for activity in Activity<ScanActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        currentActivity = nil
        startTime = nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pauseScanFromLiveActivity = Notification.Name("pauseScanFromLiveActivity")
    static let cancelScanFromLiveActivity = Notification.Name("cancelScanFromLiveActivity")
}
#endif
