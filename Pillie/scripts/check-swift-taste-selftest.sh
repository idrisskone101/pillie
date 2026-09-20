#!/usr/bin/env bash
# Prove the Swift taste checker against pass/fail fixtures, then the app.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
checker="$root/Pillie/scripts/check-swift-taste.py"
fixtures="$root/Pillie/scripts/swift-taste-fixtures"
failed=0

expect_fail() {
  local dir="$1"
  local rule="$2"
  local out status
  set +e
  out="$(python3 "$checker" --no-allowlist --root "$dir" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    printf 'fail: expected %s to fail (%s)\n%s\n' "$dir" "$rule" "$out"
    failed=1
    return
  fi
  if ! grep -q "$rule" <<<"$out"; then
    printf 'fail: %s failed without %s\n%s\n' "$dir" "$rule" "$out"
    failed=1
    return
  fi
  printf 'ok: fail fixture %s (%s)\n' "$(basename "$dir")" "$rule"
}

expect_pass() {
  local dir="$1"
  local out status
  set +e
  out="$(python3 "$checker" --no-allowlist --root "$dir" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    printf 'fail: expected %s to pass\n%s\n' "$dir" "$out"
    failed=1
    return
  fi
  if grep -Eq '^(NEW|swift-taste:)' <<<"$out"; then
    printf 'fail: %s passed but printed findings\n%s\n' "$dir" "$out"
    failed=1
    return
  fi
  printf 'ok: pass fixture %s\n' "$(basename "$dir")"
}

if [[ ! -d "$fixtures" ]]; then
  echo "error: missing fixtures at $fixtures" >&2
  exit 2
fi

shopt -s nullglob
for dir in "$fixtures"/fail-*; do
  rule="${dir##*/fail-}"
  expect_fail "$dir" "$rule"
done
for dir in "$fixtures"/pass-*; do
  expect_pass "$dir"
done
shopt -u nullglob

allow_tmp="$(mktemp)"
trap 'rm -f "$allow_tmp"' EXIT
python3 "$checker" --root "$fixtures/fail-empty-catch" --write-allowlist --allowlist "$allow_tmp" >/dev/null
set +e
allow_out="$(python3 "$checker" --root "$fixtures/fail-empty-catch" --allowlist "$allow_tmp" 2>&1)"
allow_status=$?
set -e
if [[ "$allow_status" -ne 0 ]]; then
  printf 'fail: allowlisted empty-catch fixture should pass\n%s\n' "$allow_out"
  failed=1
else
  printf 'ok: allowlist covers existing empty-catch\n'
fi
printf 'empty-catch\tghost.swift\tL1\n' >> "$allow_tmp"
set +e
stale_out="$(python3 "$checker" --root "$fixtures/fail-empty-catch" --allowlist "$allow_tmp" 2>&1)"
stale_status=$?
set -e
if [[ "$stale_status" -eq 0 ]] || ! grep -q STALE <<<"$stale_out"; then
  printf 'fail: expected stale allowlist to fail\n%s\n' "$stale_out"
  failed=1
else
  printf 'ok: stale allowlist fails\n'
fi

set +e
app_out="$(python3 "$checker" --allowlist "$root/Pillie/scripts/swift-taste-allowlist.txt" 2>&1)"
app_status=$?
set -e
if [[ "$app_status" -ne 0 ]]; then
  printf 'fail: app sources should be clean or allowlisted\n%s\n' "$app_out"
  failed=1
else
  printf 'ok: app sources\n%s\n' "$app_out"
fi

if [[ "$failed" -ne 0 ]]; then
  echo "swift-taste selftest: FAILED"
  exit 1
fi
echo "ok: swift-taste selftest"
