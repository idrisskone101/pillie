---
name: pillie-ios
description: Pillie iOS loop — worktree, make diagnose/build/run/test, simulator visual QA. Use when building, running, debugging, testing, screenshotting, logging, or editing the Pillie iOS app.
---

# Pillie iOS

The agent API is the repo-root Makefile. It wraps `Pillie/scripts` and keeps the pinned simulator plus `/tmp` DerivedData. Prefer `make` over raw `xcodebuild`. If `xcodebuildmcp` is on PATH, build and test use the MCP wrappers; otherwise the shell scripts.

`make diagnose` prints paths, UDID, DerivedData, and toolchain. `make help` lists targets. Script `--help` is the flag source of truth.

## Loop

1. **Worktree.** App edits go in a feature worktree, not the orchestration checkout `/Users/idrisskone/Developer/Pillie`. See [worktrees.md](references/worktrees.md).
   Done when: cwd is that worktree, or the user asked to work on `main`.
2. **Diagnose** if the toolchain or simulator is unclear: `make diagnose`.
   Done when: Xcode 27 is selected and the pinned simulator is listed.
3. **Build / run.** `make build` to compile. `make build-and-run` to install and launch headlessly. `make run` if the app is already built.
   Done when: the build succeeded and `simctl` printed the app PID.
4. **Verify.** UI: [visual-qa.md](references/visual-qa.md). Named tests: `make test TESTS=ClassName`. Skip hosted XCTest when compile + simulator UI proof is enough.
   Done when: the 1x screenshot shows the change, or the named tests passed.

Hand work back after step 4. Logs: [logging.md](references/logging.md). Shipping a build: [versioning.md](references/versioning.md). Open this worktree in Xcode 27 with the `open-xcode` skill.

## Targets

- `make diagnose`
- `make build`
- `make run`
- `make build-and-run`
- `make test TESTS=ClassName`
- `make screenshot`
- `make console`
- `make worktree BRANCH=codex/<slug>`
- `make agent-verify` — build; also test if `TESTS` is set

`make test` without `TESTS` is refused. Launch is already headless; there is no `clean` target — leave `/tmp/PillieDerivedData*`.

## Invariants

Keep DerivedData in `/tmp` (iCloud xattrs break codesign). One booted simulator (the wrappers shut extras down). Headless launch with `--terminate-running-process` (the scripts already do this). Destination in Xcode.app is iPhone 17 Pro, not My Mac. Prefer existing Swift/SwiftUI patterns; scope the diff to the task.
