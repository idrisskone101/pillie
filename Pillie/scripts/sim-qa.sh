#!/usr/bin/env bash
# sim-qa.sh — Boot, run, wait for a settled UI, screenshot, axe dump.
# Usage:
#   Pillie/scripts/sim-qa.sh
#   Pillie/scripts/sim-qa.sh --skip-build
#   Pillie/scripts/sim-qa.sh --capture-only
#   FORCE_BUILD=1 Pillie/scripts/sim-qa.sh
#
# Writes /tmp/sim_screenshot.png, /tmp/sim_screenshot_1x.png,
# /tmp/pillie_ax.txt, and /tmp/pillie_qa.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
. "$SCRIPT_DIR/xcode-env.sh"
pillie_select_developer_dir

SCREENSHOT="${SCREENSHOT:-/tmp/sim_screenshot.png}"
SCREENSHOT_1X="${SCREENSHOT_1X:-/tmp/sim_screenshot_1x.png}"
AX_DUMP="${PILLIE_AX_DUMP:-/tmp/pillie_ax.txt}"
QA_JSON="${PILLIE_QA_JSON:-/tmp/pillie_qa.json}"
SCALE="${SCALE:-33.33%}"
BUNDLE_ID="com.idrisskone.pillie"

SKIP_BUILD="${SKIP_BUILD:-0}"
CAPTURE_ONLY="${CAPTURE_ONLY:-0}"
FORCE_BUILD="${FORCE_BUILD:-0}"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --capture-only) CAPTURE_ONLY=1 ;;
    --force-build) FORCE_BUILD=1 ;;
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

UDID="$(pillie_default_simulator_udid)"
DERIVED_DATA="$(pillie_derived_data_for_repo_root "$REPO_ROOT")"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app"
STAMP="$DERIVED_DATA/.pillie-qa-sha"
SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
READY=0
AXE_OK=0
APP_PID=""
STARTED_AT="$SECONDS"

write_1x() {
  if command -v magick >/dev/null 2>&1; then
    magick "$SCREENSHOT" -resize "$SCALE" "$SCREENSHOT_1X"
  else
    echo "warn: magick missing; using sips for the 1x screenshot"
    sips -Z 874 "$SCREENSHOT" --out "$SCREENSHOT_1X" >/dev/null
  fi
}

capture_screenshot() {
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT"
  write_1x
  echo "Wrote $SCREENSHOT_1X"
}

capture_axe() {
  if ! command -v axe >/dev/null 2>&1; then
    echo "missing: axe" >"$AX_DUMP"
    return 1
  fi
  if axe describe-ui --udid "$UDID" >"$AX_DUMP" 2>/dev/null; then
    AXE_OK=1
    return 0
  fi
  echo "warn: axe describe-ui failed" >&2
  return 1
}

ui_looks_ready() {
  local dump="$1"
  local len
  len="$(wc -c <"$dump" | tr -d ' ')"
  if (( len < 400 )); then
    return 1
  fi
  grep -Eiq 'Today|History|Settings|Oggi|Heute|Hoy|Hoje|Cronologia|Verlauf|Einstellungen|Impostazioni|Continue|Get Started|Welcome|Plus' "$dump"
}

wait_for_ui() {
  local tries=0
  local last_len=0
  local stable=0
  local len=0
  if ! command -v axe >/dev/null 2>&1; then
    echo "warn: axe missing; sleeping 8s before screenshot"
    sleep 8
    READY=0
    return 0
  fi
  while (( tries < 40 )); do
    if axe describe-ui --udid "$UDID" >"$AX_DUMP" 2>/dev/null; then
      AXE_OK=1
      len="$(wc -c <"$AX_DUMP" | tr -d ' ')"
      if ui_looks_ready "$AX_DUMP"; then
        READY=1
        echo "ok: UI ready (${len} bytes, labels matched)"
        return 0
      fi
      if (( len > 400 && len == last_len )); then
        stable=$((stable + 1))
      else
        stable=0
      fi
      last_len="$len"
      if (( stable >= 2 )); then
        READY=1
        echo "ok: UI settled (${len} bytes)"
        return 0
      fi
    fi
    tries=$((tries + 1))
    sleep 1
  done
  echo "warn: UI did not report ready after ${tries}s; capturing anyway"
  READY=0
}

