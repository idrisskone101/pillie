---
name: pillie-ios
description: "Use for Pillie iOS app work: building, running, debugging, simulator automation, console logging, screenshots, visual QA, Swift/SwiftUI feature work, and bug fixes in /Users/idrisskone/Developer/Pillie."
---

# Pillie iOS

Use this skill whenever the task touches the Pillie iOS app, Xcode project, simulator, SwiftUI views, app services, build failures, runtime logs, screenshots, or visual QA.

## Project Facts

- Repo: `/Users/idrisskone/Developer/Pillie`
- Xcode project: `Pillie/Pillie.xcodeproj`
- Scheme: `Pillie`
- Bundle ID: `com.idrisskone.pillie`
- Simulator UDID: `124DC75F-0771-4C81-841D-F13655138260` (iPhone 17 Pro, iOS 26.2)
- DerivedData: `/tmp/PillieDerivedData` in the main checkout; `/tmp/PillieDerivedData-<worktree>` in feature worktrees
- Built app: `<DerivedData>/Build/Products/Debug-iphonesimulator/Pillie.app`
- MCP build script: `Pillie/scripts/mcp-build-and-run.sh`
- Shell build script: `Pillie/scripts/build-and-run.sh`
- MCP focused test script: `Pillie/scripts/mcp-test-focused.sh`
- Simulator browser script: `Pillie/scripts/serve-simulator-browser.sh`
- Simulator AX/browser mapper: `Pillie/scripts/simulator-browser-ax-map.mjs`
- Worktree helper: `Pillie/scripts/create-worktree.sh`
- Codex environment: `.codex/environments/environment.toml` (`Pillie iOS`)

Keep DerivedData in `/tmp`. The project folder can be iCloud-backed, and project-local DerivedData can break codesigning because of Finder xattrs.

## Git Worktrees

Use Git worktrees for parallel feature work. Codex-created feature worktrees should use branch names like `codex/<feature-name>` and sibling paths like `/Users/idrisskone/Developer/Pillie-<feature-name>`.

When starting a new task from the Codex app, use **Create worktree** and select the `Pillie iOS` local environment. The environment setup runs automatically, exposes the Build/Run actions in the thread UI, and lets `build-and-run.sh` choose the right `/tmp/PillieDerivedData-*` path for the Codex-managed worktree.

Default Codex task rule:

- Treat `/Users/idrisskone/Developer/Pillie` as the orchestration checkout.
- For every new implementation, bug fix, UI change, QA fix, refactor, or build/test task that needs file edits, create or enter a feature worktree before changing app code.
- Name Codex task branches `codex/<short-task-slug>` unless the user requests a specific branch.
- Use sibling paths like `/Users/idrisskone/Developer/Pillie-<short-task-slug>`.
- If the current working directory is the main checkout and no task worktree exists yet, run the helper below first, then continue all edits, builds, simulator installs, screenshots, and commits from that worktree.
- Only edit the main checkout directly for repo-level workflow files such as `AGENTS.md`, `.agents/skills`, or worktree helper scripts, unless the user explicitly asks to work on `main`.

Create a feature worktree with:

```bash
cd /Users/idrisskone/Developer/Pillie
Pillie/scripts/create-worktree.sh codex/<feature-name>
```

The helper creates or reuses the branch, creates the sibling worktree, and prints the matching `/tmp/PillieDerivedData-<worktree>` build path. Use the helper by default for new Codex worktrees.

The MCP and shell build scripts auto-select `/tmp/PillieDerivedData` for the main checkout and `/tmp/PillieDerivedData-<worktree-folder>` for sibling worktrees. Override it explicitly when needed:

```bash
PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-refill Pillie/scripts/mcp-build-and-run.sh
```

The simulator install is shared by bundle ID (`com.idrisskone.pillie`). Running one worktree replaces the app installed from another worktree unless using different simulators or bundle IDs.

## Tool Preference

Prefer XcodeBuildMCP/Xcode tooling when available. Use the repo-local MCP wrapper scripts first because they preserve Pillie's pinned simulator and `/tmp` DerivedData rules across Codex sessions. If MCP tooling is unavailable or insufficient, use the shell fallback commands below.

During the Xcode 27 transition, the MCP wrappers auto-select `/Users/idrisskone/Downloads/Xcode-beta.app/Contents/Developer` when the globally selected Xcode is older. Override that with `PILLIE_DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer` when needed.

For simulator UI verification, prefer MCP UI automation with accessibility identifiers and labels. Use AXe as the precision/fallback layer when MCP is missing a gesture, when the accessibility tree is the source of truth, when Codex Browser simulator annotations drift, or when coordinate mapping through the browser mirror is needed. Coordinate taps are acceptable after taking a 1x screenshot and verifying point coordinates.

Hosted XCTest is expensive regardless of whether it is invoked through MCP or raw `xcodebuild`: `PillieTests` loads inside `Pillie.app` on the simulator. Prefer compile/build proof plus simulator UI proof when app-hosted XCTest is unstable, and reserve hosted tests for explicit focused classes or methods.

