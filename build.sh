#!/bin/bash

# Mentat Capture - Command Line Build Script
# Builds a standalone macOS .app bundle

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="BitcoinBar"
BUNDLE_ID="com.randomprojects.bitcoinbar"
VERSION="1.0.0"
BUILD_CONFIG="release"  # or "debug"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo -e "${BLUE}🔨 Building BitcoinBar for macOS${NC}"
echo ""

# Step 1: Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "$APP_BUNDLE"
rm -rf "$BUILD_DIR/$BUILD_CONFIG"

# Step 2: Build with Swift Package Manager
echo -e "${YELLOW}📦 Building with Swift Package Manager...${NC}"
cd "$SCRIPT_DIR"

if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release
else
    swift build
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Step 3: Create .app bundle structure
echo -e "${YELLOW}📁 Creating .app bundle structure...${NC}"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Step 4: Copy executable
echo -e "${YELLOW}📋 Copying executable...${NC}"
if [ "$BUILD_CONFIG" = "release" ]; then
    EXECUTABLE="$BUILD_DIR/release/$APP_NAME"
else
    EXECUTABLE="$BUILD_DIR/debug/$APP_NAME"
fi

if [ ! -f "$EXECUTABLE" ]; then
    echo -e "${RED}❌ Executable not found at: $EXECUTABLE${NC}"
    exit 1
fi

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Step 5: Copy Info.plist
echo -e "${YELLOW}📄 Copying Info.plist...${NC}"
if [ -f "$SCRIPT_DIR/Resources/Info.plist" ]; then
    cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"
else
    echo -e "${YELLOW}⚠️  Info.plist not found, creating default...${NC}"
    cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
fi

# Step 6: Code signing (optional - for development)
echo -e "${YELLOW}✍️  Signing app bundle...${NC}"
if command -v codesign &> /dev/null; then
    # Ad-hoc signing (no developer certificate needed)
    codesign --force --deep --sign - "$APP_BUNDLE"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ App signed (ad-hoc)${NC}"
    else
        echo -e "${YELLOW}⚠️  Signing failed, but app may still work${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  codesign not found, skipping signing${NC}"
fi

# Step 7: Verify the bundle
echo ""
echo -e "${BLUE}📊 Build Summary:${NC}"
echo "  App Bundle: $APP_BUNDLE"
echo "  Executable: $(du -h "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | cut -f1)"
echo "  Bundle ID: $BUNDLE_ID"
echo "  Version: $VERSION"
echo ""

# Step 8: Test if app can launch
echo -e "${YELLOW}🧪 Testing app launch...${NC}"
if [ -x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo -e "${GREEN}✅ Executable is valid${NC}"
else
    echo -e "${RED}❌ Executable is not valid${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
echo ""
echo -e "${BLUE}To run the app:${NC}"
echo "  open $APP_BUNDLE"
echo ""
echo -e "${BLUE}To install to Applications:${NC}"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo -e "${BLUE}To test from command line:${NC}"
echo "  $APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo ""
