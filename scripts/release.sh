#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/release.sh --local-test  — Release build, Dev signing, reset TCC; for local verification
#   ./scripts/release.sh --ndd         — NDD only, creates GitHub Release + uploads DMG
#   ./scripts/release.sh --mas         — App Store only
#   ./scripts/release.sh --ndd --no-github  — NDD only, skip GitHub Release
#   ./scripts/release.sh               — NDD + App Store exports
#
# --purge can be combined with any mode to reset TCC mic/camera permissions and
# UserDefaults before building (forces a fresh permission prompt on next launch):
#   ./scripts/release.sh --ndd --purge
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
BUNDLE_ID="com.brilliantmindworks.radcap"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPTS_DIR")"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Radcap.xcarchive"
NOTARY_PROFILE="radcap-notary"

VERSION=$(xcodebuild -project "$ROOT_DIR/$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk '/MARKETING_VERSION/{print $3; exit}')
BUILD=$(xcodebuild -project "$ROOT_DIR/$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk '/CURRENT_PROJECT_VERSION/{print $3; exit}')
VERSION=${VERSION:-0.0.0}
BUILD=${BUILD:-1}

DO_NDD=true
DO_MAS=true
DO_GITHUB=true
DO_LOCAL_TEST=false
DO_PURGE=false
for arg in "$@"; do
  case "$arg" in
    --ndd)        DO_MAS=false ;;
    --mas)        DO_NDD=false; DO_GITHUB=false ;;
    --no-github)  DO_GITHUB=false ;;
    --local-test) DO_LOCAL_TEST=true; DO_NDD=false; DO_MAS=false; DO_GITHUB=false ;;
    --purge)      DO_PURGE=true ;;
  esac
done

echo "▶ Radcap $VERSION ($BUILD)"
mkdir -p "$BUILD_DIR"

# --- Optional: purge TCC permissions and UserDefaults ---
# Forces a fresh mic/camera permission prompt on next launch, catching any
# TCC mismatch between debug and release bundle identities.
if $DO_PURGE; then
  echo "▶ Purging TCC permissions and UserDefaults for $BUNDLE_ID..."
  tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || true
  tccutil reset Camera "$BUNDLE_ID" 2>/dev/null || true
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  echo "   ✓ TCC + UserDefaults cleared"
fi

# Purge stale DerivedData and old archive so each build starts from a clean slate.
echo "▶ Purging stale build artifacts..."
rm -rf "$BUILD_DIR/DerivedData" "$ARCHIVE_PATH"

# --- Local test mode: Release config, Dev signing, no notarization ---
# Use this to verify the Release build works before committing to the full pipeline.
if $DO_LOCAL_TEST; then
  LOCAL_EXPORT="$BUILD_DIR/export-local-test"
  echo "▶ Building Release config (Dev signing, no notarization)..."
  xcodebuild archive \
    -project "$ROOT_DIR/$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -allowProvisioningUpdates \
    | xcpretty 2>/dev/null || cat

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$LOCAL_EXPORT" \
    -exportOptionsPlist "$SCRIPTS_DIR/ExportOptions-DevSigning.plist" \
    -allowProvisioningUpdates

  APP="$LOCAL_EXPORT/Radcap.app"
  echo "✅ Local test build ready: $APP"
  echo "   Launch to verify mic/camera permissions and recording:"
  echo "   open '$APP'"
  exit 0
fi

# Archive once, used by both export paths.
# -derivedDataPath keeps the build cache inside $BUILD_DIR (isolated per release).
echo "▶ Archiving..."
xcodebuild archive \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
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
