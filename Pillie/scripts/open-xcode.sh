#!/usr/bin/env bash
# Open the current Pillie git worktree in the validated Xcode 27 app.
# Usage:
#   Pillie/scripts/open-xcode.sh              # cwd's worktree
#   Pillie/scripts/open-xcode.sh /path/to/wt  # explicit checkout

set -euo pipefail

usage() {
  sed -n '2,5p' "$0" | sed 's/^# //'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 64
fi

UDID="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -eq 1 ]]; then
  TARGET_DIR="$(cd "$1" && pwd)"
else
  TARGET_DIR="$PWD"
fi

resolve_checkout() {
  local start="$1"
  local git_root script_root
  git_root="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$git_root" && -d "$git_root/Pillie/Pillie.xcodeproj" ]]; then
    printf "%s" "$git_root"
    return
  fi
  script_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  if [[ -d "$script_root/Pillie/Pillie.xcodeproj" ]]; then
    printf "%s" "$script_root"
    return
  fi
  echo "error: could not find Pillie/Pillie.xcodeproj from $start" >&2
  exit 1
}

CHECKOUT="$(resolve_checkout "$TARGET_DIR")"
PROJECT_DIR="$CHECKOUT/Pillie"
PROJECT_PATH="$PROJECT_DIR/Pillie.xcodeproj"
START_FILE="$PROJECT_DIR/Pillie/ContentView.swift"
BRANCH="$(git -C "$CHECKOUT" branch --show-current 2>/dev/null || true)"
BRANCH="${BRANCH:-detached}"

. "$SCRIPT_DIR/xcode-env.sh"

pillie_select_developer_dir

XCODE_APP="$(pillie_xcode_app_path)"

echo "> Opening Pillie in Xcode 27"
echo "> Worktree: $CHECKOUT"
echo "> Branch: $BRANCH"
echo "> Xcode: $XCODE_APP"
echo "> Project: $PROJECT_PATH"
echo "> Simulator: $UDID"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "> DeveloperDir: $DEVELOPER_DIR"
fi
echo "> In Xcode, use the toolbar destination 'iPhone 17 Pro', not 'My Mac'."

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
open -n -a "$XCODE_APP" --args -ApplePersistenceIgnoreState YES
sleep 3
DEVELOPER_DIR="${DEVELOPER_DIR:-$(pillie_default_developer_dir)}" xed --project "$PROJECT_PATH" "$START_FILE"
