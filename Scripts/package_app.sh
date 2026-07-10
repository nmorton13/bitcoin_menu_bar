#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-release}
VERSION=${VERSION:-1.0.3}
BUILD=${BUILD:-4}
ROOT=$(cd -P "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Building BitcoinBar in $CONF mode..."
PATH_MAP="$ROOT=."
swift build -c "$CONF" --arch arm64 \
  -Xswiftc -debug-prefix-map -Xswiftc "$PATH_MAP" \
  -Xswiftc -file-prefix-map -Xswiftc "$PATH_MAP"

BINARY=".build/$CONF/BitcoinBar"
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
cp "$BINARY" "$APP/Contents/MacOS/BitcoinBar"
strip -S "$APP/Contents/MacOS/BitcoinBar"
chmod +x "$APP/Contents/MacOS/BitcoinBar"

if LC_ALL=C grep -aFq "$ROOT" "$APP/Contents/MacOS/BitcoinBar"; then
  echo "ERROR: Packaged executable contains the local repository path" >&2
  exit 1
fi

echo "Copying icon..."
if [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
fi

echo "Created $APP"
