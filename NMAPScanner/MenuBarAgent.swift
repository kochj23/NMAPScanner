//
//  MenuBarAgent.swift
//  NMAPScanner - Menu Bar Agent for Quick Access
//
//  Persistent menu bar presence with quick scan and notifications
//  Created by Jordan Koch on 2025-12-11.
//

import SwiftUI
import AppKit

// MARK: - Menu Bar Agent

@MainActor
class MenuBarAgent: ObservableObject {
    static let shared = MenuBarAgent()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    @Published var deviceCount: Int = 0
    @Published var threatCount: Int = 0
    @Published var isScanning: Bool = false
    @Published var lastScanTime: Date?

    private init() {}

    // MARK: - Setup

    /// Initialize menu bar item
    func setup() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set icon
        button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "NMAPScanner")
        button.imagePosition = .imageLeading

        // Create menu
        menu = NSMenu()

        // Add menu items
        updateMenu()

        statusItem?.menu = menu

        SecureLogger.log("Menu bar agent initialized", level: .info)
    }

    /// Update menu bar display
    func updateStatus(devices: Int, threats: Int, scanning: Bool) {
        self.deviceCount = devices
        self.threatCount = threats
        self.isScanning = scanning

        if scanning {
            statusItem?.button?.title = "Scanning..."
        } else {
            statusItem?.button?.title = "\(devices)"
        }

        // Update icon based on threat level
        if threats > 0 {
            statusItem?.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Threats Detected")
        } else {
            statusItem?.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "NMAPScanner")
        }

        updateMenu()
    }

    // MARK: - Menu Management

    private func updateMenu() {
        guard let menu = menu else { return }

        menu.removeAllItems()

        // Header
        let headerItem = NSMenuItem()
        headerItem.title = "NMAPScanner"
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Status info
        if isScanning {
            let scanItem = NSMenuItem()
            scanItem.title = "🔄 Scanning network..."
            scanItem.isEnabled = false
            menu.addItem(scanItem)
        } else {
            let devicesItem = NSMenuItem()
            devicesItem.title = "📱 \(deviceCount) devices found"
            devicesItem.isEnabled = false
            menu.addItem(devicesItem)

            if threatCount > 0 {
                let threatsItem = NSMenuItem()
                threatsItem.title = "⚠️ \(threatCount) threats detected"
                threatsItem.isEnabled = false
                menu.addItem(threatsItem)
            } else {
                let safeItem = NSMenuItem()
                safeItem.title = "✅ No threats detected"
                safeItem.isEnabled = false
                menu.addItem(safeItem)
            }

            if let lastScan = lastScanTime {
                let lastScanItem = NSMenuItem()
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                lastScanItem.title = "Last scan: \(formatter.localizedString(for: lastScan, relativeTo: Date()))"
                lastScanItem.isEnabled = false
                menu.addItem(lastScanItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Actions
        let quickScanItem = NSMenuItem(title: "Quick Scan", action: #selector(triggerQuickScan), keyEquivalent: "s")
        quickScanItem.target = self
        quickScanItem.isEnabled = !isScanning
        menu.addItem(quickScanItem)

        let fullScanItem = NSMenuItem(title: "Full Scan", action: #selector(triggerFullScan), keyEquivalent: "")
        fullScanItem.target = self
        fullScanItem.isEnabled = !isScanning
        menu.addItem(fullScanItem)

        menu.addItem(NSMenuItem.separator())

        let showMainWindowItem = NSMenuItem(title: "Open NMAPScanner", action: #selector(showMainWindow), keyEquivalent: "o")
        showMainWindowItem.target = self
        menu.addItem(showMainWindowItem)

        menu.addItem(NSMenuItem.separator())

        // Recent devices submenu (if we have devices)
        if deviceCount > 0 {
            let recentDevicesMenu = NSMenu()
            let recentItem = NSMenuItem(title: "Recent Devices", action: nil, keyEquivalent: "")
            recentItem.submenu = recentDevicesMenu
            menu.addItem(recentItem)

            // TODO: Populate with actual recent devices
            let placeholderItem = NSMenuItem()
            placeholderItem.title = "No recent devices"
            placeholderItem.isEnabled = false
            recentDevicesMenu.addItem(placeholderItem)

            menu.addItem(NSMenuItem.separator())
        }

        // Settings
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit NMAPScanner", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func triggerQuickScan() {
        NotificationCenter.default.post(name: .menuBarQuickScan, object: nil)
        SecureLogger.log("Quick scan triggered from menu bar", level: .info)
    }

    @objc private func triggerFullScan() {
        NotificationCenter.default.post(name: .menuBarFullScan, object: nil)
        SecureLogger.log("Full scan triggered from menu bar", level: .info)
    }

    @objc private func showMainWindow() {
        NotificationCenter.default.post(name: .menuBarShowWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPreferences() {
        NotificationCenter.default.post(name: .menuBarOpenPreferences, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show notification in menu bar
    func showNotification(title: String, message: String) {
        // Flash the menu bar icon
        if let button = statusItem?.button {
            let originalImage = button.image

            // Flash red
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Alert")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                button.image = originalImage
            }
        }

        // Post system notification
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }

    /// Remove menu bar item
    func teardown() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menu = nil

        SecureLogger.log("Menu bar agent removed", level: .info)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarQuickScan = Notification.Name("menuBarQuickScan")
    static let menuBarFullScan = Notification.Name("menuBarFullScan")
    static let menuBarShowWindow = Notification.Name("menuBarShowWindow")
    static let menuBarOpenPreferences = Notification.Name("menuBarOpenPreferences")
}
