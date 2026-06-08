# Pillie Interaction Feedback QA

Use this checklist for issue #60 after the Interaction Feedback implementation slices land. It covers simulator-visible state changes plus the real-device haptic pass that cannot be proven from Simulator alone.

Status key: `Not Run`, `Pass`, `Bug`, `Blocked`, `Real Device Required`.

## Current Pass Metadata

- Issue: [#60 Run simulator and real-device Interaction Feedback QA](https://github.com/idrisskone101/pillie/issues/60)
- Parent PRD: [#53 Interaction Feedback](https://github.com/idrisskone101/pillie/issues/53)
- QA date: 2026-06-08
- Branch: `codex/issue-60-interaction-feedback-qa`
- Simulator target: iPhone 17 Pro, iOS 26.2, `124DC75F-0771-4C81-841D-F13655138260`
- DerivedData: `/tmp/PillieDerivedData-codex-53cb`
- Build/test guard: `AnalyticsEvent` is enumerable and `AnalyticsManagerTests.testProductAnalyticsTelemetryDoesNotAddMotionHapticOrAnimationEvents` asserts Product Analytics Telemetry does not add motion, haptic, animation, or generic feedback event names.
- Local simulator smoke: installed `/tmp/PillieDerivedData-codex-53cb/Build/Products/Debug-iphonesimulator/Pillie.app`, launched `com.idrisskone.pillie` with PID `17135`, and captured `/tmp/pillie-issue-60-smoke.png`.
- Local automation limitation: `axe`, `idb`, and `xcsift` were not on this shell PATH, so this pass records screenshot smoke only and leaves tap-driven simulator rows as `Not Run`.

## Simulator QA Matrix

| ID | Area | Steps | Expected Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| IF-SIM-TAB-001 | Main tabs | Switch Home -> History -> Settings -> Home | Selected tab updates clearly, content remains stable, transition feels quick and does not obscure task state | Not Run |  |
| IF-SIM-HOME-001 | Home completion | From an active due-action day, tap the primary mark-taken CTA | CTA and status commit visibly to completed/taken state without layout jump | Not Run |  |
| IF-SIM-HOME-002 | Home undo | From completed state, tap `Completed (Tap to undo)` | CTA and status return to due state, streak/status redraw clearly | Not Run |  |
| IF-SIM-HOME-003 | Refill/new cycle | From a completed pack/cycle state, tap start-new-pack/start-new-cycle and confirm | Confirmation is calm, state changes to next pack/cycle, previous history remains trusted | Not Run |  |
| IF-SIM-HOME-004 | Home no-action states | Inspect pill break, patch passive/off-week, and ring passive/ring-free states | `No Action Due Today` remains clear without relying on motion | Not Run |  |
| IF-SIM-SHAKE-001 | Shake progress | Trigger representative shake-confirmation progress, then completion | Progress is visible and restrained; completion feels successful without becoming excessive | Not Run |  |
| IF-SIM-SHAKE-002 | Shake fallback | Use tap fallback where shake is unavailable or impractical | User can complete the flow without motion-only communication | Not Run |  |
| IF-SIM-SET-001 | Settings browsing | Open representative Settings rows, including schedule-critical rows | Row opens feel responsive; sheet transitions are stable and readable | Not Run |  |
| IF-SIM-SET-002 | Schedule-critical saves | Save representative schedule-critical Settings changes | Saves use clear commit feedback, destructive/reset confirmation remains trust-sensitive | Not Run |  |
| IF-SIM-PAY-001 | Plus/paywall | Open Plus/paywall, select plans, dismiss/continue free, and restore/purchase paths where available | Visible transitions do not imply false entitlement state; free path stays clear | Not Run |  |
| IF-SIM-ONB-001 | Onboarding choices | Navigate representative onboarding choice screens and Continue transitions | Choice/continue feedback is guided, warm, and does not slow setup | Not Run |  |
| IF-SIM-ONB-002 | Product Demo Moment and Plus Challenge Demo | Continue through both demo moments | Demo transitions are visible but not decorative enough to distract from setup value | Not Run |  |
| IF-SIM-ONB-003 | Review prompt and Soft Onboarding Paywall | Continue through review prompt, soft paywall, and free path | Review/paywall/free transitions remain trust-first and free path remains explicit | Not Run |  |
| IF-SIM-RED-001 | Reduced motion/constrained performance | Enable Reduce Motion where practical and repeat tab, Home, Settings, paywall, and onboarding representative steps | State remains clear without relying on spatial motion; calmer fallback is visible | Not Run |  |

## Real-Device QA Matrix

| ID | Area | Steps | Expected Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| IF-DEV-TAB-001 | Tab selection haptics | Switch tabs repeatedly on a physical iPhone | Selection feedback is noticeable but not excessive | Real Device Required |  |
| IF-DEV-HOME-001 | Mark taken haptics | Mark due action as taken repeatedly across representative methods | Commit feedback feels trust-first and does not slow logging | Real Device Required |  |
| IF-DEV-HOME-002 | Undo haptics | Undo completed due action repeatedly | Undo is lighter than commit and does not feel punitive | Real Device Required |  |
| IF-DEV-HOME-003 | Refill confirmation haptics | Confirm new pack/cycle | Confirmation feels meaningful without feeling alarming | Real Device Required |  |
| IF-DEV-SHAKE-001 | Shake progress haptics | Shake through progress states | Repeated feedback is not excessive and respects system haptic behavior | Real Device Required |  |
| IF-DEV-SHAKE-002 | Shake completion haptics | Complete shake confirmation | Success feedback feels warm and lightly playful without becoming toy-like | Real Device Required |  |
| IF-DEV-PAY-001 | Purchase/restore haptics | Complete purchase and restore success where practical | Success feedback maps only to real entitlement success | Real Device Required |  |

## Product Tone Notes

- Simulator-only note: visual state changes should communicate completion, undo, no-action, selected tab, and save outcomes without requiring motion to understand what happened.
- Local screenshot smoke note: Home rendered in a completed state with `Taken today`, `Pill 5 · Day 5`, `2 Day Streak`, and `Completed (Tap to undo)` visible; no layout overlap was visible in that captured state.
- Real-device note to capture: whether the combined motion and haptics feel trust-first, warm, and lightly playful without becoming toy-like or slowing due-action logging.
- Analytics note: do not add Product Analytics Telemetry events for haptics, animations, motion, or Interaction Feedback itself. Only existing product-domain events such as tab selection, due-action completion, settings saves, paywall actions, and onboarding progress should remain.

## Commands

```bash
cd /Users/idrisskone/.codex/worktrees/53cb/Pillie
Pillie/scripts/build-and-run.sh
Pillie/scripts/serve-simulator-browser.sh
```

```bash
UDID="124DC75F-0771-4C81-841D-F13655138260"
axe describe-ui --udid "$UDID"
xcrun simctl io "$UDID" screenshot /tmp/pillie-interaction-feedback.png
```

Focused analytics guard:

```bash
cd /Users/idrisskone/.codex/worktrees/53cb/Pillie/Pillie
xcodebuild -project Pillie.xcodeproj -scheme Pillie -sdk iphonesimulator -destination "id=124DC75F-0771-4C81-841D-F13655138260" -derivedDataPath /tmp/PillieDerivedData-codex-53cb -configuration Debug -only-testing:PillieTests/AnalyticsManagerTests/testProductAnalyticsTelemetryDoesNotAddMotionHapticOrAnimationEvents test
```
