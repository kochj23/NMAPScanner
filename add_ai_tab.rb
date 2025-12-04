#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find the NMAPScanner group
main_group = project.main_group.find_subpath('NMAPScanner', true)

# Add AIAssistantTabView.swift
file_path = 'NMAPScanner/AIAssistantTabView.swift'
if File.exist?(file_path)
  file_ref = main_group.new_reference(file_path)
  target.add_file_references([file_ref])
  puts "Added: AIAssistantTabView.swift"
else
  puts "File not found: #{file_path}"
end

project.save
puts "Project saved successfully!"
