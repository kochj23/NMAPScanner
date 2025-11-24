#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Files to add
files_to_add = [
  'NMAPScanner/ARPScanner.swift',
  'NMAPScanner/DeviceAnnotations.swift',
  'NMAPScanner/ScanScheduler.swift',
  'NMAPScanner/HistoricalTracker.swift',
  'NMAPScanner/ExportManager.swift',
  'NMAPScanner/SearchAndFilter.swift',
  'NMAPScanner/ScanPresets.swift',
  'NMAPScanner/NotificationManager.swift'
]

# Get the NMAPScanner group
nmap_group = project.main_group.find_subpath('NMAPScanner', true)

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  full_path = File.join(project.project_dir, file_path)

  # Check if file already exists in group
  existing_file = nmap_group.files.find { |f| f.path == file_name }

  if existing_file
    puts "File #{file_name} already in group, checking build phase..."
    # Make sure it's in the sources build phase
    unless target.source_build_phase.files_references.include?(existing_file)
      target.source_build_phase.add_file_reference(existing_file)
      puts "  ✅ Added #{file_name} to sources build phase"
    else
      puts "  ✓ #{file_name} already in sources build phase"
    end
  else
    # Add the file reference
    file_ref = nmap_group.new_reference(full_path)
    puts "✅ Added file reference: #{file_name}"

    # Add to sources build phase
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added #{file_name} to sources build phase"
  end
end

# Save the project
project.save

puts "\n🎉 Project file updated successfully!"
puts "All 8 files have been added to the NMAPScanner target."
