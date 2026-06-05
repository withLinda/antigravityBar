#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: script/build_release_dmg.sh <version> [--publish]

Example:
  script/build_release_dmg.sh 2026.06.06.1 --publish

Environment overrides:
  APP_VERSION            Defaults to the first three parts of <version>
  BUILD_NUMBER           Defaults to the last part of <version> or 1
  SIGNING_IDENTITY       Defaults to Developer ID Application: Linda Fitriani (2Z8N5KTWQZ)
  NOTARY_PROFILE         Defaults to codex-auth-helper-notary
  RELEASE_REPO           Defaults to withLinda/antigravityBar
  RELEASE_TITLE          Optional GitHub release title
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

RELEASE_VERSION=""
PUBLISH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      PUBLISH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$RELEASE_VERSION" ]]; then
        echo "error: only one version argument is allowed" >&2
        exit 1
      fi
      RELEASE_VERSION="$1"
      shift
      ;;
  esac
done

if [[ -z "$RELEASE_VERSION" ]]; then
  usage >&2
  exit 1
fi

RELEASE_VERSION="${RELEASE_VERSION#v}"
TAG="v$RELEASE_VERSION"

if [[ -z "${APP_VERSION:-}" ]]; then
  if [[ "$RELEASE_VERSION" =~ ^([0-9]+[.][0-9]+[.][0-9]+)([.-].*)?$ ]]; then
    APP_VERSION="${BASH_REMATCH[1]}"
  else
    APP_VERSION="$RELEASE_VERSION"
  fi
fi

if [[ -z "${BUILD_NUMBER:-}" ]]; then
  if [[ "$RELEASE_VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+[.]([0-9]+)$ ]]; then
    BUILD_NUMBER="${BASH_REMATCH[1]}"
  else
    BUILD_NUMBER=1
  fi
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AntigravityBar"
SCHEME="AntigravityBar"
PROJECT="AntigravityBar.xcodeproj"
RELEASE_REPO="${RELEASE_REPO:-withLinda/antigravityBar}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Linda Fitriani (2Z8N5KTWQZ)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-codex-auth-helper-notary}"
ARCHIVE_AGENT_NAME="${AGENT_NAME:-CODEX_RELEASE}"
ARCHIVE_PATH="$ROOT_DIR/build/archives/$ARCHIVE_AGENT_NAME/$APP_NAME.xcarchive"
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$ROOT_DIR/build/release-dmg-$TAG"
SIGNED_APP="$WORK_DIR/$APP_NAME.app"
STAGING_DIR="$WORK_DIR/staging"
DMG_NAME="$APP_NAME-$TAG.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
VOLUME_NAME="$APP_NAME $TAG"
RELEASE_TITLE="${RELEASE_TITLE:-$APP_NAME DMG release $TAG}"
NOTES_PATH="$WORK_DIR/release-notes.md"
NOTARY_LOG="$WORK_DIR/notary-log.json"
SUBMISSION_ID_PATH="$WORK_DIR/notary-submission-id.txt"
DOWNLOAD_BASE_URL="https://github.com/$RELEASE_REPO/releases/download/$TAG"

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || {
    echo "error: missing command: $name" >&2
    exit 1
  }
}

verify_signing_identity() {
  security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null 2>&1 || {
    echo "error: signing identity not found: $SIGNING_IDENTITY" >&2
    exit 1
  }
}

verify_notary_profile() {
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
}

verify_app_bundle() {
  local app_path="$1"
  codesign --verify --deep --strict --verbose=2 "$app_path"
}

cleanup_mount() {
  local mount_path="$1"
  if [[ -n "$mount_path" && -d "$mount_path" ]]; then
    hdiutil detach "$mount_path" -quiet || true
  fi
}

build_archive() {
  rm -rf "$ARCHIVE_PATH"
  xcodegen generate >/dev/null
  mkdir -p "$ROOT_DIR/build/logs/$ARCHIVE_AGENT_NAME"
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$ROOT_DIR/build/DerivedData/$ARCHIVE_AGENT_NAME" \
    -archivePath "$ARCHIVE_PATH" \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_STRICT_CONCURRENCY=complete \
    MARKETING_VERSION="$APP_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    | tee "$ROOT_DIR/build/logs/$ARCHIVE_AGENT_NAME/archive.log"
}

sign_app() {
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR" "$STAGING_DIR" "$DIST_DIR"
  /usr/bin/ditto "$ARCHIVED_APP" "$SIGNED_APP"

  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$SIGNED_APP"

  verify_app_bundle "$SIGNED_APP"
}

create_dmg() {
  rm -f "$DMG_PATH" "$CHECKSUM_PATH"
  /usr/bin/ditto "$SIGNED_APP" "$STAGING_DIR/$APP_NAME.app"
  /bin/ln -s /Applications "$STAGING_DIR/Applications"

  hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
  hdiutil verify "$DMG_PATH"
}

notarize_dmg() {
  local submit_output submission_id

  submit_output="$(
    xcrun notarytool submit "$DMG_PATH" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait \
      --output-format json
  )"
  printf '%s\n' "$submit_output" > "$NOTARY_LOG"

  submission_id="$(printf '%s\n' "$submit_output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
  printf '%s\n' "$submission_id" > "$SUBMISSION_ID_PATH"

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
}

