#!/usr/bin/env bash
# namespace-mac.sh — On-demand Namespace macOS Devbox for iOS verify.
# Usage:
#   Pillie/scripts/namespace-mac.sh install-cli
#   Pillie/scripts/namespace-mac.sh hydrate-auth
#   Pillie/scripts/namespace-mac.sh auth-check
#   Pillie/scripts/namespace-mac.sh status
#   Pillie/scripts/namespace-mac.sh ensure
#   Pillie/scripts/namespace-mac.sh start
#   Pillie/scripts/namespace-mac.sh stop
#   Pillie/scripts/namespace-mac.sh exec -- <command...>
#   Pillie/scripts/namespace-mac.sh sync [ref]
#   Pillie/scripts/namespace-mac.sh diagnose
#   Pillie/scripts/namespace-mac.sh screenshot
#   Pillie/scripts/namespace-mac.sh verify -- <command...>
#
# Linux Cloud Agents stay on Linux. Exec is native SSH (GetSSHConfig),
# not `devbox exec`, `nsc ssh`, or `nsc proxy`. Prefer `verify` for one
# iOS job. For a batch, `start`, then sync/exec, then `stop`.
# One-shot exec/sync/diagnose/screenshot stop the Mac if they had to start it.
# KEEP=1 / NS_MAC_KEEP=1 leaves it up. Always Stop; never Expire.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
API="$SCRIPT_DIR/namespace-mac-api.py"

DEVBOX_NAME="${PILLIE_NS_DEVBOX_NAME:-pillie-ios}"
REMOTE_DIR="${PILLIE_NS_REMOTE_DIR:-/Users/runner/workspaces/pillie}"
SSH_DIR="${PILLIE_NS_SSH_DIR:-$HOME/.namespace/ssh}"
SSH_HOST="${PILLIE_NS_SSH_HOST:-pillie-ios}"
SSH_CONFIG="$SSH_DIR/${SSH_HOST}.config"
ARTIFACT_DIR="${PILLIE_NS_ARTIFACT_DIR:-/opt/cursor/artifacts}"
TOKEN_PATH="${NSC_TOKEN_FILE:-$HOME/.config/ns/token.json}"

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing $1. Run: $0 install-cli" >&2
    exit 1
  fi
}

keep_requested() {
  [[ "${NS_MAC_KEEP:-${KEEP:-0}}" == "1" ]]
}

install_cli() {
  if ! command -v nsc >/dev/null 2>&1; then
    curl -fsSL https://get.namespace.so/cloud/install.sh | sh
  fi
  export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
  command -v nsc >/dev/null 2>&1 || {
    echo "error: nsc did not install onto PATH" >&2
    exit 1
  }
  command -v curl >/dev/null 2>&1 || {
    echo "error: curl is required for DevBoxService RPCs" >&2
    exit 1
  }
  echo "ok: nsc $(nsc version 2>/dev/null | head -1)"
  echo "ok: skipping the devbox CLI (this Cloud Agent token cannot log it in)"
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
  need_cmd curl
  hydrate_auth
  if [[ ! -f "${NSC_TOKEN_FILE:-$TOKEN_PATH}" ]]; then
    echo "error: not logged into Namespace. Add the NSC_TOKEN Cloud Agent secret." >&2
    exit 1
  fi
  if ! nsc auth check-login >/dev/null 2>&1; then
    echo "error: nsc auth check-login failed. Add the NSC_TOKEN Cloud Agent secret." >&2
    exit 1
  fi
}

api() {
  python3 "$API" "$@"
}

is_running() {
  api instance >/dev/null 2>&1
}

ssh_cmd() {
  if [[ ! -f "$SSH_CONFIG" ]]; then
    echo "error: missing $SSH_CONFIG. Run start first." >&2
    exit 1
  fi
  ssh -F "$SSH_CONFIG" "$SSH_HOST" "$@"
}

wait_for_ssh() {
  local tries=0
  while (( tries < 60 )); do
    if ssh -F "$SSH_CONFIG" -o ConnectTimeout=10 "$SSH_HOST" -- /usr/bin/uname -m >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries + 1))
    sleep 5
  done
  echo "error: SSH to $DEVBOX_NAME did not accept the instance key" >&2
  exit 1
}

close_ssh_master() {
  if [[ -S "$SSH_DIR/${SSH_HOST}.ctl" || -S "$SSH_DIR/${SSH_HOST}.ctl=D" ]]; then
    ssh -F "$SSH_CONFIG" -O exit "$SSH_HOST" >/dev/null 2>&1 || true
  fi
  rm -f "$SSH_DIR/${SSH_HOST}.ctl" "$SSH_DIR/${SSH_HOST}.ctl="* 2>/dev/null || true
}

ensure() {
  auth_check
  api ensure
}

print_running_instances() {
  # `nsc list --all` wants a TTY. Plain `nsc list -o json` is enough.
  local raw
  raw="$(nsc list -o json 2>/dev/null || true)"
  if [[ -z "$raw" || "$raw" == "null" ]]; then
    echo "none"
    return 0
  fi
  printf '%s\n' "$raw"
}

