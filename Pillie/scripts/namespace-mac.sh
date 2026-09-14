#!/usr/bin/env bash
# namespace-mac.sh — On-demand Namespace macOS Devbox for iOS verify.
# Usage:
#   Pillie/scripts/namespace-mac.sh install-cli
#   Pillie/scripts/namespace-mac.sh hydrate-auth
#   Pillie/scripts/namespace-mac.sh status
#   Pillie/scripts/namespace-mac.sh ensure
#   Pillie/scripts/namespace-mac.sh start
#   Pillie/scripts/namespace-mac.sh stop
#   Pillie/scripts/namespace-mac.sh exec -- <command...>
#   Pillie/scripts/namespace-mac.sh sync [ref]
#   Pillie/scripts/namespace-mac.sh diagnose
#
# Linux Cloud Agents stay on Linux. Start this Mac only for Xcode / simulator
# work, then stop it. Do not leave it running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEVBOX_NAME="${PILLIE_NS_DEVBOX_NAME:-pillie-ios}"
DEVBOX_IMAGE="${PILLIE_NS_DEVBOX_IMAGE:-goldengate}"
DEVBOX_SIZE="${PILLIE_NS_DEVBOX_SIZE:-m}"
DEVBOX_IDLE="${PILLIE_NS_DEVBOX_IDLE:-30m}"
DEVBOX_REPO="${PILLIE_NS_DEVBOX_REPO:-github.com/idrisskone101/pillie}"
REMOTE_DIR="${PILLIE_NS_REMOTE_DIR:-/Users/runner/workspaces/pillie}"
TOKEN_PATH="${NSC_TOKEN_FILE:-$HOME/.config/ns/token.json}"

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# //'
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing $1. Run: $0 install-cli" >&2
    exit 1
  fi
}

install_cli() {
  if ! command -v nsc >/dev/null 2>&1; then
    curl -fsSL https://get.namespace.so/cloud/install.sh | sh
  fi
  if ! command -v devbox >/dev/null 2>&1; then
    curl -fsSL https://get.namespace.so/devbox/install.sh | bash
  fi
  export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
  command -v nsc >/dev/null 2>&1 || {
    echo "error: nsc did not install onto PATH" >&2
    exit 1
  }
  command -v devbox >/dev/null 2>&1 || {
    echo "error: devbox did not install onto PATH" >&2
    exit 1
  }
  echo "ok: nsc $(nsc version 2>/dev/null | head -1)"
  echo "ok: devbox $(devbox version 2>/dev/null | head -1)"
}

