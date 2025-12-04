#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'NMAPScanner' }
group = project.main_group.find_subpath('NMAPScanner', true)

file_path = "NMAPScanner/NetworkTopologyView.swift"
existing_file = group.files.find { |f| f.path == "NetworkTopologyView.swift" }

unless existing_file
  file_ref = group.new_reference(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added NetworkTopologyView.swift to project"
else
  puts "NetworkTopologyView.swift already exists in project"
end

project.save
