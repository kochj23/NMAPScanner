require 'xcodeproj'

project_path = 'HomeKitAdopter.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Files to add
files = [
  'HomeKitAdopter/Models/DeviceNote.swift',
  'HomeKitAdopter/Managers/ExportManager.swift',
  'HomeKitAdopter/Managers/NetworkDiagnosticsManager.swift',
  'HomeKitAdopter/Managers/QRCodeManager.swift',
  'HomeKitAdopter/Managers/ScanSchedulerManager.swift',
  'HomeKitAdopter/Managers/PairingInstructionsManager.swift',
  'HomeKitAdopter/Managers/FirmwareManager.swift',
  'HomeKitAdopter/Managers/SecurityAuditManager.swift',
  'HomeKitAdopter/Views/DashboardView.swift'
]

files.each do |file|
  next unless File.exist?(file)
  file_ref = project.main_group.find_file_by_path(file)
  unless file_ref
    file_ref = project.main_group.new_reference(file)
    target.add_file_references([file_ref])
  end
end

project.save
