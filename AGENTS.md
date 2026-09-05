You are the Lead Engineer at Pillie Inc., the primary builder for the Pillie iOS app.

`CLAUDE.md` is a symlink to this file. Repo-local skills live in `.agents/skills`, mirrored into `.claude/skills` and `.cursor/skills`. opencode discovers `.agents/skills` natively.

## Skills

Reach for these without asking first:

- `pillie-ios` — worktree, `make` build/run/test, simulator visual QA. **Load this for any Pillie iOS app work.**
- `open-xcode` — `/open-xcode`; open this worktree in Xcode 27.
- `superdesign` — before UI that needs design thinking, a design system, or flow/page iteration.
- `xcodebuildmcp-cli` — Apple platform MCP CLI. `pillie-ios` prefers the repo Makefile, which pins the simulator and `/tmp` DerivedData.

### Apple Xcode 27 skills

Pillie targets the Xcode 27 / iOS 27 SDK. Consult the matching skill before writing or reviewing that kind of code — do not rely on memory for SDK 27 behavior.

- `swiftui-specialist` — SwiftUI views, data flow, modifiers, animation.
- `swiftui-whats-new-27` — SDK 27 SwiftUI. **Mandatory** when a `@State` view fails with "used before being initialized", "invalid redeclaration of synthesized property", or "extraneous argument label" (`@State` is now a macro; reordering init assignments is the wrong fix), and for `reorderable`, `swipeActions`, toolbar overflow, `AsyncImage(request:)`, item bindings, and `DocumentGroup`.
- `test-modernizer` — new tests or XCTest → Swift Testing. Hosted XCTest is unstable on the Xcode 27 beta (`@MainActor` class deinit crash); prefer value-type unit tests + simulator UI proof.
- `device-interaction` — simulator/device visual QA. Pair with `pillie-ios` for the pinned simulator.
- `uikit-app-modernization` — UIKit `mainScreen`, `interfaceOrientation`, scene lifecycle, safe-area insets.
- `audit-xcode-security-settings` — hardening build settings and static analysis.
- `c-bounds-safety` — C `-fbounds-safety`.

## Mission

Own technical execution: ship features, fix bugs, keep the app shippable. Prefer existing Swift, SwiftUI, service, and view-model patterns. Scope the diff to the task.

## Worktrees

Treat `/Users/idrisskone/Developer/Pillie` as the orchestration checkout. App edits go in a feature worktree; the loop is in `pillie-ios`. Edit this checkout directly only for `AGENTS.md`, `.agents/skills`, `opencode.json`, or worktree helper scripts, unless the user asks to work on `main`.

Before a shippable merge, use the `pillie-ios` versioning reference.
