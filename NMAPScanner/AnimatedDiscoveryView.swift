//
//  AnimatedDiscoveryView.swift
//  NMAP Plus Security Scanner v7.0.0
//
//  Created by Jordan Koch & Claude Code on 2025-11-30.
//
//  Beautiful animated device discovery with:
//  - Ripple effects during scanning
//  - Particle flow animations
//  - Smooth device card transitions
//  - Progress ring with gradient
//

import SwiftUI

// MARK: - Animated Discovery Container

struct AnimatedDiscoveryView: View {
    @Binding var isScanning: Bool
    @Binding var devices: [HomeKitDevice]
    @State private var discoveredDeviceIDs: Set<String> = []
    @State private var newDevices: [HomeKitDevice] = []

    var body: some View {
        ZStack {
            // Scanning ripple effect
            if isScanning {
                ScanningRippleEffect()
                    .transition(.opacity)
            }

            // Device list with staggered animations
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        AnimatedDeviceRow(
                            device: device,
                            isNew: newDevices.contains(where: { $0.id == device.id })
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.05),
                            value: devices.count
                        )
                    }
                }
                .padding()
            }
        }
        .onChange(of: devices) { oldDevices, newDevices in
            handleDeviceChange(oldDevices: oldDevices, newDevices: newDevices)
        }
    }

    private func handleDeviceChange(oldDevices: [HomeKitDevice], newDevices: [HomeKitDevice]) {
        let oldIDs = Set(oldDevices.map { $0.id })
        let newIDs = Set(newDevices.map { $0.id })

        // Find newly discovered devices
        let addedIDs = newIDs.subtracting(oldIDs)
        let added = newDevices.filter { addedIDs.contains($0.id) }

        // Mark as new with glow effect
        self.newDevices.append(contentsOf: added)

        // Remove "new" status after 3 seconds
        for device in added {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.newDevices.removeAll { $0.id == device.id }
            }
        }
    }
}

// MARK: - Animated Device Row

struct AnimatedDeviceRow: View {
    let device: HomeKitDevice
    let isNew: Bool

    @State private var glowIntensity: Double = 0

    var body: some View {
        HStack(spacing: 16) {
            // Device icon with pulse
            DeviceIconView(device: device)
                .if(isNew) { view in
                    view.pulse(color: .green, duration: 1.0)
                }

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(device.ipAddress ?? "No IP")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // New badge
            if isNew {
                Text("NEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green)
                            .glow(color: .green, radius: 8, intensity: glowIntensity)
                    )
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            glowIntensity = 0.8
                        }
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isNew ? Color.green.opacity(0.6) : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }
}

// MARK: - Device Icon View

struct DeviceIconView: View {
    let device: HomeKitDevice

    var body: some View {
        ZStack {
            Circle()
                .fill(deviceGradient)
                .frame(width: 50, height: 50)
                .shadow(color: deviceColor.opacity(0.3), radius: 8, y: 4)

            Image(systemName: deviceIcon)
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
    }

    private var deviceType: DeviceType {
        DeviceType.from(serviceType: device.serviceType ?? "")
    }

    private var deviceColor: Color {
        Color.deviceColor(for: deviceType)
    }

    private var deviceGradient: LinearGradient {
        Color.deviceGradient(for: deviceType)
    }

    private var deviceIcon: String {
        let serviceType = device.serviceType
        if serviceType.contains("homekit") || serviceType.contains("hap") {
            return "homekit"
        } else if serviceType.contains("airplay") {
            return "airplayvideo"
        } else if serviceType.contains("raop") {
            return "homepod.fill"
        } else if serviceType.contains("companion") {
            return "applelogo"
        } else {
            return "network"
        }
    }
}

// MARK: - Scanning Ripple Effect

struct ScanningRippleEffect: View {
    @State private var ripples: [RippleData] = []
    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ForEach(ripples) { ripple in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(ripple.opacity), .purple.opacity(ripple.opacity * 0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: ripple.scale * 300, height: ripple.scale * 300)
                    .scaleEffect(ripple.scale)
                    .opacity(ripple.opacity)
            }
        }
        .onReceive(timer) { _ in
            addRipple()
        }
        .onAppear {
            addRipple()
        }
    }

    private func addRipple() {
        let ripple = RippleData(id: UUID(), scale: 0, opacity: 1.0)
        ripples.append(ripple)

        withAnimation(.easeOut(duration: 2.0)) {
            if let index = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[index].scale = 1.5
                ripples[index].opacity = 0
            }
        }

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }

    struct RippleData: Identifiable {
        let id: UUID
        var scale: CGFloat
        var opacity: Double
    }
}

// MARK: - Animated Progress Ring

struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat = 8

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // Progress circle with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .purple, .pink, .blue],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)

            // Progress text
            VStack(spacing: 4) {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Scanning")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Particle Flow Animation

struct ParticleFlowView: View {
    let sourcePoint: CGPoint
    let destinationPoint: CGPoint

    @State private var particles: [FlowParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 6, height: 6)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            startParticleFlow()
        }
    }

    private func startParticleFlow() {
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                let particle = FlowParticle(
                    id: UUID(),
                    position: sourcePoint,
                    opacity: 1.0
                )
                particles.append(particle)
                animateParticle(particle)
            }
        }
    }

    private func animateParticle(_ particle: FlowParticle) {
        withAnimation(.easeInOut(duration: 1.0)) {
            if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                particles[index].position = destinationPoint
                particles[index].opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles.removeAll { $0.id == particle.id }
        }
    }

    struct FlowParticle: Identifiable {
        let id: UUID
        var position: CGPoint
        var opacity: Double
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Bounce Animation Modifier

struct BounceAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isAnimating = false
                    }
                }
            }
    }
}

extension View {
    func bounceOnAppear() -> some View {
        self.modifier(BounceAnimation())
    }
}
