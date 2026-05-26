# Pillie Launch Edge-Case QA PRD

## Goal

Create a repeatable launch QA pass for Pillie that proves schedule-critical behavior across supported contraception methods, separates simulator-verifiable coverage from real-device-only coverage, and produces reproducible bug reports.

## Goal Execution Model

This PRD is optimized for Codex Goal execution. Each run should update the linked test matrix and bug log as evidence is gathered.

- Primary matrix: [launch-edge-case-test-matrix.md](./launch-edge-case-test-matrix.md)
- Bug log: [launch-edge-case-bug-log.md](./launch-edge-case-bug-log.md)
- Domain glossary: [../../CONTEXT.md](../../CONTEXT.md)

Progress states:

- `Not Run`: flow has not been executed in the current pass.
- `Pass`: observed behavior matches expected behavior.
- `Bug`: a reproducible mismatch is recorded in the bug log.
- `Blocked`: the flow could not be executed because a required device, entitlement, account state, or tool was unavailable.
- `Real Device Required`: simulator evidence is insufficient by definition.

## Scope

Supported contraception methods:

- Pill
- Patch
- Ring

Out of scope for this QA PRD:

- New contraception methods such as injection, implant, IUD, condoms, emergency contraception, or fertility-awareness routines.
- Editing individual past days from History or Calendar.
- Exhaustive custom pill regimen combinations beyond the agreed boundary cases.
- Proving real notification delivery or Screen Time shielding in the simulator.

## Definitions

- `Current Cycle Day Adjustment`: changing the user's current day in the active cycle, forward or backward.
- `Due Action`: a scheduled action that requires explicit user logging.
- `Passive Day`: a method day that has schedule meaning but requires no user logging.
- `Tracking Data Reset`: the destructive Settings flow that clears previous tracking history after confirmation.
- `Streak`: consecutive completed due actions, not consecutive calendar days.
- `Simulator-Verifiable Flow`: behavior that can be confidently verified in the iOS simulator.
- `Real-Device Verification Flow`: behavior that depends on real notification delivery or Screen Time behavior.

The canonical wording lives in [../../CONTEXT.md](../../CONTEXT.md).

## User Stories

### US-1: Onboard With A Supported Method

As a new Pillie user, I can complete onboarding with Pill, Patch, or Ring so that my Home, History, reminders, and Settings match my selected routine.

Acceptance criteria:

- The user can complete onboarding without crashes.
- The selected method persists after relaunch.
- Home shows the correct method-specific due action or passive state.
- History/Calendar renders the correct legend and schedule colors for the method.
- Settings summarizes the selected method and relevant schedule settings.

### US-2: Track Due Actions From Home

As a Pillie user, I can log today's due action and undo it so that Home, streak, reminders, blocking state, and History stay synchronized.

Acceptance criteria:

- Due-action CTA text matches the method and action type.
- Marking taken updates Home immediately.
- Undo reverts the taken state and restores the due action when applicable.
- Passive and break days show no active due-action CTA.
- Refill/cycle completion CTA replaces due-action CTA only at the correct boundary.

### US-3: Adjust Current Cycle Day

As a Pillie user, I can correct my current cycle day forward or backward so that Pillie realigns the cycle without falsely marking prior adjusted days as missed.

Acceptance criteria:

- Cycle day clamps to the method's supported cycle length.
- Prior days before the selected day are treated as handled.
- Streak is not inflated by backfilled days after adjustment.
- Patch and ring schedules remain anchored correctly after adjustment.
- History/Calendar updates to the adjusted cycle.

### US-4: Change Method Or Regimen With Confirmation

As a Pillie user, I can change my method or pill regimen in Settings with a clear destructive confirmation.

Acceptance criteria:

- Save shows the Tracking Data Reset confirmation.
- Cancel preserves current method, regimen, cycle day, and history.
- Confirm resets tracking history and starts a new schedule from the selected cycle day.
- Pill-to-patch, pill-to-ring, patch-to-ring, and regimen changes all update Home, Settings, and History consistently.

### US-5: Configure Pill Regimens

As a pill user, I can choose any launched pill regimen or a supported custom regimen so that due actions and break days match the regimen.

Acceptance criteria:

- Presets `21/7`, `24/4`, `26/2`, `28/0`, `84/7`, and `365/0` are selectable.
- Custom boundary inputs are normalized safely.
- Break-day behavior is neutral for streak and does not require a due action.
- Cycle completion appears at the correct end boundary.

### US-6: Use Patch Schedule

As a patch user, I can track a 28-day patch cycle with apply/change/remove/off-week states.

Acceptance criteria:

- Day 1, 8, and 15 are patch change due actions.
- Day 22 is patch removal.
- Days 23-28 are off-week passive days.
- Other active patch days do not require user action.
- Restock reminder supports `1 patch left` and `2 patches left`.

### US-7: Use Ring Schedule

As a ring user, I can track a 28-day ring cycle with insert/remove/ring-free/reinsert states.

Acceptance criteria:

- Day 1 is ring insertion.
- Day 22 is ring removal.
- Days 23-28 are ring-free passive days.
- Reinsert starts the next cycle correctly.
- Ring has no supply reminder setting.

### US-8: Configure Reminders

As a Pillie user, I can configure reminder time, retry interval, and method-appropriate supply reminders.

