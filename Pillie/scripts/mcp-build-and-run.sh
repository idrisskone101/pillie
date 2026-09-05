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
  PILLIE_BUILD_JOBS=<n>          compile cores (default 4)
  PILLIE_KEEP_EXTRA_SIMS=YES     leave other booted simulators running
EOF
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

DERIVED_DATA="$(pillie_derived_data_for_repo_root "$REPO_ROOT")"

JOBS="$(pillie_build_jobs)"
pillie_shutdown_extra_simulators "$UDID"

COMMON_ARGS=(
  --project-path "$PROJECT_PATH"
  --scheme "$SCHEME"
  --configuration "$CONFIGURATION"
  --simulator-id "$UDID"
  --derived-data-path "$DERIVED_DATA"
  "--extra-args=-jobs"
  "--extra-args=$JOBS"
)

echo "> XcodeBuildMCP Pillie build"
echo "> Project: $PROJECT_PATH"
echo "> DerivedData: $DERIVED_DATA"
echo "> Simulator: $UDID"
echo "> Jobs: $JOBS (PILLIE_BUILD_JOBS to override)"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "> DeveloperDir: $DEVELOPER_DIR"
fi

if [[ "$BUILD_ONLY" == "1" ]]; then
  xcodebuildmcp simulator build "${COMMON_ARGS[@]}"
else
  xcodebuildmcp simulator build-and-run "${COMMON_ARGS[@]}"
fi
