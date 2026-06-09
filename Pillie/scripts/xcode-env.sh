#!/usr/bin/env bash
# Shared Xcode selection for Pillie workflows.
#
# Pillie is currently validated on Xcode 27 beta. Prefer it whenever it is
# installed so terminal, MCP, Codex actions, and Xcode-open workflows do not
# silently drift back to the globally selected Xcode 26.x toolchain.

pillie_default_developer_dir() {
  printf "%s" "${PILLIE_XCODE27_DEVELOPER_DIR:-/Users/idrisskone/Downloads/Xcode-beta.app/Contents/Developer}"
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
