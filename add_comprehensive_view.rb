#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
main_group = project.main_group.find_subpath('NMAPScanner', true)

file_path = 'NMAPScanner/ComprehensiveDeviceDetailView.swift'
if File.exist?(file_path)
  file_ref = main_group.new_reference(file_path)
  target.add_file_references([file_ref])
  puts "✅ Added ComprehensiveDeviceDetailView.swift to project"
else
  puts "❌ File not found: #{file_path}"
  exit 1
end

project.save
puts "✅ Project saved"
