#!/usr/bin/env bash
# Run the Swift taste checker against app sources (allowlist on).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/Pillie/scripts/check-swift-taste.py" "$@"
