#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
PRODUCT="InputOne"

echo "==> Building universal binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64 --package-path "$PROJECT_DIR"

UNIVERSAL_BINARY="$BUILD_DIR/apple/Products/Release/$PRODUCT"
echo "==> Universal binary at: $UNIVERSAL_BINARY"

# Extract single-arch binaries using lipo
BINARY_ARM64="${UNIVERSAL_BINARY}_arm64"
BINARY_X86_64="${UNIVERSAL_BINARY}_x86_64"

lipo "$UNIVERSAL_BINARY" -thin arm64 -output "$BINARY_ARM64"
lipo "$UNIVERSAL_BINARY" -thin x86_64 -output "$BINARY_X86_64"
echo "==> Extracted arm64: $BINARY_ARM64"
echo "==> Extracted x86_64: $BINARY_X86_64"

build_dmg() {
    local arch=$1
    local binary=$2
    local suffix="${arch}"
    local app_bundle="$PROJECT_DIR/build/${PRODUCT}-${suffix}.app"
    local dmg_path="$PROJECT_DIR/build/${PRODUCT}-${suffix}.dmg"

    echo ""
    echo "==> Creating ${arch} bundle..."
    rm -rf "$app_bundle"
    mkdir -p "$app_bundle/Contents/MacOS"
    mkdir -p "$app_bundle/Contents/Resources"

    cp "$binary" "$app_bundle/Contents/MacOS/$PRODUCT"
    cp "$PROJECT_DIR/Resources/Info.plist" "$app_bundle/Contents/"

    RESOURCE_BUNDLE="$BUILD_DIR/apple/Products/Release/${PRODUCT}_${PRODUCT}.bundle"
    if [ -d "$RESOURCE_BUNDLE" ]; then
        cp -R "$RESOURCE_BUNDLE" "$app_bundle/Contents/Resources/"
    fi

    if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
        cp "$PROJECT_DIR/Resources/AppIcon.icns" "$app_bundle/Contents/Resources/"
    fi

    echo "==> Ad-hoc signing ${arch} bundle..."
    codesign --force --deep --sign - "$app_bundle" 2>&1

    echo ""
    echo "==> Building ${arch} DMG..."
    rm -f "$dmg_path"

    local dmg_tmp="$PROJECT_DIR/build/.dmg-tmp-${arch}"
    rm -rf "$dmg_tmp"
    mkdir -p "$dmg_tmp"

    cp -R "$app_bundle" "$dmg_tmp/"
    ln -s /Applications "$dmg_tmp/Applications"

    hdiutil create \
        -volname "${PRODUCT} (${arch})" \
        -srcfolder "$dmg_tmp" \
        -ov \
        -format UDZO \
        -imagekey zlib-level=9 \
        "$dmg_path" 2>&1

    rm -rf "$dmg_tmp"
    echo "==> ${arch} DMG created: $dmg_path"
    echo "==> Size: $(du -sh "$dmg_path" | cut -f1)"
}

build_dmg "arm64" "$BINARY_ARM64"
build_dmg "x86_64" "$BINARY_X86_64"

echo ""
echo "==> All done! DMGs in build/:"
ls -lh "$PROJECT_DIR/build/"*.dmg 2>/dev/null
