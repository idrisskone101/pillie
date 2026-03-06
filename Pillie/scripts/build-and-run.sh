#!/usr/bin/env bash
# build-and-run.sh — Build, install, and launch Pillie on the simulator.
# Usage:
#   ./scripts/build-and-run.sh              # build + install + launch
#   ./scripts/build-and-run.sh --build-only # build only
#   ./scripts/build-and-run.sh --run-only   # install + launch (skip build)

set -euo pipefail

UDID="124DC75F-0771-4C81-841D-F13655138260"
SCHEME="Pillie"
PROJECT="Pillie.xcodeproj"
BUNDLE_ID="com.idrisskone.pillie"
DERIVED_DATA="/tmp/PillieDerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

build() {
  echo "▸ Building $SCHEME..."
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