status() {
  auth_check
  echo "Devbox: $DEVBOX_NAME"
  echo
  api status
  echo
  echo "Running instances:"
  print_running_instances
  echo
  if is_running; then
    echo "compute: running — stop with make ns-mac-stop when verify is done"
  else
    echo "compute: stopped"
  fi
  echo "cost: macOS M is \$0.06/min while running. Stopped compute is free. Prefer make ns-mac-verify."
  echo "exec: native SSH via GetSSHConfig. Do not use the devbox CLI, nsc ssh, or nsc proxy."
}

start() {
  ensure
  api activate
  api write-ssh >/dev/null
  wait_for_ssh
  echo "ok: $DEVBOX_NAME is up over native SSH. Stop it with make ns-mac-stop when verify is done."
}

stop() {
  auth_check
  close_ssh_master
  api stop
}

maybe_stop() {
  local was="${1:-0}"
  if keep_requested; then
    echo "ok: leaving $DEVBOX_NAME running (KEEP=1)"
    return 0
  fi
  if [[ "$was" == "1" ]]; then
    return 0
  fi
  echo "ok: stopping $DEVBOX_NAME (started for this command; KEEP=1 to leave it up)"
  stop
}

exec_remote() {
  if [[ $# -eq 0 ]]; then
    echo "error: pass a command after --" >&2
    exit 64
  fi
  if ! is_running; then
    start
  elif [[ ! -f "$SSH_CONFIG" ]]; then
    api write-ssh >/dev/null
    wait_for_ssh
  fi
  ssh_cmd -- "$@"
}

sync_ref() {
  local ref="${1:-}"
  if [[ -z "$ref" ]]; then
    ref="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  fi
  echo "syncing $REMOTE_DIR to $ref"
  exec_remote /bin/bash -lc \
    "set -euo pipefail; cd '$REMOTE_DIR'; git fetch --all --tags; git checkout --detach '$ref'"
}

diagnose_remote() {
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
echo "Xcode apps:"
ls /Applications | grep -i xcode || true
echo
cd /Users/runner/workspaces/pillie
git rev-parse --abbrev-ref HEAD || true
git rev-parse --short HEAD
ls Pillie >/dev/null
echo
if [[ -S /var/run/devbox/socks/control ]]; then
  echo "ok: devbox agent socket /var/run/devbox/socks/control"
else
  echo "warn: missing /var/run/devbox/socks/control"
fi
echo "ok: repo /Users/runner/workspaces/pillie"'
}

remote_screenshot_script() {
  cat <<'REMOTE'
set -euo pipefail
cd /Users/runner/workspaces/pillie
UDID="$(make -s udid)"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
make build-and-run
if command -v magick >/dev/null 2>&1; then
  make screenshot
else
  echo "warn: magick missing; using sips for the 1x screenshot"
  xcrun simctl io "$UDID" screenshot /tmp/sim_screenshot.png
  sips -Z 430 /tmp/sim_screenshot.png --out /tmp/sim_screenshot_1x.png >/dev/null
  echo "Wrote /tmp/sim_screenshot_1x.png"
fi
REMOTE
}

screenshot_remote() {
  mkdir -p "$ARTIFACT_DIR"
  sync_ref "${REF:-}"
  exec_remote /bin/bash -lc "$(remote_screenshot_script)"
  scp -F "$SSH_CONFIG" "$SSH_HOST:/tmp/sim_screenshot.png" "$ARTIFACT_DIR/pillie_simulator.png" || true
  scp -F "$SSH_CONFIG" "$SSH_HOST:/tmp/sim_screenshot_1x.png" "$ARTIFACT_DIR/pillie_simulator_1x.png"
  echo "ok: $ARTIFACT_DIR/pillie_simulator_1x.png"
}

run_oneshot() {
  local was=0
  if is_running; then
    was=1
  fi
  local rc=0
  "$@" || rc=$?
  maybe_stop "$was" || true
  return "$rc"
}

verify_remote() {
  if [[ $# -eq 0 ]]; then
    echo "error: pass a command after --" >&2
    exit 64
  fi
  local ref="${REF:-}"
  local rc=0
  start || rc=$?
  if [[ $rc -eq 0 ]]; then
    sync_ref "$ref" || rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    exec_remote "$@" || rc=$?
  fi
  if keep_requested; then
    echo "ok: leaving $DEVBOX_NAME running (KEEP=1)"
  else
    echo "ok: stopping $DEVBOX_NAME after verify"
    stop || true
  fi
  return "$rc"
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
    run_oneshot exec_remote "$@"
    ;;
  sync) run_oneshot sync_ref "${1:-}" ;;
  diagnose) run_oneshot diagnose_remote ;;
  screenshot) run_oneshot screenshot_remote ;;
  verify)
    if [[ "${1:-}" == "--" ]]; then
      shift
    fi
    verify_remote "$@"
    ;;
  *)
    echo "Unknown argument: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