hydrate_auth() {
  mkdir -p "$(dirname "$TOKEN_PATH")"
  if [[ -n "${NSC_TOKEN_FILE:-}" && -f "$NSC_TOKEN_FILE" ]]; then
    echo "ok: using NSC_TOKEN_FILE"
    return 0
  fi
  if [[ -f "$HOME/.config/ns/token.json" ]]; then
    export NSC_TOKEN_FILE="${NSC_TOKEN_FILE:-$HOME/.config/ns/token.json}"
    echo "ok: using existing Namespace login"
    return 0
  fi
  local raw="${NSC_TOKEN:-${NAMESPACE_TOKEN:-}}"
  if [[ -z "$raw" ]]; then
    echo "missing: NSC_TOKEN (Cursor Cloud Agent secret). iOS verify on Namespace cannot start." >&2
    return 0
  fi
  if [[ "$raw" == tok_* || ${#raw} -lt 80 ]]; then
    echo "error: NSC_TOKEN looks like a Namespace token id, not the bearer token. Paste the long secret value, not tok_…" >&2
    return 1
  fi
  if [[ "$raw" == \{* ]]; then
    printf '%s\n' "$raw" >"$TOKEN_PATH"
  else
    python3 - "$TOKEN_PATH" "$raw" <<'PY'
import json, sys
path, token = sys.argv[1], sys.argv[2]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({"bearer_token": token}, fh)
    fh.write("\n")
PY
  fi
  chmod 600 "$TOKEN_PATH"
  export NSC_TOKEN_FILE="$TOKEN_PATH"
  echo "ok: wrote Namespace token file"
}

auth_check() {
  need_cmd nsc
  need_cmd devbox
  hydrate_auth
  if ! nsc auth check-login >/dev/null 2>&1; then
    echo "error: not logged into Namespace. Add the NSC_TOKEN Cloud Agent secret, or run nsc login." >&2
    exit 1
  fi
}

list_json() {
  devbox list --show-all -o json
}

devbox_exists() {
  list_json | python3 -c '
import json, sys
name = sys.argv[1]
items = json.load(sys.stdin) or []
sys.exit(0 if any(item.get("name") == name for item in items) else 1)
' "$DEVBOX_NAME"
}

macos_names() {
  list_json | python3 -c '
import json, sys
items = json.load(sys.stdin) or []
for item in items:
    shape = item.get("instance_shape") or {}
    if shape.get("os") == "macos":
        print(item.get("name", ""))
'
}

ensure() {
  auth_check
  if devbox_exists; then
    echo "ok: $DEVBOX_NAME exists"
    return 0
  fi
  local extras
  extras="$(macos_names)"
  if [[ -n "$extras" ]]; then
    echo "error: found other macOS Devboxes ($extras). Keep exactly one: $DEVBOX_NAME." >&2
    exit 1
  fi
  echo "creating $DEVBOX_NAME (stopped)..."
  devbox create \
    --name "$DEVBOX_NAME" \
    --platform macos \
    --size "$DEVBOX_SIZE" \
    --image "$DEVBOX_IMAGE" \
    --checkout "$DEVBOX_REPO" \
    --auto_stop_idle_timeout "$DEVBOX_IDLE" \
    --activate=false \
    --purpose "On-demand Xcode / iOS simulator for Cursor Cloud Agents" \
    --access_mode private
}

status() {
  auth_check
  echo "Devbox: $DEVBOX_NAME"
  echo "Workspace:"
  nsc workspace describe 2>/dev/null || true
  echo
  echo "Devboxes:"
  devbox list --show-all
  echo
  echo "Running instances:"
  nsc list --all
}

start() {
  ensure
  echo "starting $DEVBOX_NAME..."
  devbox exec "$DEVBOX_NAME" -- /usr/bin/uname -a
}

stop() {
  auth_check
  if ! devbox_exists; then
    echo "ok: $DEVBOX_NAME is not present"
    return 0
  fi
  devbox shutdown "$DEVBOX_NAME" --force
}

exec_remote() {
  ensure
  if [[ $# -eq 0 ]]; then
    echo "error: pass a command after --" >&2
    exit 64
  fi
  devbox exec "$DEVBOX_NAME" -- "$@"
}

sync_ref() {
  local ref="${1:-}"
  if [[ -z "$ref" ]]; then
    ref="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  fi
  ensure
  echo "syncing $REMOTE_DIR to $ref"
  devbox exec "$DEVBOX_NAME" -- /bin/bash -lc \
    "set -euo pipefail; cd '$REMOTE_DIR'; git fetch --all --tags; git checkout --detach '$ref'"
}

diagnose_remote() {
  start
  echo
  # Single-quoted remote script so hostname/whoami/pwd run on the Mac.
  exec_remote /bin/bash -lc 'set -euo pipefail
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "Pwd:  $(pwd)"
sw_vers
echo
xcodebuild -version
echo
xcode-select -p
echo
cd /Users/runner/workspaces/pillie
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
ls Pillie >/dev/null
echo "ok: repo /Users/runner/workspaces/pillie"'
}

cmd="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$cmd" in
  ""|-h|--help) usage ;;
  install-cli) install_cli ;;
  hydrate-auth) hydrate_auth ;;
  auth-check) auth_check && echo "ok: Namespace auth" ;;
  status) status ;;
  ensure) ensure ;;
  start) start ;;
  stop) stop ;;
  exec)
    if [[ "${1:-}" == "--" ]]; then
      shift
    fi
    exec_remote "$@"
    ;;
  sync) sync_ref "${1:-}" ;;
  diagnose) diagnose_remote ;;
  *)
    echo "Unknown argument: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
