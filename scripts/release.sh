#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/release.sh --local-test  — Release build, Dev signing, no notarization; for local verification
#   ./scripts/release.sh --ndd         — NDD only: notarize, tag + push, create GitHub Release
#   ./scripts/release.sh --mas         — App Store export only (no tag/push)
#   ./scripts/release.sh --ndd --no-github  — NDD only, skip GitHub Release
#   ./scripts/release.sh --ndd --no-tag     — NDD only, skip git tag + push
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
#
# Build tracker reporting (optional):
#   release.sh self-reports release start/success/failure to the BMW build
#   tracker. This replaces the old .github/workflows/release.yml CI path, which
#   only fired on `git push` of a tag (never on UI/API-created releases) and
#   re-ran this script on a runner that lacks the notary keychain. release.sh
#   runs in the authenticated local env where the build actually happens, so it
#   reports directly. Enable by exporting TRACKER_API_TOKEN; unset = skipped.
#     export TRACKER_API_TOKEN=...        # required to enable reporting
#     export TRACKER_API_URL=...          # optional; defaults to the Tailscale URL

SCHEME="Radcap"
PROJECT="Radcap.xcodeproj"
BUNDLE_ID="com.sfegette.radcap"
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
DO_TAG=true
DO_LOCAL_TEST=false
DO_PURGE=false
for arg in "$@"; do
  case "$arg" in
    --ndd)        DO_MAS=false ;;
    --mas)        DO_NDD=false; DO_GITHUB=false; DO_TAG=false ;;
    --no-github)  DO_GITHUB=false ;;
    --no-tag)     DO_TAG=false ;;
    --local-test) DO_LOCAL_TEST=true; DO_NDD=false; DO_MAS=false; DO_GITHUB=false; DO_TAG=false ;;
    --purge)      DO_PURGE=true ;;
  esac
done

# --- Build tracker reporting (Option A: release.sh self-reports) ------------
# Upserts a single bmw_builds row keyed by TRACKER_DEPLOY_ID: a 'started' row on
# release start, then updated to 'success' or 'failed'. All POSTs are non-fatal —
# a tracker outage never aborts a release.
TRACKER_API_URL="${TRACKER_API_URL:-http://m4mini.tailbaeb43.ts.net:8090/api/builds.php}"
TRACKER_DEPLOY_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
TRACKER_STARTED_TS=0
tracker_started=false
tracker_final=false

tracker_post() {  # $1 = JSON payload
  [ -n "${TRACKER_API_TOKEN:-}" ] || return 0
  curl -sf -X POST "${TRACKER_API_URL}?token=${TRACKER_API_TOKEN}" \
    -H 'Content-Type: application/json' -d "$1" >/dev/null \
    || echo "⚠️  tracker report failed (non-fatal)"
}

tracker_report_started() {
  if [ -z "${TRACKER_API_TOKEN:-}" ]; then
    echo "ℹ️  TRACKER_API_TOKEN unset — skipping build-tracker reporting"
    return 0
  fi
  TRACKER_STARTED_TS=$(date -u +%s)
  local started_at sha branch
  started_at=$(date -u '+%Y-%m-%d %H:%M:%S')
  sha=$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo "")
  branch=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  tracker_post "$(VERSION="$VERSION" SHA="$sha" BRANCH="$branch" \
    DEPLOY_ID="$TRACKER_DEPLOY_ID" STARTED_AT="$started_at" python3 -c "
import json, os
print(json.dumps({
    'repo_name':    'radcap',
    'build_type':   'release',
    'version_tag':  'v' + os.environ['VERSION'],
    'commit_hash':  os.environ['SHA'],
    'branch':       os.environ['BRANCH'],
    'deploy_id':    os.environ['DEPLOY_ID'],
    'started_at':   os.environ['STARTED_AT'],
    'status':       'started',
    'triggered_by': 'release.sh',
}))")"
  tracker_started=true
  echo "▶ Build tracker: reported start (deploy_id ${TRACKER_DEPLOY_ID})"
}

tracker_report_success() {
  $tracker_started || return 0
  $tracker_final && return 0
  local finished_at duration
  finished_at=$(date -u '+%Y-%m-%d %H:%M:%S')
  duration=$(( $(date -u +%s) - TRACKER_STARTED_TS ))
  tracker_post "$(VERSION="$VERSION" DEPLOY_ID="$TRACKER_DEPLOY_ID" \
    FINISHED_AT="$finished_at" DURATION="$duration" python3 -c "
import json, os
print(json.dumps({
    'deploy_id':        os.environ['DEPLOY_ID'],
    'status':           'success',
    'finished_at':      os.environ['FINISHED_AT'],
    'duration_seconds': int(os.environ['DURATION']),
    'artifact_url':     'https://github.com/sfegette/radcap/releases/tag/v' + os.environ['VERSION'],
}))")"
  tracker_final=true
  echo "✅ Build tracker: reported success"
}

tracker_report_failed() {
  $tracker_started || return 0
  $tracker_final && return 0
  local finished_at duration
  finished_at=$(date -u '+%Y-%m-%d %H:%M:%S')
  duration=$(( $(date -u +%s) - TRACKER_STARTED_TS ))
  tracker_post "$(DEPLOY_ID="$TRACKER_DEPLOY_ID" FINISHED_AT="$finished_at" \
    DURATION="$duration" python3 -c "
import json, os
print(json.dumps({
    'deploy_id':        os.environ['DEPLOY_ID'],
    'status':           'failed',
    'finished_at':      os.environ['FINISHED_AT'],
    'duration_seconds': int(os.environ['DURATION']),
}))")"
  tracker_final=true
  echo "✗ Build tracker: reported failure"
}

trap 'tracker_report_failed' ERR

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

# Report release start to the build tracker (NDD path only — the real release).
if $DO_NDD; then
  tracker_report_started
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

  if $DO_TAG; then
    TAG="v$VERSION"
    if git rev-parse "$TAG" &>/dev/null; then
      echo "⚠️  Tag $TAG already exists — skipping tag + push (use --no-tag to suppress this warning)"
    else
      echo "▶ Tagging $TAG and pushing..."
      git tag "$TAG"
      git push origin HEAD "$TAG"
      echo "✅ Pushed commit + tag $TAG"
    fi
  fi

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

  # NDD release path complete — report success now so the published release is
  # recorded regardless of any later (App Store) export step.
  tracker_report_success
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
