#!/usr/bin/env bash
# Shared Xcode selection for Pillie workflows.
#
# Pillie is currently validated on Xcode 27 beta. Prefer it whenever it is
# installed so terminal, MCP, Codex actions, and Xcode-open workflows do not
# silently drift back to the globally selected Xcode 26.x toolchain.

pillie_default_developer_dir() {
  printf "%s" "${PILLIE_XCODE27_DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
}

pillie_developer_dir_version() {
  local developer_dir="$1"
  DEVELOPER_DIR="$developer_dir" xcodebuild -version 2>/dev/null | sed -n '1s/^Xcode //p'
}

pillie_current_xcode_version() {
  xcodebuild -version 2>/dev/null | sed -n '1s/^Xcode //p'
}

pillie_select_developer_dir() {
  local xcode27_dir selected_version xcode27_version
  xcode27_dir="$(pillie_default_developer_dir)"

  if [[ -n "${PILLIE_DEVELOPER_DIR:-}" ]]; then
    export DEVELOPER_DIR="$PILLIE_DEVELOPER_DIR"
    return
  fi

  if [[ -d "$xcode27_dir" ]]; then
    selected_version="$(pillie_current_xcode_version || true)"
    if [[ "$selected_version" == 27* ]]; then
      return
    fi

    xcode27_version="$(pillie_developer_dir_version "$xcode27_dir" || true)"
    if [[ "$xcode27_version" == 27* ]]; then
      export DEVELOPER_DIR="$xcode27_dir"
      return
    fi
  fi

  selected_version="$(pillie_current_xcode_version || true)"
  if [[ "$selected_version" != 27* ]]; then
    echo "warning: Pillie workflows expect Xcode 27, but active xcodebuild is Xcode ${selected_version:-unknown}." >&2
    echo "warning: set PILLIE_DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer to override." >&2
  fi
}

pillie_xcode_app_path() {
  local xcode27_dir app_path
  xcode27_dir="$(pillie_default_developer_dir)"
  app_path="$(cd "$xcode27_dir/../.." 2>/dev/null && pwd || true)"

  if [[ -n "$app_path" && -d "$app_path" ]]; then
    printf "%s" "$app_path"
  else
    printf "%s" "/Applications/Xcode.app"
  fi
}

pillie_default_simulator_udid() {
  printf "%s" "${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
}

# Quiet-by-default Swift compile parallelism. Uncapped `xcodebuild` uses every
# CPU core (10 on the M5) and is the usual fan trigger for "just launch the
# simulator". Override with PILLIE_BUILD_JOBS=10 for a full-speed compile.
pillie_build_jobs() {
  printf "%s" "${PILLIE_BUILD_JOBS:-4}"
}

# XCTest simulator cloning. Keep this off locally: parallelizable test
# destinations clone one iPhone 17 Pro per CPU core.
pillie_parallel_testing_enabled() {
  printf "%s" "${PILLIE_TEST_PARALLEL:-NO}"
}

# Keep a single booted simulator. Each extra iPhone 17 Pro in Device Hub adds
# SpringBoard plus several SimMetalHost processes. Skip with
# PILLIE_KEEP_EXTRA_SIMS=YES when two canvases are intentional.
pillie_shutdown_extra_simulators() {
  local keep_udid="$1"
  local extra
  if [[ "${PILLIE_KEEP_EXTRA_SIMS:-}" == "YES" ]]; then
    return 0
  fi
  extra="$(
    PILLIE_KEEP_UDID="$keep_udid" python3 - <<'PY'
import json, os, subprocess, sys
keep = os.environ["PILLIE_KEEP_UDID"]
try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "booted", "-j"],
        stderr=subprocess.DEVNULL,
    )
except subprocess.CalledProcessError:
    sys.exit(0)
data = json.loads(raw)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("state") == "Booted" and device.get("udid") != keep:
            print(f"{device['udid']}\t{device.get('name', '')}")
PY
  )"
  if [[ -z "$extra" ]]; then
    return 0
  fi
  while IFS=$'\t' read -r udid name; do
    [[ -z "$udid" ]] && continue
    echo "> Shutting down extra simulator: ${name:-unknown} ($udid)"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done <<< "$extra"
}
