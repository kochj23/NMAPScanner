//
//  UniFiDashboardView.swift
//  NMAP Plus Security Scanner - UniFi Devices Dashboard
//
//  Created by Jordan Koch on 2025-12-01.
//
//  Comprehensive dashboard for UniFi network infrastructure:
//  - UDP Discovery (port 10001) - finds all UniFi devices
//  - Controller API integration (with MFA support)
//  - mDNS/Bonjour discovery
//  - Displays: switches, APs, gateways, cameras, clients
//

import SwiftUI

struct UniFiDashboardView: View {
    @StateObject private var udpScanner = UniFiDiscoveryScanner.shared
    @StateObject private var controller = UniFiController.shared
    @StateObject private var bonjourScanner = BonjourScanner()
    
    @State private var selectedTab: UniFiTab = .discovery
    @State private var showingControllerSetup = false
    @State private var showingMFAPrompt = false
    @State private var mfaCode = ""
    
    enum UniFiTab: String, CaseIterable {
        case discovery = "Discovery"
        case infrastructure = "Infrastructure"
        case cameras = "Cameras"
        case clients = "Clients"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UniFi Devices")
                            .font(.system(size: 34, weight: .bold))
                        
                        if !udpScanner.discoveredDevices.isEmpty || controller.isConnected {
                            Text("\(totalDeviceCount) devices")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Controller status button
                    Button(action: { showingControllerSetup = true }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(controller.isConnected ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(controller.isConnected ? "Controller Connected" : "Setup Controller")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    ForEach(UniFiTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedTab {
                        case .discovery:
                            discoveryView
                        case .infrastructure:
                            infrastructureView
                        case .cameras:
                            camerasView
                        case .clients:
                            clientsView
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            .sheet(isPresented: $showingControllerSetup) {
                ControllerSetupView()
            }
            .alert("MFA Code Required", isPresented: $showingMFAPrompt) {
                TextField("Enter 6-digit code", text: $mfaCode)
                Button("Cancel", role: .cancel) {
                    mfaCode = ""
                }
                Button("Login") {
                    Task {
                        await controller.login(mfaCode: mfaCode)
                        mfaCode = ""
                    }
                }
            } message: {
                Text("Your UniFi controller requires a two-factor authentication code.")
            }
            .onChange(of: controller.mfaRequired) { _, required in
                if required {
                    showingMFAPrompt = true
                }
            }
        }
        .onAppear {
            // Auto-scan on appear
            if udpScanner.discoveredDevices.isEmpty && !udpScanner.isScanning {
                Task {
                    await udpScanner.startScan()
                }
            }
        }
    }
    
    private var totalDeviceCount: Int {
        udpScanner.discoveredDevices.count + 
        controller.infrastructureDevices.count +
        controller.protectCameras.count
    }
    
    // MARK: - Discovery View
    
    private var discoveryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if udpScanner.isScanning {
                scanningCard
            } else {
                statsCards
            }
            
            if !udpScanner.discoveredDevices.isEmpty {
                deviceGrid
            } else if !udpScanner.isScanning {
                emptyStateView
            }
            
            if !udpScanner.isScanning {
                scanButton
            }
        }
    }
    
    private var scanningCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                Text("Discovering UniFi Devices")
                    .font(.system(size: 20, weight: .semibold))
            }
            
            ProgressView(value: udpScanner.progress)
                .tint(.blue)
            
            Text(udpScanner.status)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var statsCards: some View {
        let stats = udpScanner.getStatistics()
        
        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(title: "Access Points", count: stats.accessPoints, icon: "wifi.router", color: .blue)
            StatCard(title: "Switches", count: stats.switches, icon: "network", color: .green)
            StatCard(title: "Gateways", count: stats.gateways, icon: "server.rack", color: .purple)
            StatCard(title: "Cameras", count: stats.cameras, icon: "video", color: .orange)
        }
    }
    
