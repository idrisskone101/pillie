---
name: verify-pillie
description: Prove Pillie iOS behavior on the real iPhone 17 Pro simulator with scripted flows, screenshots, accessibility dumps, and launch/frame timing. Use for /poteto-mode, poteto-mode, potato mode, poteto-agent, visual QA, "does this work", "check it on the simulator", screenshots, perf checks, or any time compile-only is not enough. Works from a Linux cloud agent (Namespace Mac over HTTPS) and on a Mac.
---

# Verify Pillie

This is poteto-mode's "verify on the matching surface" step for Pillie. `make build` is not done. Done is the user path driven on the simulator, with a screenshot and an accessibility dump that show the resulting state.

The surface is the iPhone 17 Pro simulator running the Debug build of `com.idrisskone.pillie`. A Linux agent drives the Namespace Mac `pillie-ios` through the same make targets; `namespace-mac` owns Activate, auth, and cost rules.

## The loop

1. **Build and install** the commit you want to prove.
   - Linux: commit, `git push -u origin HEAD`, then `make ns-mac-qa`.
   - Mac: `make qa`.
   Done when `pillie_qa.json` says `"ready": true` and its `sha` is your HEAD. The build log stays on the Mac (`/tmp/pillie_build.log`); only errors come back.
2. **Drive with a flow.** Pick the feature's flows from [features/README.md](features/README.md), or write a scratch flow for the change you made.
   - Linux: `make ns-mac-flow FLOW=today-home` (several: `FLOW="today-home history-calendar"`, everything: `FLOW=all`, a scratch file: `FLOW=/path/to/x.flow`).
   - Mac: `make flow FLOW=today-home`.
   Done when the command prints `ok: flow …`.
3. **Read the evidence** in the flow's output folder: `report.json` first, then each `NN-name.png` and its `NN-name.ax.txt` outline. Claim only what a shot shows and its outline contains.

Flows need no push. The runner ships the file, runs every step in one remote job, and pulls one archive back. Pushing matters only for app code, because the Mac runs the build from step 1.

## Writing a flow

One step per line; `#` starts a comment. `Pillie/scripts/sim-flow.sh --help-steps` is the full list. The common shape:

```
launch
openurl pillie://debug/plus-home?lang=en     # deterministic start: Plus Home, English
wait text Today 15
tap --label Settings                         # axe step; waits up to 10s for the element
wait id settingsLanguageRow
shot settings                                # 1x PNG + ax JSON + outline, numbered
```

- Start every flow from a known state: `launch` plus a debug deep link, or `fresh` for first launch. [references/state-setup.md](references/state-setup.md) lists every deep link, developer-menu scenario, and defaults key.
- Put a `wait` before every `shot`. The wait is the assertion; the shot is the record.
- Target `id` first (`.accessibilityIdentifier`), then exact English text from source. Coordinates only from a fresh shot, in points.
- Consecutive axe steps (`tap`, `swipe`, `gesture`, `type`, `button`, `key`, `sleep`) run as one `axe batch`. Selector taps wait for their element, so a `sleep` before a tap is a smell.
- Scroll is content direction: `gesture scroll-down` reveals rows below the fold.
- A failing step stops the flow and saves a `fail` shot. Read its outline before you guess.

Save a flow you will reuse under `flows/`, name it in the feature's doc, and run `make verify-flows`. That check fails on unknown steps, deep links the app does not handle, ids that are not in Swift source, and flows no feature doc names. CI runs it.

## Evidence

| What | Linux | Mac |
| --- | --- | --- |
| Launch shot, ax JSON, meta | `$ARTIFACTS/pillie_simulator_1x.png`, `pillie_ax.txt`, `pillie_qa.json` | `/tmp/sim_screenshot_1x.png`, `/tmp/pillie_ax.txt`, `/tmp/pillie_qa.json` |
| Flow run | `$ARTIFACTS/flows/<flow>/` | `/tmp/pillie-flow/<flow>/` |