write_checksum() {
  local hash
  hash="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  printf '%s  %s\n' "$hash" "$DMG_NAME" > "$CHECKSUM_PATH"
}

verify_mounted_app() {
  local mount_output mount_path mounted_app

  mount_output="$(hdiutil attach "$DMG_PATH" -nobrowse -readonly)"
  mount_path="$(printf '%s\n' "$mount_output" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/"))}' | tail -n 1)"
  if [[ -z "$mount_path" ]]; then
    echo "error: failed to find mounted DMG path" >&2
    exit 1
  fi

  trap 'cleanup_mount "$mount_path"' EXIT

  mounted_app="$mount_path/$APP_NAME.app"
  if [[ ! -d "$mounted_app" ]]; then
    echo "error: mounted app not found: $mounted_app" >&2
    exit 1
  fi

  verify_app_bundle "$mounted_app"
  spctl -a -vv "$mounted_app"
  spctl -a -vv -t open "$DMG_PATH"
  cleanup_mount "$mount_path"
  trap - EXIT
}

publish_release() {
  local full_sha

  full_sha="$(git rev-parse HEAD)"

  if gh release view "$TAG" --repo "$RELEASE_REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" --clobber --repo "$RELEASE_REPO"
    gh release edit "$TAG" --title "$RELEASE_TITLE" --repo "$RELEASE_REPO"
    return
  fi

  cat > "$NOTES_PATH" <<EOF
## Install

1. Download [\`$DMG_NAME\`]($DOWNLOAD_BASE_URL/$DMG_NAME).
2. Download [\`$DMG_NAME.sha256\`]($DOWNLOAD_BASE_URL/$DMG_NAME.sha256) if you want to verify the file.
3. Open the DMG.
4. Drag \`$APP_NAME.app\` into \`Applications\`.
5. Make sure \`antigravity-usage\` is installed before opening the app.
EOF

  gh release create "$TAG" \
    "$DMG_PATH" \
    "$CHECKSUM_PATH" \
    --repo "$RELEASE_REPO" \
    --target "$full_sha" \
    --title "$RELEASE_TITLE" \
    --notes-file "$NOTES_PATH"
}

require_command xcodegen
require_command xcodebuild
require_command codesign
require_command hdiutil
require_command gh
require_command python3

cd "$ROOT_DIR"

verify_signing_identity
verify_notary_profile
build_archive

if [[ ! -d "$ARCHIVED_APP" ]]; then
  echo "error: archived app not found: $ARCHIVED_APP" >&2
  exit 1
fi

sign_app
create_dmg
notarize_dmg
write_checksum
verify_mounted_app

if [[ "$PUBLISH" -eq 1 ]]; then
  publish_release
fi

echo "Release DMG ready:"
echo "  Tag: $TAG"
echo "  App version: $APP_VERSION"
echo "  Build number: $BUILD_NUMBER"
echo "  DMG: $DMG_PATH"
echo "  Checksum: $CHECKSUM_PATH"
echo "  Notary submission id: $(cat "$SUBMISSION_ID_PATH")"
