//
//  PortScanModeSelector.swift
//  NMAPScanner
//
//  Created by Jordan Koch on 2025-11-29.
//  UI for selecting port scanning mode
//

import SwiftUI

/// Port scan mode selector view
struct PortScanModeSelector: View {
    @Binding var selectedMode: PortScanMode
    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Port Scan Mode", systemImage: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button(action: { showingInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Mode selection cards
            ForEach(PortScanMode.allCases, id: \.self) { mode in
                PortScanModeCard(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMode = mode
                            UserDefaults.standard.selectedPortScanMode = mode
                        }
                    }
                )
            }

            // Info panel
            if showingInfo {
                InfoPanel()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

/// Individual mode selection card
struct PortScanModeCard: View {
    let mode: PortScanMode
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? mode.color : mode.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: mode.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : mode.color)
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(mode.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                    }

                    Text(mode.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 16) {
                        Label("\(mode.portCount) ports", systemImage: "number")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Label(mode.estimatedTimePerHost, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                Circle()
                    .strokeBorder(isSelected ? mode.color : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(Circle().fill(isSelected ? mode.color : Color.clear))
                    .frame(width: 24, height: 24)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered || isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    .shadow(color: isSelected ? mode.color.opacity(0.3) : .clear, radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mode.color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Info panel explaining scan modes
struct InfoPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)

                Text("Scan Mode Information")
                    .font(.system(size: 14, weight: .semibold))
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ScanInfoRow(
                    title: "Standard Ports (1-1024)",
                    description: "Scans well-known ports. Good balance of speed and coverage. Recommended for regular monitoring."
                )

                ScanInfoRow(
                    title: "Common Ports (~100)",
                    description: "Fastest option. Scans only the most frequently used ports. Best for quick scans."
                )

                ScanInfoRow(
                    title: "All Ports (1-65536)",
                    description: "Complete port scan. Very thorough but slow. Use for deep security audits or when investigating suspicious devices."
                )
            }

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text("Full port scans may take significant time on large networks")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ScanInfoRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Compact scan mode indicator (for toolbar/status bar)
struct CompactScanModeIndicator: View {
    let mode: PortScanMode

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode.icon)
                .font(.system(size: 12))
                .foregroundColor(mode.color)

            Text(mode.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Text("(\(mode.portCount) ports)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(mode.color.opacity(0.1))
        .cornerRadius(6)
    }
}

/// Preview
#if DEBUG
struct PortScanModeSelector_Previews: PreviewProvider {
    static var previews: some View {
        PortScanModeSelector(selectedMode: .constant(.current))
            .frame(width: 500)
            .padding()
    }
}
#endif
