#!/usr/bin/env bash
# serve-simulator-browser.sh - Mirror Pillie's iOS simulator into Codex Browser.
# Usage:
#   Pillie/scripts/serve-simulator-browser.sh
#   PILLIE_SIMULATOR_UDID=<simulator-udid> Pillie/scripts/serve-simulator-browser.sh

set -euo pipefail

SIM="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"

usage() {
  sed -n '2,5p' "$0" | sed 's/^# //'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "Unknown argument: $1" >&2
  usage >&2
  exit 64
fi

cleanup_serve_sim() {
  npx --yes serve-sim@latest --kill "$SIM" >/dev/null 2>&1 || true
}

trap cleanup_serve_sim EXIT INT TERM HUP

echo "Mirroring simulator: $SIM"
echo "Booting simulator if needed..."
xcrun simctl boot "$SIM" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM" -b >/dev/null

echo "Cleaning up any stale serve-sim helper for this simulator..."
cleanup_serve_sim

echo "Starting serve-sim. Open the printed localhost URL in Codex Browser."
echo "Keep this command running while the simulator mirror is in use."
npx --yes serve-sim@latest "$SIM"
