#!/usr/bin/env bash
# measure-frames.sh — Launch Pillie with a scripted frame probe and write JSON.
# Usage:
#   Pillie/scripts/measure-frames.sh
#   Pillie/scripts/measure-frames.sh calendar
#   WORKLOAD=tabs Pillie/scripts/measure-frames.sh
#
# Workloads: tabs | calendar | idle | all
# Writes /tmp/pillie_frames.json (override with PILLIE_FRAME_JSON).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
. "$SCRIPT_DIR/xcode-env.sh"
pillie_select_developer_dir

WORKLOAD="${1:-${WORKLOAD:-all}}"
BUNDLE_ID="com.idrisskone.pillie"
OUT="${PILLIE_FRAME_JSON:-/tmp/pillie_frames.json}"
LOG="${PILLIE_FRAME_LOG:-/tmp/pillie_frames.log}"
COMBINED="${PILLIE_FRAME_COMBINED_LOG:-/tmp/pillie_frames_all.log}"
ONBOARDING_COMPLETE=16

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

case "$WORKLOAD" in
  tabs|calendar|idle|all) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown workload: $WORKLOAD (tabs|calendar|idle|all)" >&2
    usage >&2
    exit 2
    ;;
esac

UDID="$(pillie_default_simulator_udid)"
DERIVED_DATA="$(pillie_derived_data_for_repo_root "$REPO_ROOT")"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app"
SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"

if [[ ! -d "$APP_PATH" || "${FORCE_BUILD:-0}" == "1" ]]; then
  echo "▸ Building before measure..."
  "$SCRIPT_DIR/build-and-run.sh" --build-only
fi

echo "▸ Booting simulator $UDID..."
pillie_boot_simulator "$UDID"
echo "▸ Installing $BUNDLE_ID..."
xcrun simctl install "$UDID" "$APP_PATH"
echo "▸ Seeding onboardingStep=$ONBOARDING_COMPLETE"
xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" onboardingStep -int "$ONBOARDING_COMPLETE"

run_one() {
  local name="$1"
  shift
  local timeout_s="${1:-45}"
  shift
  local arg_log="$LOG.$name"
  rm -f "$arg_log"
  : >"$arg_log"

  echo "▸ Measuring workload=$name"
  xcrun simctl spawn "$UDID" log stream \
    --style compact \
    --predicate 'subsystem == "com.idrisskone.pillie" AND category == "frames"' \
    >"$arg_log" 2>&1 &
  local log_pid=$!
  sleep 1
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" "$@" >/dev/null

  local i
  for i in $(seq 1 "$timeout_s"); do
    if grep -q 'PILLIE_FRAMES_JSON' "$arg_log"; then
      break
    fi
    sleep 1
  done

  kill "$log_pid" 2>/dev/null || true
  wait "$log_pid" 2>/dev/null || true

  if ! grep -q 'PILLIE_FRAMES_JSON\|PILLIE_FRAMES SUMMARY' "$arg_log"; then
    echo "error: no PILLIE_FRAMES summary for $name" >&2
    echo "--- $arg_log ---" >&2
    tail -n 40 "$arg_log" >&2 || true
    return 1
  fi

  local parsed
  parsed="$LOG.$name.json"
  python3 "$SCRIPT_DIR/parse_frame_metrics.py" "$arg_log" >"$parsed"
  echo "▸ $name -> $parsed"
  cat "$parsed"
}

rm -f "$COMBINED"
: >"$COMBINED"

declare -a names=()
if [[ "$WORKLOAD" == "all" ]]; then
  names=(idle tabs calendar)
elif [[ "$WORKLOAD" == "tabs" ]]; then
  names=(tabs)
elif [[ "$WORKLOAD" == "calendar" ]]; then
  names=(calendar)
else
  names=(idle)
fi

for name in "${names[@]}"; do
  case "$name" in
    tabs)
      run_one tabs 45 -PillieTabSwitchLoop 1
      ;;
    calendar)
      run_one calendar 50 -PillieCalendarSwipeLoop 1
      ;;
    idle)
      run_one idle 20 -PillieIdleFrameProbe 1
      ;;
  esac
  cat "$LOG.$name" >>"$COMBINED"
done

python3 - "$OUT" "$SHA" "$WORKLOAD" "$LOG" "${names[@]}" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
sha = sys.argv[2]
workload = sys.argv[3]
log_prefix = sys.argv[4]
names = sys.argv[5:]
workloads = {}
for name in names:
    path = Path(f"{log_prefix}.{name}.json")
    if path.exists():
        workloads[name] = json.loads(path.read_text())
payload = {
    "sha": sha,
    "workload": workload,
    "workloads": workloads,
}
out.write_text(json.dumps(payload, indent=2) + "\n")
print(f"Wrote {out}")
print(json.dumps(payload, indent=2))
PY
