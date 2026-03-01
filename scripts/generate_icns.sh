#!/bin/bash
set -e

# Generate AppIcon.icns from assets/logo.svg
# Requires: rsvg-convert (from librsvg, install via: brew install librsvg)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SVG_SOURCE="$PROJECT_ROOT/assets/logo.svg"
ICONSET_DIR="$PROJECT_ROOT/assets/AppIcon.iconset"
OUTPUT="$PROJECT_ROOT/assets/AppIcon.icns"

if ! command -v rsvg-convert &> /dev/null; then
  echo "Error: rsvg-convert not found. Install with: brew install librsvg"
  exit 1
fi

echo "Generating .icns from $SVG_SOURCE..."

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# macOS icon sizes required for .icns
sizes=(16 32 64 128 256 512)
for size in "${sizes[@]}"; do
  rsvg-convert -w "$size" -h "$size" "$SVG_SOURCE" -o "$ICONSET_DIR/icon_${size}x${size}.png"
  echo "  Created ${size}x${size}"
done

# Retina variants
retina_pairs=("16 32" "32 64" "128 256" "256 512" "512 1024")
for pair in "${retina_pairs[@]}"; do
  base=$(echo "$pair" | cut -d' ' -f1)
  actual=$(echo "$pair" | cut -d' ' -f2)
  rsvg-convert -w "$actual" -h "$actual" "$SVG_SOURCE" -o "$ICONSET_DIR/icon_${base}x${base}@2x.png"
  echo "  Created ${base}x${base}@2x (${actual}px)"
done

# Generate .icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"
rm -rf "$ICONSET_DIR"

echo "Done: $OUTPUT"
