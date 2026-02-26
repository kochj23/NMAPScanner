//
//  NotificationManager.swift
//  NMAPScanner
//
//  Comprehensive notification system for security alerts and scan events
//  Supports banners, sounds, and persistent notification history
//  Created by Jordan Koch on 11/23/2025.
//

import Foundation
import SwiftUI
import UserNotifications

/// Manages notifications and alerts
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var settings = NotificationSettings()
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published var currentBanner: AppNotification?

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "notification_settings"
    private let notificationsKey = "notification_history"
    private let maxNotifications = 100

    // MARK: - Data Models

    struct NotificationSettings: Codable, Equatable {
        var enabled: Bool = true
        var soundEnabled: Bool = true
        var showBanner: Bool = true
        var notifyOnRogue: Bool = true
        var notifyOnNewDevice: Bool = true
        var notifyOnCriticalThreat: Bool = true
        var notifyOnScanComplete: Bool = false
        var notifyOnScheduledScan: Bool = false
        var bannerDuration: TimeInterval = 5.0
    }

    struct AppNotification: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let type: NotificationType
        let title: String
        let message: String
        let severity: Severity
        var isRead: Bool
        let actionData: [String: String]? // For actionable notifications

        enum NotificationType: String, Codable {
            case rogueDevice = "Rogue Device"
            case newDevice = "New Device"
            case criticalThreat = "Critical Threat"
            case highThreat = "High Threat"
            case scanComplete = "Scan Complete"
            case scheduledScanStarted = "Scheduled Scan"
            case deviceOffline = "Device Offline"
            case deviceOnline = "Device Online"
            case portChanged = "Port Change"
            case systemAlert = "System Alert"
            // Shadow AI Detection
            case shadowAIDetected = "Shadow AI Detected"
            case shadowAIOffline = "Shadow AI Offline"
            case shadowAIModelChanged = "AI Model Changed"
        }

        enum Severity: String, Codable {
            case info = "Info"
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
        }

        var icon: String {
            switch type {
            case .rogueDevice: return "exclamationmark.shield.fill"
            case .newDevice: return "plus.circle.fill"
            case .criticalThreat: return "exclamationmark.triangle.fill"
            case .highThreat: return "exclamationmark.octagon.fill"
            case .scanComplete: return "checkmark.circle.fill"
            case .scheduledScanStarted: return "clock.fill"
            case .deviceOffline: return "power"
            case .deviceOnline: return "power"
            case .portChanged: return "arrow.left.arrow.right"
            case .systemAlert: return "bell.fill"
            // Shadow AI Detection
            case .shadowAIDetected: return "brain.head.profile"
            case .shadowAIOffline: return "brain"
            case .shadowAIModelChanged: return "arrow.triangle.2.circlepath"
            }
        }

        var color: Color {
            switch severity {
            case .info: return .blue
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }

        init(type: NotificationType, title: String, message: String, severity: Severity, actionData: [String: String]? = nil) {
            self.id = UUID()
            self.timestamp = Date()
            self.type = type
            self.title = title
            self.message = message
            self.severity = severity
            self.isRead = false
            self.actionData = actionData
        }
    }

    // MARK: - Initialization

    init() {
        loadSettings()
        loadNotifications()
        requestNotificationPermissions()
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Show Notifications

    /// Show a notification with all configured alerts
    func showNotification(_ type: AppNotification.NotificationType, title: String, message: String, severity: AppNotification.Severity = .medium, actionData: [String: String]? = nil) {
        guard settings.enabled else { return }

        // Check if this type is enabled
        let shouldShow: Bool
        switch type {
        case .rogueDevice:
            shouldShow = settings.notifyOnRogue
        case .newDevice:
            shouldShow = settings.notifyOnNewDevice
        case .criticalThreat:
            shouldShow = settings.notifyOnCriticalThreat
        case .scanComplete:
            shouldShow = settings.notifyOnScanComplete
        case .scheduledScanStarted:
            shouldShow = settings.notifyOnScheduledScan
        default:
            shouldShow = true
        }

        guard shouldShow else { return }

        let notification = AppNotification(
            type: type,
            title: title,
            message: message,
            severity: severity,
            actionData: actionData
        )

        // Add to history
        notifications.insert(notification, at: 0)
        unreadCount += 1

        // Limit history size
        if notifications.count > maxNotifications {
            notifications.removeLast(notifications.count - maxNotifications)
        }

        saveNotifications()

        // Show banner
        if settings.showBanner {
            showBanner(notification)
        }

        // Play sound
        if settings.soundEnabled {
            playAlert(for: severity)
        }

        // Send system notification (for background)
        sendSystemNotification(notification)
    }

    // MARK: - Banner Management

    private func showBanner(_ notification: AppNotification) {
        currentBanner = notification

        // Auto-dismiss after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(settings.bannerDuration * 1_000_000_000))
            if currentBanner?.id == notification.id {
                currentBanner = nil
            }
        }
    }

    func dismissBanner() {
        currentBanner = nil
    }

    // MARK: - Sound Alerts

    func playAlert(for severity: AppNotification.Severity = .medium) {
        guard settings.soundEnabled else { return }

        // tvOS has limited sound playback options
        // In a full implementation, you would use AVFoundation
        // For now, we use system sounds

        #if os(tvOS)
        // tvOS system sound playback would go here
        print("Playing alert sound for severity: \(severity.rawValue)")
        #endif
    }

    // MARK: - System Notifications

    private func sendSystemNotification(_ notification: AppNotification) {
        #if os(iOS) || os(macOS) || os(watchOS)
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = settings.soundEnabled ? .default : nil
        content.badge = NSNumber(value: unreadCount)

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            }
        }
        #else
        // tvOS does not support UNUserNotificationCenter notifications
        // Notifications will only appear in the in-app notification center
        #endif
    }

    // MARK: - Convenience Methods

    func notifyRogueDevice(ipAddress: String, hostname: String? = nil) {
        let deviceName = hostname ?? ipAddress
        showNotification(
            .rogueDevice,
            title: "Rogue Device Detected",
            message: "Unknown device '\(deviceName)' detected on your network",
            severity: .critical,
            actionData: ["ipAddress": ipAddress]
        )
    }

    func notifyNewDevice(ipAddress: String, hostname: String? = nil, manufacturer: String? = nil) {
        let deviceInfo = [hostname, manufacturer].compactMap { $0 }.joined(separator: " - ")
        let deviceName = deviceInfo.isEmpty ? ipAddress : "\(ipAddress) (\(deviceInfo))"

        showNotification(
            .newDevice,
            title: "New Device Found",
            message: "Device discovered: \(deviceName)",
            severity: .medium,
            actionData: ["ipAddress": ipAddress]
        )
    }

    func notifyCriticalThreat(threat: String, host: String) {
        showNotification(
            .criticalThreat,
            title: "Critical Security Threat",
            message: "\(threat) on \(host)",
            severity: .critical,
            actionData: ["host": host, "threat": threat]
        )
    }

    func notifyScanComplete(deviceCount: Int, threatCount: Int) {
        showNotification(
            .scanComplete,
            title: "Scan Complete",
            message: "Found \(deviceCount) devices and \(threatCount) threats",
            severity: .info
        )
    }

    func notifyScheduledScanStarted(scanName: String) {
        showNotification(
            .scheduledScanStarted,
            title: "Scheduled Scan Started",
            message: "Running: \(scanName)",
            severity: .info
        )
    }

    func notifyPortChange(ipAddress: String, portsAdded: [Int], portsRemoved: [Int]) {
        var message = "Port changes on \(ipAddress): "
        if !portsAdded.isEmpty {
            message += "Opened: \(portsAdded.map(String.init).joined(separator: ", ")) "
        }
        if !portsRemoved.isEmpty {
            message += "Closed: \(portsRemoved.map(String.init).joined(separator: ", "))"
        }

        let severity: AppNotification.Severity = portsAdded.contains(where: { [22, 23, 3389, 5900].contains($0) }) ? .high : .medium

        showNotification(
            .portChanged,
            title: "Port Configuration Changed",
            message: message,
            severity: severity,
            actionData: ["ipAddress": ipAddress]
        )
    }

    // MARK: - Notification Management

    func markAsRead(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            if unreadCount > 0 {
                unreadCount -= 1
            }
            saveNotifications()
        }
    }

    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        unreadCount = 0
        saveNotifications()
    }

    func deleteNotification(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            if !notifications[index].isRead {
                unreadCount -= 1
            }
            notifications.remove(at: index)
            saveNotifications()
        }
    }

    func clearAll() {
        notifications.removeAll()
        unreadCount = 0
        saveNotifications()
    }

    func clearOld(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let countBefore = notifications.count

        notifications = notifications.filter { $0.timestamp >= cutoffDate }

        // Recalculate unread count
        unreadCount = notifications.filter { !$0.isRead }.count

        if notifications.count < countBefore {
            saveNotifications()
        }
    }

    // MARK: - Query Methods

    func getUnreadNotifications() -> [AppNotification] {
        return notifications.filter { !$0.isRead }
    }

    func getNotifications(ofType type: AppNotification.NotificationType) -> [AppNotification] {
        return notifications.filter { $0.type == type }
    }

    func getNotifications(withSeverity severity: AppNotification.Severity) -> [AppNotification] {
        return notifications.filter { $0.severity == severity }
    }

    func getRecentNotifications(limit: Int = 10) -> [AppNotification] {
        return Array(notifications.prefix(limit))
    }

    // MARK: - Persistence

    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            settings = decoded
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    private func loadNotifications() {
        if let data = userDefaults.data(forKey: notificationsKey),
           let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) {
            notifications = decoded
            unreadCount = notifications.filter { !$0.isRead }.count
        }
    }

    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            userDefaults.set(data, forKey: notificationsKey)
        }
    }
}

