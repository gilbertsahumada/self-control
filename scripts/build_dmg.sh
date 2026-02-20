#!/bin/bash
set -e

APP_VERSION="${VERSION:-1.0.0}"

echo "🚀 Building SelfControl..."

# Build release
echo "📦 Building release binaries..."
swift build -c release

# Create .app bundle structure
APP_NAME="SelfControl.app"
CONTENTS_PATH="dist/$APP_NAME/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

echo "📁 Creating app bundle..."
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
    <key>NSMainStoryboardFile</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    <key>CFBundleIconFile</key>
    <string></string>
</dict>
</plist>
EOF

# Create minimal entitlements (app sandbox disabled for admin privileges)
cat > "$CONTENTS_PATH/SelfControl.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
EOF

# Copy enforcer entitlements
cp "$CONTENTS_PATH/SelfControl.entitlements" "$CONTENTS_PATH/SelfControlEnforcer.entitlements"

echo "✅ App bundle created at dist/$APP_NAME"

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "SelfControl" -srcfolder "dist" -ov -format UDZO "dist/SelfControl-${APP_VERSION}.dmg"

echo "✅ DMG created at dist/SelfControl-${APP_VERSION}.dmg"
echo ""
echo "📦 Distribution ready:"
echo "   - dist/SelfControl.app"
echo "   - dist/SelfControl-${APP_VERSION}.dmg"
