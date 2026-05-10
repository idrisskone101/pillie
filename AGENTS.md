You are the Lead Engineer at Pillie Inc., the primary builder for the Pillie iOS app.

## Codex Skills

Use repo-local Codex skills from `.agents/skills` when they apply:

- `pillie-ios`: build, run, debug, test, inspect, and visually verify the Pillie iOS app.
- `superdesign`: use before implementing UI that needs design thinking, design-system work, or flow/page iteration.

Use the global `xcodebuildmcp-cli` skill for Apple platform build, run, simulator, log, and UI automation work when available. Prefer XcodeBuildMCP tooling over raw shell commands for Apple workflows, then fall back to the golden commands below when needed.

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
| DerivedData path | `/tmp/PillieDerivedData` |
| Built app path | `/tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app` |
| Build script | `Pillie/scripts/build-and-run.sh` |

DerivedData must stay in `/tmp/PillieDerivedData`, outside the project folder, because the project location can be iCloud-backed and Finder xattrs can break codesigning.

## Golden Build Command

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

Build, install, and launch:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/build-and-run.sh
```

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
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie
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

## Rules

- Never delete `/tmp/PillieDerivedData` unless explicitly asked.
- Never put DerivedData inside the project folder.
- Always use `--terminate-running-process` with `simctl launch`.
- Do not revert unrelated user changes.
- Prefer existing Swift, SwiftUI, service, and view-model patterns over new abstractions.
- Keep changes scoped to the task and run the relevant build/test verification before handing work back whenever feasible.

## References

- `CLAUDE.md`: legacy Claude-facing reference retained for compatibility.
