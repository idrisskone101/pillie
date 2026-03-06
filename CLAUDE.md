# Pillie — Project Instructions

## Project Paths & Build Info

| Item                | Value                                                        |
|---------------------|--------------------------------------------------------------|
| Xcode project       | `Pillie/Pillie.xcodeproj`                                   |
| Scheme              | `Pillie`                                                     |
| Bundle ID           | `com.idrisskone.pillie`                                      |
| Simulator UDID      | `124DC75F-0771-4C81-841D-F13655138260` (iPhone 17 Pro, iOS 26.2) |
| DerivedData path    | `/tmp/PillieDerivedData` (outside project to avoid iCloud xattr issues) |
| Built app path      | `/tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app` |
| Build script        | `Pillie/scripts/build-and-run.sh`                            |

## Golden Build Command

```bash
cd Pillie && xcodebuild \
  -project Pillie.xcodeproj \
  -scheme Pillie \
  -sdk iphonesimulator \
  -destination "id=124DC75F-0771-4C81-841D-F13655138260" \
  -derivedDataPath /tmp/PillieDerivedData \
  -configuration Debug \
  build 2>&1 | xcsift
```

**Important:** DerivedData MUST be in `/tmp/PillieDerivedData` (not inside the project folder) because the Desktop folder is iCloud-backed and adds `com.apple.FinderInfo` xattrs that break codesigning.

### Build → Install → Launch (one-liner)

```bash
Pillie/scripts/build-and-run.sh
```

Or manually:

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
xcrun simctl install "$UDID" /tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app
xcrun simctl launch --terminate-running-process "$UDID" com.idrisskone.pillie
```

### Deep links (optional)

```bash
xcrun simctl openurl "$UDID" "pillie://some/path"
```

## Console & Logging

### Quick blocking console (for short-lived output)

```bash
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie
```

### Write to log file (for larger output)

```bash
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie > /tmp/pillie_console.log 2>&1
```

### Background monitoring with `run_in_background`

Use the Bash tool with `run_in_background: true` to start the `--console` launch, then periodically read `/tmp/pillie_console.log`.

### OSLog / Logger stream (background, filtered by subsystem)

```bash
xcrun simctl spawn "$UDID" log stream \
  --predicate 'subsystem == "com.idrisskone.pillie"' \
  --level debug
```

Run this in the background, then launch the app separately.

## Rules — NEVER Do These

- **NEVER delete `/tmp/PillieDerivedData`** — incremental builds are critical for speed. Only clean build when explicitly asked.
- **NEVER put DerivedData inside the project folder** — iCloud xattrs break codesigning.
- Always use `--terminate-running-process` with `simctl launch` to avoid silent no-launch.

## Simulator Eyes & Fingers (AXe + simctl)

### Prerequisites (all installed via Homebrew)

| Tool        | Purpose                        |
|-------------|--------------------------------|
| `axe`       | Accessibility-based tap/swipe/type on simulators |
| `idb`       | Meta-dependency of AXe         |
| `magick`    | ImageMagick — downscale screenshots to 1× |
| `ffmpeg`    | (Optional) video recording     |

### Getting the simulator UDID

```bash
# List booted simulators — grab the UDID from the output
xcrun simctl list devices booted
```

Store it in a variable for the session:
```bash
UDID=$(xcrun simctl list devices booted -j | python3 -c "
import sys,json
devs=json.load(sys.stdin)['devices']
print(next(d['udid'] for r in devs.values() for d in r if d['state']=='Booted'))
")
```

### Taking a screenshot + downscaling to 1×

Simulators render at 2× or 3× but SwiftUI coordinates are in **points** (1×).
Always downscale so pixel coordinates = point coordinates for AXe.

```bash
# 1. Capture screenshot (PNG, at device pixel scale)
xcrun simctl io "$UDID" screenshot /tmp/sim_screenshot.png

# 2. Downscale to 1× (divide dimensions by device scale factor)
#    iPhone 15/16 Pro = 3×, iPhone SE / older = 2×
magick /tmp/sim_screenshot.png -resize 33.33% /tmp/sim_screenshot_1x.png   # 3× device
# magick /tmp/sim_screenshot.png -resize 50% /tmp/sim_screenshot_1x.png    # 2× device
```

After downscaling, the image dimensions match the point coordinate system.
Read the resulting image to identify tap targets.

### AXe — Tap

```bash
# Tap by point coordinates (use 1× screenshot coords)
axe tap -x 200 -y 400 --udid "$UDID"

# Tap by accessibility identifier (preferred when available)
axe tap --id "startButton" --udid "$UDID"

# Tap by accessibility label
axe tap --label "Start" --udid "$UDID"
```

### AXe — Type text

```bash
axe type "hello world" --udid "$UDID"
```

### AXe — Swipe (manual coordinates)

```bash
# Swipe from (200,600) to (200,300) over 0.5s
axe swipe --start-x 200 --start-y 600 --end-x 200 --end-y 300 --duration 0.5 --udid "$UDID"
```

### AXe — Gesture presets (scroll & edge swipes)

```bash
axe gesture scroll-down --udid "$UDID"
axe gesture scroll-up --udid "$UDID"
axe gesture swipe-from-left-edge --udid "$UDID"   # back navigation
```

#### Scroll direction semantics (important!)

AXe gestures use **content direction**, not finger direction:

| Command             | Finger moves | Content moves | Use when you want to…       |
|---------------------|-------------|---------------|-----------------------------|
| `scroll-down`       | ↑ (up)      | ↓ (down)      | See content **below** the fold |
| `scroll-up`         | ↓ (down)    | ↑ (up)        | See content **above**        |
| `scroll-left`       | → (right)   | ← (left)      | See content to the **left**  |
| `scroll-right`      | ← (left)    | → (right)     | See content to the **right** |

**In short:** `scroll-down` = reveal more content below = finger drags upward.

### AXe — Describe UI hierarchy

```bash
# Dump the full accessibility tree (useful to find element IDs/labels)
axe describe-ui --udid "$UDID"
```

### AXe — Hardware buttons

```bash
axe button home --udid "$UDID"
```

### Recording video (optional, requires ffmpeg)

```bash
# Using AXe's built-in recorder
axe record-video --udid "$UDID" --output /tmp/sim_recording.mp4

# Or using simctl
xcrun simctl io "$UDID" recordVideo /tmp/sim_recording.mp4
# (Ctrl+C to stop)
```

### Workflow: Visual QA loop

1. Build & run the app on the simulator
2. `axe describe-ui --udid "$UDID"` — inspect accessibility tree
3. Take screenshot → downscale to 1× → read the image
4. Tap/swipe/type to navigate
5. Screenshot again to verify the result
6. Repeat as needed
