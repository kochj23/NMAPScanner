#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find the NMAPScanner group
main_group = project.main_group.find_subpath('NMAPScanner', true)

# All NMAPScanner/*.swift files that exist on disk
all_swift_files = Dir.glob('NMAPScanner/*.swift').sort

added_count = 0
already_exists_count = 0

all_swift_files.each do |file_path|
  # Check if already in project by searching for the filename
  filename = File.basename(file_path)
  already_exists = false

  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path == filename
      already_exists = true
      break
    end
  end

  unless already_exists
    file_ref = main_group.new_reference(file_path)
    target.add_file_references([file_ref])
    puts "✅ Added: #{filename}"
    added_count += 1
  else
    already_exists_count += 1
  end
end

project.save
puts "\n📊 Summary:"
puts "  Added: #{added_count} files"
puts "  Already in project: #{already_exists_count} files"
puts "  Total Swift files: #{all_swift_files.length}"
puts "\n✅ Project saved successfully!"
