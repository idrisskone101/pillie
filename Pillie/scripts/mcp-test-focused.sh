#!/usr/bin/env bash
# mcp-test-focused.sh - Run explicit Pillie XCTest classes or methods through XcodeBuildMCP.
# Usage:
#   Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests
#   Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests/testCTAUsesPilliePlusCopy
#   Pillie/scripts/mcp-test-focused.sh PillieTests/SoftPaywallContentTests

set -euo pipefail

UDID="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
SCHEME="Pillie"
CONFIGURATION="Debug"
TEST_TARGET="PillieTests"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"
PROJECT_PATH="$PROJECT_DIR/Pillie.xcodeproj"
. "$SCRIPT_DIR/xcode-env.sh"

usage() {
  cat <<'USAGE'
Usage:
  Pillie/scripts/mcp-test-focused.sh <TestClassOrMethod> [more...]

Examples:
  Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests
  Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests/testCTAUsesPilliePlusCopy
  Pillie/scripts/mcp-test-focused.sh PillieTests/SoftPaywallContentTests

Environment overrides:
  PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-demo
  PILLIE_SIMULATOR_UDID=<simulator-udid>
  PILLIE_DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer
USAGE
}

safe_name() {
  printf "%s" "$1" | tr -cs '[:alnum:]_.-' '-' | sed 's/^-//; s/-$//'
}

normalize_test_identifier() {
  local identifier="$1"

  if [[ "$identifier" == "$TEST_TARGET/"* ]]; then
    printf "%s" "$identifier"
  else
    printf "%s/%s" "$TEST_TARGET" "$identifier"
  fi
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  if [[ $# -eq 0 ]]; then
    exit 64
  fi
  exit 0
fi

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

ONLY_TESTING_ARGS=()
for test_identifier in "$@"; do
  ONLY_TESTING_ARGS+=("-only-testing:$(normalize_test_identifier "$test_identifier")")
done

echo "> XcodeBuildMCP focused Pillie tests"
echo "> Project: $PROJECT_PATH"
echo "> DerivedData: $DERIVED_DATA"
echo "> Simulator: $UDID"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "> DeveloperDir: $DEVELOPER_DIR"
fi
for test_identifier in "$@"; do
  echo "> Test: $(normalize_test_identifier "$test_identifier")"
done

MCP_ARGS=(
  --project-path "$PROJECT_PATH"
  --scheme "$SCHEME"
  --configuration "$CONFIGURATION"
  --simulator-id "$UDID"
  --derived-data-path "$DERIVED_DATA"
)

for arg in "${ONLY_TESTING_ARGS[@]}"; do
  MCP_ARGS+=("--extra-args=$arg")
done

xcodebuildmcp simulator test "${MCP_ARGS[@]}"
