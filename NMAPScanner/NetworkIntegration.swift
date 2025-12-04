//
//  NetworkIntegration.swift
//  NMAP Plus Security Scanner - Network Integration Module
//
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation

/// Network integration module - ensures all network components are available
/// This file serves as an entry point to load UniFi and DNS integration modules
struct NetworkIntegration {
    // Reference the singletons to ensure they're initialized
    static let unifi = UniFiController.shared
    static let dns = CustomDNSResolver.shared
    static let icons = ManufacturerIconManager.shared
}
