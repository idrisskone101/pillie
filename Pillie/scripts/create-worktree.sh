#!/usr/bin/env bash
# create-worktree.sh - Create a Pillie feature worktree with predictable build settings.
# Usage:
#   Pillie/scripts/create-worktree.sh codex/refill-flow
#   Pillie/scripts/create-worktree.sh codex/refill-flow /Users/idrisskone/Developer/Pillie-refill-flow

set -euo pipefail

usage() {
  sed -n '2,6p' "$0" | sed 's/^# //'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 64
fi

BRANCH="$1"
ROOT="$(git rev-parse --show-toplevel)"
PARENT="$(dirname "$ROOT")"

safe_name() {
  printf "%s" "$1" | tr -cs '[:alnum:]_.-' '-' | sed 's#^codex-##; s#^-##; s#-$##'
}

SAFE_BRANCH="$(safe_name "${BRANCH//\//-}")"
WORKTREE_PATH="${2:-$PARENT/Pillie-$SAFE_BRANCH}"
WORKTREE_NAME="$(basename "$WORKTREE_PATH")"
DERIVED_DATA="/tmp/PillieDerivedData-$(safe_name "$WORKTREE_NAME")"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git worktree add "$WORKTREE_PATH" "$BRANCH"
else
  git worktree add -b "$BRANCH" "$WORKTREE_PATH"
fi

cat <<EOF

Created worktree:
  $WORKTREE_PATH

DerivedData for this worktree:
  $DERIVED_DATA

Build, install, and launch:
  cd "$WORKTREE_PATH" && PILLIE_DERIVED_DATA="$DERIVED_DATA" Pillie/scripts/build-and-run.sh

Open in Xcode 27:
  cd "$WORKTREE_PATH" && Pillie/scripts/open-xcode.sh
EOF
