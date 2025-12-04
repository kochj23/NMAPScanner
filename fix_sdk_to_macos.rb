#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NMAPScanner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Update all build configurations to use macOS
target.build_configurations.each do |config|
  config.build_settings['SDKROOT'] = 'macosx'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings.delete('TVOS_DEPLOYMENT_TARGET')
  config.build_settings.delete('TARGETED_DEVICE_FAMILY')

  puts "Updated #{config.name} configuration to macOS"
end

# Update project-level settings
project.build_configurations.each do |config|
  config.build_settings['SDKROOT'] = 'macosx'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings.delete('TVOS_DEPLOYMENT_TARGET')

  puts "Updated project #{config.name} configuration to macOS"
end

project.save
puts "\n✅ Project successfully configured for macOS!"
puts "SDK: macOS (macosx)"
puts "Deployment Target: 13.0"
