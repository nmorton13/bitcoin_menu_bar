#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BitcoinBar"
APP_BUNDLE="BitcoinBar.app"
ROOT=$(cd -P "$(dirname "$0")/.." && pwd)
cd "$ROOT"

PLIST_SOURCE="$ROOT/Resources/Info.plist"
VERSION=${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_SOURCE")}
BUILD=${BUILD:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_SOURCE")}
ZIP_NAME="BitcoinBar-${VERSION}.zip"

for command in asc codesign ditto git security spctl xcrun zipinfo; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: Required command is unavailable: $command" >&2
    exit 1
  fi
done

if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo "ERROR: Refusing to create a release from a dirty Git checkout." >&2
  echo "Commit the reviewed release changes before running this script." >&2
  exit 1
fi

RELEASE_COMMIT=$(git rev-parse --verify HEAD)
echo "Release source commit: $RELEASE_COMMIT"

if [[ -e "$ROOT/$ZIP_NAME" ]]; then
  echo "ERROR: Refusing to overwrite existing release artifact: $ROOT/$ZIP_NAME" >&2
  exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ -z "${APP_IDENTITY:-}" ]]; then
  IDENTITY_FILE="$TEMP_DIR/developer-id-identities.txt"
  security find-identity -v -p codesigning \
    | awk '/"Developer ID Application:/{print $2}' > "$IDENTITY_FILE"
  IDENTITY_COUNT=$(wc -l < "$IDENTITY_FILE" | tr -d ' ')

  if [[ "$IDENTITY_COUNT" -ne 1 ]]; then
    echo "ERROR: Expected exactly one usable Developer ID Application identity; found $IDENTITY_COUNT." >&2
    echo "Import the certificate and its private key, or set APP_IDENTITY explicitly." >&2
    exit 1
  fi

  APP_IDENTITY=$(sed -n '1p' "$IDENTITY_FILE")
fi

echo "Checking ASC authentication..."
asc auth status >/dev/null

echo "Building $APP_NAME $VERSION (build $BUILD)..."
VERSION="$VERSION" BUILD="$BUILD" ./Scripts/package_app.sh release

# Remove local filesystem metadata before signing.
xattr -cr "$APP_BUNDLE"

echo "Signing with Developer ID Application identity..."
codesign --force --deep --options runtime --timestamp --sign "$APP_IDENTITY" "$APP_BUNDLE"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose "$APP_BUNDLE"
SIGNATURE_INFO="$TEMP_DIR/signature.txt"
codesign -dv --verbose=4 "$APP_BUNDLE" > /dev/null 2> "$SIGNATURE_INFO"
cat "$SIGNATURE_INFO"

if ! grep -q '^Authority=Developer ID Application:' "$SIGNATURE_INFO"; then
  echo "ERROR: App is not signed with a Developer ID Application identity." >&2
  exit 1
fi

if ! grep -q '^Timestamp=' "$SIGNATURE_INFO"; then
  echo "ERROR: App signature does not contain a secure timestamp." >&2
  exit 1
fi

echo "Creating notarization zip..."
NOTARIZATION_ZIP="$TEMP_DIR/BitcoinBarNotarize.zip"
ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$NOTARIZATION_ZIP"

echo "Submitting for notarization (this may take several minutes)..."
NOTARIZATION_RESULT="$TEMP_DIR/notarization.json"
asc notarization submit \
  --file "$NOTARIZATION_ZIP" \
  --wait \
  --timeout 1h \
  --output json > "$NOTARIZATION_RESULT"
cat "$NOTARIZATION_RESULT"

NOTARIZATION_STATUS=$(/usr/bin/plutil -extract data.attributes.status raw -o - "$NOTARIZATION_RESULT")
if [[ "$NOTARIZATION_STATUS" != "Accepted" ]]; then
  echo "ERROR: Notarization status is $NOTARIZATION_STATUS, not Accepted." >&2
  exit 1
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

echo "Creating release zip..."
FINAL_ZIP="$TEMP_DIR/$ZIP_NAME"
ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$FINAL_ZIP"

if zipinfo -1 "$FINAL_ZIP" | grep -Eq '(^|/)\._|^__MACOSX/'; then
  echo "ERROR: Release ZIP contains AppleDouble metadata." >&2
  exit 1
fi

echo "Validating extracted release..."
VERIFY_DIR="$TEMP_DIR/verify"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$FINAL_ZIP" "$VERIFY_DIR"
codesign --verify --deep --strict --verbose "$VERIFY_DIR/$APP_BUNDLE"
spctl -a -t exec -vv "$VERIFY_DIR/$APP_BUNDLE"
xcrun stapler validate "$VERIFY_DIR/$APP_BUNDLE"

VERIFIED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$VERIFY_DIR/$APP_BUNDLE/Contents/Info.plist")
VERIFIED_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$VERIFY_DIR/$APP_BUNDLE/Contents/Info.plist")
VERIFIED_ARCHS=$(lipo -archs "$VERIFY_DIR/$APP_BUNDLE/Contents/MacOS/$APP_NAME")

if [[ "$VERIFIED_VERSION" != "$VERSION" || "$VERIFIED_BUILD" != "$BUILD" ]]; then
  echo "ERROR: Extracted app version/build does not match the release request." >&2
  exit 1
fi

if [[ "$VERIFIED_ARCHS" != "arm64" ]]; then
  echo "ERROR: Expected an arm64-only executable; found: $VERIFIED_ARCHS" >&2
  exit 1
fi

mv "$FINAL_ZIP" "$ROOT/$ZIP_NAME"
CHECKSUM=$(shasum -a 256 "$ROOT/$ZIP_NAME" | awk '{print $1}')

echo ""
echo "✅ Done! Release ready: $ZIP_NAME"
echo "Source commit: $RELEASE_COMMIT"
echo "SHA-256: $CHECKSUM"
echo "Upload this verified ZIP and checksum to GitHub Releases."
