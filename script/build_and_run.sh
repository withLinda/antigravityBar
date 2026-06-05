#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="AntigravityBar"
SCHEME="AntigravityBar"
PROJECT="AntigravityBar.xcodeproj"
AGENT_NAME="${AGENT_NAME:-CODEX}"
DERIVED="$ROOT_DIR/build/DerivedData/$AGENT_NAME"
LOG_DIR="$ROOT_DIR/build/logs/$AGENT_NAME"
APP_PATH="$DERIVED/Build/Products/Debug/$APP_NAME.app"
RUN_ONLY=0
VERIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-only)
      RUN_ONLY=1
      shift
      ;;
    --verify)
      VERIFY=1
      shift
      ;;
    -h|--help)
      echo "Usage: script/build_and_run.sh [--run-only] [--verify]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$LOG_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_NAME" || true
  sleep 0.3
fi

if [[ "$RUN_ONLY" -eq 0 ]]; then
  xcodegen generate
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED" \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_STRICT_CONCURRENCY=complete \
    | tee "$LOG_DIR/build-and-run.log"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

open -gj "$APP_PATH"

if [[ "$VERIFY" -eq 1 ]]; then
  sleep 1
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "Launched $APP_NAME"
  else
    echo "$APP_NAME did not stay running" >&2
    exit 1
  fi
fi
