#!/usr/bin/env bash
# mcp-build-and-run.sh - Build, install, and launch Pillie through XcodeBuildMCP.
# Usage:
#   Pillie/scripts/mcp-build-and-run.sh              # build + install + launch
#   Pillie/scripts/mcp-build-and-run.sh --build-only # build only
#   PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-demo Pillie/scripts/mcp-build-and-run.sh

set -euo pipefail

UDID="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
SCHEME="Pillie"
CONFIGURATION="Debug"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"
PROJECT_PATH="$PROJECT_DIR/Pillie.xcodeproj"
BUILD_ONLY=0
. "$SCRIPT_DIR/xcode-env.sh"

usage() {
  cat <<EOF
Usage: $0 [--build-only]

Options:
  --build-only  Build the app and skip install/launch.

Environment overrides:
  PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-demo
  PILLIE_SIMULATOR_UDID=<simulator-udid>
  PILLIE_DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer
EOF
}

safe_name() {
  printf "%s" "$1" | tr -cs '[:alnum:]_.-' '-' | sed 's/^-//; s/-$//'
}

for arg in "$@"; do
  case "$arg" in
    --build-only)
      BUILD_ONLY=1
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

pillie_select_developer_dir

if ! command -v xcodebuildmcp >/dev/null 2>&1; then
  echo "xcodebuildmcp is not installed or not on PATH." >&2
  exit 127
fi

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

COMMON_ARGS=(
  --project-path "$PROJECT_PATH"
  --scheme "$SCHEME"
  --configuration "$CONFIGURATION"
  --simulator-id "$UDID"
  --derived-data-path "$DERIVED_DATA"
)

echo "> XcodeBuildMCP Pillie build"
echo "> Project: $PROJECT_PATH"
echo "> DerivedData: $DERIVED_DATA"
echo "> Simulator: $UDID"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "> DeveloperDir: $DEVELOPER_DIR"
fi

if [[ "$BUILD_ONLY" == "1" ]]; then
  xcodebuildmcp simulator build "${COMMON_ARGS[@]}"
else
  xcodebuildmcp simulator build-and-run "${COMMON_ARGS[@]}"
fi
