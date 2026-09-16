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
#   Pillie/scripts/namespace-mac.sh check-sync [ref]
#   Pillie/scripts/namespace-mac.sh sync [ref]
#   Pillie/scripts/namespace-mac.sh diagnose
#   Pillie/scripts/namespace-mac.sh ensure-tools
#   Pillie/scripts/namespace-mac.sh qa
#   Pillie/scripts/namespace-mac.sh screenshot
#   Pillie/scripts/namespace-mac.sh verify -- <command...>
#
# Linux Cloud Agents stay on Linux. Exec is native SSH (GetSSHConfig),
# not `devbox exec`, `nsc ssh`, or `nsc proxy`. Prefer `qa` for iOS
# proof. `verify` with no command is `qa`. For a custom remote job,
# `verify -- make test TESTS=Class`. Do not Stop unless the user asked.
# KEEP=1 / NS_MAC_KEEP=1 is the default. Never Expire.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PILLIE_NS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
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
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
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

ssh_ready() {
  [[ -f "$SSH_CONFIG" ]] || return 1
  ssh -F "$SSH_CONFIG" -o ConnectTimeout=8 "$SSH_HOST" -- /usr/bin/uname -m >/dev/null 2>&1
}

ssh_cmd() {
  if [[ ! -f "$SSH_CONFIG" ]]; then
    echo "error: missing $SSH_CONFIG. Run start first." >&2
    exit 1
  fi
  local rc=0
  ssh -F "$SSH_CONFIG" "$SSH_HOST" "$@" || rc=$?
  if [[ $rc -eq 0 || $rc -ne 255 ]]; then
    return "$rc"
  fi
  echo "warn: SSH dropped; refreshing the instance key and retrying" >&2
  close_ssh_master
  if is_running; then
    api write-ssh >/dev/null || true
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
    if (( tries % 6 == 0 )); then
      echo "waiting for SSH on $DEVBOX_NAME (${tries}/60)"
    fi
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
    echo "compute: running. Leave it up until the user asks to stop."
  else
    echo "compute: stopped"
  fi
  echo "cost: macOS M is \$0.06/min while running. Stopped compute is free. Prefer make ns-mac-qa."
  echo "exec: native SSH via GetSSHConfig. Do not use the devbox CLI, nsc ssh, or nsc proxy."
}

