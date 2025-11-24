//
//  DevicePersistence.swift
//  NMAP Scanner - Device Whitelist & Persistent Tracking
//
//  Created by Jordan Koch & Claude Code on 2025-11-23.
//

import Foundation

// MARK: - Persisted Device Record

/// Represents a device that has been seen on the network with persistent tracking
struct PersistedDevice: Codable, Identifiable {
    let id: UUID
    let ipAddress: String
    let macAddress: String?
    var hostname: String?
    var manufacturer: String?
    let deviceType: String
    var firstSeen: Date
    var lastSeen: Date
    var isWhitelisted: Bool
    var userNotes: String?
    var customName: String?

    init(from device: EnhancedDevice) {
        self.id = device.id
        self.ipAddress = device.ipAddress
        self.macAddress = device.macAddress
        self.hostname = device.hostname
        self.manufacturer = device.manufacturer
        self.deviceType = device.deviceType.rawValue
        self.firstSeen = device.firstSeen
        self.lastSeen = device.lastSeen
        self.isWhitelisted = device.isKnownDevice
        self.userNotes = nil
        self.customName = device.deviceName
    }

    mutating func updateLastSeen() {
        self.lastSeen = Date()
    }
}

// MARK: - Network History Record

/// Represents a network subnet that has been scanned
struct NetworkRecord: Codable, Identifiable {
    let id: UUID
    let subnet: String // e.g., "192.168.1"
    let subnetMask: String // e.g., "255.255.255.0" or "/24"
    var firstScanned: Date
    var lastScanned: Date
    var scanCount: Int
    var deviceCount: Int
    var notes: String?

    init(subnet: String, subnetMask: String = "/24") {
        self.id = UUID()
        self.subnet = subnet
        self.subnetMask = subnetMask
        self.firstScanned = Date()
        self.lastScanned = Date()
        self.scanCount = 1
        self.deviceCount = 0
        self.notes = nil
    }

    mutating func recordScan(deviceCount: Int) {
        self.lastScanned = Date()
        self.scanCount += 1
        self.deviceCount = deviceCount
    }
}

// MARK: - User Settings

/// User-configurable settings for threat detection
struct ThreatDetectionSettings: Codable {
    var rogueDeviceTimeWindowMinutes: Int // Time window for rogue device detection
    var enableAutomaticScanning: Bool
    var scanIntervalMinutes: Int
    var enableRogueDeviceAlerts: Bool
    var enableBackdoorAlerts: Bool
    var autoWhitelistKnownServices: Bool

    static let `default` = ThreatDetectionSettings(
        rogueDeviceTimeWindowMinutes: 60, // 1 hour
        enableAutomaticScanning: true,
        scanIntervalMinutes: 30,
        enableRogueDeviceAlerts: true,
        enableBackdoorAlerts: true,
        autoWhitelistKnownServices: false
    )
}

// MARK: - Device Persistence Manager

@MainActor
class DevicePersistenceManager: ObservableObject {
    static let shared = DevicePersistenceManager()

    @Published var persistedDevices: [PersistedDevice] = []
    @Published var networkHistory: [NetworkRecord] = []
    @Published var settings: ThreatDetectionSettings = .default

    private let devicesKey = "com.digitalnoise.nmapscanner.devices"
    private let networksKey = "com.digitalnoise.nmapscanner.networks"
    private let settingsKey = "com.digitalnoise.nmapscanner.settings"

    private init() {
        loadAll()
    }

    // MARK: - Device Management

    /// Add or update a device in persistent storage
    func addOrUpdateDevice(_ device: EnhancedDevice) {
        // Try to find existing device by IP or MAC
        if let index = persistedDevices.firstIndex(where: {
            $0.ipAddress == device.ipAddress ||
            ($0.macAddress != nil && device.macAddress != nil && $0.macAddress == device.macAddress)
        }) {
            // Update existing device
            persistedDevices[index].updateLastSeen()
            persistedDevices[index].hostname = device.hostname ?? persistedDevices[index].hostname
            persistedDevices[index].manufacturer = device.manufacturer ?? persistedDevices[index].manufacturer
        } else {
            // Add new device
            let persisted = PersistedDevice(from: device)
            persistedDevices.append(persisted)
        }

        saveDevices()
    }

    /// Check if a device is whitelisted (known)
    func isDeviceKnown(_ device: EnhancedDevice) -> Bool {
        // Check by IP address
        if let persisted = persistedDevices.first(where: { $0.ipAddress == device.ipAddress }) {
            return persisted.isWhitelisted
        }

        // Check by MAC address if available
        if let mac = device.macAddress {
            if let persisted = persistedDevices.first(where: { $0.macAddress == mac }) {
                return persisted.isWhitelisted
            }
        }

        return false
    }

