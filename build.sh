#!/bin/bash
# AEGIS Capture Mac Build Script
# Run this on a Mac with Xcode 15+ installed

echo "Building AEGIS Capture for Mac..."

# 1. Build the .app using xcodebuild
xcodebuild -project AegisCapture.xcodeproj -scheme AegisCapture -configuration Release -derivedDataPath build

# 2. Find the .app and copy to Release folder
APP_PATH=$(find build -name "AEGIS_Capture.app" -type d | head -n 1)
mkdir -p Release
cp -R "$APP_PATH" Release/

# 3. Create DMG installer
DMG_NAME="AEGIS_Capture_v1.0.0.dmg"
hdiutil create -volname "AEGIS Capture" -srcfolder "Release" -ov -format UDZO "$DMG_NAME"

echo "Build complete! Output: $DMG_NAME"