// MARK: - Notification UI

/// Banner notification overlay
struct NotificationBanner: View {
    let notification: NotificationManager.AppNotification
    let onDismiss: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: notification.icon)
                    .font(.system(size: 32))
                    .foregroundColor(notification.color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text(notification.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    Text(notification.message)
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(notification.color, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Notification center view
struct NotificationCenterView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var filterType: FilterType = .all

    enum FilterType: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case critical = "Critical"
        case today = "Today"
    }

    var filteredNotifications: [NotificationManager.AppNotification] {
        switch filterType {
        case .all:
            return notificationManager.notifications
        case .unread:
            return notificationManager.getUnreadNotifications()
        case .critical:
            return notificationManager.getNotifications(withSeverity: .critical)
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return notificationManager.notifications.filter { $0.timestamp >= today }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter bar
                HStack {
                    Text("Filter:")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)

                    Picker("Filter", selection: $filterType) {
                        ForEach(FilterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Spacer()

                    if notificationManager.unreadCount > 0 {
                        Button("Mark All Read") {
                            notificationManager.markAllAsRead()
                        }
                        .font(.system(size: 20))
                    }
                }
                .padding()

                if filteredNotifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                        Text("No Notifications")
                            .font(.system(size: 32, weight: .semibold))
                        Text("You're all caught up!")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                } else {
                    List {
                        ForEach(filteredNotifications) { notification in
                            NotificationRow(notification: notification)
                                // swipeActions not available on tvOS - use long press instead
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // Menu with availability check for tvOS 17+
                    if #available(tvOS 17.0, *) {
                        Menu {
                            Button("Clear All", role: .destructive) {
                                notificationManager.clearAll()
                            }
                            Button("Clear Old (30+ days)") {
                                notificationManager.clearOld()
                            }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        } else {
                            // Fallback for tvOS <17: just a clear all button
                            Button("Clear All") {
                                notificationManager.clearAll()
                            }
                        }
                    }
                }
            }
        }
    }

struct NotificationRow: View {
    let notification: NotificationManager.AppNotification
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        Button(action: {
            notificationManager.markAsRead(notification)
        }) {
            HStack(spacing: 16) {
                Image(systemName: notification.icon)
                    .font(.system(size: 32))
                    .foregroundColor(notification.color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 24, weight: notification.isRead ? .regular : .bold))

                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                        }
                    }

                    Text(notification.message)
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack {
                        Text(notification.type.rawValue)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(notification.timestamp, style: .relative)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)

                        Text("ago")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

/// Notification settings view
struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Enable Notifications", isOn: $notificationManager.settings.enabled)
                        .font(.system(size: 24))

                    Toggle("Play Sounds", isOn: $notificationManager.settings.soundEnabled)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)

                    Toggle("Show Banners", isOn: $notificationManager.settings.showBanner)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)
                }

                Section(header: Text("Notification Types")) {
                    Toggle("Rogue Devices", isOn: $notificationManager.settings.notifyOnRogue)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)

                    Toggle("New Devices", isOn: $notificationManager.settings.notifyOnNewDevice)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)

                    Toggle("Critical Threats", isOn: $notificationManager.settings.notifyOnCriticalThreat)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)

                    Toggle("Scan Completed", isOn: $notificationManager.settings.notifyOnScanComplete)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)

                    Toggle("Scheduled Scans", isOn: $notificationManager.settings.notifyOnScheduledScan)
                        .font(.system(size: 24))
                        .disabled(!notificationManager.settings.enabled)
                }

                Section(header: Text("Banner Display")) {
                    // Slider and Stepper not available on tvOS, use buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration: \(String(format: "%.0f", notificationManager.settings.bannerDuration))s")
                            .font(.system(size: 20))
                        HStack(spacing: 8) {
                            ForEach([3.0, 5.0, 7.0, 10.0], id: \.self) { duration in
                                Button("\(Int(duration))s") {
                                    notificationManager.settings.bannerDuration = duration
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(notificationManager.settings.bannerDuration == duration ? .white : .blue)
                                .background(notificationManager.settings.bannerDuration == duration ? Color.blue : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .disabled(!notificationManager.settings.enabled || !notificationManager.settings.showBanner)
                }
            }
            .navigationTitle("Notification Settings")
            .onChange(of: notificationManager.settings) { _ in
                notificationManager.saveSettings()
            }
        }
    }
}
