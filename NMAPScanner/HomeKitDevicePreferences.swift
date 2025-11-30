//
//  HomeKitDevicePreferences.swift
//  NMAP Plus Security Scanner
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Manages user preferences for HomeKit devices:
//  - Favorites/pinned devices
//  - Custom device aliases/nicknames
//  - Device-specific settings
//
//  Persists to UserDefaults with Codable for type safety.
//

import Foundation
import Combine

/// Manages persistent preferences for HomeKit devices
@MainActor
class HomeKitDevicePreferences: ObservableObject {

    static let shared = HomeKitDevicePreferences()

    // MARK: - Published Properties

    @Published var favoriteDeviceIDs: Set<String> = []
    @Published var deviceAliases: [String: String] = [:]  // deviceID -> alias

    // MARK: - Private Properties

    private let favoritesKey = "HomeKitFavoriteDevices"
    private let aliasesKey = "HomeKitDeviceAliases"

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadPreferences()
        setupAutoSave()
    }

    // MARK: - Public Methods

    /// Check if device is favorited
    func isFavorite(_ deviceID: String) -> Bool {
        return favoriteDeviceIDs.contains(deviceID)
    }

    /// Toggle favorite status
    func toggleFavorite(_ deviceID: String) {
        if favoriteDeviceIDs.contains(deviceID) {
            favoriteDeviceIDs.remove(deviceID)
        } else {
            favoriteDeviceIDs.insert(deviceID)
        }
        savePreferences()
    }

    /// Get alias for device (returns nil if no alias set)
    func alias(for deviceID: String) -> String? {
        return deviceAliases[deviceID]
    }

    /// Set alias for device
    func setAlias(_ alias: String, for deviceID: String) {
        if alias.trimmingCharacters(in: .whitespaces).isEmpty {
            // Empty alias = remove alias
            deviceAliases.removeValue(forKey: deviceID)
        } else {
            deviceAliases[deviceID] = alias
        }
        savePreferences()
    }

    /// Remove alias for device
    func removeAlias(for deviceID: String) {
        deviceAliases.removeValue(forKey: deviceID)
        savePreferences()
    }

    /// Get display name (alias if set, otherwise original name)
    func displayName(for device: HomeKitDevice) -> String {
        return alias(for: device.id) ?? device.displayName
    }

    /// Clear all favorites
    func clearAllFavorites() {
        favoriteDeviceIDs.removeAll()
        savePreferences()
    }

    /// Clear all aliases
    func clearAllAliases() {
        deviceAliases.removeAll()
        savePreferences()
    }

    // MARK: - Private Methods

    private func loadPreferences() {
        // Load favorites
        if let favoritesData = UserDefaults.standard.data(forKey: favoritesKey),
           let favorites = try? JSONDecoder().decode(Set<String>.self, from: favoritesData) {
            favoriteDeviceIDs = favorites
            print("📱 HomeKit Preferences: Loaded \(favorites.count) favorite devices")
        }

        // Load aliases
        if let aliasesData = UserDefaults.standard.data(forKey: aliasesKey),
           let aliases = try? JSONDecoder().decode([String: String].self, from: aliasesData) {
            deviceAliases = aliases
            print("📱 HomeKit Preferences: Loaded \(aliases.count) device aliases")
        }
    }

    private func savePreferences() {
        // Save favorites
        if let favoritesData = try? JSONEncoder().encode(favoriteDeviceIDs) {
            UserDefaults.standard.set(favoritesData, forKey: favoritesKey)
        }

        // Save aliases
        if let aliasesData = try? JSONEncoder().encode(deviceAliases) {
            UserDefaults.standard.set(aliasesData, forKey: aliasesKey)
        }

        print("📱 HomeKit Preferences: Saved \(favoriteDeviceIDs.count) favorites, \(deviceAliases.count) aliases")
    }

    private func setupAutoSave() {
        // Auto-save when published properties change
        $favoriteDeviceIDs
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)

        $deviceAliases
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)
    }
}