    private var deviceGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
        ], spacing: 16) {
            ForEach(udpScanner.discoveredDevices) { device in
                UniFiDeviceCard(device: device)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No UniFi Devices Found")
                .font(.system(size: 20, weight: .semibold))
            Text("Click the scan button to discover UniFi devices on your network")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    private var scanButton: some View {
        Button(action: {
            Task {
                await udpScanner.startScan()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                Text("Discover UniFi Devices")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Infrastructure View
    
    private var infrastructureView: some View {
        Group {
            if controller.isConnected {
                if controller.infrastructureDevices.isEmpty {
                    VStack(spacing: 16) {
                        Button("Fetch Infrastructure Devices") {
                            Task {
                                await controller.fetchInfrastructureDevices()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        ForEach(controller.infrastructureDevices) { device in
                            InfrastructureDeviceCard(device: device)
                        }
                    }
                }
            } else {
                controllerNotConnectedView
            }
        }
    }
    
    // MARK: - Cameras View
    
    private var camerasView: some View {
        Group {
            if controller.isConnected {
                if controller.protectCameras.isEmpty {
                    VStack(spacing: 16) {
                        Button("Fetch Protect Cameras") {
                            Task {
                                await controller.fetchProtectCameras()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        ForEach(controller.protectCameras) { camera in
                            ProtectCameraCard(camera: camera)
                        }
                    }
                }
            } else {
                controllerNotConnectedView
            }
        }
    }
    
    // MARK: - Clients View
    
    private var clientsView: some View {
        Group {
            if controller.isConnected {
                if controller.devices.isEmpty {
                    VStack(spacing: 16) {
                        Button("Fetch Client Devices") {
                            Task {
                                await controller.fetchDevices()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        ForEach(controller.devices) { device in
                            ClientDeviceCard(device: device)
                        }
                    }
                }
            } else {
                controllerNotConnectedView
            }
        }
    }
    
    private var controllerNotConnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Controller Not Connected")
                .font(.system(size: 20, weight: .semibold))
            Text("Connect to your UniFi controller to view this data")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Button("Setup Controller") {
                showingControllerSetup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Support Views

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct UniFiDeviceCard: View {
    let device: UniFiDiscoveredDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: device.deviceType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(colorForType(device.deviceType))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(device.deviceType.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if device.adopted == true {
                    Text("ADOPTED")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                UniFiInfoRow(label: "IP Address", value: device.ipAddress)
                UniFiInfoRow(label: "MAC", value: device.mac)
                if let model = device.model {
                    UniFiInfoRow(label: "Model", value: model)
                }
                if let version = device.version {
                    UniFiInfoRow(label: "Version", value: version)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func colorForType(_ type: UniFiDeviceType) -> Color {
        switch type {
        case .accessPoint: return .blue
        case .switch: return .green
        case .gateway: return .purple
        case .camera: return .orange
        case .nvr: return .red
        case .unknown: return .gray
        }
    }
}

struct InfrastructureDeviceCard: View {
    let device: UniFiInfrastructureDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForType(device.deviceType))
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name ?? device.model ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(device.deviceType)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                if let ip = device.ip {
                    UniFiInfoRow(label: "IP", value: ip)
                }
                if let model = device.model {
                    UniFiInfoRow(label: "Model", value: model)
                }
                if let version = device.version {
                    UniFiInfoRow(label: "Version", value: version)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "Switch": return "network"
        case "Access Point": return "wifi.router"
        case "Gateway": return "server.rack"
        default: return "questionmark.circle"
        }
    }
}

struct ProtectCameraCard: View {
    let camera: UniFiProtectCamera
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "video")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(camera.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(camera.state ?? "Unknown")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if camera.isMotionDetected == true {
                    Image(systemName: "figure.walk.motion")
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                if let host = camera.host {
                    UniFiInfoRow(label: "Host", value: host)
                }
                if let model = camera.model {
                    UniFiInfoRow(label: "Model", value: model)
                }
                if let version = camera.firmwareVersion {
                    UniFiInfoRow(label: "Version", value: version)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct ClientDeviceCard: View {
    let device: UniFiDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: device.isWired == true ? "cable.connector" : "wifi")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.hostname ?? device.name ?? device.mac)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(device.isWired == true ? "Wired" : "Wireless")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                if let ip = device.ip {
                    UniFiInfoRow(label: "IP", value: ip)
                }
                UniFiInfoRow(label: "MAC", value: device.mac)
                if let oui = device.oui {
                    UniFiInfoRow(label: "Manufacturer", value: oui)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct UniFiInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
    }
}

struct ControllerSetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var controller = UniFiController.shared
    
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var siteName = "default"
    
    var body: some View {
        VStack(spacing: 24) {
            Text("UniFi Controller Setup")
                .font(.system(size: 28, weight: .bold))
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Controller Address")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("https://192.168.1.1:8443", text: $host)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("admin", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.system(size: 13, weight: .semibold))
                    SecureField("password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Site Name (optional)")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("default", text: $siteName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            if let error = controller.lastError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Connect") {
                    controller.configure(host: host, username: username, password: password, siteName: siteName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 500)
    }
}

#Preview {
    UniFiDashboardView()
}