## Build

Golden build command:

```bash
cd /Users/idrisskone/Developer/Pillie/Pillie && xcodebuild \
  -project Pillie.xcodeproj \
  -scheme Pillie \
  -sdk iphonesimulator \
  -destination "id=124DC75F-0771-4C81-841D-F13655138260" \
  -derivedDataPath /tmp/PillieDerivedData \
  -configuration Debug \
  build 2>&1 | xcsift
```

MCP build, install, and launch in one step:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/mcp-build-and-run.sh
```

Shell fallback build, install, and launch in one step:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/build-and-run.sh
```

`build-and-run.sh` launches headlessly by default so the command returns after `simctl` prints the app PID. Do not use blocking console launch for routine build/run verification; opt into it only when console output is the thing being inspected.

Mirror the simulator into Codex Browser:

```bash
cd /Users/idrisskone/Developer/Pillie
Pillie/scripts/serve-simulator-browser.sh
```

Open the localhost URL printed by `serve-sim` in the Codex in-app browser. Keep this command running while using the mirror. The script boots the pinned simulator if needed, kills only stale `serve-sim` helpers for that simulator UDID, and cleans up the helper when the terminal exits. Build/run the app separately when app code changed.

When Codex Browser annotations drift on the simulator mirror, treat the accessibility tree as canonical. The app is rendered through a streamed canvas, so SwiftUI controls are not regular DOM elements. Use the AX/browser mapper to print simulator-point frames and browser-mapped frames:

```bash
Pillie/scripts/simulator-browser-ax-map.mjs --filter "Upgrade" --frame 326,121.8,525,1141.4
```

The `--frame` argument is the simulator mirror frame from `getBoundingClientRect()` in `left,top,width,height` form. Omit it for simulator-point frames only, or use `--json` for structured output.

Run focused tests only through MCP:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests
```

Shell fallback focused tests:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/test-focused.sh SoftPaywallContentTests
```

Pass one or more explicit XCTest classes or methods. The helper uses the same simulator and `/tmp` DerivedData selection as `build-and-run.sh`, and intentionally requires at least one test target to avoid accidental full-suite local runs.

Manual install and launch:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
xcrun simctl install "$UDID" /tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app
xcrun simctl launch --terminate-running-process "$UDID" com.idrisskone.pillie
```

Always use `--terminate-running-process` when launching to avoid a silent no-launch.

## Logging

Short blocking console:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
Pillie/scripts/build-and-run.sh --run-only --console
```

Larger console capture:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie > /tmp/pillie_console.log 2>&1
```

OSLog stream filtered to the app subsystem:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
xcrun simctl spawn "$UDID" log stream \
  --predicate 'subsystem == "com.idrisskone.pillie"' \
  --level debug
```

## Simulator Automation

Installed local tools:

- `axe`: accessibility-based tap, swipe, type, and UI tree inspection
- `idb`: AXe dependency
- `magick`: ImageMagick screenshot downscaling
- `ffmpeg`: optional video recording

Find the booted simulator UDID when needed:

```bash
xcrun simctl list devices booted
```

Dump UI hierarchy:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
axe describe-ui --udid "$UDID"
```

Tap:

```bash
axe tap --id "startButton" --udid "$UDID"
axe tap --label "Start" --udid "$UDID"
axe tap -x 200 -y 400 --udid "$UDID"
```

Type:

```bash
axe type "hello world" --udid "$UDID"
```

Scroll and edge gestures:

```bash
axe gesture scroll-down --udid "$UDID"
axe gesture scroll-up --udid "$UDID"
axe gesture swipe-from-left-edge --udid "$UDID"
```

AXe scroll gestures are content-direction commands: `scroll-down` reveals content below the fold, and `scroll-up` reveals content above.

## Screenshots

Simulators render at 2x or 3x, while SwiftUI coordinates are points. Downscale screenshots to 1x before using coordinates.

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
xcrun simctl io "$UDID" screenshot /tmp/sim_screenshot.png
magick /tmp/sim_screenshot.png -resize 33.33% /tmp/sim_screenshot_1x.png
```

Use 50% instead of 33.33% for 2x simulators. Inspect the resulting 1x image before coordinate-based taps.

## Visual QA Loop

1. Build and run the app.
2. Inspect the accessibility tree with `axe describe-ui`.
3. Take a screenshot, downscale to 1x, and inspect it.
4. Navigate with accessibility identifiers, labels, or verified coordinates.
5. Take another screenshot to confirm the result.
6. Repeat until the behavior and UI are verified.

## Guardrails

- Do not delete `/tmp/PillieDerivedData` or `/tmp/PillieDerivedData-*` unless explicitly asked. Incremental builds matter.
- Do not put DerivedData inside the project folder.
- Keep simulator launches headless for normal build/run work. `simctl launch --console` and `build-and-run.sh --console` are blocking and should only be used for intentional console capture.
- Do not revert user changes or unrelated generated Xcode state.
- Prefer minimal, local changes that keep the app shippable.
- Run the golden build or a narrower relevant verification before handing work back whenever feasible.
