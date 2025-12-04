#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first

# Track which files we've seen
seen_files = {}
duplicates_removed = 0

# Remove duplicate build file references
target.source_build_phase.files.to_a.each do |build_file|
  next unless build_file.file_ref

  file_name = build_file.file_ref.path

  if seen_files[file_name]
    puts "Removing duplicate: #{file_name}"
    build_file.remove_from_project
    duplicates_removed += 1
  else
    seen_files[file_name] = true
  end
end

puts "\n✅ Removed #{duplicates_removed} duplicate build file references"
project.save
puts "✅ Project saved successfully!"
