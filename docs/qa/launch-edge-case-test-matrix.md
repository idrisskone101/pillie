# Pillie Launch Edge-Case Test Matrix

Status key: `Not Run`, `Pass`, `Bug`, `Blocked`, `Real Device Required`.

## Current Pass Metadata

- QA pass started: 2026-05-26
- Simulator target: iPhone 17 Pro, iOS 26.2, `124DC75F-0771-4C81-841D-F13655138260`
- DerivedData: `/tmp/PillieDerivedData`
- Build evidence: `xcodebuildmcp simulator build-and-run` succeeded for scheme `Pillie`
- App launch evidence: `com.idrisskone.pillie` running in simulator; initial UI snapshot captured Home
- History evidence: fresh Pill `21/7` state rendered the Pill legend `Taken/Missed/Break`, `May 2026`, `0 check-ins`, `0% on track`, and `0/1 done` in AXe snapshot, PID 33617
- Test-target inventory: `xcodebuild -list` found app and extension schemes but no repo-owned `PillieTests` or `PillieUITests` target, so this pass is simulator-driven plus source inspection rather than XCTest-backed schedule enumeration.
- Fresh-install control note: `simctl uninstall` is insufficient after screenshot automation because simulator-level defaults can survive outside the app container. Clean onboarding runs must also delete simulator defaults domains for `com.idrisskone.pillie` and `group.com.idrisskone.pillie`.

## Simulator-Verifiable Flows

