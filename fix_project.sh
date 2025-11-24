#!/bin/bash

# Remove problematic file references from the project
sed -i '' '/BB0012M/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/BB0013M/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/BB0014M/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/BB0015M/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/BB0016M/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/BB0017M/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/AA0012/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/AA0013/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/AA0014/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/AA0015/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/AA0016/d' HomeKitAdopter.xcodeproj/project.pbxproj
sed -i '' '/AA0017/d' HomeKitAdopter.xcodeproj/project.pbxproj

echo "Cleaned up project file"
