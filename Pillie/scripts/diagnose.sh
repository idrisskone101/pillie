#!/usr/bin/env bash
# diagnose.sh — Print Pillie toolchain, simulator, and DerivedData.
# Usage:
#   Pillie/scripts/diagnose.sh
#   Pillie/scripts/diagnose.sh --udid
#   Pillie/scripts/diagnose.sh --derived-data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
. "$SCRIPT_DIR/xcode-env.sh"

MODE="all"
case "${1:-}" in
  --udid) MODE="udid" ;;
  --derived-data) MODE="derived-data" ;;
  -h|--help)
    sed -n '2,7p' "$0" | sed 's/^# //'
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 2
    ;;
esac

pillie_select_developer_dir
UDID="$(pillie_default_simulator_udid)"
DERIVED_DATA="$(pillie_derived_data_for_repo_root "$REPO_ROOT")"

if [[ "$MODE" == "udid" ]]; then
  printf "%s\n" "$UDID"
  exit 0
fi
if [[ "$MODE" == "derived-data" ]]; then
  printf "%s\n" "$DERIVED_DATA"
  exit 0
fi

print_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    echo "ok: $name ($(command -v "$name"))"
  else
    echo "missing: $name"
  fi
}

echo "Repo: $REPO_ROOT"
echo "Branch: $(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)"
echo "Project: $PROJECT_DIR/Pillie.xcodeproj"
echo "Scheme: Pillie"
echo "Bundle ID: com.idrisskone.pillie"
echo "Simulator UDID: $UDID"
echo "DerivedData: $DERIVED_DATA"
echo "Build jobs: $(pillie_build_jobs)"
echo "Parallel tests: $(pillie_parallel_testing_enabled)"

echo ""
if command -v xcode-select >/dev/null 2>&1; then
  echo "xcode-select: $(xcode-select -p)"
else
  echo "missing: xcode-select"
fi
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "DEVELOPER_DIR: $DEVELOPER_DIR"
fi
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version
else
  echo "missing: xcodebuild"
fi

echo ""
print_cmd xcodebuildmcp
print_cmd xcsift
print_cmd axe
print_cmd magick
print_cmd idb
print_cmd jq

echo ""
if xcrun simctl list devices "$UDID" >/dev/null 2>&1; then
  xcrun simctl list devices | grep -F "$UDID" || true
else
  echo "simulator: not found ($UDID)"
fi
