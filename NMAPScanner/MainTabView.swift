//
//  MainTabView.swift
//  NMAP Scanner - Main Tabbed Interface
//
//  Created by Jordan Koch on 2025-11-24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var scanner = IntegratedScannerV3.shared

    var body: some View {
        ZStack {
            // Modern glassmorphic background
            GlassmorphicBackground()

            TabView(selection: $selectedTab) {
            // Main Dashboard
            IntegratedDashboardViewV3()
                .tabItem {
                    Label("Dashboard", systemImage: "network")
                }
                .tag(0)

            // Security & Traffic Dashboard
            SecurityDashboardView()
                .tabItem {
                    Label("Security & Traffic", systemImage: "chart.bar.fill")
                }
                .tag(1)

            // AI Assistant (NEW in v8.0.0)
            AIAssistantTabView()
                .tabItem {
                    Label("AI Assistant", systemImage: "brain.head.profile")
                }
                .tag(2)

            // HomeKit Discovery
            HomeKitTabView()
                .tabItem {
                    Label("HomeKit", systemImage: "homekit")
                }
                .tag(3)

            // WiFi Networks (NEW in v2.1.0)
            WiFiNetworksView()
                .tabItem {
                    Label("WiFi Networks", systemImage: "wifi")
                }
                .tag(4)

            // Network Tools (NEW in v8.2.0)
            NetworkToolsTabView()
                .tabItem {
                    Label("Network Tools", systemImage: "wrench.and.screwdriver")
                }
                .tag(5)

            // Network Topology
            NetworkTopologyView(devices: scanner.devices)
                .tabItem {
                    Label("Topology", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(6)

            // Service Dependencies (NEW in v8.3.0)
            DependencyGraphView(devices: scanner.devices)
                .tabItem {
                    Label("Dependencies", systemImage: "arrow.triangle.branch")
                }
                .tag(7)
            }
            .frame(minWidth: 1400, minHeight: 900)
        }
    }
}

#Preview {
    MainTabView()
}
