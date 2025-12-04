#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove incorrectly referenced files
files_to_remove = [
  'VisualEnhancementsSystem.swift',
  'AnimatedDiscoveryView.swift',
  'BeautifulDataVisualizations.swift',
  'EnhancedDeviceDetailView.swift',
  'DeviceIconSystem.swift'
]

main_group = project.main_group['NMAPScanner']

files_to_remove.each do |file_name|
  file_ref = main_group.files.find { |f| f.path == file_name }
  if file_ref
    target.source_build_phase.remove_file_reference(file_ref)
    file_ref.remove_from_project
    puts "Removed incorrect reference: #{file_name}"
  end
end

# Add files with correct paths
files_to_add = [
  'NMAPScanner/VisualEnhancementsSystem.swift',
  'NMAPScanner/AnimatedDiscoveryView.swift',
  'NMAPScanner/BeautifulDataVisualizations.swift',
  'NMAPScanner/EnhancedDeviceDetailView.swift',
  'NMAPScanner/DeviceIconSystem.swift'
]

files_to_add.each do |file_path|
  file_ref = main_group.new_file(file_path)
  target.add_file_references([file_ref])
  puts "Added: #{file_path}"
end

project.save
puts "Project fixed successfully!"