Acceptance criteria:

- Reminder time persists and displays correctly in 12-hour format.
- Midnight and noon display correctly.
- Retry interval supports `5`, `10`, `15`, and `30` minutes.
- Pill refill reminder supports `3`, `5`, and `7` days before end.
- Patch restock reminder supports `1` and `2` patches left.
- Ring does not show a supply reminder row.
- Scheduled reminder request construction can be inspected in simulator where possible.

### US-9: Review History And Calendar

As a Pillie user, I can review current and adjacent months so that schedule status, adherence, and method-specific legends reflect my tracked actions.

Acceptance criteria:

- Calendar month navigation works by buttons and swipe.
- Adherence card updates with the displayed month.
- Future days are visually distinct from past/today states.
- Method changes reset the view to the current month.
- History/Calendar are read-only schedule surfaces.

### US-10: Use Plus App Blocking

As a Plus user, I can select blocked apps and have Pillie block them after a due action remains untaken.

Acceptance criteria:

- Free users are not misled into thinking blocking is active.
- Plus users can grant Screen Time authorization and select apps.
- Blocking state reflects no apps, enabled, active, and off states.
- Marking the due action taken removes blocking.
- Simulator verifies setup UI/status only; real device verifies actual shielding.

### US-11: Survive Date And Time Boundaries

As a Pillie user, I need schedule behavior to remain correct across local time and calendar boundaries.

Acceptance criteria:

- Reminder time before current time today schedules catch-up behavior instead of dropping today.
- Reminder time after current time today schedules normally.
- Month-end and next-month History rendering is correct.
- Leap day schedule math does not crash or skip a due action.
- Daylight saving transitions do not duplicate or drop a due action.
- Cycle-end boundary shows Start New Pack/Cycle on the correct day.

## Simulator Runbook

Use the repo's configured simulator and DerivedData path:

```bash
xcodebuildmcp simulator build-and-run \
  --project-path /Users/idrisskone/Developer/Pillie/Pillie/Pillie.xcodeproj \
  --scheme Pillie \
  --simulator-id 124DC75F-0771-4C81-841D-F13655138260 \
  --configuration Debug \
  --derived-data-path /tmp/PillieDerivedData
```

If the CLI cannot complete the workflow, fall back to:

```bash
cd /Users/idrisskone/Developer/Pillie && Pillie/scripts/build-and-run.sh
```

Inspect UI:

```bash
xcodebuildmcp ui-automation snapshot-ui --simulator-id 124DC75F-0771-4C81-841D-F13655138260
```

Fallback AXe commands:

```bash
UDID=124DC75F-0771-4C81-841D-F13655138260
axe describe-ui --udid "$UDID"
axe tap --label "Continue" --udid "$UDID"
xcrun simctl io "$UDID" screenshot /tmp/pillie-qa.png
magick /tmp/pillie-qa.png -resize 33.33% /tmp/pillie-qa-1x.png
```

Clean first-install reset:

```bash
UDID=124DC75F-0771-4C81-841D-F13655138260
BUNDLE=com.idrisskone.pillie
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl spawn "$UDID" defaults delete "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl spawn "$UDID" defaults delete group.com.idrisskone.pillie >/dev/null 2>&1 || true
xcrun simctl install "$UDID" /tmp/PillieDerivedData/Build/Products/Debug-iphonesimulator/Pillie.app
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE"
```

The extra `defaults delete` calls are required because screenshot automation can write simulator-level defaults outside the app container; `simctl uninstall` alone is not a reliable fresh-install reset for onboarding QA.

Simulator evidence to record:

- Flow ID from the test matrix.
- Starting controlled simulator state.
- Commands used.
- Key UI tree snippets or screenshot paths.
- Expected behavior.
- Actual behavior.
- Pass/bug/blocked status.

## Real-Device Checklist

These flows must not be marked fully passed from simulator-only evidence:

- Actual local notification delivery at the configured time.
- Notification action handling from lock screen or notification banner.
- Snooze behavior from delivered notification.
- Screen Time authorization sheet behavior.
- FamilyActivityPicker selecting real apps.
- DeviceActivity schedule starting at due time.
- ManagedSettings shield appearing over selected apps.
- Shield action/deep link back into Pillie.
- Blocking removal after due action is marked taken.

## Bug Severity

- `S0 Launch Blocker`: crash, data loss without confirmation, impossible onboarding, or broken primary schedule tracking.
- `S1 Critical`: wrong due action, wrong cycle boundary, missed notification construction, misleading blocking state, or streak/adherence corruption.
- `S2 Major`: broken Settings flow, History/Calendar inconsistency, confusing reset/cancel behavior, or accessibility-blocking UI issue.
- `S3 Minor`: copy, visual polish, non-blocking layout issue, or low-risk edge mismatch.

## Completion Criteria

This QA goal is complete only when:

- The PRD is current with agreed terms and scope.
- Every simulator-verifiable flow in the matrix is marked `Pass`, `Bug`, or `Blocked` with evidence.
- Every real-device-only flow is listed separately and not falsely claimed as simulator-proven.
- Every reproducible bug has severity, reproduction steps, expected behavior, actual behavior, and evidence.
- The app has been built and launched through the iOS testing pipeline at least once during the pass.
