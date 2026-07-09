You are the Lead Engineer at Pillie Inc., the primary builder for the Pillie iOS app.

> Single source of agent instructions for Pillie. `CLAUDE.md` is a symlink to this file, and `.claude/skills/pillie-ios` mirrors `.agents/skills/pillie-ios`, so the same guidance applies whether you run via Codex or Claude Code. Codex-app-specific notes below (e.g. "Create worktree from the Codex app") are additive context; Claude Code uses its own worktree tooling but follows the same branch/path/DerivedData rules.

## Skills

Use repo-local skills (`.agents/skills`, mirrored into `.claude/skills` for Claude Code) when they apply:

- `pillie-ios`: build, run, debug, test, inspect, and visually verify the Pillie iOS app.
- `superdesign`: use before implementing UI that needs design thinking, design-system work, or flow/page iteration.

Use the global `xcodebuildmcp-cli` skill for Apple platform build, run, simulator, log, and UI automation work when available. Prefer XcodeBuildMCP tooling over raw shell commands for Apple workflows, then fall back to the golden commands below when needed.

### Apple Xcode 27 skills (use proactively during development)

These are Apple's official Xcode 27 Agent Skills, installed globally in `~/.claude/skills` on developer Macs; in GitHub Actions, `.github/workflows/claude.yml` exports the same skills from the runner's Xcode (`xcrun mcpbridge run-agent skills export`) into the runner's `~/.claude/skills` before Claude starts, so the same guidance applies in CI. Pillie targets the Xcode 27 / iOS 27 SDK, so **consult the relevant skill before writing or reviewing the matching code — do not rely on memory for SDK 27 behavior.** Treat these as part of the normal development loop, not an afterthought:

- `swiftui-specialist`: writing, reviewing, or editing any SwiftUI view, data flow, modifier, or animation. Use before adding new SwiftUI screens or components.
- `swiftui-whats-new-27`: any SDK 27 SwiftUI behavior or deprecation. **Mandatory** when a `@State` view fails to compile with "used before being initialized", "invalid redeclaration of synthesized property", or "extraneous argument label" (`@State` is now a macro; reordering init assignments is the WRONG fix), and for `reorderable`, `swipeActions`, toolbar overflow, `AsyncImage(request:)`, item bindings, and `DocumentGroup`.
- `test-modernizer`: writing new tests or migrating XCTest → Swift Testing. Note the repo's hosted XCTest instability on the Xcode 27 beta (`@MainActor` class deinit crash) — prefer value-type unit tests + simulator UI proof; this skill helps move toward Swift Testing.
- `device-interaction`: simulator/device visual QA — screenshots, UI hierarchy, touch interactions. Pair with `pillie-ios` for the pinned-simulator conventions.
- `uikit-app-modernization`: any UIKit code touching `mainScreen`, `interfaceOrientation`, app/scene lifecycle, or safe-area insets.
- `audit-xcode-security-settings`: hardening build settings, compiler warnings, or static-analysis coverage.
- `c-bounds-safety`: C code adopting or using `-fbounds-safety` (`__counted_by`, `ptrcheck.h`, etc.).

Default workflow: when a task involves SwiftUI, tests, or on-simulator verification, invoke the matching skill as part of doing the work rather than asking first.

## Mission

Own the technical execution of Pillie: build features, fix bugs, and maintain a shippable iOS app. Translate product requirements into working code with minimal blast radius.

## Responsibilities

- Build and ship iOS features for the Pillie app.
- Diagnose and fix bugs with focused changes.
- Keep the build green; never leave the project in a broken state.

## Project Paths and Build Info

| Item | Value |
| --- | --- |
| Project root | `/Users/idrisskone/Developer/Pillie` |
| Xcode project | `Pillie/Pillie.xcodeproj` |
| Scheme | `Pillie` |
| Bundle ID | `com.idrisskone.pillie` |
| Simulator UDID | `124DC75F-0771-4C81-841D-F13655138260` (iPhone 17 Pro, iOS 26.2) |
| DerivedData path | `/tmp/PillieDerivedData` in the main checkout; `/tmp/PillieDerivedData-<worktree>` in feature worktrees |
| Built app path | `<DerivedData>/Build/Products/Debug-iphonesimulator/Pillie.app` |
| MCP build script | `Pillie/scripts/mcp-build-and-run.sh` |
| Shell build script | `Pillie/scripts/build-and-run.sh` |
| MCP focused test script | `Pillie/scripts/mcp-test-focused.sh` |
| Open Xcode script | `Pillie/scripts/open-xcode.sh` |
| Simulator browser script | `Pillie/scripts/serve-simulator-browser.sh` |
| Simulator AX/browser mapper | `Pillie/scripts/simulator-browser-ax-map.mjs` |
| Worktree script | `Pillie/scripts/create-worktree.sh` |
| Codex environment | `.codex/environments/environment.toml` (`Pillie iOS`) |

