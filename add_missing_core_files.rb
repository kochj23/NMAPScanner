#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find the NMAPScanner group
main_group = project.main_group.find_subpath('NMAPScanner', true)

# Core files that must be added
core_files = [
  'NMAPScanner/IntegratedDashboardViewV3.swift',
  'NMAPScanner/ComprehensiveDeviceDetailView.swift'
]

core_files.each do |file_path|
  if File.exist?(file_path)
    # Check if already in project
    already_exists = false
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref && build_file.file_ref.real_path.to_s.include?(File.basename(file_path))
        already_exists = true
        break
      end
    end

    unless already_exists
      file_ref = main_group.new_reference(file_path)
      target.add_file_references([file_ref])
      puts "✅ Added: #{File.basename(file_path)}"
    else
      puts "⚠️  Already exists: #{File.basename(file_path)}"
    end
  else
    puts "❌ File not found: #{file_path}"
  end
end

project.save
puts "\n✅ Project saved successfully!"
