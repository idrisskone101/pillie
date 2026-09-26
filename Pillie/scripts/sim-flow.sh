#!/usr/bin/env bash
# sim-flow.sh — Run one QA flow against the booted iPhone 17 Pro in one process.
# Usage:
#   Pillie/scripts/sim-flow.sh FLOW_FILE [OUT_DIR]
#   Pillie/scripts/sim-flow.sh --help-steps
#
# Runs on the Mac (laptop or pillie-ios). Linux agents call it through
# `make ns-mac-flow FLOW=…`, which ships the flow file and pulls OUT_DIR back.
# Writes OUT_DIR/NN-<name>.png (1x), NN-<name>.ax.json, NN-<name>.ax.txt
# (outline), steps.jsonl, and report.json. Exit 0 only if every step passed.
#
# Flow file: one step per line, `#` comments. Consecutive axe interaction lines
# (swipe, gesture, touch, type, button, key, sleep, coordinate taps) run as one
# `axe batch`. A tap by --id/--label/--value runs alone with --wait-timeout, so
# it waits for its element on a fresh tree instead of needing sleeps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
. "$SCRIPT_DIR/xcode-env.sh"
pillie_select_developer_dir

BUNDLE_ID="com.idrisskone.pillie"
WAIT="${FLOW_WAIT:-10}"
SCALE="${SCALE:-33.33%}"
OUTLINE="$SCRIPT_DIR/ax-outline.py"

help_steps() {
  cat <<'EOF'
Flow steps (one per line):

  launch [ARGS...]          terminate, launch with ARGS (e.g. -AppleLanguages "(it)"), wait for UI
  fresh                     empty the App Group, uninstall + reinstall: a real first launch
  defaults KEY TYPE VALUE   write app defaults (TYPE: -bool -int -string -float), before `launch`
  openurl URL               open a URL or deep link in the simulator
  wait id|label|text X [S]  poll the ax tree until X appears (default 10s)
  gone id|label|text X [S]  poll until X is gone
  expect id|label|text X    fail unless X is on screen now
  expect-not id|label|text X
  shot NAME                 1x PNG + ax dump + outline, numbered in run order
  appearance light|dark     simctl ui appearance
  statusbar clean|clear     9:41 full-battery status bar, or clear the override
  privacy grant|revoke|reset SERVICE   simctl privacy for this app (notifications, photos, …)
  push FILE.apns            simctl push FILE to this app
  record start|stop         axe record-video to NN-record.mp4 (keep flows short)
  log start|stop            app OSLog (subsystem com.idrisskone.pillie) to app.log
  perf-launch N             N cold launches, ms from `simctl launch` to first settled ax tree
  frames WORKLOAD           Pillie/scripts/measure-frames.sh WORKLOAD (idle|tabs|calendar|all)
  note TEXT                 record a note in the report
  tap … / swipe … / gesture … / touch … / type … / button … / key … / sleep N
                            axe batch steps, same syntax as `axe batch --step`

A failing step stops the flow, takes a `fail` shot, and exits 1.
EOF
}

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  ""|-h|--help) usage; exit 0 ;;
  --help-steps) help_steps; exit 0 ;;
esac

FLOW="$1"
NAME="$(basename "$FLOW" .flow)"
OUT="${2:-/tmp/pillie-flow/$NAME}"
[[ -f "$FLOW" ]] || { echo "error: missing flow $FLOW" >&2; exit 2; }
"$SCRIPT_DIR/ensure-qa-tools.sh" >/dev/null
rm -rf "$OUT"
mkdir -p "$OUT"

UDID="$(pillie_default_simulator_udid)"
DERIVED_DATA="$(pillie_derived_data_for_repo_root "$REPO_ROOT")"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app"
BUILT_SHA="$(cat "$DERIVED_DATA/.pillie-qa-sha" 2>/dev/null || echo unknown)"
pillie_boot_simulator "$UDID" >/dev/null

