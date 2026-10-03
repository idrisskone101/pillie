#!/usr/bin/env bash
# sim-qa-selftest.sh — Prove sim-qa.sh never installs a stale Assets.car.
# Usage:
#   Pillie/scripts/sim-qa-selftest.sh
#
# Runs this checkout's sim-qa.sh in a throwaway worktree with stub xcrun,
# make, axe, magick, and xcodebuild, so it works on Linux. The stub make
# rewrites Assets.car on build-and-run only when a catalog file is newer,
# the way actool does.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP="$(mktemp -d)"
WT="$TMP/wt"
BIN="$TMP/bin"
UDID="AAAAAAAA-0000-0000-0000-000000000000"
trap 'git -C "$REPO_ROOT" worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

mkdir -p "$BIN"
cat >"$BIN/xcrun" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "simctl list") echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"$UDID","name":"iPhone 17 Pro","state":"Booted","isAvailable":true}]}}' ;;
  "simctl io") : >"\$5" ;;
esac
EOF
cat >"$BIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "Xcode 27.0"
EOF
cat >"$BIN/axe" <<'EOF'
#!/usr/bin/env bash
printf 'Today %.0s' $(seq 100)
EOF
cat >"$BIN/magick" <<'EOF'
#!/usr/bin/env bash
cp "$1" "${@: -1}"
EOF
cat >"$BIN/make" <<'EOF'
#!/usr/bin/env bash
root="$2"; target="$3"
echo "$target" >>"$SELFTEST_MAKE_LOG"
[[ "$target" == build-and-run ]] || exit 0
car="$PILLIE_DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app/Assets.car"
mkdir -p "$(dirname "$car")"
if [[ ! -f "$car" || -n "$(find "$root/Pillie/Pillie/Assets.xcassets" -type f -newer "$car" -print -quit)" ]]; then
  touch "$car"
fi
EOF
chmod +x "$BIN"/*

git -C "$REPO_ROOT" worktree add -q --detach "$WT" HEAD
cp "$SCRIPT_DIR/sim-qa.sh" "$WT/Pillie/scripts/sim-qa.sh"
git -C "$WT" -c user.name=selftest -c user.email=selftest@localhost commit -qam "sim-qa under test" >/dev/null || true

export PATH="$BIN:$PATH"
export PILLIE_DERIVED_DATA="$TMP/dd" PILLIE_SIMULATOR_UDID="$UDID" PILLIE_DEVELOPER_DIR=/nonexistent
export SELFTEST_MAKE_LOG="$TMP/make.log" PILLIE_BUILD_LOG="$TMP/build.log"
export PILLIE_QA_JSON="$TMP/qa.json" PILLIE_AX_DUMP="$TMP/ax.txt" SCREENSHOT="$TMP/s.png" SCREENSHOT_1X="$TMP/s1.png"
ASSETS="$WT/Pillie/Pillie/Assets.xcassets"
SVG="$ASSETS/MethodIcons/MethodIconPill.imageset/MethodIconPill.svg"
CAR="$PILLIE_DERIVED_DATA/Build/Products/Debug-iphonesimulator/Pillie.app/Assets.car"
FAIL=0

qa() {
  : >"$SELFTEST_MAKE_LOG"
  "$WT/Pillie/scripts/sim-qa.sh" >"$TMP/qa.out" 2>&1
}

check() {
  if "${@:2}"; then echo "pass: $1"; else echo "FAIL: $1"; FAIL=1; fi
}

car_fresh() {
  [[ -z "$(find "$ASSETS" -type f -newer "$CAR" -print -quit)" ]]
}

ran() {
  [[ "$(cat "$SELFTEST_MAKE_LOG")" == "$1" ]]
}

touch_later() {
  sleep 1.1
  "$@"
}

qa
check "first run builds" ran build-and-run
qa
check "clean rerun at the same SHA skips the build" ran run
: >"$WT/stray_agent_script.sh"
qa
check "an untracked file outside Pillie/ still skips the build" ran run

touch_later sh -c "printf '<!-- selftest -->\n' >>'$SVG'"
qa
check "uncommitted asset edit rebuilds" ran build-and-run
check "uncommitted asset edit installs a fresh Assets.car" car_fresh

touch_later sh -c "printf '<!-- selftest 2 -->\n' >>'$SVG'"
SKIP_BUILD=1 qa
check "SKIP_BUILD=1 over a newer asset exits non-zero" test $? -ne 0
check "SKIP_BUILD=1 over a newer asset names the stale file" grep -q "Assets.car is older than" "$TMP/qa.out"

touch_later git -C "$WT" checkout -q -- "$SVG"
qa
check "reverting a dirty build rebuilds" ran build-and-run
check "reverted tree installs a fresh Assets.car" car_fresh

exit "$FAIL"
