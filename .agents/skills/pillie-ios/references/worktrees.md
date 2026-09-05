# Worktrees

Treat `/Users/idrisskone/Developer/Pillie` as the orchestration checkout. For implementation, bug fix, UI, QA, refactor, or build/test work that needs file edits, create or enter a feature worktree first. Continue edits, builds, installs, screenshots, and commits from that worktree.

Edit the orchestration checkout directly only for `AGENTS.md`, `.agents/skills`, `opencode.json`, or worktree helper scripts, unless the user asks to work on `main`.

The simulator install is shared by bundle ID `com.idrisskone.pillie`. Running one worktree replaces the app installed from another unless you use a different simulator.

## Create

From the orchestration checkout:

```bash
make worktree BRANCH=codex/<short-task-slug>    # Codex
make worktree BRANCH=feature/<short-task-slug>  # opencode / Cursor
```

Or `Pillie/scripts/create-worktree.sh <branch>`. The helper creates or reuses the branch, makes a sibling `/Users/idrisskone/Developer/Pillie-<slug>` worktree, and prints the `/tmp/PillieDerivedData-<worktree>` path. Use a specific branch name when the user requests one.

Build scripts pick DerivedData from the checkout: `/tmp/PillieDerivedData` on main, `/tmp/PillieDerivedData-<folder>` on siblings, `/tmp/PillieDerivedData-codex-*` and `/tmp/PillieDerivedData-claude-*` for those harness worktrees. Override with `PILLIE_DERIVED_DATA`.

## Harness branches

- **Codex.** Use **Create worktree** and the `Pillie iOS` local environment when starting from the Codex app. That exposes Build/Run in the thread UI. Branch prefix `codex/<slug>`.
- **opencode.** No Create-worktree app action and no in-app simulator mirror. Use the helper with `feature/<slug>`. Visual QA is screenshot + AXe only. Session defaults live in `opencode.json`; overlay in `.opencode/instructions/opencode.md`.
- **Claude Code.** `EnterWorktree` creates `Pillie/.claude/worktrees/<name>` (base ref from `worktree.baseRef`). The helper script also works and creates a sibling folder. Scripts map Claude worktrees to `/tmp/PillieDerivedData-claude-<name>`.
- **Cursor.** Same helper as opencode: `make worktree BRANCH=feature/<slug>`, then work in the sibling checkout.
