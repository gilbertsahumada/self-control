#!/bin/bash
set -e

APP_VERSION="${VERSION:-1.0.0}"

echo "Building MonkMode v${APP_VERSION}..."

# Build release
echo "Building release binaries..."
swift build -c release

# Create .app bundle structure
APP_NAME="MonkMode.app"
CONTENTS_PATH="dist/$APP_NAME/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

echo "Creating app bundle..."
rm -rf dist
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# Copy executables
cp ".build/release/MonkMode" "$MACOS_PATH/"
cp ".build/release/MonkModeEnforcer" "$MACOS_PATH/"

# Copy app icon if it exists
if [ -f "assets/AppIcon.icns" ]; then
  cp "assets/AppIcon.icns" "$RESOURCES_PATH/"
  echo "App icon copied to Resources"
fi

# Ship the uninstall script inside the app so the in-app uninstall flow
# can locate it via Bundle.main.
cp "scripts/uninstall.sh" "$RESOURCES_PATH/uninstall.sh"
chmod +x "$RESOURCES_PATH/uninstall.sh"

# Ship the brand icon SVGs under Resources/BrandIcons/ so BrandIcon.swift
# can resolve them via Bundle.main.url(..., subdirectory: "BrandIcons").
if [ -d "assets/brand-icons" ]; then
  mkdir -p "$RESOURCES_PATH/BrandIcons"
  cp assets/brand-icons/*.svg "$RESOURCES_PATH/BrandIcons/"
  echo "Brand icons copied to Resources/BrandIcons"
fi

# Create Info.plist
cat > "$CONTENTS_PATH/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MonkMode</string>
    <key>CFBundleIdentifier</key>
    <string>com.monkmode.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MonkMode</string>
    <key>CFBundleDisplayName</key>
    <string>MonkMode</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024. All rights reserved.</string>
</dict>
</plist>
EOF

# Ad-hoc code sign the executables and app bundle
echo "Code signing (ad-hoc)..."
codesign --force --sign - "$MACOS_PATH/MonkModeEnforcer"
codesign --force --sign - "$MACOS_PATH/MonkMode"
codesign --force --sign - "dist/$APP_NAME"

echo "Verifying code signature..."
codesign --verify --verbose "dist/$APP_NAME"

echo "App bundle created at dist/$APP_NAME"

# Create DMG — stage the .app + the uninstaller so the DMG is self-contained.
echo "Creating DMG..."
STAGING_DIR=$(mktemp -d)
cp -R "dist/$APP_NAME" "$STAGING_DIR/"
cp "scripts/uninstall.sh" "$STAGING_DIR/uninstall.sh"
chmod +x "$STAGING_DIR/uninstall.sh"
hdiutil create -volname "MonkMode" -srcfolder "$STAGING_DIR" -ov -format UDZO "dist/MonkMode-${APP_VERSION}.dmg"
rm -rf "$STAGING_DIR"

echo "DMG created at dist/MonkMode-${APP_VERSION}.dmg"

# Emit SHA256SUMS so users can verify download integrity. The file lists
# every artifact uploaded to a GitHub release; a single mismatched line
# means the corresponding asset was tampered with in transit.
echo "Generating SHA256SUMS..."
(
  cd dist
  shasum -a 256 \
    "MonkMode-${APP_VERSION}.dmg" \
    "MonkMode.app/Contents/MacOS/MonkMode" \
    "MonkMode.app/Contents/MacOS/MonkModeEnforcer" \
    > "SHA256SUMS"
)
echo "SHA256SUMS written to dist/SHA256SUMS"

echo ""
echo "Distribution ready:"
echo "   - dist/MonkMode.app"
echo "   - dist/MonkMode-${APP_VERSION}.dmg"
echo "   - dist/SHA256SUMS"
echo ""
echo "NOTE: This app is ad-hoc signed. Users downloading from the internet"
echo "will need to remove the quarantine attribute before opening:"
echo "   xattr -cr /path/to/MonkMode.app"
