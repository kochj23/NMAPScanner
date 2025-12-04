//
//  VisualEnhancementsSystem.swift
//  NMAP Plus Security Scanner v7.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  Comprehensive visual beauty system including:
//  - Glass/Frosted UI with dynamic colors
//  - Smooth micro-interactions
//  - Animation utilities
//  - Visual themes and gradients
//

import SwiftUI

// MARK: - Visual Theme System

/// Central theme manager for app-wide visual consistency
@MainActor
class VisualThemeManager: ObservableObject {
    static let shared = VisualThemeManager()

    @Published var accentColor: Color = .blue
    @Published var useGlassEffect: Bool = true
    @Published var animationsEnabled: Bool = true

    private init() {
        loadPreferences()
    }

    private func loadPreferences() {
        if let colorData = UserDefaults.standard.data(forKey: "AccentColor"),
           let components = try? JSONDecoder().decode([Double].self, from: colorData) {
            if components.count == 4 {
                accentColor = Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
            }
        }
        useGlassEffect = UserDefaults.standard.bool(forKey: "UseGlassEffect")
        animationsEnabled = UserDefaults.standard.bool(forKey: "AnimationsEnabled")
    }
}

// MARK: - Device Type Colors

extension Color {
    /// Color palette for different device types
    static func deviceColor(for type: DeviceType) -> Color {
        switch type {
        case .homeKit:
            return .orange
        case .airPlay:
            return .purple
        case .apple:
            return .blue
        case .iot:
            return .green
        case .network:
            return .cyan
        case .unknown:
            return .gray
        }
    }

    /// Gradient for device type
    static func deviceGradient(for type: DeviceType) -> LinearGradient {
        let baseColor = deviceColor(for: type)
        return LinearGradient(
            colors: [baseColor, baseColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum DeviceType {
    case homeKit
    case airPlay
    case apple
    case iot
    case network
    case unknown

    static func from(serviceType: String) -> DeviceType {
        if serviceType.contains("homekit") || serviceType.contains("hap") {
            return .homeKit
        } else if serviceType.contains("airplay") {
            return .airPlay
        } else if serviceType.contains("companion") {
            return .apple
        } else if serviceType.contains("http") || serviceType.contains("ssh") {
            return .network
        } else {
            return .iot
        }
    }
}

// MARK: - Health Colors

extension Color {
    /// Color for connection quality
    static func healthColor(quality: String) -> Color {
        switch quality.lowercased() {
        case "excellent":
            return .green
        case "good":
            return .blue
        case "fair":
            return .yellow
        case "poor":
            return .orange
        case "offline":
            return .red
        default:
            return .gray
        }
    }

    /// Gradient for health status
    static func healthGradient(quality: String) -> LinearGradient {
        let baseColor = healthColor(quality: quality)
        return LinearGradient(
            colors: [baseColor.opacity(0.8), baseColor.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Glass UI Components

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16

    init(cornerRadius: CGFloat = 12, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
    }
}

struct GlassButton<Content: View>: View {
    let action: () -> Void
    let content: Content

    @State private var isHovered = false
    @State private var isPressed = false

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isHovered ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.1), radius: isHovered ? 8 : 5, y: isHovered ? 4 : 2)
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Animated Card

struct AnimatedDeviceCard<Content: View>: View {
    let content: Content
    let deviceType: DeviceType

    @State private var isHovered = false
    @State private var isPressed = false

    init(deviceType: DeviceType, @ViewBuilder content: () -> Content) {
        self.deviceType = deviceType
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: isHovered ? [Color.deviceColor(for: deviceType).opacity(0.6), Color.deviceColor(for: deviceType).opacity(0.2)] : [Color.clear, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(intensity * 0.7), radius: radius / 2, x: 0, y: 0)
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 10, intensity: Double = 0.5) -> some View {
        self.modifier(GlowEffect(color: color, radius: radius, intensity: intensity))
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let speed: Double

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width)
                    .offset(x: geometry.size.width * (phase - 1))
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer(speed: Double = 2.0) -> some View {
        self.modifier(ShimmerEffect(speed: speed))
    }
}

// MARK: - Pulse Animation

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    let duration: Double

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse(color: Color = .blue, duration: Double = 1.5) -> some View {
        self.modifier(PulseEffect(color: color, duration: duration))
    }
}

// MARK: - Gradient Backgrounds

struct MeshGradientBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(.degrees(phase * 60))
            .onAppear {
                withAnimation(.linear(duration: 60).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Ripple Effect

struct RippleEffect: View {
    @State private var ripples: [Ripple] = []
    let origin: CGPoint
    let color: Color

    var body: some View {
        ZStack {
            ForEach(ripples) { ripple in
                Circle()
                    .stroke(color.opacity(ripple.opacity), lineWidth: 2)
                    .frame(width: ripple.radius * 2, height: ripple.radius * 2)
                    .position(origin)
            }
        }
        .onAppear {
            startRipple()
        }
    }

    private func startRipple() {
        for i in 0..<3 {
            let ripple = Ripple(id: UUID(), radius: 0, opacity: 1.0)
            ripples.append(ripple)

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.easeOut(duration: 1.5)) {
                    if let index = ripples.firstIndex(where: { $0.id == ripple.id }) {
                        ripples[index].radius = 150
                        ripples[index].opacity = 0
                    }
                }
            }
        }
    }

    struct Ripple: Identifiable {
        let id: UUID
        var radius: CGFloat
        var opacity: Double
    }
}

// MARK: - Particle System

struct ParticleSystem: View {
    @State private var particles: [Particle] = []
    let color: Color
    let count: Int

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(color.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        for _ in 0..<count {
            let particle = Particle(
                id: UUID(),
                position: CGPoint(x: CGFloat.random(in: 0...800), y: CGFloat.random(in: 0...600)),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.4)
            )
            particles.append(particle)
            animateParticle(particle)
        }
    }

    private func animateParticle(_ particle: Particle) {
        withAnimation(.linear(duration: Double.random(in: 10...20)).repeatForever(autoreverses: true)) {
            if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                particles[index].position.y += CGFloat.random(in: -100...100)
                particles[index].opacity = Double.random(in: 0.1...0.4)
            }
        }
    }

    struct Particle: Identifiable {
        let id: UUID
        var position: CGPoint
        var size: CGFloat
        var opacity: Double
    }
}

// MARK: - Bounce Animation

extension Animation {
    static var smoothBounce: Animation {
        .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    }

    static var gentleSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
    }
}

// MARK: - Loading States

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isAnimating ? 300 : -300)
            )
            .mask(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Interactive Hover Card

struct InteractiveCard<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    @State private var mouseLocation: CGPoint = .zero

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    RadialGradient(
                                        colors: isHovered ? [Color.accentColor.opacity(0.15), .clear] : [.clear],
                                        center: UnitPoint(
                                            x: mouseLocation.x / geometry.size.width,
                                            y: mouseLocation.y / geometry.size.height
                                        ),
                                        startRadius: 0,
                                        endRadius: 200
                                    )
                                )
                        )
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        mouseLocation = location
                        isHovered = true
                    case .ended:
                        isHovered = false
                    }
                }
        }
    }
}