| ID | Area | Controlled State | Steps | Expected Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| SIM-ONB-001 | Onboarding | Clean first install | Complete onboarding with Pill `21/7`, cycle day 1, reminder 8:00 AM, notification permission allowed | Home opens with `Mark Pill as Taken`, `Pill 1 · Day 1`, `Pack 1 · 21/7 CYCLE`, and reminder `8:00 AM` | Pass | Fixed BUG-002 and retested after clean uninstall plus simulator defaults deletion; after iOS notification `Allow` and `Finish Setup`, Home showed `Mark Pill as Taken`, `Pill 1 · Day 1`, `Pack 1 · 21/7 CYCLE`, and `8:00 AM`. |
| SIM-ONB-002 | Onboarding | Clean first install | Complete onboarding with Patch, cycle day 1 | Home shows patch change due action, Settings shows Patch, History shows patch legend | Pass | Fixed BUG-002 and retested after clean uninstall plus simulator defaults deletion; after iOS notification `Allow`, onboarding stayed on the app-blocking step, then `Finish Setup` opened Home with `Mark Patch Changed`, `PATCH`, `Patch Cycle · Day 1`, and `PATCH 3/1 CYCLE`. |
| SIM-ONB-003 | Onboarding | Clean first install with simulator app/defaults domains cleared | Completed onboarding with Ring, cycle day 1, reminder 8:00 AM, notification permission allowed, skipped blocking | Home shows ring insert due action, Settings shows Ring, History shows ring legend | Pass | Clean reinstall with `defaults delete com.idrisskone.pillie` and `defaults delete group.com.idrisskone.pillie` reached Home with `Mark Ring Inserted`, `INSERT`, `Ring Cycle · Day 1`, `Cycle 1 · RING 21/7 CYCLE`; Settings showed `Contraceptive Type, Ring`; Calendar showed `Inserted`, `Missed`, `Ring-Free`, `May 2026` |
| SIM-PILL-001 | Pill presets | Pill `21/7`, cycle days 21 and 22 via Settings reset/adjustment | Inspected Home on day 21, then adjusted to day 22 | Day 21 is active pill due action; next day is break/no action | Pass | Home showed `Mark Pill as Taken`, `Pill 21 · Day 21`, then `No Action Due Today`, `BREAK`, `Pill 22 · Day 22` |
| SIM-PILL-002 | Pill presets | Pill `24/4`, cycle days 24 and 25 via Settings reset/adjustment | Inspected Home on day 24, then adjusted to day 25 | Day 24 active; day 25 break/no action | Pass | Home showed `Mark Pill as Taken`, `Pill 24 · Day 24`, then `No Action Due Today`, `BREAK`, `Pill 25 · Day 25` |
| SIM-PILL-003 | Pill presets | Pill `26/2`, cycle days 26 and 27 via Settings reset/adjustment | Inspected Home on day 26, then adjusted to day 27 | Day 26 active; day 27 break/no action | Pass | Home showed `Mark Pill as Taken`, `Pill 26 · Day 26`, then `No Action Due Today`, `BREAK`, `Pill 27 · Day 27` |
| SIM-PILL-004 | Pill presets | Pill `28/0`, cycle day 28 and elapsed day 29 boundary | Inspect Home and completion boundary | Day 28 active; cycle completion appears at correct boundary | Pass | Day 28 active state verified earlier: Home showed `Mark Pill as Taken`, `PILL`, `Pill 28 · Day 28`, `DAY 28 OF 28`; elapsed-boundary seed showed `Pack Complete!` and `Start New Pack` on `Pack 1 · 28/0 CYCLE` |
| SIM-PILL-005 | Pill presets | Pill `84/7`, cycle days 84 and 85 via Settings reset/adjustment | Inspected Home on day 84, then adjusted to day 85 | Day 84 active; day 85 break/no action | Pass | Home showed `Mark Pill as Taken`, `PILL`, `Pill 84 · Day 84`, `DAY 84 OF 91`, then `No Action Due Today`, `BREAK`, `Pill 85 · Day 85` |
| SIM-PILL-006 | Pill presets | Pill `365/0`, cycle day 365 | Seeded SwiftData state, relaunched, and inspected Home | Long active cycle remains stable at day 365 boundary | Pass | Seeded `pillRegimenRaw = 365/0`, start date 364 days before today; Home showed `Mark Pill as Taken`, `PILL`, `Pill 365 · Day 365`, `Pack 1 · 365/0 CYCLE`, `DAY 365 OF 365` |
| SIM-PILL-007 | Custom pill | Custom `1 active / 0 break`, cycle day 1 | Seeded SwiftData state, relaunched, and inspected Home | Shortest custom cycle does not crash and has one active due action | Pass | Home showed `Mark Pill as Taken`, `PILL`, `Take Pill`, `Pill 1 · Day 1`, `Pack 1 · 1/0 CYCLE`, `DAY 1 OF 1` |
| SIM-PILL-008 | Custom pill | Custom `1 active / 28 break`, cycle day 2 | Seeded SwiftData state, relaunched, and inspected Home | Day 2 is break/no action; no false missed state | Pass | Home showed `No Action Due Today`, `BREAK`, `Break/Placebo`, `Pill 2 · Day 2`, `Pack 1 · 1/28 CYCLE`, `DAY 2 OF 29` |
| SIM-PILL-009 | Custom pill | Custom `365 active / 0 break`, cycle day 365 | Seeded SwiftData state, relaunched, and inspected Home | Longest active-only custom cycle does not crash | Pass | Home showed `Mark Pill as Taken`, `PILL`, `Take Pill`, `Pill 365 · Day 365`, `Pack 1 · 365/0 CYCLE`, `DAY 365 OF 365` |
| SIM-PILL-010 | Custom pill | Custom `365 active / 28 break`, cycle day 393 | Seeded SwiftData state, relaunched, and inspected boundary | Longest custom cycle handles end boundary | Pass | Home showed `No Action Due Today`, `BREAK`, `Break/Placebo`, `Pill 393 · Day 393`, `Pack 1 · 365/28 CYCLE`, `DAY 393 OF 393` |
| SIM-PILL-011 | Custom pill | Custom blank/non-numeric inputs | Enter unsafe text and save | Inputs normalize safely; app does not crash | Blocked | Exact text-entry flow needs XCTest/manual keyboard coverage; current AXe pass could not reliably select and type into custom number fields after scrolling the schedule editor |
| SIM-PILL-012 | Custom pill | Custom out-of-range `0 / 99` | Seeded invalid persisted values and inspected Home normalization | Values clamp to supported active/break ranges | Pass | Seeded `customActiveDays = 0`, `customBreakDays = 99`; Home normalized to `Pack 1 · 1/28 CYCLE`, `Pill 29 · Day 29`, `DAY 29 OF 29`, `No Action Due Today` |
| SIM-PATCH-001 | Patch | Patch cycle day 1 via Settings reset | Inspect Home CTA, Settings, and History | Day 1 CTA is Mark Patch Changed | Pass | Home showed `Mark Patch Changed`, `Patch Cycle · Day 1`, `PATCH 3/1 CYCLE`; Settings showed `Contraceptive Type, Patch`; History showed patch legend `Changed/Missed` |
| SIM-PATCH-002 | Patch | Patch cycle day 8 via Current Cycle Day Adjustment | Inspect Home CTA and History | Day 8 CTA is Mark Patch Changed | Pass | Home showed `Mark Patch Changed`, `Patch Cycle · Day 8`, `DAY 8 OF 28` |
| SIM-PATCH-003 | Patch | Patch cycle day 15 via Settings reset | Inspect Home CTA and History | Day 15 CTA is Mark Patch Changed | Pass | Home showed `Mark Patch Changed`, `Change Patch`, `Patch Cycle · Day 15`, `DAY 15 OF 28` |
| SIM-PATCH-004 | Patch | Patch cycle day 22 via Current Cycle Day Adjustment | Inspect Home CTA and History | Day 22 CTA is Mark Patch Removed | Pass | Home showed `Mark Patch Removed`, `Remove Patch`, `Patch Cycle · Day 22`, `DAY 22 OF 28` |
| SIM-PATCH-005 | Patch | Patch cycle day 23 via Current Cycle Day Adjustment | Inspect Home CTA and History | Day 23 is off-week/no action | Pass | Home showed `No Action Due Today`, `Patch Cycle · Day 23`, `DAY 23 OF 28` |
| SIM-PATCH-006 | Patch | Patch cycle day 2 via Current Cycle Day Adjustment | Inspect Home CTA | Passive patch active day has No Action Due Today | Pass | Home showed `No Action Due Today`, `Patch Cycle · Day 2`, `DAY 2 OF 28` |
| SIM-RING-001 | Ring | Ring cycle day 1 via Settings reset | Inspect Home CTA and History | Day 1 CTA is Mark Ring Inserted | Pass | Home showed `Mark Ring Inserted`, `Insert Ring`, `Ring Cycle · Day 1`, `RING 21/7 CYCLE`; History showed `Inserted/Missed/Ring-Free` |
| SIM-RING-002 | Ring | Ring cycle day 21 via Current Cycle Day Adjustment | Inspect Home CTA | Ring active day has No Action Due Today | Pass | Home showed `No Action Due Today`, `Ring Cycle · Day 21`, `DAY 21 OF 28` |
| SIM-RING-003 | Ring | Ring cycle day 22 via Current Cycle Day Adjustment | Inspect Home CTA and History | Day 22 CTA is Mark Ring Removed | Pass | Home showed `Mark Ring Removed`, `Remove Ring`, `Ring Cycle · Day 22`, `DAY 22 OF 28` |
| SIM-RING-004 | Ring | Ring cycle day 23 via Current Cycle Day Adjustment | Inspect Home CTA and History | Day 23 is ring-free/no action | Pass | Home showed `No Action Due Today`, `Ring Cycle · Day 23`, `DAY 23 OF 28` |
| SIM-RING-005 | Ring | Ring reinsertion boundary seeded from a pinned insertion date 28 days before today | Marked `Mark Ring Reinserted` on Home | New cycle starts and day 1 is treated as handled | Pass | Before tap, Home showed `Mark Ring Reinserted`, `Reinsert Ring`, `Ring Cycle · Day 1`, `Cycle 1 · RING 21/7 CYCLE`; after tap, Home showed `Completed (Tap to undo)`, `Cycle 2 · RING 21/7 CYCLE`, and streak `1` |
| SIM-HOME-001 | Home | Existing Pill `21/7`, day 16, active pill due action | Tapped `Mark Pill as Taken`, observed completed state, tapped `Completed (Tap to undo)` | CTA toggled back to `Mark Pill as Taken`; status changed to `TAKEN` then back to due; streak changed `0 -> 1 -> 0` | Pass | XcodeBuildMCP UI snapshots, PID 32560 |
| SIM-HOME-002 | Home | Patch day 2, Patch day 23, Ring day 21, Ring day 23, Pill break days | Inspect CTA | CTA is disabled No Action Due Today | Pass | Home showed `No Action Due Today` across passive/off-week/break states |
| SIM-HOME-003 | Home | Cycle complete from elapsed `28/0` pack boundary | Tapped `Start New Pack`, confirmed alert | New pack/cycle starts, previous history preserved | Pass | Home showed `Pack Complete!`, `Start New Pack`, and alert copy `This will start a new pack from today. Your previous history will be preserved.` After confirmation Home showed `Mark Pill as Taken`, `Pill 1 · Day 1`, `Pack 3 · 28/0 CYCLE` |
| SIM-STREAK-001 | Streak | Consecutive due actions taken | Inspect Stats row | Streak counts due actions only | Blocked | Seeded yesterday as taken and today as due showed streak `1`; marking today completed did not prove `2` because manual SQLite seeding attached the current completion to a stale pack row after prior pack creation. Needs app-native debug seed, elapsed-date hook, or XCTest helper. |
| SIM-STREAK-002 | Streak | Current Cycle Day Adjustment with backfill | Adjusted Ring day 23 back to day 21 and later adjusted Pill preset boundaries | Backfilled days do not inflate streak | Pass | Home still showed streak value `0` after backfilled cycle-day adjustments |
| SIM-SET-001 | Settings | Fresh Pill `21/7` state | Changed method to Patch, tapped Save, then canceled `Reset Tracking Data?` and canceled editor | Method/history remain unchanged | Pass | Settings still showed `Contraceptive Type, Pill (21/7)` after cancel |
| SIM-SET-002 | Settings | Fresh Pill `21/7` state | Changed method to Patch and confirmed `Reset & Save` | Method changes and old tracking data resets | Pass | Settings showed `Contraceptive Type, Patch`, `Restock Reminder, 1 patch left`, `Current Day in Cycle, Day 1 of 28`; Home/History switched to Patch surfaces |
| SIM-SET-003 | Settings | Patch schedule | Current Cycle Day Adjustment forward to days 2, 8, 22, and 23 | Home/History realign without false missed days | Pass | Home showed the expected passive/change/remove/off-week states for each selected day |
| SIM-SET-004 | Settings | Ring schedule | Current Cycle Day Adjustment backward from day 23 to day 21 | Home/History realign without false missed days | Pass | Home showed `No Action Due Today`, `Ring Cycle · Day 21`, `DAY 21 OF 28`, with no missed state surfaced |
| SIM-REM-001 | Reminder time | Ring day 23 | Set reminder to 12:00 AM | Settings displays 12:00 AM and persists after relaunch | Blocked | AXe exposes the wheel pickers as unlabeled sliders; direct plist seeding of `pillie_reminder_hour = 0` did not produce a trustworthy visible Settings change during the running simulator pass |
| SIM-REM-002 | Reminder time | Ring day 23 | Set reminder to 12:00 PM | Settings displays 12:00 PM and persists after relaunch | Blocked | Same automation limitation as SIM-REM-001; needs XCTest helper, app debug seed hook, or manual simulator wheel interaction |
| SIM-REM-003 | Reminder retry | Fresh Pill `21/7`, free user | Selected 5, 10, 15, and 30 minute retry intervals from Settings | Each option saved and displayed correctly as `5 min`, `10 min`, `15 min`, and `30 min` | Pass | AXe UI snapshots, PID 33617 |
| SIM-REM-004 | Supply reminder | Fresh Pill `21/7` | Selected 3, 5, and 7 days before end from Settings | Each option saved and displayed correctly as `3 days before end`, `5 days before end`, and `7 days before end` | Pass | AXe UI snapshots, PID 33617 |
| SIM-REM-005 | Supply reminder | Patch | Selected 1 and 2 patches left from Settings | Each option saves and displays correctly | Pass | Settings showed default `1 patch left`, then saved and displayed `2 patches left` |
| SIM-REM-006 | Supply reminder | Ring | Open Settings after Ring reset | Supply reminder row is absent | Pass | Settings showed `Contraceptive Type, Ring`, `Reminder Time`, `Auto-Reminder Interval`, and `Current Day in Cycle`; no `Refill Reminder` or `Restock Reminder` row appeared |
| SIM-HIST-001 | History | Ring schedule | Navigated previous/next month by buttons | Month and adherence update without layout break | Pass | Buttons changed `May 2026` to `April 2026` and back to `May 2026`; legend remained `Inserted/Missed/Ring-Free` |
| SIM-HIST-002 | History | Ring schedule | Swiped calendar next/previous month | Month and adherence update without layout break | Pass | Horizontal swipe changed `May 2026` to `June 2026` and back to `May 2026`; adherence card stayed visible |
| SIM-HIST-003 | History | Changed method in Settings | Returned to History after Patch and Ring method changes | History resets to current month and method legend updates | Pass | Patch History showed `Changed/Missed`; Ring History showed `Inserted/Missed/Ring-Free`; both returned to `May 2026` |
| SIM-BLOCK-001 | Blocking | Free user after paywall skip | Reached app blocking onboarding after `Continue for Free` | UI should not imply active blocking without Plus | Pass | Fixed BUG-001 and retested after `Continue for Free`; screen showed `App blocking is a Pillie+ tool you can set up after upgrading`, `Included with Pillie+`, and `Finish Setup`, with no `Choose apps to block` or `Enable Blocking & Finish`. |
| SIM-BLOCK-002 | Blocking | Free user in Settings | Opened `Blocked Apps, Pillie+` row | Shows Pillie+ upsell with `Upgrade to Pillie+`, `Not Now`, and `Restore Purchases`; no blocked-app editor shown | Pass | XcodeBuildMCP UI snapshot, PID 32560 |
| SIM-BLOCK-003 | Blocking | Plus entitlement available | Manage blocked apps in Settings | Selection/status UI can be managed; actual shielding not simulator-proven | Blocked | Requires a reliable Plus entitlement or StoreKit/RevenueCat override in the simulator. Free-user Settings path correctly shows the Plus upsell, but Plus management cannot be proven from the current account state. |
| SIM-TIME-001 | Date/time | Reminder time before current time | Inspect scheduled/catch-up behavior if accessible | Today is not silently dropped | Blocked | Needs app-native date/clock injection, XCTest helper, or controlled notification scheduler inspection. Simulator wall-clock cannot be safely time-traveled in the current pipeline. |
| SIM-TIME-002 | Date/time | Month boundary | Inspect last/first day across adjacent months | Calendar and schedule state remain correct | Blocked | Needs app-native date/clock injection or a deterministic seed hook for "today" at month end. Existing History month navigation passed, but current-date boundary math was not simulator-proven. |
| SIM-TIME-003 | Date/time | Leap day controlled date | Inspect due action and History | No crash or skipped due action | Blocked | Needs app-native date/clock injection or XCTest coverage around `PillStore.scheduleSnapshot(...)`/`DoseScheduleEngine`; no safe simulator date override is available in this pass. |
| SIM-TIME-004 | Date/time | DST transition controlled date | Inspect due action and reminders if accessible | No duplicate/drop of due action | Blocked | Needs app-native date/clock injection and notification request inspection across a DST boundary; current simulator pipeline cannot prove this without altering device time globally. |
| SIM-PERSIST-001 | Persistence | Ring day 23 configured through Settings | Relaunched with `xcrun simctl launch --terminate-running-process` | Method, settings, History state persist | Pass | Relaunch PID 51472 returned to Home with `No Action Due Today`, `Ring Cycle · Day 23`, `RING 21/7 CYCLE`, `DAY 23 OF 28` |

