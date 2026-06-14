#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
PRODUCT="InputOne"

echo "==> Building release binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64 --package-path "$PROJECT_DIR"

BINARY="$BUILD_DIR/apple/Products/Release/$PRODUCT"
echo "==> Binary at: $BINARY"

APP_BUNDLE="$PROJECT_DIR/build/$PRODUCT.app"
echo "==> Creating bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$PRODUCT"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy resource bundle (contains lock.png)
RESOURCE_BUNDLE="$BUILD_DIR/apple/Products/Release/${PRODUCT}_${PRODUCT}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

echo "==> Bundle created: $APP_BUNDLE"
echo "==> Size: $(du -sh "$APP_BUNDLE" | cut -f1)"

# Build .dmg disk image
echo ""
echo "==> Building .dmg disk image..."
DMG_PATH="$PROJECT_DIR/build/$PRODUCT.dmg"
rm -f "$DMG_PATH"

# Create a temporary directory for DMG contents
DMG_TMP="$PROJECT_DIR/build/.dmg-tmp"
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"

# Copy app bundle and create a symlink to /Applications
cp -R "$APP_BUNDLE" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

# Create the DMG
hdiutil create \
    -volname "$PRODUCT" \
    -srcfolder "$DMG_TMP" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" 2>&1

rm -rf "$DMG_TMP"

echo "==> DMG created: $DMG_PATH"
echo "==> Size: $(du -sh "$DMG_PATH" | cut -f1)"
