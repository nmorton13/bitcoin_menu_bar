#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-release}
ROOT=$(cd -P "$(dirname "$0")/.." && pwd)
cd "$ROOT"

PLIST_SOURCE="$ROOT/Resources/Info.plist"
ICON_SOURCE="$ROOT/Icon.icns"

if [[ ! -f "$PLIST_SOURCE" ]]; then
  echo "ERROR: Missing canonical Info.plist: $PLIST_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "ERROR: Missing app icon: $ICON_SOURCE" >&2
  exit 1
fi

VERSION=${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_SOURCE")}
BUILD=${BUILD:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_SOURCE")}

echo "Building BitcoinBar in $CONF mode..."
PATH_MAP="$ROOT=."
swift build -c "$CONF" --arch arm64 \
  -Xswiftc -debug-prefix-map -Xswiftc "$PATH_MAP" \
  -Xswiftc -file-prefix-map -Xswiftc "$PATH_MAP"

BINARY=".build/$CONF/BitcoinBar"
APP="$ROOT/BitcoinBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Creating Info.plist for version $VERSION (build $BUILD)..."
cp -X "$PLIST_SOURCE" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD" "$APP/Contents/Info.plist"

echo "Copying executable..."
cp "$BINARY" "$APP/Contents/MacOS/BitcoinBar"
strip -S "$APP/Contents/MacOS/BitcoinBar"
chmod +x "$APP/Contents/MacOS/BitcoinBar"

if LC_ALL=C grep -aFq "$ROOT" "$APP/Contents/MacOS/BitcoinBar"; then
  echo "ERROR: Packaged executable contains the local repository path" >&2
  exit 1
fi

echo "Copying icon..."
cp -X "$ICON_SOURCE" "$APP/Contents/Resources/Icon.icns"

echo "Created $APP"
