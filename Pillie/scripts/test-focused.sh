#!/usr/bin/env bash
# test-focused.sh - Run one or more explicit Pillie XCTest classes or methods.
# Usage:
#   Pillie/scripts/test-focused.sh SoftPaywallContentTests
#   Pillie/scripts/test-focused.sh SoftPaywallContentTests/testCTAUsesPilliePlusCopy
#   Pillie/scripts/test-focused.sh PillieTests/SoftPaywallContentTests
#   PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-demo Pillie/scripts/test-focused.sh AnalyticsManagerTests

set -euo pipefail

UDID="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
SCHEME="Pillie"
PROJECT="Pillie.xcodeproj"
TEST_TARGET="PillieTests"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"
. "$SCRIPT_DIR/xcode-env.sh"

usage() {
  cat <<'USAGE'
Usage:
  Pillie/scripts/test-focused.sh <TestClassOrMethod> [more...]

Examples:
  Pillie/scripts/test-focused.sh SoftPaywallContentTests
  Pillie/scripts/test-focused.sh SoftPaywallContentTests/testCTAUsesPilliePlusCopy
  Pillie/scripts/test-focused.sh PillieTests/SoftPaywallContentTests

Environment overrides:
  PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-demo
  PILLIE_SIMULATOR_UDID=<simulator-udid>
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

# Disable parallel testing by default. With parallelizable="YES" in the scheme,
# xcodebuild clones the simulator once per CPU core, which pegs every core and
# spins the fans. Override with PILLIE_TEST_PARALLEL=YES to restore cloning.
PARALLEL_TESTING="${PILLIE_TEST_PARALLEL:-NO}"

echo "> Running focused Pillie tests..."
echo "> DerivedData: $DERIVED_DATA"
echo "> Simulator: $UDID"
echo "> Parallel testing: $PARALLEL_TESTING (PILLIE_TEST_PARALLEL=YES re-enables simulator cloning)"
pillie_select_developer_dir
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "> DeveloperDir: $DEVELOPER_DIR"
fi
for test_identifier in "$@"; do
  echo "> Test: $(normalize_test_identifier "$test_identifier")"
done

XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -sdk iphonesimulator
  -destination "id=$UDID"
  -derivedDataPath "$DERIVED_DATA"
  -configuration Debug
  -parallel-testing-enabled "$PARALLEL_TESTING"
)
# Optional compile-core cap to keep the build phase quieter (slower, cooler).
# e.g. PILLIE_BUILD_JOBS=4
if [[ -n "${PILLIE_BUILD_JOBS:-}" ]]; then
  XCODEBUILD_ARGS+=(-jobs "$PILLIE_BUILD_JOBS")
fi
XCODEBUILD_ARGS+=(test)
XCODEBUILD_ARGS+=("${ONLY_TESTING_ARGS[@]}")

cd "$PROJECT_DIR"
xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 | xcsift
