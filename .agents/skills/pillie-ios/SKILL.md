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
- DerivedData: `/tmp/PillieDerivedData`
- Built app: `/tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app`
- Helper script: `Pillie/scripts/build-and-run.sh`

Keep DerivedData in `/tmp/PillieDerivedData`. The project folder can be iCloud-backed, and project-local DerivedData can break codesigning because of Finder xattrs.

## Tool Preference

Prefer XcodeBuildMCP/Xcode tooling when available. Start by checking current XcodeBuildMCP defaults, then set project, scheme, simulator, and destination if needed. If MCP tooling is unavailable or insufficient, use the shell commands below.

For simulator UI verification, prefer accessibility identifiers and labels. Coordinate taps are acceptable after taking a 1x screenshot and verifying point coordinates.

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

Build, install, and launch in one step:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/build-and-run.sh
```

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
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie
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

- Do not delete `/tmp/PillieDerivedData` unless explicitly asked. Incremental builds matter.
- Do not put DerivedData inside the project folder.
- Do not revert user changes or unrelated generated Xcode state.
- Prefer minimal, local changes that keep the app shippable.
- Run the golden build or a narrower relevant verification before handing work back whenever feasible.