## Smoke Flows

| ID | Area | Steps | Expected Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| SMOKE-001 | Pain points | Selected `I simply forget`, continued | Selection advanced without crash | Pass | XcodeBuildMCP UI snapshots, PID 33617 |
| SMOKE-002 | Personal goal | Selected `Stay protected`, continued | Selection advanced without crash | Pass | XcodeBuildMCP UI snapshots, PID 33617 |
| SMOKE-003 | Miss frequency | Selected `Rarely`, continued | Selection advanced without crash | Pass | XcodeBuildMCP UI snapshots, PID 33617 |
| SMOKE-004 | Paywall | Opened premium preview, opened paywall, tapped `Continue for Free` | User reached method setup without dead end | Pass | XcodeBuildMCP UI snapshots, PID 33617 |
| SMOKE-005 | Subscription | Open Settings subscription row as free user | Free user sees paywall; Plus user sees manage subscriptions | Pass | Free user opened `Join Pillie Plus` paywall with `Start Your Free Trial`, `Continue for Free`, `Restore Purchases`; Plus manage subscriptions path remains unverified without entitlement |

## Real-Device Verification Flows

| ID | Area | Required Device State | Steps | Expected Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| DEV-NOTIF-001 | Notification delivery | Physical iPhone, notifications allowed | Set reminder a few minutes ahead and wait | Notification arrives at configured time | Real Device Required |  |
| DEV-NOTIF-002 | Notification action | Delivered notification | Tap Mark as Taken action | Due action is logged and future retries clear | Real Device Required |  |
| DEV-NOTIF-003 | Snooze | Delivered notification | Tap Snooze | Follow-up reminder fires after selected retry interval | Real Device Required |  |
| DEV-BLOCK-001 | Screen Time auth | Physical iPhone, Plus entitlement | Grant Screen Time authorization | Authorization status becomes approved | Real Device Required |  |
| DEV-BLOCK-002 | App selection | Physical iPhone, Plus entitlement | Select apps/categories in FamilyActivityPicker | Selection persists and Settings count updates | Real Device Required |  |
| DEV-BLOCK-003 | Blocking active | Physical iPhone, selected apps, due action untaken after reminder time | Open selected blocked app | Shield appears with Pillie messaging | Real Device Required |  |
| DEV-BLOCK-004 | Blocking removal | Physical iPhone, blocking active | Mark due action taken in Pillie | Selected apps unblock | Real Device Required |  |
| DEV-BLOCK-005 | Shield deep link | Physical iPhone, shield visible | Use shield action to open Pillie | Pillie opens to actionable tracking state | Real Device Required |  |