start() {
  auth_check
  if ssh_ready; then
    echo "ok: $DEVBOX_NAME already reachable over SSH. Leave it running until the user asks to stop."
    return 0
  fi
  ensure
  api activate
  close_ssh_master
  api write-ssh >/dev/null
  wait_for_ssh
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

# OpenSSH runs the guest login shell with -c and joins argv with spaces.
# `ssh host bash -lc "cd x && y"` becomes `zsh -c "bash -lc cd x && y"`.
# Send one script on stdin instead.
exec_remote() {
  if [[ $# -eq 0 ]]; then
    echo "error: pass a command after --" >&2
    exit 64
  fi
  if ! ssh_ready; then
    start
  fi
  local script
  if [[ $# -ge 3 && "$1" == /bin/bash && "$2" == -lc ]]; then
    script="$3"
  else
    script="$*"
  fi
  ssh -F "$SSH_CONFIG" "$SSH_HOST" -- bash --login -s <<EOF
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
cd '$REMOTE_DIR'
${script}
EOF
}

ensure_tools_remote() {
  check_sync "${REF:-}"
  start
  sync_ref "${REF:-}"
  exec_remote "Pillie/scripts/ensure-qa-tools.sh"
}

check_sync() {
  local ref="${1:-}"
  local using_head=0
  if [[ -z "$ref" ]]; then
    ref="$(git -C "$REPO_ROOT" rev-parse HEAD)"
    using_head=1
  fi
  if [[ "$using_head" == "1" && "${NS_MAC_ALLOW_DIRTY:-0}" != "1" ]]; then
    if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
      echo "error: uncommitted changes. Commit and push before verifying on the Mac." >&2
      git -C "$REPO_ROOT" status --short >&2
      echo "hint: the Mac syncs HEAD, not your working tree. NS_MAC_ALLOW_DIRTY=1 skips this check." >&2
      exit 1
    fi
  fi
  git -C "$REPO_ROOT" fetch origin --quiet >/dev/null 2>&1 || true
  if [[ "${NS_MAC_ALLOW_UNPUSHED:-0}" != "1" ]]; then
    if ! git -C "$REPO_ROOT" branch -r --contains "$ref" | grep -q .; then
      echo "error: $ref is not on a remote. Push this branch, then retry." >&2
      echo "  git push -u origin HEAD" >&2
      exit 1
    fi
  fi
  echo "ok: $ref is on a remote"
}

sync_ref() {
  local ref="${1:-}"
  if [[ -z "$ref" ]]; then
    ref="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  fi
  check_sync "$ref"
  echo "syncing $REMOTE_DIR to $ref"
  exec_remote "git fetch --prune origin
if ! git cat-file -e ${ref}^{commit} 2>/dev/null; then
  git fetch origin '$ref'
fi
if ! git cat-file -e ${ref}^{commit}; then
  echo 'error: $ref missing after fetch. Push from the Cloud Agent first.' >&2
  exit 1
fi
git reset --hard '$ref'
echo ok: \$(git rev-parse --short HEAD)"
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
echo "tools: axe=$(command -v axe || echo missing) magick=$(command -v magick || echo missing)"
if [[ -x /Users/runner/workspaces/pillie/Pillie/scripts/ensure-qa-tools.sh ]]; then
  /Users/runner/workspaces/pillie/Pillie/scripts/ensure-qa-tools.sh --check || true
fi
echo "ok: repo /Users/runner/workspaces/pillie"'
}

pull_qa_artifacts() {
  mkdir -p "$ARTIFACT_DIR"
  scp -F "$SSH_CONFIG" "$SSH_HOST:/tmp/sim_screenshot.png" "$ARTIFACT_DIR/pillie_simulator.png" || true
  scp -F "$SSH_CONFIG" "$SSH_HOST:/tmp/sim_screenshot_1x.png" "$ARTIFACT_DIR/pillie_simulator_1x.png"
  scp -F "$SSH_CONFIG" "$SSH_HOST:/tmp/pillie_ax.txt" "$ARTIFACT_DIR/pillie_ax.txt" || true
  scp -F "$SSH_CONFIG" "$SSH_HOST:/tmp/pillie_qa.json" "$ARTIFACT_DIR/pillie_qa.json" || true
  if [[ ! -f "$ARTIFACT_DIR/pillie_simulator_1x.png" ]]; then
    echo "error: missing $ARTIFACT_DIR/pillie_simulator_1x.png" >&2
    exit 1
  fi
  echo "ok: $ARTIFACT_DIR/pillie_simulator_1x.png"
  if [[ -f "$ARTIFACT_DIR/pillie_qa.json" ]]; then
    echo "ok: $ARTIFACT_DIR/pillie_qa.json"
  fi
}

remote_qa_args() {
  local args=()
  if [[ "${CAPTURE_ONLY:-0}" == "1" ]]; then
    args+=(--capture-only)
  elif [[ "${SKIP_BUILD:-0}" == "1" ]]; then
    args+=(--skip-build)
  fi
  if [[ "${FORCE_BUILD:-0}" == "1" ]]; then
    args+=(--force-build)
  fi
  printf '%s' "${args[*]}"
}

qa_remote() {
  mkdir -p "$ARTIFACT_DIR"
  check_sync "${REF:-}"
  start
  sync_ref "${REF:-}"
  exec_remote "Pillie/scripts/ensure-qa-tools.sh"
  exec_remote "Pillie/scripts/sim-qa.sh $(remote_qa_args)"
  pull_qa_artifacts
}

screenshot_remote() {
  qa_remote
}

run_oneshot() {
  local was=0
  if ssh_ready || is_running; then
    was=1
  fi
  local rc=0
  "$@" || rc=$?
  maybe_stop "$was" || true
  return "$rc"
}

verify_remote() {
  if [[ $# -eq 0 ]]; then
    run_oneshot qa_remote
    return
  fi
  local ref="${REF:-}"
  local rc=0
  check_sync "$ref" || rc=$?
  if [[ $rc -eq 0 ]]; then
    start || rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    sync_ref "$ref" || rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    exec_remote "Pillie/scripts/ensure-qa-tools.sh" || rc=$?
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
  check-sync) check_sync "${1:-}" ;;
  sync) run_oneshot sync_ref "${1:-}" ;;
  diagnose) run_oneshot diagnose_remote ;;
  ensure-tools) run_oneshot ensure_tools_remote ;;
  qa) run_oneshot qa_remote ;;
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
