//
//  DeviceAnnotations.swift
//  NMAPScanner
//
//  Device naming, tagging, and annotation system
//  Created by Claude Code on 11/23/2025.
//

import Foundation
import SwiftUI

/// Device annotation and naming manager
@MainActor
class DeviceAnnotationManager: ObservableObject {
    static let shared = DeviceAnnotationManager()

    @Published var deviceNames: [String: String] = [:] // IP -> Custom Name
    @Published var deviceNotes: [String: String] = [:] // IP -> Notes
    @Published var deviceTags: [String: Set<String>] = [:] // IP -> Tags
    @Published var deviceGroups: [String: String] = [:] // IP -> Group Name

    private let userDefaults = UserDefaults.standard
    private let namesKey = "device_custom_names"
    private let notesKey = "device_notes"
    private let tagsKey = "device_tags"
    private let groupsKey = "device_groups"

    init() {
        loadAnnotations()
    }

    // MARK: - Device Names

    func setCustomName(_ name: String, for ipAddress: String) {
        deviceNames[ipAddress] = name
        saveNames()
    }

    func getCustomName(for ipAddress: String) -> String? {
        return deviceNames[ipAddress]
    }

    func removeCustomName(for ipAddress: String) {
        deviceNames.removeValue(forKey: ipAddress)
        saveNames()
    }

    // MARK: - Device Notes

    func setNotes(_ notes: String, for ipAddress: String) {
        deviceNotes[ipAddress] = notes
        saveNotes()
    }

    func getNotes(for ipAddress: String) -> String? {
        return deviceNotes[ipAddress]
    }

    // MARK: - Device Tags

    func addTag(_ tag: String, to ipAddress: String) {
        if deviceTags[ipAddress] == nil {
            deviceTags[ipAddress] = Set()
        }
        deviceTags[ipAddress]?.insert(tag)
        saveTags()
    }

    func removeTag(_ tag: String, from ipAddress: String) {
        deviceTags[ipAddress]?.remove(tag)
        saveTags()
    }

    func getTags(for ipAddress: String) -> Set<String> {
        return deviceTags[ipAddress] ?? Set()
    }

    func getAllTags() -> Set<String> {
        var allTags = Set<String>()
        for tags in deviceTags.values {
            allTags.formUnion(tags)
        }
        return allTags
    }

    // MARK: - Device Groups

    func setGroup(_ group: String, for ipAddress: String) {
        deviceGroups[ipAddress] = group
        saveGroups()
    }

    func getGroup(for ipAddress: String) -> String? {
        return deviceGroups[ipAddress]
    }

    func getAllGroups() -> Set<String> {
        return Set(deviceGroups.values)
    }

    func getDevicesInGroup(_ group: String) -> [String] {
        return deviceGroups.filter { $0.value == group }.map { $0.key }
    }

    // MARK: - Persistence

    private func loadAnnotations() {
        if let namesData = userDefaults.data(forKey: namesKey),
           let names = try? JSONDecoder().decode([String: String].self, from: namesData) {
            deviceNames = names
        }

        if let notesData = userDefaults.data(forKey: notesKey),
           let notes = try? JSONDecoder().decode([String: String].self, from: notesData) {
            deviceNotes = notes
        }

        if let tagsData = userDefaults.data(forKey: tagsKey),
           let tags = try? JSONDecoder().decode([String: Set<String>].self, from: tagsData) {
            deviceTags = tags
        }

        if let groupsData = userDefaults.data(forKey: groupsKey),
           let groups = try? JSONDecoder().decode([String: String].self, from: groupsData) {
            deviceGroups = groups
        }
    }

    private func saveNames() {
        if let data = try? JSONEncoder().encode(deviceNames) {
            userDefaults.set(data, forKey: namesKey)
        }
    }

    private func saveNotes() {
        if let data = try? JSONEncoder().encode(deviceNotes) {
            userDefaults.set(data, forKey: notesKey)
        }
    }

    private func saveTags() {
        if let data = try? JSONEncoder().encode(deviceTags) {
            userDefaults.set(data, forKey: tagsKey)
        }
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(deviceGroups) {
            userDefaults.set(data, forKey: groupsKey)
        }
    }
}

// MARK: - Device Annotation Views

struct DeviceAnnotationSheet: View {
    let device: EnhancedDevice
    @StateObject private var annotationManager = DeviceAnnotationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var customName: String = ""
    @State private var notes: String = ""
    @State private var selectedGroup: String = "None"
    @State private var newTag: String = ""
    @State private var deviceTags: Set<String> = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Custom Name")) {
                    TextField("Device Name", text: $customName)
                        .font(.system(size: 24))
                }

                Section(header: Text("Group")) {
                    Picker("Group", selection: $selectedGroup) {
                        Text("None").tag("None")
                        ForEach(Array(annotationManager.getAllGroups()).sorted(), id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                }

                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Add tag", text: $newTag)
                            .font(.system(size: 20))
                        Button("Add") {
                            if !newTag.isEmpty {
                                deviceTags.insert(newTag)
                                annotationManager.addTag(newTag, to: device.ipAddress)
                                newTag = ""
                            }
                        }
                    }

                    ForEach(Array(deviceTags).sorted(), id: \.self) { tag in
                        HStack {
                            Text(tag)
                                .font(.system(size: 20))
                            Spacer()
                            Button(action: {
                                deviceTags.remove(tag)
                                annotationManager.removeTag(tag, from: device.ipAddress)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                Section(header: Text("Notes")) {
                    // TextEditor is not available on tvOS, use TextField instead
                    TextField("Enter notes about this device", text: $notes, axis: .vertical)
                        .lineLimit(5...10)
                        .font(.system(size: 20))
                }
            }
            .navigationTitle("Edit Device Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAnnotations()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            customName = annotationManager.getCustomName(for: device.ipAddress) ?? ""
            notes = annotationManager.getNotes(for: device.ipAddress) ?? ""
            selectedGroup = annotationManager.getGroup(for: device.ipAddress) ?? "None"
            deviceTags = annotationManager.getTags(for: device.ipAddress)
        }
    }

    private func saveAnnotations() {
        if !customName.isEmpty {
            annotationManager.setCustomName(customName, for: device.ipAddress)
        }
        if !notes.isEmpty {
            annotationManager.setNotes(notes, for: device.ipAddress)
        }
        if selectedGroup != "None" {
            annotationManager.setGroup(selectedGroup, for: device.ipAddress)
        }
    }
}
