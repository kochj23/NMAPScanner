#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove files that depend on missing types
files_to_remove = [
  'ScanScheduler.swift',
  'ScanPresets.swift'
]

project.files.each do |file_ref|
  if file_ref.path && files_to_remove.any? { |f| file_ref.path.include?(f) }
    puts "Removing dependent file: #{file_ref.path}"
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        target.source_build_phase.files.delete(build_file)
      end
    end
    file_ref.remove_from_project
  end
end

project.save
puts "Removed dependent files!"
