//
//  BeautifulDataVisualizations.swift
//  NMAP Plus Security Scanner v7.0.0
//
//  Created by Jordan Koch on 2025-11-30.
//
//  Stunning data visualizations including:
//  - Animated donut charts
//  - Sparkline graphs
//  - Gradient area charts
//  - Interactive bar charts
//  - Radial progress indicators
//

import SwiftUI
import Charts

// MARK: - Animated Donut Chart

struct AnimatedDonutChart: View {
    let data: [ChartSegment]
    @State private var animatedSegments: [ChartSegment] = []
    @State private var selectedSegment: ChartSegment?

    var body: some View {
        ZStack {
            // Donut segments
            ForEach(Array(animatedSegments.enumerated()), id: \.element.id) { index, segment in
                DonutSegmentShape(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    innerRadiusRatio: 0.6
                )
                .fill(segment.color)
                .overlay(
                    DonutSegmentShape(
                        startAngle: segment.startAngle,
                        endAngle: segment.endAngle,
                        innerRadiusRatio: 0.6
                    )
                    .stroke(selectedSegment?.id == segment.id ? Color.white : Color.clear, lineWidth: 4)
                )
                .shadow(color: segment.color.opacity(0.3), radius: 8, y: 4)
                .scaleEffect(selectedSegment?.id == segment.id ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSegment)
                .onTapGesture {
                    withAnimation {
                        selectedSegment = segment
                    }
                }
            }

            // Center info
            if let selected = selectedSegment {
                VStack(spacing: 4) {
                    Text("\(selected.value)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(selected.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("\(Int(selected.percentage))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 4) {
                    Text("\(totalValue)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Total Devices")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 250, height: 250)
        .onAppear {
            animateSegments()
        }
    }

    private var totalValue: Int {
        data.reduce(0) { $0 + $1.value }
    }

    private func animateSegments() {
        var currentAngle: Double = 0
        let total = Double(totalValue)

        for (index, segment) in data.enumerated() {
            let percentage = Double(segment.value) / total
            let sweepAngle = percentage * 360

            var animatedSegment = segment
            animatedSegment.startAngle = Angle(degrees: currentAngle)
            animatedSegment.endAngle = Angle(degrees: currentAngle)
            animatedSegment.percentage = percentage * 100

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    if let i = animatedSegments.firstIndex(where: { $0.id == segment.id }) {
                        animatedSegments[i].endAngle = Angle(degrees: currentAngle + sweepAngle)
                    } else {
                        var newSegment = animatedSegment
                        newSegment.endAngle = Angle(degrees: currentAngle + sweepAngle)
                        animatedSegments.append(newSegment)
                    }
                }
            }

            currentAngle += sweepAngle
        }
    }
}

struct ChartSegment: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: Int
    let color: Color
    var startAngle: Angle = .zero
    var endAngle: Angle = .zero
    var percentage: Double = 0

    static func == (lhs: ChartSegment, rhs: ChartSegment) -> Bool {
        return lhs.id == rhs.id
    }
}

struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * innerRadiusRatio

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addLine(to: CGPoint(
            x: center.x + Foundation.cos(endAngle.radians) * innerRadius,
            y: center.y + Foundation.sin(endAngle.radians) * innerRadius
        ))
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Beautiful Sparkline Graph

struct BeautifulSparklineGraph: View {
    let data: [Double]
    let color: Color
    let showGradient: Bool

    @State private var animatedData: [Double] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Gradient fill
                if showGradient {
                    sparklinePath(in: geometry.size, data: animatedData, filled: true)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Line stroke
                sparklinePath(in: geometry.size, data: animatedData, filled: false)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .shadow(color: color.opacity(0.3), radius: 4, y: 2)

                // Endpoint circle
                if let last = animatedData.last, !animatedData.isEmpty {
                    let x = CGFloat(animatedData.count - 1) / CGFloat(max(data.count - 1, 1)) * geometry.size.width
                    let normalizedValue = (last - (data.min() ?? 0)) / max((data.max() ?? 1) - (data.min() ?? 0), 1)
                    let y = geometry.size.height - (CGFloat(normalizedValue) * geometry.size.height)

                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }
            }
        }
        .onAppear {
            animateData()
        }
    }

    private func sparklinePath(in size: CGSize, data: [Double], filled: Bool) -> Path {
        guard !data.isEmpty else { return Path() }

        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let range = max(maxValue - minValue, 1)

        var path = Path()

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) / CGFloat(max(data.count - 1, 1)) * size.width
            let normalizedValue = (value - minValue) / range
            let y = size.height - (CGFloat(normalizedValue) * size.height)

            if index == 0 {
                if filled {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.move(to: CGPoint(x: x, y: y))
                }
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        if filled {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }

        return path
    }

    private func animateData() {
        for (index, value) in data.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.02) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animatedData.append(value)
                }
            }
        }
    }
}

