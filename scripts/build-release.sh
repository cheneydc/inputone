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

build_dmg() {
    local arch=$1
    local binary=$2
    local dmg_path="$PROJECT_DIR/build/${PRODUCT}-${arch}.dmg"

    echo ""
    echo "==> Creating ${arch} bundle..."
    local dmg_tmp="$PROJECT_DIR/build/.dmg-tmp-${arch}"
    rm -rf "$dmg_tmp"
    mkdir -p "$dmg_tmp/${PRODUCT}.app/Contents/MacOS"
    mkdir -p "$dmg_tmp/${PRODUCT}.app/Contents/Resources"

    cp "$binary" "$dmg_tmp/${PRODUCT}.app/Contents/MacOS/$PRODUCT"
    cp "$PROJECT_DIR/Resources/Info.plist" "$dmg_tmp/${PRODUCT}.app/Contents/"

    RESOURCE_BUNDLE="$BUILD_DIR/apple/Products/Release/${PRODUCT}_${PRODUCT}.bundle"
    if [ -d "$RESOURCE_BUNDLE" ]; then
        cp -R "$RESOURCE_BUNDLE" "$dmg_tmp/${PRODUCT}.app/Contents/Resources/"
    fi

    if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
        cp "$PROJECT_DIR/Resources/AppIcon.icns" "$dmg_tmp/${PRODUCT}.app/Contents/Resources/"
    fi

    echo "==> Ad-hoc signing ${arch} bundle..."
    codesign --force --deep --sign - "$dmg_tmp/${PRODUCT}.app" 2>&1

    ln -s /Applications "$dmg_tmp/Applications"

    echo ""
    echo "==> Building ${arch} DMG..."
    rm -f "$dmg_path"

    hdiutil create \
        -volname "$PRODUCT" \
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