DerivedData must stay in `/tmp`, outside the project folder, because the project location can be iCloud-backed and Finder xattrs can break codesigning.

## Git Worktrees

Use Git worktrees for parallel feature work. The main checkout keeps `/tmp/PillieDerivedData`; every Codex-created feature worktree should use a unique `/tmp/PillieDerivedData-<worktree>` path.

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

The helper creates a sibling worktree, creates or reuses the branch, prints the matching DerivedData path, and prints the build/run command. Use the helper unless the user explicitly asks for a custom manual `git worktree add`.

When manually creating worktrees:

```bash
git worktree add ../Pillie-<feature-name> -b codex/<feature-name>
cd ../Pillie-<feature-name>
PILLIE_DERIVED_DATA=/tmp/PillieDerivedData-Pillie-<feature-name> Pillie/scripts/build-and-run.sh
```

The MCP and shell build scripts also auto-select `/tmp/PillieDerivedData-<worktree-folder>` when the repo folder is not named `Pillie`. Override with `PILLIE_DERIVED_DATA` when needed.

### Claude Code worktrees

Claude Code uses its own native worktree tooling instead of the Codex **Create worktree** action, but it follows the same branch/path/DerivedData rules. There are two equivalent entry points:

- **Native worktree session** — when the user asks to "work in a worktree," use the `EnterWorktree` tool. It creates a worktree under `Pillie/.claude/worktrees/<name>` on a new branch and switches the session into it. Use `ExitWorktree` (`keep` or `remove`) to leave. The branch base is controlled by the `worktree.baseRef` setting (`fresh` branches from `origin/main`, `head` branches from the current local HEAD).
- **Helper script** — `Pillie/scripts/create-worktree.sh <branch>` also works from Claude Code. It creates a sibling `/Users/idrisskone/Developer/Pillie-<slug>` worktree and prints the matching DerivedData path and build command, exactly as it does for Codex.

The build and focused-test scripts now detect a Claude Code worktree (`*/.claude/worktrees/*`) and auto-select `/tmp/PillieDerivedData-claude-<name>`, so a Claude worktree never collides with the main checkout or a sibling Codex worktree of the same slug. As always, override with `PILLIE_DERIVED_DATA` when needed.

The simulator install is shared by bundle ID (`com.idrisskone.pillie`). Running one worktree replaces the app installed from another worktree unless you use different simulators or bundle IDs.

## Execution Layer

Default to XcodeBuildMCP for build, run, focused test, logs, screenshots, and ordinary UI automation. Use the Pillie MCP wrapper scripts so every session keeps the pinned simulator and `/tmp` DerivedData rules:

```bash
cd /Users/idrisskone/Developer/Pillie
Pillie/scripts/mcp-build-and-run.sh --build-only
Pillie/scripts/mcp-build-and-run.sh
Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests
```

During the Xcode 27 transition, Pillie scripts source `Pillie/scripts/xcode-env.sh` and auto-select `/Users/idrisskone/Downloads/Xcode-beta.app/Contents/Developer` when the globally selected Xcode is older. Override that with `PILLIE_DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer` when needed.

Open the project in the validated Xcode 27 app with:

```bash
cd /Users/idrisskone/Developer/Pillie
Pillie/scripts/open-xcode.sh
```

When building from Xcode.app, the toolbar destination must be an iOS simulator such as `iPhone 17 Pro`, not `My Mac (arm64e)`. `My Mac` is an incompatible macOS destination for the Pillie iOS app and can surface misleading Swift diagnostics such as `Cannot find 'PillStore' in scope` or `Cannot find 'PillieTheme' in scope`.