`$ARTIFACTS` is `$PILLIE_NS_ARTIFACT_DIR` when set, else `/opt/cursor/artifacts` on Cursor, else the repo's gitignored `.qa-artifacts/`. `make ns-mac-flow` prints the exact `report.json` path. In a Claude Code cloud session, set `PILLIE_NS_ARTIFACT_DIR=$PWD/.qa-artifacts` if the environment points it at `/tmp`, so the user can open the shots.

A flow folder holds `report.json` (steps, pass/fail, ms, installed `app_sha`), `steps.jsonl`, and per shot `NN-name.png` (1x, points), `NN-name.ax.json` (raw axe), and `NN-name.ax.txt` (outline, one line per element: `Type  #id  "label"  =value  @x,y wxh`). Read the outline; open the JSON only for a detail it drops.

Check `app_sha` in `report.json` against the commit you meant to prove. Flows run whatever build is installed.

## Perf

`make ns-mac-flow FLOW=perf` (Mac: `make flow FLOW=perf`) writes:

- `perf-launch.json`: 5 warm relaunches, ms from `simctl launch` until the accessibility tree is non-empty. It is a regression signal, not a cold-start number.
- `frames.json`: the app's own frame probes (`Pillie/Pillie/Developer/TabSwitchFrameProbe.swift`) for idle, tab switching, and calendar paging, with dropped frames and the worst gap. Its `sha` field is the checkout, not the build; trust `app_sha`.

Compare against the same flow on `main` before you claim a perf change. `Pillie/PERF_CHECKLIST.md` holds the Instruments gates that need a real device or Xcode.

Other tools in a flow: `statusbar clean`, `record start` / `record stop` (MP4), `log start` / `log stop` (app OSLog to `app.log`), `privacy grant notifications`, `push file.apns`. `appearance dark` only changes system UI; the app forces light mode (`PillieApp.swift` `.preferredColorScheme(.light)`).

## Doctor

Run this when anything looks off.

- Linux, before launch: `Pillie/scripts/namespace-mac.sh auth-check` prints `ok: Namespace auth`, `make ns-mac-check-sync` prints `ok:`, `make ns-mac-status` shows `pillie-ios`.
- After launch: `pillie_qa.json` has your SHA and `"axe": true`; the 1x PNG shows Pillie, not SpringBoard or a white launch frame.
- Mac: `make diagnose` shows Xcode 27 and an iPhone 17 Pro UDID.
- A flow stuck on a SpringBoard alert: the `fail` outline shows `Sheet` elements outside the app. Add the tap that clears it (`tap --label Allow`) to the flow.

## One-off commands

`make ns-mac-exec CMD='axe describe-ui --udid "$(make -s udid)" | head'` runs one command on the Mac. `CMD` reaches the Mac unexpanded. Each call costs about 7 s of round trip, so batch anything longer than one command into a flow. `Pillie/scripts/ax-outline.py DUMP` turns any dump into the outline.

## Measured cost (pillie-ios, HTTPS transport)

| Action | Time |
| --- | --- |
| `make ns-mac-qa` from a stopped Mac, full build | 195 s |
| `make ns-mac-qa` on a warm Mac, incremental build | 29 s |
| One `make ns-mac-exec` | about 7 s |
| `make ns-mac-flow` of 8 steps and 3 shots | 20 s on the Mac, about 24 s wall |
| One tap inside a flow | about 0.9 s |

## Cleanup

Leave the simulator and the Mac up. `make ns-mac-stop` only when the user asks. Never kill by process name. Flow folders are evidence; leave them.

## Keeping the map honest

The feature map rots when the app changes. When a flow fails because the app changed on purpose, fix the flow and the feature doc in the same change. When it fails because the app broke, report the product bug and keep the flow. `/maintain-verification-skill` runs the full upkeep pass.