    /// Get first seen date for a device
    func getFirstSeen(for device: EnhancedDevice) -> Date? {
        // Check by IP address first
        if let persisted = persistedDevices.first(where: { $0.ipAddress == device.ipAddress }) {
            return persisted.firstSeen
        }

        // Check by MAC address if available
        if let mac = device.macAddress {
            if let persisted = persistedDevices.first(where: { $0.macAddress == mac }) {
                return persisted.firstSeen
            }
        }

        return nil
    }

    /// Whitelist a device (mark as known/trusted)
    func whitelistDevice(ipAddress: String) {
        if let index = persistedDevices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            persistedDevices[index].isWhitelisted = true
            saveDevices()
        }
    }

    /// Remove device from whitelist
    func removeFromWhitelist(ipAddress: String) {
        if let index = persistedDevices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            persistedDevices[index].isWhitelisted = false
            saveDevices()
        }
    }

    /// Delete a device from persistent storage
    func deleteDevice(id: UUID) {
        persistedDevices.removeAll { $0.id == id }
        saveDevices()
    }

    /// Set custom name for device
    func setCustomName(_ name: String, for ipAddress: String) {
        if let index = persistedDevices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            persistedDevices[index].customName = name
            saveDevices()
        }
    }

    /// Set notes for device
    func setNotes(_ notes: String, for ipAddress: String) {
        if let index = persistedDevices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            persistedDevices[index].userNotes = notes
            saveDevices()
        }
    }

    // MARK: - Network History Management

    /// Add or update network in history
    func addOrUpdateNetwork(subnet: String, deviceCount: Int) {
        if let index = networkHistory.firstIndex(where: { $0.subnet == subnet }) {
            // Update existing network
            networkHistory[index].recordScan(deviceCount: deviceCount)
        } else {
            // Add new network
            var network = NetworkRecord(subnet: subnet)
            network.deviceCount = deviceCount
            networkHistory.append(network)
        }

        saveNetworks()
    }

    /// Get network record by subnet
    func getNetworkRecord(for subnet: String) -> NetworkRecord? {
        return networkHistory.first { $0.subnet == subnet }
    }

    /// Delete network from history
    func deleteNetwork(id: UUID) {
        networkHistory.removeAll { $0.id == id }
        saveNetworks()
    }

    // MARK: - Settings Management

    /// Update threat detection settings
    func updateSettings(_ newSettings: ThreatDetectionSettings) {
        self.settings = newSettings
        saveSettings()
    }

    /// Get rogue device time window in seconds
    var rogueDeviceTimeWindowSeconds: TimeInterval {
        return TimeInterval(settings.rogueDeviceTimeWindowMinutes * 60)
    }

    // MARK: - Persistence

    private func loadAll() {
        loadDevices()
        loadNetworks()
        loadSettings()
    }

    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: devicesKey) {
            do {
                persistedDevices = try JSONDecoder().decode([PersistedDevice].self, from: data)
            } catch {
                print("Failed to load devices: \(error)")
                persistedDevices = []
            }
        }
    }

    private func saveDevices() {
        do {
            let data = try JSONEncoder().encode(persistedDevices)
            UserDefaults.standard.set(data, forKey: devicesKey)
        } catch {
            print("Failed to save devices: \(error)")
        }
    }

    private func loadNetworks() {
        if let data = UserDefaults.standard.data(forKey: networksKey) {
            do {
                networkHistory = try JSONDecoder().decode([NetworkRecord].self, from: data)
            } catch {
                print("Failed to load networks: \(error)")
                networkHistory = []
            }
        }
    }

    private func saveNetworks() {
        do {
            let data = try JSONEncoder().encode(networkHistory)
            UserDefaults.standard.set(data, forKey: networksKey)
        } catch {
            print("Failed to save networks: \(error)")
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey) {
            do {
                settings = try JSONDecoder().decode(ThreatDetectionSettings.self, from: data)
            } catch {
                print("Failed to load settings: \(error)")
                settings = .default
            }
        }
    }

    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    // MARK: - Bulk Operations

    /// Clear all persisted data (for debugging/testing)
    func clearAll() {
        persistedDevices = []
        networkHistory = []
        settings = .default

        UserDefaults.standard.removeObject(forKey: devicesKey)
        UserDefaults.standard.removeObject(forKey: networksKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    /// Export data for backup
    func exportData() -> String? {
        let exportData: [String: Any] = [
            "devices": persistedDevices.compactMap { try? JSONEncoder().encode($0) }.map { $0.base64EncodedString() },
            "networks": networkHistory.compactMap { try? JSONEncoder().encode($0) }.map { $0.base64EncodedString() },
            "settings": (try? JSONEncoder().encode(settings))?.base64EncodedString() ?? "",
            "exportDate": ISO8601DateFormatter().string(from: Date())
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8)
        }

        return nil
    }
}