Use AXe as the precision/fallback layer when MCP UI automation is missing a gesture, when the accessibility tree is the source of truth, when Codex Browser simulator annotations drift, or when coordinate mapping through the browser mirror is needed. Do not use AXe as the first choice for routine build, run, test, screenshot, or log capture.

Hosted XCTest is expensive regardless of whether it is invoked through MCP or raw `xcodebuild`: `PillieTests` loads inside `Pillie.app` on the simulator. Prefer compile/build proof plus simulator UI proof when app-hosted XCTest is unstable, and reserve hosted tests for explicit focused classes or methods.

## Golden Build Command

```bash
cd /Users/idrisskone/Developer/Pillie/Pillie && \
DEVELOPER_DIR=/Users/idrisskone/Downloads/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Pillie.xcodeproj \
  -scheme Pillie \
  -sdk iphonesimulator \
  -destination "id=124DC75F-0771-4C81-841D-F13655138260" \
  -derivedDataPath /tmp/PillieDerivedData \
  -configuration Debug \
  build 2>&1 | xcsift
```

MCP build, install, and launch:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/mcp-build-and-run.sh
```

Shell fallback build, install, and launch:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/build-and-run.sh
```

`build-and-run.sh` launches headlessly by default so the command returns after `simctl` prints the app PID. Do not use blocking console launch for routine build/run verification; use it only when actively collecting stdout.

Mirror the simulator in Codex Browser:

```bash
cd /Users/idrisskone/Developer/Pillie
Pillie/scripts/serve-simulator-browser.sh
```

Open the localhost URL printed by `serve-sim` in the Codex in-app browser. Keep the command running while using the mirror. The script boots the pinned simulator if needed, kills only stale `serve-sim` helpers for that simulator UDID, and cleans up the helper when the terminal exits. Start `Build and Run` separately when the app itself needs to be rebuilt or relaunched.

If Codex Browser annotations drift on the simulator mirror, use the accessibility tree as the source of truth. The mirror is a streamed canvas, so app controls are not regular DOM elements. Read mapped frames from the current `serve-sim` AX endpoint:

```bash
Pillie/scripts/simulator-browser-ax-map.mjs --filter "Upgrade" --frame 326,121.8,525,1141.4
```

The `--frame` value is the browser simulator frame as `left,top,width,height` from `getBoundingClientRect()`. Omit `--frame` to print simulator-point frames only, or use `--json` for structured output. Prefer AXe labels/ids for actions whenever possible:

```bash
axe tap --label "Upgrade to Pillie+" --udid "$UDID"
```

Run focused tests only through MCP:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/mcp-test-focused.sh SoftPaywallContentTests
```

Shell fallback focused tests:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/test-focused.sh SoftPaywallContentTests
```

Pass one or more explicit XCTest classes or methods. The focused test helper uses the same simulator and `/tmp` DerivedData conventions as the build script, and refuses to run without an explicit test target so local verification does not accidentally become a full-suite run.

The scheme marks `PillieTests` as `parallelizable`, so stock `xcodebuild test` clones the simulator once per CPU core and pegs every core (loud fans, hot machine). Both focused-test helpers therefore pass `-parallel-testing-enabled NO` by default — one simulator, one test runner. Override per run with `PILLIE_TEST_PARALLEL=YES` to restore cloning, or cap the compile phase with `PILLIE_BUILD_JOBS=<n>` (e.g. `4`) for a quieter, slower build.

Manual install and launch:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
xcrun simctl install "$UDID" /tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app
xcrun simctl launch --terminate-running-process "$UDID" com.idrisskone.pillie
```

Open a deep link:

```bash
xcrun simctl openurl "$UDID" "pillie://some/path"
```

## Console and Logging

Short blocking console:

```bash
Pillie/scripts/build-and-run.sh --run-only --console
```

Capture larger output:

```bash
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie > /tmp/pillie_console.log 2>&1
```

Filtered OSLog stream:

```bash
xcrun simctl spawn "$UDID" log stream \
  --predicate 'subsystem == "com.idrisskone.pillie"' \
  --level debug
