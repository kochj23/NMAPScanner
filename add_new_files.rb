#!/usr/bin/env ruby

# Script to add new Swift files to Xcode project

require 'securerandom'

project_path = '/Volumes/Data/xcode/NMAPScanner/NMAPScanner.xcodeproj/project.pbxproj'

# Files to add
new_files = [
  'ARPScanner.swift',
  'DeviceAnnotations.swift',
  'ScanScheduler.swift',
  'HistoricalTracker.swift',
  'ExportManager.swift',
  'SearchAndFilter.swift',
  'ScanPresets.swift',
  'NotificationManager.swift'
]

# Read the project file
content = File.read(project_path)

# Generate unique IDs for each file (PBXFileReference and PBXBuildFile)
file_refs = {}
build_files = {}

new_files.each do |filename|
  file_refs[filename] = SecureRandom.hex(12).upcase
  build_files[filename] = SecureRandom.hex(12).upcase
end

# Add PBXBuildFile entries
build_file_section = new_files.map do |filename|
  "\t\t#{build_files[filename]} /* #{filename} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_refs[filename]} /* #{filename} */; };"
end.join("\n")

content.sub!(/\/\* End PBXBuildFile section \*\//, "#{build_file_section}\n/* End PBXBuildFile section */")

# Add PBXFileReference entries
file_ref_section = new_files.map do |filename|
  "\t\t#{file_refs[filename]} /* #{filename} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = #{filename}; path = NMAPScanner/#{filename}; sourceTree = \"<group>\"; };"
end.join("\n")

content.sub!(/0B12C978BA4C53C4ED40C3DA \/\* IntegratedDashboardViewV3.swift \*\/\);/,
             "0B12C978BA4C53C4ED40C3DA /* IntegratedDashboardViewV3.swift */,\n" +
             new_files.map { |f| "\t\t\t\t#{file_refs[f]} /* #{f} */," }.join("\n") + "\n\t\t\t);")

# Add to Sources build phase
sources_section = new_files.map do |filename|
  "\t\t\t\t#{build_files[filename]} /* #{filename} in Sources */,"
end.join("\n")

content.sub!(/77A6FCFEFF900F3195082B50 \/\* IntegratedDashboardViewV3.swift in Sources \*\/,/,
             "77A6FCFEFF900F3195082B50 /* IntegratedDashboardViewV3.swift in Sources */,\n#{sources_section}")

# Write back
File.write(project_path, content)

puts "✅ Successfully added #{new_files.count} files to Xcode project!"
new_files.each { |f| puts "   - #{f}" }
