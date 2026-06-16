#!/usr/bin/env bash
# build-and-run.sh — Build, install, and launch Pillie on the simulator.
# Usage:
#   ./scripts/build-and-run.sh              # build + install + headless launch
#   ./scripts/build-and-run.sh --build-only # build only
#   ./scripts/build-and-run.sh --run-only   # install + headless launch (skip build)
#   ./scripts/build-and-run.sh --console    # build + install + blocking console launch
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
. "$SCRIPT_DIR/xcode-env.sh"

safe_name() {
  printf "%s" "$1" | tr -cs '[:alnum:]_.-' '-' | sed 's/^-//; s/-$//'
}

if [[ -n "${PILLIE_DERIVED_DATA:-}" ]]; then
  DERIVED_DATA="$PILLIE_DERIVED_DATA"
elif [[ "$REPO_ROOT" == "$HOME/.codex/worktrees/"* ]]; then
  WORKTREE_ID="$(basename "$(dirname "$REPO_ROOT")")"
  DERIVED_DATA="/tmp/PillieDerivedData-codex-$(safe_name "$WORKTREE_ID")"
elif [[ "$REPO_ROOT" == *"/.claude/worktrees/"* ]]; then
  WORKTREE_ID="${REPO_ROOT##*/.claude/worktrees/}"
  DERIVED_DATA="/tmp/PillieDerivedData-claude-$(safe_name "$WORKTREE_ID")"
elif [[ "$REPO_NAME" == "Pillie" ]]; then
  DERIVED_DATA="/tmp/PillieDerivedData"
else
  DERIVED_DATA="/tmp/PillieDerivedData-$(safe_name "$REPO_NAME")"
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app"
BUILD=1
RUN=1
CONSOLE=0

usage() {
  cat <<EOF
Usage: $0 [--build-only] [--run-only] [--console]

Options:
  --build-only  Build the app and skip install/launch.
  --run-only    Install and launch the existing build.
  --console     Launch attached to the blocking app console.

Default launch is headless so the command returns after simctl prints the app PID.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --build-only)
      BUILD=1
      RUN=0
      ;;
    --run-only)
      BUILD=0
      RUN=1
      ;;
    --console)
      CONSOLE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

build() {
  echo "▸ Building $SCHEME..."
  echo "▸ DerivedData: $DERIVED_DATA"
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    echo "▸ DeveloperDir: $DEVELOPER_DIR"
  fi
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
  if [[ "$CONSOLE" == "1" ]]; then
    echo "▸ Launching $BUNDLE_ID with blocking console..."
    xcrun simctl launch --terminate-running-process --console "$UDID" "$BUNDLE_ID"
  else
    echo "▸ Launching $BUNDLE_ID headlessly..."
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID"
  fi
}

if [[ "$BUILD" == "1" ]]; then
  pillie_select_developer_dir
  build
fi

if [[ "$RUN" == "1" ]]; then
  install_app
  launch_app
fi
