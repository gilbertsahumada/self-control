#!/bin/bash
set -e

APP_VERSION="${VERSION:-1.0.0}"

echo "Building SelfControl v${APP_VERSION}..."

# Build release
echo "Building release binaries..."
swift build -c release

# Create .app bundle structure
APP_NAME="SelfControl.app"
CONTENTS_PATH="dist/$APP_NAME/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

echo "Creating app bundle..."
rm -rf dist
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# Copy executables
cp ".build/release/SelfControl" "$MACOS_PATH/"
cp ".build/release/SelfControlEnforcer" "$MACOS_PATH/"

# Create Info.plist
cat > "$CONTENTS_PATH/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SelfControl</string>
    <key>CFBundleIdentifier</key>
    <string>com.selfcontrol.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SelfControl</string>
    <key>CFBundleDisplayName</key>
    <string>SelfControl</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024. All rights reserved.</string>
</dict>
</plist>
EOF

# Ad-hoc code sign the executables and app bundle
echo "Code signing (ad-hoc)..."
codesign --force --sign - "$MACOS_PATH/SelfControlEnforcer"
codesign --force --sign - "$MACOS_PATH/SelfControl"
codesign --force --sign - "dist/$APP_NAME"

echo "Verifying code signature..."
codesign --verify --verbose "dist/$APP_NAME"

echo "App bundle created at dist/$APP_NAME"

# Create DMG — move .app to a temp staging dir so the DMG only contains the .app
echo "Creating DMG..."
STAGING_DIR=$(mktemp -d)
cp -R "dist/$APP_NAME" "$STAGING_DIR/"
hdiutil create -volname "SelfControl" -srcfolder "$STAGING_DIR" -ov -format UDZO "dist/SelfControl-${APP_VERSION}.dmg"
rm -rf "$STAGING_DIR"

echo "DMG created at dist/SelfControl-${APP_VERSION}.dmg"
echo ""
echo "Distribution ready:"
echo "   - dist/SelfControl.app"
echo "   - dist/SelfControl-${APP_VERSION}.dmg"
echo ""
echo "NOTE: This app is ad-hoc signed. Users downloading from the internet"
echo "will need to remove the quarantine attribute before opening:"
echo "   xattr -cr /path/to/SelfControl.app"
