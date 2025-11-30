//
//  HomeKitNotificationManager.swift
//  NMAP Plus Security Scanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Manages smart notifications for HomeKit device changes:
//  - New device discovered
//  - Known device disappeared
//  - Device changed IP address
//  - Device changed name
//
//  Integrates with macOS notification center.
//

import Foundation
#if os(macOS) || os(iOS)
import UserNotifications
#endif

/// Manages notifications for HomeKit device events
@MainActor
class HomeKitNotificationManager: ObservableObject {

    static let shared = HomeKitNotificationManager()

    // MARK: - Published Properties

    @Published var notificationsEnabled: Bool = true
    @Published var notifyOnNewDevice: Bool = true
    @Published var notifyOnDeviceDisappeared: Bool = true
    @Published var notifyOnDeviceChanged: Bool = true

    // MARK: - Private Properties

    #if os(macOS) || os(iOS)
    private let notificationCenter = UNUserNotificationCenter.current()
    #endif
    private var knownDevices: Set<String> = []  // device IDs
    private var deviceIPMapping: [String: String] = [:]  // deviceID -> IP
    private var deviceNameMapping: [String: String] = [:]  // deviceID -> name

    private let prefsKey = "HomeKitNotificationPreferences"

    // MARK: - Initialization

    private init() {
        loadPreferences()
        requestAuthorization()
    }

    // MARK: - Public Methods

    /// Request notification authorization
    func requestAuthorization() {
        #if os(macOS) || os(iOS)
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                if granted {
                    print("🔔 Notifications: Authorization granted")
                } else if let error = error {
                    print("🔔 Notifications: Authorization error: \(error)")
                } else {
                    print("🔔 Notifications: Authorization denied")
                }
            }
        }
        #else
        print("🔔 Notifications: Not supported on this platform")
        #endif
    }

    /// Process discovered devices and send notifications
    func processDevices(_ devices: [HomeKitDevice]) {
        guard notificationsEnabled else { return }

        let currentDeviceIDs = Set(devices.map { $0.id })

        #if os(macOS) || os(iOS)
        // Check for new devices
        if notifyOnNewDevice {
            for device in devices where !knownDevices.contains(device.id) {
                sendNewDeviceNotification(device)
            }
        }

        // Check for disappeared devices
        if notifyOnDeviceDisappeared {
            let disappearedIDs = knownDevices.subtracting(currentDeviceIDs)
            for deviceID in disappearedIDs {
                sendDeviceDisappearedNotification(deviceID: deviceID)
            }
        }

        // Check for IP/name changes
        if notifyOnDeviceChanged {
            for device in devices where knownDevices.contains(device.id) {
                // Check IP change
                if let oldIP = deviceIPMapping[device.id],
                   let newIP = device.ipAddress,
                   oldIP != newIP {
                    sendIPChangedNotification(device: device, oldIP: oldIP, newIP: newIP)
                }

                // Check name change
                if let oldName = deviceNameMapping[device.id],
                   oldName != device.displayName {
                    sendNameChangedNotification(device: device, oldName: oldName, newName: device.displayName)
                }
            }
        }
        #endif

        // Update known devices
        knownDevices = currentDeviceIDs
        for device in devices {
            if let ip = device.ipAddress {
                deviceIPMapping[device.id] = ip
            }
            deviceNameMapping[device.id] = device.displayName
        }
    }

    /// Clear notification history
    func clearNotifications() {
        #if os(macOS) || os(iOS)
        notificationCenter.removeAllDeliveredNotifications()
        #endif
    }

    // MARK: - Private Methods

    #if os(macOS) || os(iOS)
    private func sendNewDeviceNotification(_ device: HomeKitDevice) {
        let content = UNMutableNotificationContent()
        content.title = "New HomeKit Device Discovered"
        content.body = "\(device.displayName) joined the network"
        content.sound = .default
        content.categoryIdentifier = "homekit.new_device"

        if let ip = device.ipAddress {
            content.subtitle = "IP: \(ip)"
        }

        let request = UNNotificationRequest(
            identifier: "homekit.new.\(device.id).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("🔔 Notifications: Error sending new device notification: \(error)")
            } else {
                print("🔔 Notifications: Sent new device notification for \(device.displayName)")
            }
        }
    }

    private func sendDeviceDisappearedNotification(deviceID: String) {
        let deviceName = deviceNameMapping[deviceID] ?? "Unknown Device"

        let content = UNMutableNotificationContent()
        content.title = "HomeKit Device Offline"
        content.body = "\(deviceName) is no longer visible on the network"
        content.sound = .default
        content.categoryIdentifier = "homekit.device_disappeared"

        if let ip = deviceIPMapping[deviceID] {
            content.subtitle = "Last IP: \(ip)"
        }

        let request = UNNotificationRequest(
            identifier: "homekit.disappeared.\(deviceID).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("🔔 Notifications: Error sending disappeared notification: \(error)")
            } else {
                print("🔔 Notifications: Sent disappeared notification for \(deviceName)")
            }
        }
    }

    private func sendIPChangedNotification(device: HomeKitDevice, oldIP: String, newIP: String) {
        let content = UNMutableNotificationContent()
        content.title = "HomeKit Device IP Changed"
        content.body = "\(device.displayName) changed IP address"
        content.subtitle = "\(oldIP) → \(newIP)"
        content.sound = .default
        content.categoryIdentifier = "homekit.ip_changed"

        let request = UNNotificationRequest(
            identifier: "homekit.ipchange.\(device.id).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("🔔 Notifications: Error sending IP change notification: \(error)")
            } else {
                print("🔔 Notifications: Sent IP change notification for \(device.displayName)")
            }
        }
    }

    private func sendNameChangedNotification(device: HomeKitDevice, oldName: String, newName: String) {
        let content = UNMutableNotificationContent()
        content.title = "HomeKit Device Name Changed"
        content.body = "Device renamed: \(oldName) → \(newName)"
        content.sound = .default
        content.categoryIdentifier = "homekit.name_changed"

        if let ip = device.ipAddress {
            content.subtitle = "IP: \(ip)"
        }

        let request = UNNotificationRequest(
            identifier: "homekit.namechange.\(device.id).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("🔔 Notifications: Error sending name change notification: \(error)")
            } else {
                print("🔔 Notifications: Sent name change notification")
            }
        }
    }

    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: prefsKey),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            notificationsEnabled = prefs.enabled
            notifyOnNewDevice = prefs.notifyOnNewDevice
            notifyOnDeviceDisappeared = prefs.notifyOnDeviceDisappeared
            notifyOnDeviceChanged = prefs.notifyOnDeviceChanged
        }
    }

    private func savePreferences() {
        let prefs = NotificationPreferences(
            enabled: notificationsEnabled,
            notifyOnNewDevice: notifyOnNewDevice,
            notifyOnDeviceDisappeared: notifyOnDeviceDisappeared,
            notifyOnDeviceChanged: notifyOnDeviceChanged
        )

        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: prefsKey)
        }
    }

    // MARK: - Codable Preferences

    private struct NotificationPreferences: Codable {
        let enabled: Bool
        let notifyOnNewDevice: Bool
        let notifyOnDeviceDisappeared: Bool
        let notifyOnDeviceChanged: Bool
    }
    #endif
}
