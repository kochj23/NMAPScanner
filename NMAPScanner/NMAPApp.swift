//
//  NMAPApp.swift
//  NMAP Scanner
//
//  Created by Jordan Koch on 2025-11-23.
//  Updated: 2026-01-31 - Added Menu Bar Agent integration
//  Updated: 2026-01-31 - Migrated to @Observable (Swift 5.9+)
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import UserNotifications

@main
struct NMAPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // With @Observable, singletons don't need @StateObject wrapper
    // They're automatically observable when accessed in views
    private var menuBarAgent = MenuBarAgent.shared
    private var scheduledScanManager = ScheduledScanManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: .menuBarShowWindow)) { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    NotificationCenter.default.post(name: .menuBarOpenPreferences, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Settings window
        Settings {
            EnhancedSettingsView()
        }
    }
}

// MARK: - App Delegate for Menu Bar Integration

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar agent
        Task { @MainActor in
            MenuBarAgent.shared.setup()
            SecureLogger.log("Menu bar agent initialized on app launch", level: .info)
        }

        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                SecureLogger.log("Notification permissions granted", level: .info)
            } else if let error = error {
                SecureLogger.log("Notification permission error: \(error.localizedDescription)", level: .warning)
            }
        }

        // Set up observers for menu bar actions
        setupMenuBarObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            MenuBarAgent.shared.teardown()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        return !UserDefaults.standard.bool(forKey: "RunInMenuBarOnly")
    }

    private func setupMenuBarObservers() {
        // Quick scan from menu bar
        NotificationCenter.default.addObserver(
            forName: .menuBarQuickScan,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarAgent.shared.updateStatus(
                    devices: MenuBarAgent.shared.deviceCount,
                    threats: MenuBarAgent.shared.threatCount,
                    scanning: true
                )
                // Trigger a quick scan via the scheduled scan notification
                NotificationCenter.default.post(name: .performScheduledScan, object: nil)
            }
        }

        // Full scan from menu bar
        NotificationCenter.default.addObserver(
            forName: .menuBarFullScan,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarAgent.shared.updateStatus(
                    devices: MenuBarAgent.shared.deviceCount,
                    threats: MenuBarAgent.shared.threatCount,
                    scanning: true
                )
                // Trigger a full scan
                NotificationCenter.default.post(name: .performScheduledScan, object: nil)
            }
        }

        // Open preferences from menu bar
        NotificationCenter.default.addObserver(
            forName: .menuBarOpenPreferences,
            object: nil,
            queue: .main
        ) { _ in
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap - bring app to front
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }
}
