#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/release.sh           — builds NDD (Developer ID) + App Store exports
#   ./scripts/release.sh --ndd     — NDD only, creates GitHub Release + uploads DMG
#   ./scripts/release.sh --mas     — App Store only
#   ./scripts/release.sh --ndd --no-github  — NDD only, skip GitHub Release
#
# First-time setup for notarytool (run once, stores credentials in Keychain):
#   xcrun notarytool store-credentials "radcap-notary" \
#     --apple-id "YOUR_APPLE_ID" \
#     --team-id "MX6K4V7DP6" \
#     --password "APP_SPECIFIC_PASSWORD"
#
# Generate an app-specific password at: appleid.apple.com → Sign-In and Security
# GitHub CLI (gh) must be authenticated: gh auth login

SCHEME="Radcap"
PROJECT="Radcap.xcodeproj"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPTS_DIR")"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Radcap.xcarchive"
NOTARY_PROFILE="radcap-notary"

VERSION=$(defaults read "$ROOT_DIR/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.0.0")
BUILD=$(defaults read "$ROOT_DIR/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

DO_NDD=true
DO_MAS=true
DO_GITHUB=true
for arg in "$@"; do
  case "$arg" in
    --ndd)       DO_MAS=false ;;
    --mas)       DO_NDD=false; DO_GITHUB=false ;;
    --no-github) DO_GITHUB=false ;;
  esac
done

echo "▶ Radcap $VERSION ($BUILD) — archive + export"
mkdir -p "$BUILD_DIR"

# Archive once, used by both export paths
echo "▶ Archiving..."
xcodebuild archive \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  | xcpretty 2>/dev/null || cat

# --- Developer ID (NDD) ---
if $DO_NDD; then
  NDD_EXPORT="$BUILD_DIR/export-devid"
  echo "▶ Exporting Developer ID build..."
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$NDD_EXPORT" \
    -exportOptionsPlist "$SCRIPTS_DIR/ExportOptions-DevID.plist" \
    -allowProvisioningUpdates

  APP="$NDD_EXPORT/Radcap.app"
  ZIP="$BUILD_DIR/Radcap-$VERSION-DevID.zip"

  echo "▶ Notarizing..."
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "▶ Stapling..."
  xcrun stapler staple "$APP"

  echo "▶ Creating DMG..."
  DMG="$BUILD_DIR/Radcap-$VERSION.dmg"
  hdiutil create -volname "Radcap" -srcfolder "$APP" -ov -format UDZO "$DMG"
  echo "✅ NDD DMG ready: $DMG"

  if $DO_GITHUB; then
    if ! command -v gh &>/dev/null; then
      echo "⚠️  gh CLI not found — skipping GitHub Release. Install with: brew install gh"
    else
      TAG="v$VERSION"
      echo "▶ Creating GitHub Release $TAG..."
      gh release create "$TAG" "$DMG" \
        --repo sfegette/radcap \
        --title "Radcap $VERSION" \
        --notes "## Radcap $VERSION

### Install
Download \`Radcap-$VERSION.dmg\`, open it, and drag Radcap to Applications.

macOS will verify the app on first launch — if prompted, right-click → Open." \
        --latest
      echo "✅ GitHub Release $TAG published"
    fi
  fi
fi

# --- App Store ---
if $DO_MAS; then
  MAS_EXPORT="$BUILD_DIR/export-appstore"
  echo "▶ Exporting App Store build..."
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$MAS_EXPORT" \
    -exportOptionsPlist "$SCRIPTS_DIR/ExportOptions-AppStore.plist" \
    -allowProvisioningUpdates
  echo "✅ App Store export ready: $MAS_EXPORT"
  echo "   Upload via: xcrun altool --upload-app -f '$MAS_EXPORT/Radcap.pkg' -t osx"
  echo "   Or drag into Transporter.app"
fi
