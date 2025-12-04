#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Files to remove (they don't exist at the wrong path)
files_to_remove = [
  'VisualEnhancementsSystem.swift',
  'AnimatedDiscoveryView.swift',
  'BeautifulDataVisualizations.swift',
  'EnhancedDeviceDetailView.swift',
  'DeviceIconSystem.swift'
]

# Remove file references that have the wrong path
files_to_remove.each do |filename|
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path == filename
      puts "Removing bad reference: #{filename}"
      build_file.remove_from_project
    end
  end

  # Also remove from groups
  project.main_group.recursive_children.each do |item|
    if item.is_a?(Xcodeproj::Project::Object::PBXFileReference) && item.path == filename
      puts "Removing from group: #{filename}"
      item.remove_from_project
    end
  end
end

project.save
puts "Project cleaned successfully!"