SEQ=0
BATCH="$OUT/.batch"
: >"$BATCH"
STEPS="$OUT/steps.jsonl"
: >"$STEPS"
FLOW_OK=1
FAILED_LINE=""
RECORD_PID=""
LOG_PID=""
T0="$(python3 -c 'import time; print(time.time())')"

now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

record_step() {
  # record_step LINE OK MS [ARTIFACT] [DETAIL]
  python3 - "$STEPS" "$@" <<'PY'
import json, sys
path, line, ok, ms = sys.argv[1:5]
art = sys.argv[5] if len(sys.argv) > 5 else ""
detail = sys.argv[6] if len(sys.argv) > 6 else ""
row = {"step": line, "ok": ok == "1", "ms": int(ms)}
if art:
    row["artifact"] = art
if detail:
    row["detail"] = detail
with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(row, ensure_ascii=False) + "\n")
PY
}

dump() {
  axe describe-ui --udid "$UDID" >"$1" 2>/dev/null
}

present() {
  # present KIND VALUE [DUMP]
  local file="${3:-$OUT/.probe.json}"
  [[ -n "${3:-}" ]] || dump "$file" || return 1
  "$OUTLINE" "$file" --has "$1" "$2"
}

poll_for() {
  # poll_for want|gone KIND VALUE SECONDS
  local mode="$1" kind="$2" value="$3" secs="$4"
  local deadline=$((SECONDS + secs))
  while :; do
    if present "$kind" "$value"; then
      [[ "$mode" == want ]] && return 0
    else
      [[ "$mode" == gone ]] && return 0
    fi
    (( SECONDS >= deadline )) && return 1
    sleep 0.25
  done
}

settle() {
  # Wait until the ax tree has content and stops changing.
  local last="" cur="" stable=0 deadline=$((SECONDS + ${1:-20}))
  while (( SECONDS < deadline )); do
    if dump "$OUT/.probe.json"; then
      cur="$(wc -c <"$OUT/.probe.json" | tr -d ' ')"
      if (( cur > 400 )) && [[ "$cur" == "$last" ]]; then
        stable=$((stable + 1))
        (( stable >= 2 )) && return 0
      else
        stable=0
      fi
      last="$cur"
    fi
    sleep 0.25
  done
  return 1
}

shot() {
  SEQ=$((SEQ + 1))
  local base
  base="$(printf '%02d-%s' "$SEQ" "$1")"
  xcrun simctl io "$UDID" screenshot "$OUT/.full.png" >/dev/null 2>&1
  magick "$OUT/.full.png" -resize "$SCALE" "$OUT/$base.png"
  dump "$OUT/$base.ax.json" || true
  "$OUTLINE" "$OUT/$base.ax.json" >"$OUT/$base.ax.txt" 2>/dev/null || true
  LAST_ARTIFACT="$base.png"
}

flush_batch() {
  [[ -s "$BATCH" ]] || return 0
  local t rc=0 err
  t="$(now_ms)"
  # perStep: a tap that opens or closes a sheet changes the tree the next step searches.
  err="$(axe batch --udid "$UDID" --ax-cache perStep --wait-timeout "$WAIT" --file "$BATCH" 2>&1 >/dev/null)" || rc=$?
  local steps
  steps="$(paste -sd ';' "$BATCH")"
  : >"$BATCH"
  if (( rc != 0 )); then
    record_step "batch: $steps" 0 $(( $(now_ms) - t )) "" "$(printf '%s' "$err" | tail -3 | tr '\n' ' ')"
    echo "FAIL batch: $steps $(printf '%s' "$err" | tail -3 | tr '\n' ' ')"
    return 1
  fi
  record_step "batch: $steps" 1 $(( $(now_ms) - t ))
  echo "ok   batch: $steps ($(( $(now_ms) - t ))ms)"
}

launch_app() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" "$@" >/dev/null
  settle 30
}

