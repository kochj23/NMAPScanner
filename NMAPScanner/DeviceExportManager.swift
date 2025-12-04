//
//  DeviceExportManager.swift
//  NMAP Scanner - Device Export (PDF/JSON/CSV)
//
//  Created by Jordan Koch & Claude Code on 2025-11-24.
//

import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Manages device exports to various formats
class DeviceExportManager {
    static let shared = DeviceExportManager()

    private init() {}

    // MARK: - JSON Export

    /// Export single device to JSON
    func exportDeviceToJSON(_ device: EnhancedDevice) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(device)
            return data
        } catch {
            print("❌ Export Error: Failed to encode device to JSON: \(error)")
            return nil
        }
    }

    /// Export multiple devices to JSON
    func exportDevicesToJSON(_ devices: [EnhancedDevice]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(devices)
            return data
        } catch {
            print("❌ Export Error: Failed to encode devices to JSON: \(error)")
            return nil
        }
    }

    // MARK: - CSV Export

    /// Export devices to CSV
    func exportDevicesToCSV(_ devices: [EnhancedDevice]) -> Data? {
        var csv = "IP Address,MAC Address,Hostname,Manufacturer,Device Type,Open Ports,Status,First Seen,Last Seen\n"

        for device in devices {
            let ip = device.ipAddress
            let mac = device.macAddress ?? "N/A"
            let hostname = device.hostname ?? "N/A"
            let manufacturer = device.manufacturer ?? "N/A"
            let deviceType = "\(device.deviceType)"
            let ports = device.openPorts.map { "\($0.port)" }.joined(separator: ";")
            let status = device.isOnline ? "Online" : "Offline"
            let firstSeen = ISO8601DateFormatter().string(from: device.firstSeen)
            let lastSeen = ISO8601DateFormatter().string(from: device.lastSeen)

            csv += "\(ip),\(mac),\(hostname),\(manufacturer),\(deviceType),\(ports),\(status),\(firstSeen),\(lastSeen)\n"
        }

        return csv.data(using: .utf8)
    }

    // MARK: - PDF Export

    /// Export single device to PDF
    func exportDeviceToPDF(_ device: EnhancedDevice) -> Data? {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        pdfContext.beginPDFPage(nil)

        // Title
        drawText("Device Report", at: CGPoint(x: 50, y: 720), fontSize: 24, bold: true, in: pdfContext)

        // Device Details
        var yPosition: CGFloat = 680

        drawText("IP Address: \(device.ipAddress)", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
        yPosition -= 25

        if let mac = device.macAddress {
            drawText("MAC Address: \(mac)", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
            yPosition -= 25
        }

        if let hostname = device.hostname {
            drawText("Hostname: \(hostname)", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
            yPosition -= 25
        }

        if let manufacturer = device.manufacturer {
            drawText("Manufacturer: \(manufacturer)", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
            yPosition -= 25
        }

        drawText("Device Type: \(device.deviceType)", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
        yPosition -= 25

        drawText("Status: \(device.isOnline ? "Online" : "Offline")", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
        yPosition -= 25

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        drawText("First Seen: \(dateFormatter.string(from: device.firstSeen))", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
        yPosition -= 25

        drawText("Last Seen: \(dateFormatter.string(from: device.lastSeen))", at: CGPoint(x: 50, y: yPosition), in: pdfContext)
        yPosition -= 40

        // Open Ports Section
        if !device.openPorts.isEmpty {
            drawText("Open Ports (\(device.openPorts.count)):", at: CGPoint(x: 50, y: yPosition), fontSize: 16, bold: true, in: pdfContext)
            yPosition -= 30

            for port in device.openPorts.prefix(50) { // Limit to 50 ports to fit on page
                let portText = "\(port.port) - \(port.service)"
                drawText(portText, at: CGPoint(x: 70, y: yPosition), fontSize: 12, in: pdfContext)
                yPosition -= 20

                if yPosition < 50 {
                    break // Avoid going off page
                }
            }

            if device.openPorts.count > 50 {
                drawText("... and \(device.openPorts.count - 50) more ports", at: CGPoint(x: 70, y: yPosition), fontSize: 10, in: pdfContext)
            }
        }

        // Footer
        let footer = "Generated by NMAP Scanner - \(dateFormatter.string(from: Date()))"
        drawText(footer, at: CGPoint(x: 50, y: 30), fontSize: 10, in: pdfContext)

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return pdfData as Data
    }

    /// Draw text in PDF context
    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat = 14, bold: Bool = false, in context: CGContext) {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.textPosition = point
        CTLineDraw(line, context)
    }

    // MARK: - Save to File

    /// Save data to file with save panel
    @MainActor
    func saveToFile(data: Data, defaultName: String, allowedFileTypes: [String]) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultName
        savePanel.allowedContentTypes = allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
        savePanel.canCreateDirectories = true

        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try data.write(to: url)
                print("✅ Export: Saved to \(url.path)")
                return true
            } catch {
                print("❌ Export Error: Failed to save file: \(error)")
                return false
            }
        }

        return false
    }

    /// Export device with format selection
    @MainActor
    func exportDevice(_ device: EnhancedDevice, format: ExportFormat) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let safeName = device.hostname?.replacingOccurrences(of: " ", with: "_") ?? device.ipAddress.replacingOccurrences(of: ".", with: "_")

        switch format {
        case .json:
            if let data = exportDeviceToJSON(device) {
                _ = saveToFile(data: data, defaultName: "\(safeName)_\(timestamp).json", allowedFileTypes: ["json"])
            }

        case .pdf:
            if let data = exportDeviceToPDF(device) {
                _ = saveToFile(data: data, defaultName: "\(safeName)_\(timestamp).pdf", allowedFileTypes: ["pdf"])
            }

        case .csv:
            if let data = exportDevicesToCSV([device]) {
                _ = saveToFile(data: data, defaultName: "\(safeName)_\(timestamp).csv", allowedFileTypes: ["csv"])
            }
        }
    }

    /// Export multiple devices
    @MainActor
    func exportDevices(_ devices: [EnhancedDevice], format: ExportFormat) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        switch format {
        case .json:
            if let data = exportDevicesToJSON(devices) {
                _ = saveToFile(data: data, defaultName: "devices_\(timestamp).json", allowedFileTypes: ["json"])
            }

        case .csv:
            if let data = exportDevicesToCSV(devices) {
                _ = saveToFile(data: data, defaultName: "devices_\(timestamp).csv", allowedFileTypes: ["csv"])
            }

        case .pdf:
            // For multiple devices, export as JSON (PDF would be too long)
            if let data = exportDevicesToJSON(devices) {
                _ = saveToFile(data: data, defaultName: "devices_\(timestamp).json", allowedFileTypes: ["json"])
            }
        }
    }

    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case pdf = "PDF"
        case csv = "CSV"
    }
}

// MARK: - Make EnhancedDevice Encodable

extension EnhancedDevice: Encodable {
    enum CodingKeys: String, CodingKey {
        case ipAddress, macAddress, hostname, manufacturer, deviceType, openPorts
        case isOnline, firstSeen, lastSeen, isKnownDevice, operatingSystem, deviceName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ipAddress, forKey: .ipAddress)
        try container.encodeIfPresent(macAddress, forKey: .macAddress)
        try container.encodeIfPresent(hostname, forKey: .hostname)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encode("\(deviceType)", forKey: .deviceType)
        try container.encode(openPorts, forKey: .openPorts)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(firstSeen, forKey: .firstSeen)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encode(isKnownDevice, forKey: .isKnownDevice)
        try container.encodeIfPresent(operatingSystem, forKey: .operatingSystem)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
    }
}

extension PortInfo: Encodable {
    enum CodingKeys: String, CodingKey {
        case port, service, version, state, protocolType, banner
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(port, forKey: .port)
        try container.encode(service, forKey: .service)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encode("\(state)", forKey: .state)
        try container.encode(protocolType, forKey: .protocolType)
        try container.encodeIfPresent(banner, forKey: .banner)
    }
}
