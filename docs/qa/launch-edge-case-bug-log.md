# Pillie Launch Edge-Case Bug Log

Use this file for confirmed, reproducible findings from [launch-edge-case-test-matrix.md](./launch-edge-case-test-matrix.md).

## Bug Template

```md
## BUG-NNN: Short Title

- Severity:
- Flow IDs:
- Environment:
- Build:
- Preconditions:
- Steps:
- Expected:
- Actual:
- Evidence:
- Notes:
```

## Open Bugs

None.

## Closed Bugs

## BUG-001: Free onboarding implies app blocking can be enabled without Plus

- Severity: S1 Critical
- Flow IDs: SIM-BLOCK-001
- Environment: iPhone 17 Pro simulator, iOS 26.2, app PID 33617, fresh install after `xcrun simctl uninstall/install`
- Build: `xcodebuildmcp simulator build-and-run` succeeded for scheme `Pillie`
- Preconditions: User continues through onboarding as a free user by tapping `Continue for Free` on the paywall.
- Steps:
  1. Fresh install and launch Pillie.
  2. Complete personalization screens.
  3. Continue through free plan and premium challenge preview.
  4. Tap `Continue for Free` on the paywall.
  5. Continue with default Pill `21/7`, Day 1, and set reminder.
  6. Allow notification permission when prompted.
  7. Observe the app blocking onboarding screen.
- Expected: A free user should either see app blocking as clearly Plus-only or be directed to skip/upgrade. The UI should not imply active blocking can be enabled without Plus.
- Actual: The screen showed `Screen Time access granted`, `Choose apps to block`, and a primary CTA labeled `Enable Blocking & Finish` even though `AppBlockingManager.applyBlocking(...)` is Plus-gated.
- Evidence: XcodeBuildMCP UI snapshot after notification permission, PID 33617.
- Status: Closed 2026-05-26
- Fix: The app-blocking onboarding step now treats `Continue for Free` as an explicit free-plan path and shows Plus-only copy with a `Finish Setup` CTA instead of Screen Time/app-selection controls.
- Verification: Clean simulator reinstall with app and app-group defaults deleted, paywall skipped with `Continue for Free`, Patch onboarding completed through notification permission. AXe snapshot showed `App blocking is a Pillie+ tool you can set up after upgrading`, `Included with Pillie+`, and `Finish Setup`, with no `Choose apps to block` or `Enable Blocking & Finish`.
- Notes: `Skip for now` remains available for Plus users who choose not to configure blocking during onboarding, and Settings still locks `Blocked Apps` behind `Pillie+`.

## BUG-002: Clean first-run onboarding resets to Welcome after notification permission

- Severity: S2 High
- Flow IDs: SIM-ONB-001, SIM-ONB-002
- Environment: iPhone 17 Pro simulator, iOS 26.2, app PID 88703, clean simulator install after deleting simulator-level defaults for `com.idrisskone.pillie` and `group.com.idrisskone.pillie`
- Build: Existing `/tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app` from successful `Pillie` simulator build
- Preconditions: No existing app install and simulator defaults domains cleared with `xcrun simctl spawn "$UDID" defaults delete ...`; notification permission has not already been granted.
- Steps:
  1. Install and launch Pillie.
  2. Tap `Get Started`.
  3. Select `I simply forget`, `Stay protected`, and `Rarely`.
  4. Continue through the free plan, premium preview, and `Continue for Free` on the paywall.
  5. Select Patch.
  6. Continue with default Patch day 1.
  7. Tap `Set Reminder`.
  8. Tap `Allow` on the iOS notification permission alert.
- Expected: Onboarding continues to the next setup step and preserves the selected method/schedule. The user should not lose progress.
- Actual: After tapping `Allow`, Pillie returned to the Welcome screen showing `Get Started`; app and simulator defaults had no persisted `onboardingStep`.
- Evidence: AXe snapshot after permission showed Welcome copy (`The alarm clock for your pill`, `Get Started`) instead of the next onboarding step. Preference inspection showed no `onboardingStep` in the app container or simulator-level app defaults after the reset.
- Status: Closed 2026-05-26
- Fix: Onboarding step changes are now explicitly written to `UserDefaults`, and the reminder step advances before requesting notification permission/rescheduling reminders.
- Verification: Clean simulator reinstall with app and app-group defaults deleted, notification permission reset, and iOS notification `Allow` tapped. Patch onboarding stayed on the app-blocking step and then opened Home with `Mark Patch Changed`, `Patch Cycle · Day 1`, and `PATCH 3/1 CYCLE`. Pill onboarding opened Home with `Mark Pill as Taken`, `Pill 1 · Day 1`, `Pack 1 · 21/7 CYCLE`, and `8:00 AM`.
- Notes: This is distinct from the QA contamination where `Pillie/scripts/appstore_screenshots.sh` writes simulator-level defaults with `xcrun simctl spawn defaults write`. That contamination can skip onboarding, so clean onboarding QA must keep deleting simulator-level defaults.

## Watchlist

### WATCH-001: Free-user onboarding may imply app blocking is enabled

- Severity candidate: S1 Critical if reproduced
- Related flows: SIM-BLOCK-001, SIM-BLOCK-002
- Rationale: Settings and `AppBlockingManager.applyBlocking(...)` gate blocking behind Plus, but onboarding still contains an "Enable Blocking & Finish" path after the paywall can be skipped.
- Status: Reproduced as BUG-001; closed 2026-05-26.

### WATCH-002: Simulator defaults can contaminate fresh-install QA

- Related flows: SIM-ONB-001, SIM-ONB-002, SIM-ONB-003
- Rationale: `Pillie/scripts/appstore_screenshots.sh` writes app state with `xcrun simctl spawn defaults write`, which stores values under the simulator device preferences outside the app container. `simctl uninstall` alone does not clear those values, so a supposed fresh install can skip onboarding or use stale reminder/method defaults.
- Status: Confirmed QA pipeline risk, not a production app bug. Fresh-install simulator runs must delete the simulator-level `com.idrisskone.pillie` and `group.com.idrisskone.pillie` defaults domains before installing.

## Closed / Not Reproducible

None.