perf_launch() {
  local n="$1" i t samples=()
  for ((i = 1; i <= n; i++)); do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    sleep 1
    t="$(now_ms)"
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
    until dump "$OUT/.probe.json" && (( $(wc -c <"$OUT/.probe.json") > 400 )); do
      (( $(now_ms) - t > 30000 )) && break
      sleep 0.05
    done
    samples+=($(( $(now_ms) - t )))
  done
  python3 - "$OUT/perf-launch.json" "${samples[@]}" <<'PY'
import json, statistics, sys
path, *vals = sys.argv[1:]
ms = sorted(int(v) for v in vals)
out = {"what": "terminate, then simctl launch until the ax tree is non-empty (ms; warm caches; includes one axe poll)",
       "samples_ms": ms, "median_ms": int(statistics.median(ms)), "max_ms": ms[-1]}
json.dump(out, open(path, "w"), indent=2)
print(json.dumps(out))
PY
}

run_pseudo() {
  local verb="$1"
  shift
  case "$verb" in
    launch) launch_app "$@" ;;
    fresh)
      [[ -d "$APP_PATH" ]] || { echo "no built app at $APP_PATH; run make qa first"; return 1; }
      # The store and shared defaults live in the App Group container, which
      # outlives `simctl uninstall`. Empty it so this is a real first launch.
      local group
      while IFS=$'\t' read -r _ group; do
        [[ -d "$group" ]] && find "$group" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
      done < <(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" groups 2>/dev/null || true)
      xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
      xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
      xcrun simctl install "$UDID" "$APP_PATH"
      ;;
    defaults) xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" "$@" ;;
    openurl)
      xcrun simctl openurl "$UDID" "$1"
      # Safari-style "Open in “Pillie”?" confirmation on every simctl openurl.
      # The tap can land while the alert is still animating in, so retry until it is gone.
      local tries=0
      while poll_for want text "Open in “Pillie”?" 3 && (( tries < 3 )); do
        sleep 0.5
        axe tap --udid "$UDID" --label Open --element-type Button --wait-timeout 3 >/dev/null 2>&1 || true
        tries=$((tries + 1))
        poll_for gone text "Open in “Pillie”?" 2 && break
      done
      ! present text "Open in “Pillie”?" || { echo "openurl confirmation stuck"; return 1; }
      settle 10 || true
      ;;
    wait) poll_for want "$1" "$2" "${3:-$WAIT}" ;;
    gone) poll_for gone "$1" "$2" "${3:-$WAIT}" ;;
    expect) present "$1" "$2" ;;
    expect-not) ! present "$1" "$2" ;;
    shot) shot "$1" ;;
    appearance) xcrun simctl ui "$UDID" appearance "$1" ;;
    statusbar)
      if [[ "$1" == clear ]]; then
        xcrun simctl status_bar "$UDID" clear
      else
        xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged \
          --batteryLevel 100 --cellularBars 4 --wifiBars 3
      fi
      ;;
    privacy) xcrun simctl privacy "$UDID" "$1" "$2" "$BUNDLE_ID" ;;
    push) xcrun simctl push "$UDID" "$BUNDLE_ID" "$REPO_ROOT/$1" ;;
    record)
      if [[ "$1" == start ]]; then
        SEQ=$((SEQ + 1))
        axe record-video --udid "$UDID" --fps 10 --scale 0.5 \
          --output "$OUT/$(printf '%02d' "$SEQ")-record.mp4" >/dev/null 2>&1 &
        RECORD_PID=$!
        sleep 1
      elif [[ -n "$RECORD_PID" ]]; then
        kill -INT "$RECORD_PID" 2>/dev/null || true
        wait "$RECORD_PID" 2>/dev/null || true
        RECORD_PID=""
      fi
      ;;
    log)
      if [[ "$1" == start ]]; then
        xcrun simctl spawn "$UDID" log stream --style compact \
          --predicate "subsystem == \"$BUNDLE_ID\"" --level debug >"$OUT/app.log" 2>&1 &
        LOG_PID=$!
      elif [[ -n "$LOG_PID" ]]; then
        kill "$LOG_PID" 2>/dev/null || true
        wait "$LOG_PID" 2>/dev/null || true
        LOG_PID=""
      fi
      ;;
    perf-launch) perf_launch "${1:-3}" ;;
    frames)
      "$SCRIPT_DIR/measure-frames.sh" "${1:-all}" >"$OUT/frames.log" 2>&1
      cp /tmp/pillie_frames.json "$OUT/frames.json"
      cat "$OUT/frames.json"
      ;;
    note) : ;;
    *) echo "unknown step: $verb"; return 2 ;;
  esac
}

