#!/usr/bin/env bash
# ensure-qa-tools.sh — Keep axe and ImageMagick on PATH.
# Usage:
#   Pillie/scripts/ensure-qa-tools.sh
#   Pillie/scripts/ensure-qa-tools.sh --check
#
# Stop/Start on a Namespace Devbox keeps the persistent volume, including
# Homebrew under /opt/homebrew. Delete and ephemeral Devboxes wipe it.
# macOS Devboxes cannot use a custom image, so this script installs the
# two QA tools the first time they are missing. Safe to run on every boot.

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK="${HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK:-1}"
export NONINTERACTIVE=1

CHECK_ONLY=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

have() {
  command -v "$1" >/dev/null 2>&1
}

tool_path() {
  command -v "$1" 2>/dev/null || echo missing
}

report() {
  echo "tools: axe=$(tool_path axe) magick=$(tool_path magick)"
}

both_present() {
  have axe && have magick
}

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if both_present; then
  echo "ok: axe and magick already on PATH"
  report
  exit 0
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo "missing: axe and/or magick"
  report
  exit 1
fi

if ! have brew; then
  echo "error: brew missing; cannot install axe or imagemagick" >&2
  echo "hint: Namespace macOS images normally ship Homebrew at /opt/homebrew." >&2
  report
  exit 1
fi

if ! have axe; then
  echo "install: axe via cameroncooke/axe"
  brew tap cameroncooke/axe
  brew install axe
fi

if ! have magick; then
  echo "install: imagemagick"
  brew install imagemagick
fi

if ! both_present; then
  echo "error: axe or magick still missing after brew install" >&2
  report
  exit 1
fi

echo "ok: installed axe and magick"
report
