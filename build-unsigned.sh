#!/bin/bash
#
# build-unsigned.sh
# Build Flycut without code signing
#
# Usage: ./build-unsigned.sh [debug|release]
#

set -e

CONFIG="${1:-Release}"
BUILD_DIR="build"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Flycut Unsigned Build                                        ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Configuration: ${CONFIG}                                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: xcodebuild not found. Install Xcode or Command Line Tools."
    exit 1
fi

echo ""
echo "► Xcode version:"
xcodebuild -version
echo ""

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo "► Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# List available schemes
echo "► Available schemes:"
xcodebuild -list -project Flycut.xcodeproj 2>/dev/null | grep -A 100 "Schemes:" | tail -n +2 | head -20
echo ""

# Build
echo "► Building Flycut (unsigned)..."
xcodebuild \
    -project Flycut.xcodeproj \
    -scheme Flycut \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    ONLY_ACTIVE_ARCH=NO \
    build 2>&1 | tee build.log

# Check result
APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/Flycut.app"

if [ -d "$APP_PATH" ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  BUILD SUCCESSFUL                                             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "► App location: $APP_PATH"
    echo ""
    echo "► App info:"
    ls -la "$APP_PATH"
    echo ""
    
    # Show architectures
    echo "► Binary architectures:"
    lipo -info "$APP_PATH/Contents/MacOS/Flycut" 2>/dev/null || echo "  (lipo not available)"
    echo ""
    
    # Create dist folder
    mkdir -p dist
    cp -R "$APP_PATH" dist/
    
    # Create ZIP
    echo "► Creating dist/Flycut.zip..."
    cd dist && zip -r Flycut.zip Flycut.app && cd ..
    
    # Create DMG (if hdiutil available)
    if command -v hdiutil &> /dev/null; then
        echo "► Creating Flycut.dmg..."
        hdiutil create -volname "Flycut" \
            -srcfolder dist \
            -ov -format UDZO \
            Flycut.dmg
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  OUTPUTS:"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  • dist/Flycut.app    - Application bundle"
    echo "  • dist/Flycut.zip    - Zipped application"
    [ -f "Flycut.dmg" ] && echo "  • Flycut.dmg         - Disk image"
    echo ""
    echo "  To install:"
    echo "    1. Copy dist/Flycut.app to /Applications"
    echo "    2. Right-click → Open (first time, to bypass Gatekeeper)"
    echo "    3. Grant Accessibility permissions when prompted"
    echo "═══════════════════════════════════════════════════════════════"
    
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  BUILD FAILED                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "App not found at expected path. Searching..."
    find "$BUILD_DIR" -name "*.app" -type d 2>/dev/null
    echo ""
    echo "Check build.log for errors:"
    tail -50 build.log
    exit 1
fi