cleanup() {
  [[ -n "$RECORD_PID" ]] && kill -INT "$RECORD_PID" 2>/dev/null || true
  [[ -n "$LOG_PID" ]] && kill "$LOG_PID" 2>/dev/null || true
  rm -f "$OUT/.probe.json" "$OUT/.full.png" "$OUT/.step.log" "$BATCH"
}
trap cleanup EXIT

echo "▸ sim-flow $NAME udid=$UDID app=${BUILT_SHA:0:12} out=$OUT"
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  verb="${line%% *}"
  case "$verb" in
    tap|swipe|gesture|touch|type|button|key|key-sequence|key-combo|sleep)
      # A selector tap gets its own batch. Inside one batch, axe cannot find an
      # element that only appears after an earlier step (a sheet closing, a scroll).
      if [[ "$verb" == tap && "$line" =~ --(id|label|value)[[:space:]] ]]; then
        flush_batch || { FLOW_OK=0; FAILED_LINE="$(tail -1 "$STEPS")"; break; }
        printf '%s\n' "$line" >>"$BATCH"
        flush_batch || { FLOW_OK=0; FAILED_LINE="$(tail -1 "$STEPS")"; break; }
        continue
      fi
      printf '%s\n' "$line" >>"$BATCH"
      continue
      ;;
  esac
  if ! flush_batch; then
    FLOW_OK=0
    FAILED_LINE="$(tail -1 "$STEPS")"
    break
  fi
  LAST_ARTIFACT=""
  t="$(now_ms)"
  rc=0
  # shlex, not eval: a flow line is data, and `&` in a URL must stay literal.
  args=()
  while IFS= read -r -d '' tok; do args+=("$tok"); done < <(
    python3 -c 'import shlex, sys; sys.stdout.write("".join(t + "\0" for t in shlex.split(sys.argv[1])))' "$line")
  set -- "${args[@]:1}"
  run_pseudo "$verb" "$@" >"$OUT/.step.log" 2>&1 || rc=$?
  out="$(cat "$OUT/.step.log")"
  ms=$(( $(now_ms) - t ))
  if (( rc == 0 )); then
    record_step "$line" 1 "$ms" "$LAST_ARTIFACT" "$(printf '%s' "$out" | tail -1)"
    echo "ok   $line (${ms}ms)"
  else
    record_step "$line" 0 "$ms" "$LAST_ARTIFACT" "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')"
    echo "FAIL $line (${ms}ms) $out"
    FLOW_OK=0
    FAILED_LINE="$line"
    break
  fi
done <"$FLOW"

if (( FLOW_OK == 1 )) && ! flush_batch; then
  FLOW_OK=0
  FAILED_LINE="$(tail -1 "$STEPS")"
fi
if (( FLOW_OK == 0 )); then
  shot fail || true
  echo "FAIL $FAILED_LINE"
fi

python3 - "$OUT" "$NAME" "$UDID" "$BUILT_SHA" "$FLOW_OK" "$T0" <<'PY'
import json, os, sys, time
out, name, udid, sha, ok, t0 = sys.argv[1:]
steps = [json.loads(l) for l in open(os.path.join(out, "steps.jsonl"), encoding="utf-8") if l.strip()]
report = {"flow": name, "ok": ok == "1", "udid": udid, "app_sha": sha,
          "duration_s": round(time.time() - float(t0), 1),
          "shots": sorted(f for f in os.listdir(out) if f.endswith(".png")),
          "steps": steps}
json.dump(report, open(os.path.join(out, "report.json"), "w"), indent=2, ensure_ascii=False)
print(f"{'ok' if report['ok'] else 'FAIL'}: flow {name} {len(steps)} steps {report['duration_s']}s -> {out}")
PY
(( FLOW_OK == 1 ))
