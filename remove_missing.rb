#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove missing file reference
main_group = project.main_group['NMAPScanner']

missing_files = ['NMAPScanner/DashboardView.swift']

missing_files.each do |file_path|
  file_ref = main_group.files.find { |f| f.path == file_path || f.path == file_path.split('/').last }
  if file_ref
    target.source_build_phase.remove_file_reference(file_ref)
    file_ref.remove_from_project
    puts "Removed missing file reference: #{file_path}"
  end
end

project.save
puts "Project cleaned successfully!"
