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
# iOS job. For a batch, `start`, then sync/exec. Do not Stop unless the
# user asked. KEEP=1 / NS_MAC_KEEP=1 is the default. KEEP=0 stops a
# one-shot if this session started the instance. Never Expire.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
API="$SCRIPT_DIR/namespace-mac-api.py"

DEVBOX_NAME="${PILLIE_NS_DEVBOX_NAME:-pillie-ios}"
REMOTE_DIR="${PILLIE_NS_REMOTE_DIR:-/Users/runner/workspaces/pillie}"
GUEST_HOME="${PILLIE_NS_REMOTE_HOME:-/Users/runner}"
GUEST_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
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
  [[ "${NS_MAC_KEEP:-${KEEP:-1}}" == "1" ]]
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

write_token_file() {
  local dest="$1"
  local raw="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$raw" == \{* ]]; then
    printf '%s\n' "$raw" >"$dest"
  else
    python3 - "$dest" "$raw" <<'PY'
import json, sys
path, token = sys.argv[1], sys.argv[2]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({"bearer_token": token}, fh)
    fh.write("\n")
PY
  fi
  chmod 600 "$dest"
  export NSC_TOKEN_FILE="$dest"
}

hydrate_auth() {
  mkdir -p "$(dirname "$TOKEN_PATH")"
  local dest="${NSC_TOKEN_FILE:-$TOKEN_PATH}"
  local raw="${NSC_TOKEN:-${NAMESPACE_TOKEN:-}}"
  # Cloud Agent secrets are injected per pod. A snapshot-baked token.json
  # must not win over a rotated NSC_TOKEN.
  if [[ -n "$raw" ]]; then
    if [[ "$raw" == tok_* || ${#raw} -lt 80 ]]; then
      echo "error: NSC_TOKEN looks like a Namespace token id, not the bearer token. Paste the long secret value, not tok_…" >&2
      return 1
    fi
    write_token_file "$dest" "$raw"
    echo "ok: wrote Namespace token file from NSC_TOKEN"
    return 0
  fi
  if [[ -f "$dest" ]]; then
    export NSC_TOKEN_FILE="$dest"
    echo "ok: using NSC_TOKEN_FILE"
    return 0
  fi
  if [[ -f "$HOME/.config/ns/token.json" ]]; then
    export NSC_TOKEN_FILE="$HOME/.config/ns/token.json"
    echo "ok: using existing Namespace login"
    return 0
  fi
  echo "missing: NSC_TOKEN (Cursor Cloud Agent secret). iOS verify on Namespace cannot start." >&2
  return 0
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
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi
  # Join into one remote string so `bash -lc '…'` stays one -c argument.
  # Non-login remote bash does not load Homebrew; keep axe on PATH.
  local quoted
  quoted="$(printf '%q ' "$@")"
  ssh -F "$SSH_CONFIG" "$SSH_HOST" -- \
    "/usr/bin/env HOME=${GUEST_HOME} PATH=${GUEST_PATH} ${quoted}"
}

provision_remote_axe() {
  # stdin script: do not put the installer in `bash -lc`, which SSH word-splits.
  ssh -F "$SSH_CONFIG" "$SSH_HOST" -- \
    "/usr/bin/env HOME=${GUEST_HOME} PATH=${GUEST_PATH} /bin/bash -s" <<'REMOTE'
set -euo pipefail
export HOME="${HOME:-/Users/runner}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1
export NONINTERACTIVE=1
if command -v axe >/dev/null 2>&1; then
  echo "ok: axe $(axe --version 2>/dev/null | head -1)"
  exit 0
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is missing on the Namespace Mac; cannot install axe" >&2
  exit 1
fi
echo "installing axe (cameroncooke/axe)"
brew trust cameroncooke/axe >/dev/null 2>&1 || true
brew tap cameroncooke/axe
brew install cameroncooke/axe/axe
if ! command -v axe >/dev/null 2>&1; then
  echo "error: axe install finished but axe is not on PATH" >&2
  exit 1
fi
echo "ok: axe $(axe --version 2>/dev/null | head -1)"
REMOTE
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
    echo "compute: running — leave it up until the user asks to stop"
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
  provision_remote_axe
  echo "ok: $DEVBOX_NAME is up over native SSH. Leave it running until the user asks to stop."
}

stop() {
  auth_check
  close_ssh_master
  api stop
}

maybe_stop() {
  local was="${1:-0}"
  if keep_requested; then
    echo "ok: leaving $DEVBOX_NAME running (KEEP=${NS_MAC_KEEP:-${KEEP:-1}})"
    return 0
  fi
  if [[ "$was" == "1" ]]; then
    return 0
  fi
  echo "ok: stopping $DEVBOX_NAME (KEEP=0 and this command started it)"
  stop
}

exec_remote() {
  if [[ $# -eq 0 ]]; then
    echo "error: pass a command after --" >&2
    exit 64
  fi
  if ! is_running; then
    start
  else
    if [[ ! -f "$SSH_CONFIG" ]]; then
      api write-ssh >/dev/null
      wait_for_ssh
    fi
    provision_remote_axe
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
echo "Kernel: $(uname -srm)"
sw_vers
echo
xcodebuild -version
echo
xcode-select -p
echo
echo "Xcode apps:"
ls /Applications | grep -i xcode || true
echo
if command -v axe >/dev/null 2>&1; then
  echo "ok: axe $(axe --version 2>/dev/null | head -1) ($(command -v axe))"
else
  echo "missing: axe"
fi
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
if lsof -nP -iTCP:22210 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "ok: devbox agent listening on 22210"
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
sleep 8
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
    echo "ok: leaving $DEVBOX_NAME running (KEEP=${NS_MAC_KEEP:-${KEEP:-1}})"
  else
    echo "ok: stopping $DEVBOX_NAME after verify (KEEP=0)"
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
