#!/usr/bin/env bash
# screen-tour.sh — screenshot every user-facing Pillie screen in one or more locales.
# Usage:
#   Pillie/scripts/copy-rewrite/screen-tour.sh <lang> [<lang> ...]
#   Pillie/scripts/copy-rewrite/screen-tour.sh all
#
# Renders screen-tour.flow.in once per AppLanguage code into screen-tour-<lang>.flow
# and runs them all in one `make ns-mac-flow` call. Shots land in
# .qa-artifacts/flows/screen-tour-<lang>/ at the repo root.
# Locales that fail get one retry. Runs whatever build is installed on the
# simulator; `make ns-mac-qa` first to refresh it.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
TEMPLATE="$HERE/screen-tour.flow.in"
LANGUAGE_SOURCE="$REPO_ROOT/Pillie/Pillie/Localization/AppLanguagePreference.swift"

(( $# > 0 )) || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }

known="$(sed -nE 's/^ *case [A-Za-z]+ = "([A-Za-z-]+)"$/\1/p' "$LANGUAGE_SOURCE")"
[[ -n "$known" ]] || { echo "error: no AppLanguage codes found in $LANGUAGE_SOURCE" >&2; exit 2; }

langs=()
for lang in "$@"; do
  if [[ "$lang" == all ]]; then
    mapfile -t -O "${#langs[@]}" langs <<<"$known"
  elif grep -qxF -- "$lang" <<<"$known"; then
    langs+=("$lang")
  else
    echo "error: '$lang' is not an AppLanguage code. Known: $(tr '\n' ' ' <<<"$known")" >&2
    exit 64
  fi
done

stage="$(mktemp -d "${TMPDIR:-/tmp}/screen-tour.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
flows=()
for lang in "${langs[@]}"; do
  sed "s/{{lang}}/$lang/g" "$TEMPLATE" >"$stage/screen-tour-$lang.flow"
  flows+=("$stage/screen-tour-$lang.flow")
done

export PILLIE_NS_ARTIFACT_DIR="$REPO_ROOT/.qa-artifacts"
make -C "$REPO_ROOT" ns-mac-flow FLOW="${flows[*]}" && exit 0

retry=()
for lang in "${langs[@]}"; do
  report="$PILLIE_NS_ARTIFACT_DIR/flows/screen-tour-$lang/report.json"
  python3 -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1]))["ok"] else 1)' "$report" 2>/dev/null ||
    retry+=("$stage/screen-tour-$lang.flow")
done
(( ${#retry[@]} > 0 )) || exit 1
echo "retrying ${#retry[@]} locale(s)" >&2
make -C "$REPO_ROOT" ns-mac-flow FLOW="${retry[*]}"
