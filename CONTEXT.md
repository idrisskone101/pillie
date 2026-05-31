# Pillie Domain

Pillie helps people track contraception routines, reminders, and adherence across method-specific cycles. This glossary keeps product language precise for planning, implementation, and testing.

## Language

**Current Cycle Day Adjustment**:
Changing the user's current day within the active contraception cycle, including forward and backward corrections. Prior days in the adjusted cycle are treated as already handled, not missed.
_Avoid_: Advance cycle, skip ahead, cycle advance

**Simulator-Verifiable Flow**:
A user flow whose expected behavior can be confidently checked in the iOS simulator. These flows cover app state, schedule math, persistence, and visible UI behavior.
_Avoid_: Fully tested flow, device behavior

**Real-Device Verification Flow**:
A user flow whose expected behavior depends on iOS capabilities that are not fully reliable in the simulator. These flows cover actual notification delivery and Screen Time app blocking behavior.
_Avoid_: Simulator test, local-only verification

**Supported Contraception Method**:
One of the contraception routines Pillie currently supports in the launched app: Pill, Patch, or Ring. Other contraception types are outside the current QA PRD unless they are introduced as product expansion work.
_Avoid_: All contraception types, method expansion

**Pill Regimen Coverage**:
The QA coverage set for pill schedules: every launched preset regimen plus representative custom boundary values. It is not an attempt to manually test every possible custom active and break-day combination.
_Avoid_: Every custom value, arbitrary pill schedules

**Tracking Data Reset**:
The destructive schedule-edit behavior where Pillie clears existing tracking history and starts a fresh cycle from the selected method, regimen, and current cycle day. It is the expected launched-app behavior for confirmed method or regimen changes in Settings.
_Avoid_: Preserve history, silent migration

**Product Analytics Telemetry**:
First-party app usage signals collected to understand whether Pillie flows are working and where users drop off. It excludes Apple-defined Tracking, advertising identifiers, cross-app or cross-site matching, and routine details such as contraception history, reminder times, app-blocking selections, or dose outcomes unless those details are separately approved.
_Avoid_: Tracking, surveillance, behavioral ads

**Streak**:
The count of consecutive completed due actions, not consecutive calendar days. Passive active days and break or off-week days do not require user action and should not inflate or break the streak.
_Avoid_: Daily streak, calendar-day streak

**Due Action Reminder**:
The primary local reminder for the next contraception action that requires user logging, delivered at the user's configured reminder time.
_Avoid_: Daily reminder, generic reminder

**Auto-Reminder Retry**:
A same-day follow-up reminder for an untaken due action, scheduled at the user's selected retry interval. It does not define the primary reminder time.
_Avoid_: Reminder time, snooze interval

**Supply Reminder**:
A local reminder about remaining contraception supply: pill refills or patch restocks. Ring routines do not currently expose a supply reminder setting in the launched app.
_Avoid_: Due action reminder, ring refill reminder

**Read-Only Schedule Surface**:
A view that presents schedule, status, and adherence without directly editing individual day records. Home, Settings, onboarding, notifications, and blocking flows create the mutations that these surfaces reflect.
_Avoid_: Calendar editing, history editing

**Schedule-Critical Setting**:
A setting that can change due actions, reminder timing, supply reminders, blocking behavior, streaks, or schedule status. These settings receive full edge-case coverage in the QA PRD.
_Avoid_: Every setting, cosmetic setting

**Personalization Setting**:
A setup preference that shapes onboarding or messaging but does not directly change contraception schedule math. These settings receive smoke coverage for persistence, navigation, and no-crash behavior.
_Avoid_: Schedule setting, critical schedule input

**Plus App Blocking**:
The Pillie Plus feature that blocks selected apps after a due action remains untaken. Free users should not be led to believe app blocking is active without a Plus entitlement.
_Avoid_: Free app blocking, enabled blocking for free users

**Controlled Simulator State**:
A known app data state created for a simulator QA scenario, including method, regimen, current cycle day, reminder time, and expected due action. It can be reset between scenario families to keep failures attributable.
_Avoid_: Existing simulator state, production device state

**Date/Time Boundary Flow**:
A schedule scenario that probes behavior around clock, calendar, and cycle boundaries. These flows are first-class QA stories because Pillie depends on accurate local date and time interpretation.
_Avoid_: Exotic time case, optional edge case

## Example Dialogue

Dev: "When the user changes from Day 18 to Day 12, is that an advance?"

Domain Expert: "No. That is a Current Cycle Day Adjustment because the user is correcting their position in the cycle, and Pillie should treat the earlier days in that adjusted cycle as already handled."

Dev: "Can we call notification delivery fully tested after simulator automation?"

Domain Expert: "No. Reminder setup can be a Simulator-Verifiable Flow, but actual notification delivery and Screen Time blocking need Real-Device Verification Flows."

Dev: "Should this launch QA cover injections and implants?"

Domain Expert: "No. The Supported Contraception Methods for this PRD are Pill, Patch, and Ring."

Dev: "Do we need to manually test all 10,000+ custom pill combinations?"

Domain Expert: "No. Pill Regimen Coverage means every preset plus custom boundary values and unsafe input normalization."

Dev: "If a user changes from Pill to Patch in Settings, should the old pill history remain?"

Domain Expert: "No. Confirmed method or regimen edits use a Tracking Data Reset, while canceling the confirmation keeps the existing schedule and history unchanged."

Dev: "Can we call PostHog event collection tracking?"

Domain Expert: "No. Use Product Analytics Telemetry for first-party app usage signals. Tracking still refers to Pillie's routine history in product language or Apple-defined cross-app and cross-site Tracking in privacy language."

Dev: "Does a ring-free day count toward the streak?"

Domain Expert: "No. The Streak counts consecutive completed due actions, so passive days and break days are neutral."

Dev: "If a user changes the auto-reminder interval, did they change the morning reminder time?"

Domain Expert: "No. The Due Action Reminder time and Auto-Reminder Retry cadence are separate reminder concepts."

Dev: "Should the user edit past days from History in this QA pass?"

Domain Expert: "No. History and Calendar are Read-Only Schedule Surfaces for this PRD; they verify that mutations made elsewhere are reflected correctly."

Dev: "Does every onboarding preference need to be crossed with every contraception method?"

Domain Expert: "No. Schedule-Critical Settings get full coverage, while Personalization Settings get smoke coverage."

Dev: "Can a free user rely on app blocking after onboarding?"

Domain Expert: "No. App blocking is Plus App Blocking; setup should not imply active blocking unless the user has Plus."

Dev: "Should we test every schedule using the currently installed simulator data?"

Domain Expert: "No. Use a Controlled Simulator State for each scenario family, then reset when the next family needs a different baseline."

Dev: "Are daylight saving and month-end checks overkill?"

Domain Expert: "No. They are Date/Time Boundary Flows because Pillie is only trustworthy if schedule behavior survives local clock and calendar boundaries."
