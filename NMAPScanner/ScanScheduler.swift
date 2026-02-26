//
//  ScanScheduler.swift
//  NMAPScanner
//
//  Automated scan scheduling and background monitoring
//  Created by Claude Code on 11/23/2025.
//

import Foundation
import SwiftUI

/// Scan schedule configuration
struct ScanSchedule: Codable, Identifiable {
    let id: UUID
    var name: String
    var enabled: Bool
    var scanType: ScanType
    var interval: TimeInterval // in seconds
    var lastRun: Date?
    var nextRun: Date

    enum ScanType: String, Codable {
        case quick = "Quick Scan"
        case full = "Full Scan"
        case deep = "Deep Scan"
    }

    init(name: String, scanType: ScanType, interval: TimeInterval) {
        self.id = UUID()
        self.name = name
        self.enabled = true
        self.scanType = scanType
        self.interval = interval
        self.lastRun = nil
        self.nextRun = Date().addingTimeInterval(interval)
    }
}

/// Manages automated scan scheduling
@MainActor
class ScanScheduler: ObservableObject {
    static let shared = ScanScheduler()

    @Published var schedules: [ScanSchedule] = []
    @Published var isMonitoring = false

    private var monitoringTask: Task<Void, Never>?
    private let userDefaults = UserDefaults.standard
    private let schedulesKey = "scan_schedules"

    init() {
        loadSchedules()
    }

    // MARK: - Schedule Management

    func addSchedule(_ schedule: ScanSchedule) {
        schedules.append(schedule)
        saveSchedules()
    }

    func removeSchedule(_ schedule: ScanSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules()
    }

    func updateSchedule(_ schedule: ScanSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
        }
    }

    func toggleSchedule(_ schedule: ScanSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].enabled.toggle()
            saveSchedules()
        }
    }

    // MARK: - Monitoring

    func startMonitoring(scanner: IntegratedScannerV3) {
        guard !isMonitoring else { return }

        isMonitoring = true
        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await checkSchedules(scanner: scanner)

                // Check every minute
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch is CancellationError {
                    print("ScanScheduler: Monitoring task cancelled")
                    break
                } catch {
                    print("ScanScheduler: Sleep error: \(error.localizedDescription)")
                }
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func checkSchedules(scanner: IntegratedScannerV3) async {
        let now = Date()

        for index in schedules.indices {
            guard schedules[index].enabled else { continue }
            guard schedules[index].nextRun <= now else { continue }
            guard !scanner.isScanning else { continue } // Don't start if already scanning

            // Run the scheduled scan
            switch schedules[index].scanType {
            case .quick:
                await scanner.startQuickScan()
            case .full:
                await scanner.startFullScan()
            case .deep:
                await scanner.startDeepScan()
            }

            // Update schedule
            schedules[index].lastRun = now
            schedules[index].nextRun = now.addingTimeInterval(schedules[index].interval)
            saveSchedules()
        }
    }

    // MARK: - Persistence

    private func loadSchedules() {
        if let data = userDefaults.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([ScanSchedule].self, from: data) {
            schedules = decoded
        } else {
            // Create default schedules
            schedules = [
                ScanSchedule(name: "Hourly Quick Scan", scanType: .quick, interval: 3600),
                ScanSchedule(name: "Daily Full Scan", scanType: .full, interval: 86400)
            ]
            saveSchedules()
        }
    }

    private func saveSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            userDefaults.set(data, forKey: schedulesKey)
        }
    }
}

// MARK: - Schedule Settings View

struct ScanScheduleSettingsView: View {
    @StateObject private var scheduler = ScanScheduler.shared
    @State private var showingAddSchedule = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Monitoring")) {
                    Toggle("Enable Automated Scanning", isOn: Binding(
                        get: { scheduler.isMonitoring },
                        set: { enabled in
                            if enabled {
                                // Note: Would need scanner reference
                                // scheduler.startMonitoring(scanner: scanner)
                            } else {
                                scheduler.stopMonitoring()
                            }
                        }
                    ))
                    .font(.system(size: 24))
                }

                Section(header: Text("Schedules")) {
                    ForEach(scheduler.schedules) { schedule in
                        ScheduleRow(schedule: schedule)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            scheduler.removeSchedule(scheduler.schedules[index])
                        }
                    }
                }

                Section {
                    Button(action: {
                        showingAddSchedule = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Schedule")
                        }
                        .font(.system(size: 24))
                    }
                }
            }
            .navigationTitle("Scan Schedules")
            .sheet(isPresented: $showingAddSchedule) {
                AddScheduleView()
            }
        }
    }
}

struct ScheduleRow: View {
    let schedule: ScanSchedule
    @StateObject private var scheduler = ScanScheduler.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.name)
                    .font(.system(size: 24, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { schedule.enabled },
                    set: { _ in scheduler.toggleSchedule(schedule) }
                ))
            }

            Text(schedule.scanType.rawValue)
                .font(.system(size: 20))
                .foregroundColor(.secondary)

            Text("Every \(formatInterval(schedule.interval))")
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            if let lastRun = schedule.lastRun {
                Text("Last run: \(lastRun, style: .relative) ago")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            Text("Next run: \(schedule.nextRun, style: .relative)")
                .font(.system(size: 16))
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        if hours > 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        let minutes = Int(interval / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var scheduler = ScanScheduler.shared

    @State private var name = ""
    @State private var scanType: ScanSchedule.ScanType = .quick
    @State private var intervalHours = 1

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Schedule Details")) {
                    TextField("Name", text: $name)
                        .font(.system(size: 24))

                    Picker("Scan Type", selection: $scanType) {
                        Text("Quick Scan").tag(ScanSchedule.ScanType.quick)
                        Text("Full Scan").tag(ScanSchedule.ScanType.full)
                        Text("Deep Scan").tag(ScanSchedule.ScanType.deep)
                    }
                    .font(.system(size: 24))

                    Picker("Interval", selection: $intervalHours) {
                        Text("Every Hour").tag(1)
                        Text("Every 2 Hours").tag(2)
                        Text("Every 6 Hours").tag(6)
                        Text("Every 12 Hours").tag(12)
                        Text("Daily").tag(24)
                    }
                    .font(.system(size: 24))
                }
            }
            .navigationTitle("New Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let schedule = ScanSchedule(
                            name: name.isEmpty ? "New Schedule" : name,
                            scanType: scanType,
                            interval: TimeInterval(intervalHours * 3600)
                        )
                        scheduler.addSchedule(schedule)
                        dismiss()
                    }
                }
            }
        }
    }
}
