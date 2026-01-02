#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BitcoinBar"
APP_IDENTITY="${APP_IDENTITY:-Developer ID Application}"
APP_BUNDLE="BitcoinBar.app"
VERSION="1.0.2"
ZIP_NAME="BitcoinBar-${VERSION}.zip"

# Look for API key file
API_KEY_PATH="${API_KEY_PATH:-$HOME/.appstoreconnect/private_key.p8}"

# Check for required files and environment variables
if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "ERROR: API key file not found at: $API_KEY_PATH" >&2
  echo "" >&2
  echo "Please either:" >&2
  echo "  1. Save your .p8 file to: $HOME/.appstoreconnect/private_key.p8" >&2
  echo "  2. Or set API_KEY_PATH environment variable to point to your .p8 file" >&2
  echo "" >&2
  echo "Download your .p8 file from: https://appstoreconnect.apple.com/access/api" >&2
  exit 1
fi

if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  echo "ERROR: Missing required environment variables:" >&2
  echo "  - APP_STORE_CONNECT_KEY_ID (your key ID)" >&2
  echo "  - APP_STORE_CONNECT_ISSUER_ID (your issuer ID)" >&2
  echo "" >&2
  echo "Get these from: https://appstoreconnect.apple.com/access/api" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  export APP_STORE_CONNECT_KEY_ID='ABC123XYZ'" >&2
  echo "  export APP_STORE_CONNECT_ISSUER_ID='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'" >&2
  exit 1
fi

# Create temp directory for notarization files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Build and package
echo "Building app..."
./Scripts/package_app.sh release

# Sign the app
echo "Signing with $APP_IDENTITY..."
codesign --force --deep --options runtime --timestamp --sign "$APP_IDENTITY" "$APP_BUNDLE"

# Verify signature
echo "Verifying signature..."
codesign --verify --verbose "$APP_BUNDLE"

# Create zip for notarization
echo "Creating notarization zip..."
ditto -c -k --keepParent "$APP_BUNDLE" "$TEMP_DIR/BitcoinBarNotarize.zip"

# Submit for notarization
echo "Submitting for notarization (this may take several minutes)..."
xcrun notarytool submit "$TEMP_DIR/BitcoinBarNotarize.zip" \
  --key "$API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

# Staple the notarization ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

# Create final release zip
echo "Creating release zip..."
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

# Validate
echo "Validating..."
spctl -a -t exec -vv "$APP_BUNDLE"
stapler validate "$APP_BUNDLE"

echo ""
echo "✅ Done! Release ready: $ZIP_NAME"
echo "Upload this to GitHub Releases"