## Current Known Risks To Watch

- Free-user onboarding app-blocking copy should stay explicitly Plus-only after the paywall skip path.
- Clean first-run Pill/Patch onboarding should continue preserving progress after notification permission.
- Screenshot automation writes simulator-level defaults; always clear those domains before any "fresh install" onboarding claim.
- Patch and ring passive days must never appear as required due actions.
- Current Cycle Day Adjustment must not inflate streak with backfilled days.
- Ring reinsertion must create the next cycle with a stable insertion anchor.
- Reminder construction must not exceed iOS pending notification limits.

## Continuation Notes

- Current matrix status after this tranche: `48 Pass`, `0 Bug`, `9 Blocked`, `8 Real Device Required`, `0 Not Run`.
- Recompute with `awk -F'|' '$0 ~ /^\|/ && $0 !~ /^\| ---/ && $0 !~ /Status/ {for(i=1;i<=NF;i++){s=$i; gsub(/^ +| +$/, "", s); if(s ~ /^(Not Run|Pass|Bug|Blocked|Real Device Required)$/) c[s]++}} END{for(k in c) print k, c[k]}' docs/qa/launch-edge-case-test-matrix.md | sort` after each update.
- Highest-value remaining simulator gaps: add a Plus entitlement test override, add a deterministic date/clock injection seam, prove streak accumulation with app-native seeding, and add exact custom text-entry validation.
- Long pill/custom boundary rows SIM-PILL-006 through SIM-PILL-012 used controlled SwiftData seeds followed by simulator UI verification. They prove the schedule read model and Home rendering, but not every end-to-end editor tap/typing path.
- Reminder-time midnight/noon flows are blocked by AXe exposing wheel pickers as unlabeled sliders; use an XCTest helper, debug seed hook, or manual simulator interaction before marking them complete.
- Ring reinsertion requires an elapsed day beyond the 28-day cycle, not just a Current Cycle Day Adjustment, because `ringReinsert` is generated when the anchored ring day wraps to day 1 after a full elapsed cycle.
