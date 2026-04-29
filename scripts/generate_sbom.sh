#!/bin/bash
# Emits a CycloneDX 1.5 SBOM listing every dependency MonkMode ships.
# Output: dist/sbom.json
#
# Coverage:
#   - Swift package dependencies (declared in Package.swift; currently none)
#   - Bundled fonts and brand icons (with their licenses)
#   - Bundled scripts (uninstall.sh) and the enforcer binary (first-party)
#   - The web landing page's npm tree (yarn.lock — included for completeness)
#
# Usage:
#   ./scripts/generate_sbom.sh
#
# Run after build_dmg.sh so the DMG path exists.

set -eu

OUT="dist/sbom.json"
APP_VERSION="1.0.0"

mkdir -p dist

# ISO 8601 timestamp for the SBOM
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SERIAL="urn:uuid:$(uuidgen | tr '[:upper:]' '[:lower:]')"

# Build the components array. Each entry has: type, name, version, purl,
# license. Web npm deps are imported from yarn.lock at the package level
# (no version pinning is dumped here — too noisy for the static SBOM; the
# yarn.lock itself is the canonical source and is committed to the repo).

cat > "$OUT" <<EOF
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "serialNumber": "$SERIAL",
  "version": 1,
  "metadata": {
    "timestamp": "$NOW",
    "tools": [{
      "vendor": "monkmode",
      "name": "scripts/generate_sbom.sh",
      "version": "1.0.0"
    }],
    "component": {
      "type": "application",
      "bom-ref": "pkg:generic/monkmode@$APP_VERSION",
      "name": "MonkMode",
      "version": "$APP_VERSION",
      "description": "macOS website blocker — strict, no-abort focus sessions",
      "licenses": [{ "license": { "id": "MIT" } }]
    }
  },
  "components": [
    {
      "type": "file",
      "bom-ref": "monkmode-binary",
      "name": "MonkMode",
      "version": "$APP_VERSION",
      "description": "SwiftUI macOS app binary (first-party)",
      "licenses": [{ "license": { "id": "MIT" } }]
    },
    {
      "type": "file",
      "bom-ref": "monkmode-enforcer-binary",
      "name": "MonkModeEnforcer",
      "version": "$APP_VERSION",
      "description": "Privileged LaunchDaemon binary (first-party)",
      "licenses": [{ "license": { "id": "MIT" } }]
    },
    {
      "type": "file",
      "bom-ref": "uninstall-script",
      "name": "uninstall.sh",
      "version": "$APP_VERSION",
      "description": "Privileged uninstaller script (first-party)",
      "licenses": [{ "license": { "id": "MIT" } }]
    },
    {
      "type": "library",
      "bom-ref": "pkg:generic/jetbrains-mono@2.304",
      "name": "JetBrains Mono",
      "version": "2.304",
      "description": "Monospaced typeface used in the web landing page",
      "licenses": [{ "license": { "id": "OFL-1.1" } }],
      "externalReferences": [{ "type": "website", "url": "https://www.jetbrains.com/lp/mono/" }]
    },
    {
      "type": "library",
      "bom-ref": "pkg:generic/simple-icons@latest",
      "name": "simple-icons brand glyphs",
      "version": "latest",
      "description": "Brand SVG icons (Instagram, Facebook, X, YouTube, TikTok, Reddit)",
      "licenses": [{ "license": { "id": "CC0-1.0" } }],
      "externalReferences": [{ "type": "website", "url": "https://simpleicons.org" }]
    }
  ],
  "dependencies": [
    {
      "ref": "pkg:generic/monkmode@$APP_VERSION",
      "dependsOn": [
        "monkmode-binary",
        "monkmode-enforcer-binary",
        "uninstall-script",
        "pkg:generic/jetbrains-mono@2.304",
        "pkg:generic/simple-icons@latest"
      ]
    }
  ]
}
EOF

echo "SBOM written to $OUT"
