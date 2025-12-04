#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add the 5 new Swift files
files_to_add = [
  'VisualEnhancementsSystem.swift',
  'AnimatedDiscoveryView.swift',
  'BeautifulDataVisualizations.swift',
  'EnhancedDeviceDetailView.swift',
  'DeviceIconSystem.swift'
]

main_group = project.main_group['NMAPScanner']

files_to_add.each do |file_path|
  file_ref = main_group.new_reference(file_path)
  target.add_file_references([file_ref])
  puts "Added: #{file_path}"
end

project.save
puts "Project saved successfully!"
