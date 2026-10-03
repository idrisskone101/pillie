#!/usr/bin/env bash
# render-server-load.sh: run a flow and sample the simulator's render server
# (backboardd) while it runs. Reports busy ms on the Core Animation render threads and
# how much of it went to shadows and blurs. A simulator proxy for device GPU cost:
# compare runs of the same flow, never the absolute number against a device.
# Usage: Pillie/scripts/render-server-load.sh FLOW SECONDS [MARKER]
#   MARKER: start sampling once this text appears in the flow log (default: launch).
# Honors PILLIE_APP_PATH like sim-flow.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW="$1"; SECONDS_TO_SAMPLE="$2"; MARKER="${3:-^ok   launch}"
WORK="$(mktemp -d)"
BACKBOARD="$(ps -axo pid,command | grep '[b]ackboardd' | grep -i CoreSimulator | awk '{print $1}' | head -1)"
[[ -n "$BACKBOARD" ]] || { echo "error: no simulator backboardd; boot the simulator" >&2; exit 1; }

make -C "$SCRIPT_DIR/../.." flow FLOW="$FLOW" >"$WORK/flow.log" 2>&1 &
FLOW_PID=$!
for _ in $(seq 1 600); do grep -q "$MARKER" "$WORK/flow.log" 2>/dev/null && break; sleep 0.1; done
sample "$BACKBOARD" "$SECONDS_TO_SAMPLE" 1 -file "$WORK/backboardd.txt" >/dev/null 2>&1
wait "$FLOW_PID" || { tail -3 "$WORK/flow.log" >&2; exit 1; }
tail -1 "$WORK/flow.log" >&2
echo "sample: $WORK/backboardd.txt" >&2

python3 - "$WORK/backboardd.txt" <<'PY'
import json, re, sys
lines = open(sys.argv[1]).read().split("\n")
heads = [i for i, l in enumerate(lines) if re.match(r"^\s{4}\d+ Thread_", l)]
heads.append(next(i for i, l in enumerate(lines) if l.startswith("Total number")))
idle = {"mach_msg2_trap", "__workq_kernreturn", "__psynch_cvwait", "__semwait_signal", "kevent_id", "__ulock_wait", "__ulock_wait2"}
busy = shadow = blur = 0
for a, b in zip(heads, heads[1:]):
    if "coreanimation" not in lines[a]:
        continue
    waiting = 0
    inside = {"shadow": None, "blur": None}
    for line in lines[a:b]:
        m = re.match(r"^([\s\+\!\:\|]*)(\d+) (\S+)", line)
        if not m:
            continue
        depth, count, name = len(m.group(1)), int(m.group(2)), m.group(3)
        for key in inside:
            if inside[key] is not None and depth <= inside[key]:
                inside[key] = None
        if name in idle:
            waiting += count
        # The sample tree repeats a frame at every nesting level; count only the outermost.
        if name == "CA::OGL::ShadowNode::apply(float," and inside["shadow"] is None:
            shadow += count
            inside["shadow"] = depth
        if name == "CA::OGL::Context::blur_surface(float," and inside["blur"] is None:
            blur += count
            inside["blur"] = depth
    busy += int(lines[a].split()[0]) - waiting
print(json.dumps({"render_busy_ms": busy, "shadow_wall_ms": shadow, "blur_wall_ms": blur}))
PY
