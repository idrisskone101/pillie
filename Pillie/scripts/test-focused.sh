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
  PILLIE_BUILD_JOBS=<n>          compile cores (default 4)
  PILLIE_TEST_PARALLEL=YES       re-enable per-core simulator clones
  PILLIE_KEEP_EXTRA_SIMS=YES     leave other booted simulators running
USAGE
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

DERIVED_DATA="$(pillie_derived_data_for_repo_root "$REPO_ROOT")"

ONLY_TESTING_ARGS=()
for test_identifier in "$@"; do
  ONLY_TESTING_ARGS+=("-only-testing:$(normalize_test_identifier "$test_identifier")")
done

PARALLEL_TESTING="$(pillie_parallel_testing_enabled)"
JOBS="$(pillie_build_jobs)"

echo "> Running focused Pillie tests..."
echo "> DerivedData: $DERIVED_DATA"
echo "> Simulator: $UDID"
echo "> Jobs: $JOBS (PILLIE_BUILD_JOBS to override)"
echo "> Parallel testing: $PARALLEL_TESTING (PILLIE_TEST_PARALLEL=YES re-enables simulator cloning)"
pillie_select_developer_dir
pillie_shutdown_extra_simulators "$UDID"
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
  -jobs "$JOBS"
  test
)
XCODEBUILD_ARGS+=("${ONLY_TESTING_ARGS[@]}")

cd "$PROJECT_DIR"
xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 | xcsift
