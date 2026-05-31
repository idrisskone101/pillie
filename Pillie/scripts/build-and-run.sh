#!/usr/bin/env bash
# build-and-run.sh — Build, install, and launch Pillie on the simulator.
# Usage:
#   ./scripts/build-and-run.sh              # build + install + launch
#   ./scripts/build-and-run.sh --build-only # build only
#   ./scripts/build-and-run.sh --run-only   # install + launch (skip build)
#   PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-demo ./scripts/build-and-run.sh

set -euo pipefail

UDID="124DC75F-0771-4C81-841D-F13655138260"
SCHEME="Pillie"
PROJECT="Pillie.xcodeproj"
BUNDLE_ID="com.idrisskone.pillie"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"

safe_name() {
  printf "%s" "$1" | tr -cs '[:alnum:]_.-' '-' | sed 's/^-//; s/-$//'
}

if [[ -n "${PILLIE_DERIVED_DATA:-}" ]]; then
  DERIVED_DATA="$PILLIE_DERIVED_DATA"
elif [[ "$REPO_ROOT" == "$HOME/.codex/worktrees/"* ]]; then
  WORKTREE_ID="$(basename "$(dirname "$REPO_ROOT")")"
  DERIVED_DATA="/tmp/PillieDerivedData-codex-$(safe_name "$WORKTREE_ID")"
elif [[ "$REPO_NAME" == "Pillie" ]]; then
  DERIVED_DATA="/tmp/PillieDerivedData"
else
  DERIVED_DATA="/tmp/PillieDerivedData-$(safe_name "$REPO_NAME")"
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app"

build() {
  echo "▸ Building $SCHEME..."
  echo "▸ DerivedData: $DERIVED_DATA"
  cd "$PROJECT_DIR"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -sdk iphonesimulator \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    -configuration Debug \
    build 2>&1 | xcsift
}

install_app() {
  echo "▸ Installing on $UDID..."
  xcrun simctl install "$UDID" "$APP_PATH"
}

launch_app() {
  echo "▸ Launching $BUNDLE_ID..."
  xcrun simctl launch --terminate-running-process --console "$UDID" "$BUNDLE_ID"
}

case "${1:-}" in
  --build-only) build ;;
  --run-only)   install_app && launch_app ;;
  *)            build && install_app && launch_app ;;
esac
