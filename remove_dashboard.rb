#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Find and remove all references to DashboardView.swift
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('DashboardView.swift')
    puts "Found: #{file_ref.path}"
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        target.source_build_phase.files.delete(build_file)
        puts "Removed from build phase"
      end
    end
    file_ref.remove_from_project
    puts "Removed from project"
  end
end

project.save
puts "Cleanup complete!"
