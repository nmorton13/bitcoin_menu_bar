#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-release}
VERSION=${VERSION:-1.0.2}
BUILD=${BUILD:-3}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Building BitcoinBar in $CONF mode..."
swift build -c "$CONF" --arch arm64

APP="$ROOT/BitcoinBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Creating Info.plist..."
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>BitcoinBar</string>
    <key>CFBundleDisplayName</key><string>BitcoinBar</string>
    <key>CFBundleIdentifier</key><string>com.randomprojects.bitcoinbar</string>
    <key>CFBundleExecutable</key><string>BitcoinBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>nmorton — hodljuice.app — thebtcbrew.com</string>
</dict>
</plist>
PLIST

echo "Copying executable..."
cp ".build/$CONF/BitcoinBar" "$APP/Contents/MacOS/BitcoinBar"
chmod +x "$APP/Contents/MacOS/BitcoinBar"

echo "Copying icon..."
if [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
fi

echo "Created $APP"
