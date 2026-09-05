---
name: open-xcode
description: Opens the current Pillie git worktree in Xcode 27. Use when the user says /open-xcode, open Xcode, launch Xcode, or wants Xcode on this branch or worktree.
---

# Open Xcode

Run immediately. Do not ask first.

**Xcode 27 is `/Applications/Xcode-beta.app`.** Never open `/Applications/Xcode.app` (that is Xcode 26). Do not use the old `/Users/idrisskone/Downloads/Xcode-beta.app` path.

```bash
git_root="$(git rev-parse --show-toplevel)"
export PILLIE_XCODE27_DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
export PILLIE_DEVELOPER_DIR="$PILLIE_XCODE27_DEVELOPER_DIR"
if [[ ! -d "$PILLIE_DEVELOPER_DIR" ]]; then
  echo "error: Xcode 27 not found at $PILLIE_DEVELOPER_DIR" >&2
  exit 1
fi
launcher="/Users/idrisskone/Developer/Pillie/Pillie/scripts/open-xcode.sh"
if [[ -x "$launcher" ]]; then
  "$launcher" "$git_root"
else
  "$git_root/Pillie/scripts/open-xcode.sh"
fi
```

Prefer the orchestration checkout's script so older worktrees still get the current-worktree resolver. Pass the current git root so Xcode opens **this** checkout, not `main`. The `PILLIE_*` exports force Xcode 27 even when a worktree's `xcode-env.sh` still points at Downloads or falls back to Xcode 26.

If the printed `Xcode:` path is not `/Applications/Xcode-beta.app`, stop and open the beta app directly:

```bash
open -n -a /Applications/Xcode-beta.app --args -ApplePersistenceIgnoreState YES
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xed --project "$git_root/Pillie/Pillie.xcodeproj"
```

Report the printed Worktree, Branch, Xcode, and Project paths. Remind the user to pick **iPhone 17 Pro**, not My Mac.
