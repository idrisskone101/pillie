---
name: pillie-ios
description: Pillie iOS loop — worktree, make diagnose/build/run/test, simulator visual QA. Use when building, running, debugging, testing, screenshotting, logging, or editing the Pillie iOS app.
---

# Pillie iOS

The agent API is the repo-root Makefile. It wraps `Pillie/scripts`, `/tmp` DerivedData, and an iPhone 17 Pro: the laptop pin if that UDID exists, otherwise a local device (Namespace / Cloud Agent Macs). Prefer `make` over raw `xcodebuild`. If `xcodebuildmcp` is on PATH, build and test use the MCP wrappers; otherwise the shell scripts. `xcsift` is optional.

`make diagnose` prints paths, UDID, DerivedData, and toolchain. `make help` lists targets. Script `--help` is the flag source of truth.

## Linux Cloud Agents

If `uname` is Linux, do not run `xcodebuild` or `simctl` on this VM. Load `verify-pillie` and `namespace-mac`. Build with `make ns-mac-qa`, then drive with `make ns-mac-flow FLOW=…`. Potato / `/poteto-mode` uses the same skill. Do not `make ns-mac-stop` unless the user asked. The Cloud Agent stays on Linux; `pillie-ios` is the only Namespace Mac. Do not use Idriss's MacBook, the `devbox` CLI, `nsc ssh`, or Expire.

## Loop

1. **Worktree.** App edits go in a feature worktree, not the orchestration checkout `/Users/idrisskone/Developer/Pillie`. See [worktrees.md](references/worktrees.md).
   Done when: cwd is that worktree, or the user asked to work on `main`.
2. **Diagnose** if the toolchain or simulator is unclear: `make diagnose`.
   Done when: Xcode 27 is selected and an iPhone 17 Pro UDID is listed.
3. **Build / run.** `make build` to compile. `make build-and-run` to install and launch headlessly. `make run` if the app is already built.
   Done when: the build succeeded and `simctl` printed the app PID.
4. **Verify.** Load `verify-pillie`. UI: [visual-qa.md](references/visual-qa.md). Named tests: `make test TESTS=ClassName`. Skip hosted XCTest when `make qa` (or `make ns-mac-qa` on Linux) is enough.
   Done when: the 1x screenshot shows the change and the axe dump contains the expected labels.

Hand work back after step 4. Logs: [logging.md](references/logging.md). Shipping a build: [versioning.md](references/versioning.md). Open this worktree in Xcode 27 with the `open-xcode` skill.

## Targets

- `make diagnose`
- `make build`
- `make run`
- `make build-and-run`
- `make test TESTS=ClassName`
- `make screenshot`
- `make qa` — ensure axe/magick, boot, build-and-run, wait, 1x PNG, axe dump
- `make flow FLOW=today-home` — run a `verify-pillie` flow (shots, outlines, report.json)
- `make ensure-qa-tools` — install axe and ImageMagick if they are missing
- `make console`
- `make worktree BRANCH=codex/<slug>`
- `make agent-verify` — build; also test if `TESTS` is set

`make test` without `TESTS` is refused. Launch is already headless; there is no `clean` target — leave `/tmp/PillieDerivedData*`.

## Copy

A copy change is not done until every `AppLanguage` catalog has the new wording. Update `Commerce.xcstrings` / `Localizable.xcstrings` / `Notifications.xcstrings` plus `locked-copy.json` (`en`/`de`/`it`) and `honest-paywall-locales.json` when those files own the key. Run `python3 Pillie/scripts/copy-rewrite/check-translated-copy.py`. See `AGENTS.md` (§ Copy and locales).

## Invariants

Keep DerivedData in `/tmp` (iCloud xattrs break codesign). One booted simulator (the wrappers shut extras down). Headless launch with `--terminate-running-process` (the scripts already do this). Destination in Xcode.app is iPhone 17 Pro, not My Mac. Prefer existing Swift/SwiftUI patterns; scope the diff to the task.