write_qa_json() {
  python3 - "$QA_JSON" <<'PY'
import json, os, sys
path = sys.argv[1]
payload = {
    "sha": os.environ.get("PILLIE_QA_SHA", ""),
    "udid": os.environ.get("PILLIE_QA_UDID", ""),
    "bundle_id": os.environ.get("PILLIE_QA_BUNDLE", ""),
    "app_pid": os.environ.get("PILLIE_QA_PID", ""),
    "ready": os.environ.get("PILLIE_QA_READY", "0") == "1",
    "axe": os.environ.get("PILLIE_QA_AXE", "0") == "1",
    "screenshot": os.environ.get("PILLIE_QA_SHOT", ""),
    "screenshot_1x": os.environ.get("PILLIE_QA_SHOT_1X", ""),
    "ax_dump": os.environ.get("PILLIE_QA_AX", ""),
    "xcode": os.environ.get("PILLIE_QA_XCODE", ""),
    "duration_s": int(os.environ.get("PILLIE_QA_DURATION", "0")),
    "skip_build": os.environ.get("PILLIE_QA_SKIP_BUILD", "0") == "1",
    "capture_only": os.environ.get("PILLIE_QA_CAPTURE_ONLY", "0") == "1",
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
    fh.write("\n")
print(f"Wrote {path}")
PY
}

already_built() {
  [[ "$FORCE_BUILD" != "1" && -d "$APP_PATH" && -f "$STAMP" && "$(cat "$STAMP")" == "$SHA" ]]
}

echo "▸ sim-qa UDID=$UDID sha=${SHA:0:12}"
echo "▸ DerivedData: $DERIVED_DATA"
pillie_boot_simulator "$UDID"

if [[ "$CAPTURE_ONLY" != "1" ]]; then
  if [[ "$SKIP_BUILD" == "1" ]] || already_built; then
    if already_built && [[ "$SKIP_BUILD" != "1" ]]; then
      echo "ok: $SHA already built; launching existing app"
      SKIP_BUILD=1
    fi
    make -C "$REPO_ROOT" run
  else
    make -C "$REPO_ROOT" build-and-run
    mkdir -p "$DERIVED_DATA"
    printf '%s\n' "$SHA" >"$STAMP"
  fi
  APP_PID="$(xcrun simctl spawn "$UDID" launchctl print system 2>/dev/null | grep -F "$BUNDLE_ID" | head -1 || true)"
  wait_for_ui
else
  echo "▸ capture-only"
fi

capture_screenshot
capture_axe || true

XCODE_VER="$(xcodebuild -version 2>/dev/null | sed -n '1s/^Xcode //p' || true)"
export PILLIE_QA_SHA="$SHA"
export PILLIE_QA_UDID="$UDID"
export PILLIE_QA_BUNDLE="$BUNDLE_ID"
export PILLIE_QA_PID="$APP_PID"
export PILLIE_QA_READY="$READY"
export PILLIE_QA_AXE="$AXE_OK"
export PILLIE_QA_SHOT="$SCREENSHOT"
export PILLIE_QA_SHOT_1X="$SCREENSHOT_1X"
export PILLIE_QA_AX="$AX_DUMP"
export PILLIE_QA_XCODE="$XCODE_VER"
export PILLIE_QA_DURATION="$((SECONDS - STARTED_AT))"
export PILLIE_QA_SKIP_BUILD="$SKIP_BUILD"
export PILLIE_QA_CAPTURE_ONLY="$CAPTURE_ONLY"
write_qa_json

if [[ ! -f "$SCREENSHOT_1X" ]]; then
  echo "error: missing $SCREENSHOT_1X" >&2
  exit 1
fi
echo "ok: sim-qa ready=$READY axe=$AXE_OK ${SCREENSHOT_1X}"