// MARK: - Animated Bar Chart

struct AnimatedBarChart: View {
    let data: [BarData]
    @State private var animatedHeights: [UUID: CGFloat] = [:]
    @State private var hoveredBar: UUID?

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(data) { bar in
                    VStack(spacing: 8) {
                        // Value label
                        if hoveredBar == bar.id {
                            Text("\(bar.value)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .transition(.scale.combined(with: .opacity))
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [bar.color, bar.color.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: animatedHeights[bar.id] ?? 0)
                            .shadow(color: bar.color.opacity(0.3), radius: 4, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(hoveredBar == bar.id ? Color.white : Color.clear, lineWidth: 2)
                            )
                            .onHover { hovering in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    hoveredBar = hovering ? bar.id : nil
                                }
                            }

                        // Label
                        Text(bar.label)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .onAppear {
            animateBars(maxHeight: 200)
        }
    }

    private func animateBars(maxHeight: CGFloat) {
        let maxValue = Double(data.map { $0.value }.max() ?? 1)

        for (index, bar) in data.enumerated() {
            let height = CGFloat(Double(bar.value) / maxValue) * maxHeight

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animatedHeights[bar.id] = height
                }
            }
        }
    }
}

struct BarData: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let color: Color
}

// MARK: - Radial Progress Indicator

struct RadialProgressIndicator: View {
    let progress: Double
    let color: Color
    let label: String

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 12)

            // Progress circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.5), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: 4)

            // Center content
            VStack(spacing: 4) {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Gradient Area Chart

struct GradientAreaChart: View {
    let data: [DataPoint]
    let color: Color

    @State private var animatedData: [DataPoint] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Gradient fill
                areaPath(in: geometry.size, data: animatedData)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.4), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Line stroke
                linePath(in: geometry.size, data: animatedData)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: color.opacity(0.3), radius: 4, y: 2)

                // Data points
                ForEach(animatedData.indices, id: \.self) { index in
                    let point = animatedData[index]
                    let x = xPosition(for: index, in: geometry.size)
                    let y = yPosition(for: point.value, in: geometry.size)

                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }
            }
        }
        .onAppear {
            animateData()
        }
    }

    private func linePath(in size: CGSize, data: [DataPoint]) -> Path {
        guard !data.isEmpty else { return Path() }

        var path = Path()

        for (index, point) in data.enumerated() {
            let x = xPosition(for: index, in: size)
            let y = yPosition(for: point.value, in: size)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func areaPath(in size: CGSize, data: [DataPoint]) -> Path {
        guard !data.isEmpty else { return Path() }

        var path = Path()

        let firstX = xPosition(for: 0, in: size)
        let firstY = yPosition(for: data[0].value, in: size)

        path.move(to: CGPoint(x: firstX, y: size.height))
        path.addLine(to: CGPoint(x: firstX, y: firstY))

        for (index, point) in data.enumerated() where index > 0 {
            let x = xPosition(for: index, in: size)
            let y = yPosition(for: point.value, in: size)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        let lastX = xPosition(for: data.count - 1, in: size)
        path.addLine(to: CGPoint(x: lastX, y: size.height))
        path.closeSubpath()

        return path
    }

    private func xPosition(for index: Int, in size: CGSize) -> CGFloat {
        CGFloat(index) / CGFloat(max(data.count - 1, 1)) * size.width
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        let minValue = data.map { $0.value }.min() ?? 0
        let maxValue = data.map { $0.value }.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let normalized = (value - minValue) / range
        return size.height - (CGFloat(normalized) * size.height)
    }

    private func animateData() {
        for (index, point) in data.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    animatedData.append(point)
                }
            }
        }
    }
}

struct DataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}
