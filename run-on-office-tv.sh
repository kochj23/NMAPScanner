#!/bin/bash

# HomeKitAdopter - Run on Office Apple TV
# This script ensures the app always runs on the Office Apple TV when executed

PROJECT_PATH="/Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter.xcodeproj"
SCHEME="HomeKitAdopter"
OFFICE_TV_ID="915604CB-97FF-5F2E-9AE6-15AEB8852719"
OFFICE_TV_NAME="Office"

echo "🚀 Building and running HomeKitAdopter on Office Apple TV..."
echo "   Device: $OFFICE_TV_NAME"
echo "   ID: $OFFICE_TV_ID"
echo ""

# Build and run on Office Apple TV
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "platform=tvOS,id=$OFFICE_TV_ID" \
    -allowProvisioningUpdates \
    clean build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build succeeded! Installing on Office Apple TV..."

    # Install the app
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=tvOS,id=$OFFICE_TV_ID" \
        -allowProvisioningUpdates \
        install

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Successfully installed on Office Apple TV!"
        echo "   You can now launch the app from the Apple TV home screen"
    else
        echo ""
        echo "❌ Installation failed"
        exit 1
    fi
else
    echo ""
    echo "❌ Build failed"
    exit 1
fi