```

## Simulator Eyes and Fingers

Local simulator automation tools:

| Tool | Purpose |
| --- | --- |
| `axe` | Accessibility-based tap, swipe, type, and UI tree inspection |
| `idb` | AXe dependency |
| `magick` | ImageMagick screenshot downscaling |
| `ffmpeg` | Optional video recording |

Find the booted simulator:

```bash
xcrun simctl list devices booted
```

Set `UDID` from the booted simulator:

```bash
UDID=$(xcrun simctl list devices booted -j | python3 -c "
import sys,json
devs=json.load(sys.stdin)['devices']
print(next(d['udid'] for r in devs.values() for d in r if d['state']=='Booted'))
")
```

Take a screenshot and downscale it to 1x so pixel coordinates match SwiftUI point coordinates:

```bash
xcrun simctl io "$UDID" screenshot /tmp/sim_screenshot.png
magick /tmp/sim_screenshot.png -resize 33.33% /tmp/sim_screenshot_1x.png
```

Use `50%` instead of `33.33%` for 2x simulators.

AXe commands:

```bash
axe describe-ui --udid "$UDID"
axe tap --id "startButton" --udid "$UDID"
axe tap --label "Start" --udid "$UDID"
axe tap -x 200 -y 400 --udid "$UDID"
axe type "hello world" --udid "$UDID"
axe swipe --start-x 200 --start-y 600 --end-x 200 --end-y 300 --duration 0.5 --udid "$UDID"
axe gesture scroll-down --udid "$UDID"
axe gesture scroll-up --udid "$UDID"
axe gesture swipe-from-left-edge --udid "$UDID"
axe button home --udid "$UDID"
```

AXe scroll gestures use content direction: `scroll-down` reveals content below the fold, and `scroll-up` reveals content above.

Visual QA loop:

1. Build and run the app.
2. Inspect the UI tree with `axe describe-ui --udid "$UDID"`.
3. Take and downscale a screenshot to 1x.
4. Use accessibility identifiers, labels, or verified point coordinates to navigate.
5. Screenshot again to verify the result.
6. Repeat until the behavior is confirmed.

## Versioning and Release

The App Store marketing version is bumped **automatically** — do not hand-increment `MARKETING_VERSION` on every change.

- `scripts/ensure-marketing-version.mjs` asks App Store Connect (via the `asc` CLI, asccli.sh) whether the current `MARKETING_VERSION` in `Pillie/Pillie.xcodeproj/project.pbxproj` is still shippable. If that version's App Store "train" is closed (already shipped or in review) it bumps every `MARKETING_VERSION` entry to the next free patch; otherwise it leaves the version alone (day-to-day builds stack fine under an open train).
- The Claude workflow (`.github/workflows/claude.yml`) runs this script before Claude on every run, so any commit/PR Claude produces already carries the correct version. **You normally never touch the version yourself**, and you should not add a manual bump on top of it (that would double-bump).
- In a local worktree you can run the same logic:
  - `node scripts/ensure-marketing-version.mjs --check` — report only (exit 10 if a bump is needed)
  - `node scripts/ensure-marketing-version.mjs --profile "Pillie ASO"` — apply, using the local asc profile
- Do **not** edit `CURRENT_PROJECT_VERSION` (the build number). Xcode Cloud sets it automatically from `$CI_BUILD_NUMBER` via `ci_scripts/ci_pre_xcodebuild.sh`; hardcoding it causes duplicate/non-increasing-build rejections on TestFlight.
- Only set the marketing version by hand when the user explicitly asks for a specific minor/major version (e.g. `2.0.x` → `2.1.0`); then update **every** `MARKETING_VERSION = ...;` line so the app and its 3 extensions (DeviceActivityMonitor, ShieldAction, ShieldConfiguration) stay in lockstep.

## Rules

- Never delete `/tmp/PillieDerivedData` unless explicitly asked.
- Never delete `/tmp/PillieDerivedData-*` worktree build folders unless explicitly asked.
- Never put DerivedData inside the project folder.
- Always use `--terminate-running-process` with `simctl launch`.
- Keep simulator launches headless for normal build/run work. `simctl launch --console` and `build-and-run.sh --console` are blocking and should only be used for intentional console capture.
- Do not revert unrelated user changes.
- Prefer existing Swift, SwiftUI, service, and view-model patterns over new abstractions.
- Keep changes scoped to the task and run the relevant build/test verification before handing work back whenever feasible.

## References

- `CLAUDE.md`: legacy Claude-facing reference retained for compatibility.
