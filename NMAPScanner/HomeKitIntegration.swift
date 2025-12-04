//
//  HomeKitIntegration.swift
//  NMAP Plus Security Scanner - HomeKit Device Identification
//
//  Created by Jordan Koch on 2025-11-24.
//
//  NOTE: HomeKit framework is only available on iOS, tvOS, and watchOS.
//  For macOS, this provides a stub implementation that indicates HomeKit is unavailable.
//

import Foundation
import SwiftUI

#if canImport(HomeKit)
import HomeKit

/// HomeKit Integration - Identifies IoT devices using HomeKit accessories
@MainActor
class HomeKitIntegration: NSObject, ObservableObject, HMHomeManagerDelegate {
    static let shared = HomeKitIntegration()

    @Published var isAuthorized = false
    @Published var homes: [HMHome] = []
    @Published var accessories: [HMAccessory] = []
    @Published var accessoriesByIP: [String: HMAccessory] = [:]
    @Published var lastSync: Date?
    @Published var authorizationStatus: String = "Not Requested"

    private var homeManager: HMHomeManager?

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    /// Request HomeKit authorization
    func requestAuthorization() {
        print("🏠 HomeKit: Requesting authorization...")
        homeManager = HMHomeManager()
        homeManager?.delegate = self
        authorizationStatus = "Requested"
    }

    /// Check if HomeKit is authorized
    var isHomeKitAvailable: Bool {
        return homeManager != nil && !homes.isEmpty
    }

    // MARK: - HMHomeManagerDelegate

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            print("🏠 HomeKit: Homes updated")
            self.homes = manager.homes
            self.isAuthorized = true
            self.authorizationStatus = "Authorized"
            await syncAccessories()
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in
            print("🏠 HomeKit: Home added - \(home.name)")
            self.homes = manager.homes
            await syncAccessories()
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in
            print("🏠 HomeKit: Home removed - \(home.name)")
            self.homes = manager.homes
            await syncAccessories()
        }
    }

    // MARK: - Accessory Discovery

    /// Sync all HomeKit accessories
    func syncAccessories() async {
        print("🏠 HomeKit: Syncing accessories from \(homes.count) homes...")

        var allAccessories: [HMAccessory] = []
        var accessoriesMap: [String: HMAccessory] = [:]

        for home in homes {
            print("🏠 HomeKit: Processing home '\(home.name)' with \(home.accessories.count) accessories")

            for accessory in home.accessories {
                allAccessories.append(accessory)

                if let ipAddress = extractIPAddress(from: accessory) {
                    print("🏠 HomeKit: Found accessory '\(accessory.name)' at IP \(ipAddress)")
                    accessoriesMap[ipAddress] = accessory
                }
            }
        }

        accessories = allAccessories
        accessoriesByIP = accessoriesMap
        lastSync = Date()

        print("🏠 HomeKit: Sync complete - \(accessories.count) total accessories, \(accessoriesByIP.count) with IPs")
    }

    /// Extract IP address from HomeKit accessory
    private func extractIPAddress(from accessory: HMAccessory) -> String? {
        let ipPattern = #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#
        if let range = accessory.name.range(of: ipPattern, options: .regularExpression) {
            return String(accessory.name[range])
        }
        return nil
    }
}

#else

/// HomeKit Integration Stub for macOS
/// HomeKit framework is not available on native macOS apps
@MainActor
class HomeKitIntegration: ObservableObject {
    static let shared = HomeKitIntegration()

    @Published var isAuthorized = false
    @Published var homes: [AnyObject] = []
    @Published var accessories: [AnyObject] = []
    @Published var accessoriesByIP: [String: AnyObject] = [:]
    @Published var lastSync: Date?
    @Published var authorizationStatus: String = "Not Available on macOS"

    private init() {}

    func requestAuthorization() {
        print("⚠️ HomeKit: Not available on macOS")
        authorizationStatus = "Not Available on macOS"
    }

    var isHomeKitAvailable: Bool {
        return false
    }

    func syncAccessories() async {
        print("⚠️ HomeKit: Not available on macOS")
    }
}

#endif

// MARK: - Data Models

/// HomeKit device information
struct HomeKitDeviceInfo {
    let name: String
    let category: String
    let manufacturer: String
    let model: String
    let firmwareVersion: String
    let room: String?
    let isReachable: Bool
    let services: [HomeKitServiceInfo]
}

/// HomeKit service information
struct HomeKitServiceInfo {
    let type: String
    let name: String
    let isPrimary: Bool
}

// MARK: - HomeKit Settings View

struct HomeKitSettingsView: View {
    @ObservedObject var homeKit: HomeKitIntegration

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("HomeKit Integration")
                .font(.system(size: 22, weight: .semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("HomeKit", systemImage: "homekit")
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        if homeKit.isAuthorized {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Authorized")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    #if canImport(HomeKit)
                    Text("Access HomeKit accessories to better identify IoT devices on your network")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if !homeKit.isAuthorized {
                        Button("Authorize HomeKit") {
                            homeKit.requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(homeKit.homes.count)")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("Homes")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(homeKit.accessories.count)")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("Accessories")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(homeKit.accessoriesByIP.count)")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("With IPs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let lastSync = homeKit.lastSync {
                                Text("Last synced: \(lastSync, style: .relative) ago")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Button("Sync Accessories") {
                                Task {
                                    await homeKit.syncAccessories()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    #else
                    Text("HomeKit framework is not available on macOS. HomeKit integration requires iOS, tvOS, or watchOS.")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)

                    Text("Status: \(homeKit.authorizationStatus)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    #endif
                }
                .padding()
            }
        }
    }
}

#Preview {
    HomeKitSettingsView(homeKit: HomeKitIntegration.shared)
}
