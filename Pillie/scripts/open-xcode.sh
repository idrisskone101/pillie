#!/usr/bin/env bash
# Open Pillie in the validated Xcode 27 app.

set -euo pipefail

UDID="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
PROJECT_PATH="$PROJECT_DIR/Pillie.xcodeproj"
START_FILE="$PROJECT_DIR/Pillie/ContentView.swift"
. "$SCRIPT_DIR/xcode-env.sh"

pillie_select_developer_dir

XCODE_APP="$(pillie_xcode_app_path)"

echo "> Opening Pillie in Xcode 27"
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
