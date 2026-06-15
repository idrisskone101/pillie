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
First-party app usage signals collected with the user's consent to understand whether Pillie flows are working and where users drop off. It excludes Apple-defined Tracking, advertising identifiers, cross-app or cross-site matching, and routine details such as contraception history, reminder times, app-blocking selections, or dose outcomes unless those details are separately approved. PostHog capture must not start until the user grants analytics consent.
_Avoid_: Tracking, surveillance, behavioral ads

**Analytics Consent**:
The user's onboarding choice to allow or decline first-party Product Analytics Telemetry. Declining must still allow full app use, and no PostHog events should be sent before consent is granted.
_Avoid_: Tracking permission, ATT prompt, required consent

**Streak**:
The count of consecutive completed due actions, not consecutive calendar days. Passive active days and break or off-week days do not require user action and should not inflate or break the streak.
_Avoid_: Daily streak, calendar-day streak

**Due Action Reminder**:
The primary local reminder for the next contraception action that requires user logging, delivered at the user's configured reminder time.
_Avoid_: Daily reminder, generic reminder

**Due Action Time**:
The method-aware user-facing moment when a Due Action Reminder matters: pill time, patch change time, or ring routine time. Broad brand copy may say pill time, but setup and personalized copy should use method-aware language after the Supported Contraception Method is known.
_Avoid_: Pill time for every method, generic reminder time

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
A setup preference that shapes onboarding or messaging but does not directly change contraception schedule math. Pain point, goal, and miss frequency are required during onboarding; Acquisition Source is optional. These settings receive smoke coverage for persistence, navigation, and no-crash behavior.
_Avoid_: Schedule setting, critical schedule input

**Acquisition Source**:
An optional onboarding answer for how the user heard about Pillie, stored locally and captured only as coarse categories for first-party Product Analytics Telemetry. It is a Personalization Setting and should not include free text, identifiers, or cross-app tracking.
_Avoid_: Tracking source, ad identifier, referral identity

**Plus App Blocking**:
The Pillie Plus feature that blocks selected apps after a due action remains untaken. Free users should not be led to believe app blocking is active without a Plus entitlement, and onboarding should only offer setup controls to users with Plus or an active trial.
_Avoid_: Free app blocking, enabled blocking for free users

**Soft Onboarding Paywall**:
An optional Pillie Plus offer shown during onboarding that keeps a clear free path available. It should appear after the user has enough personalized setup context to understand the value of upgrading, and may use coarse personalization buckets without displaying routine details or exact answers.
_Avoid_: Hard paywall, required subscription gate

**Reminder Plan**:
The onboarding summary of the user's reminder-only Pillie setup: contraception method, current cycle position, reminder time, and one behavioral support focus. It is not a medical, hormone, or risk-reduction plan.
_Avoid_: Health plan, hormone plan, optimized risk

**Pill Protection Plan**:
The onboarding summary of how Pillie will protect pill time from chosen distracting apps during the user's configured due-action window. It is behavioral app-time protection, not medical protection, contraceptive efficacy, or health-risk reduction.
_Avoid_: Medical protection plan, health protection plan, risk-reduction plan, generic reminder plan

**Draft Pill Protection Plan**:
A pre-permission onboarding version of the user's intended Pill Protection Plan. It can include one or more broad Distraction Choices, but it is not the saved Screen Time app selection.
_Avoid_: Active app blocking, saved blocker config, authorized app selection

**Distraction Choice**:
A broad onboarding answer for what pulls the user away from pill time, covering named apps, behaviors such as snoozing or being busy, and `Other` for apps Pillie does not name directly.
_Avoid_: Blocked app, Screen Time selection, app token

**Draft Blocked App Choice**:
A pre-permission onboarding answer for what the user intends Pillie to block during Due Action Time. It is app or category oriented and remains separate from the real Screen Time app selection.
_Avoid_: Distraction Choice, app token, saved blocker app

**Primary Distraction**:
The single Distraction Choice Pillie uses in personalized onboarding copy when the user selected more than one. It is a messaging anchor, not a limit on what can later be blocked.
_Avoid_: Only blocked app, required app, saved blocker app

**Delay Consequence**:
The user's onboarding answer for what missing or delaying a due action usually feels like emotionally or practically. It is a personalization signal, not a medical outcome or risk statement.
_Avoid_: Personal goal, health consequence, medical risk

**Risk Window**:
The user's onboarding answer for when they are most likely to drift away from the due action. In the v1 protection-plan onboarding, it personalizes copy but does not change the blocking start time.
_Avoid_: Blocking schedule, reminder time, delay timer

**Reminder-Only Onboarding Completion**:
The completed onboarding state for a user who finishes setup without saved app blocking and Screen Time authorization, regardless of whether they have a Plus entitlement. It means reminders are ready and app blocking remains incomplete.
_Avoid_: Activated user, protection plan ready, blocker activation

**Protection Plan Activation**:
The completed onboarding state for a user who has finished onboarding, saved blocker configuration, and completed Screen Time authorization. It is the activation definition for Pillie's app-blocking differentiator.
_Avoid_: Onboarding complete, reminder-only activation, paywall conversion

**Product Demo Moment**:
A short onboarding screen that shows Pillie's actual value loop before asking setup questions: a Due Action Reminder, the user's drift toward distraction, Pillie turning that moment into a clear checkpoint, and visible completion feedback after the due action is marked taken. It should be implemented as truthful in-app UI, not generic feature marketing.
_Avoid_: Explainer video, fake app preview, feature list

**Plus Challenge Demo**:
A prior onboarding concept for previewing shake-to-confirm or shake-to-unlock behavior. It is not part of the protection-plan onboarding v1 because it competes with the app-blocking differentiator.
_Avoid_: Product Demo Moment, protection-plan proof, blocker mechanism proof

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

Domain Expert: "No. Use Product Analytics Telemetry for consented first-party app usage signals. Tracking still refers to Pillie's routine history in product language or Apple-defined cross-app and cross-site Tracking in privacy language."

Dev: "Can Pillie send onboarding analytics before the user has answered the analytics consent screen?"

Domain Expert: "No. Analytics Consent must be granted before PostHog capture starts; declining must not block app use."

Dev: "Does a ring-free day count toward the streak?"

Domain Expert: "No. The Streak counts consecutive completed due actions, so passive days and break days are neutral."

Dev: "If a user changes the auto-reminder interval, did they change the morning reminder time?"

Domain Expert: "No. The Due Action Reminder time and Auto-Reminder Retry cadence are separate reminder concepts."

Dev: "Can personalized setup copy say pill time after the user chose Patch?"

Domain Expert: "No. After the method is known, use Due Action Time language such as patch change time or ring routine time. Pill time is acceptable only as broad Pillie brand copy or for pill users."

Dev: "Should the user edit past days from History in this QA pass?"

Domain Expert: "No. History and Calendar are Read-Only Schedule Surfaces for this PRD; they verify that mutations made elsewhere are reflected correctly."

Dev: "Does every onboarding preference need to be crossed with every contraception method?"

Domain Expert: "No. Schedule-Critical Settings get full coverage, while Personalization Settings get smoke coverage. Pain point, goal, and miss frequency are required for onboarding personalization; Acquisition Source is optional."

Dev: "Can Pillie ask how the user heard about the app?"

Domain Expert: "Yes, as an optional Acquisition Source using coarse categories stored locally and sent as first-party Product Analytics Telemetry. Do not collect free text or identifiers."

Dev: "Can a free user rely on app blocking after onboarding?"

Domain Expert: "No. App blocking is Plus App Blocking; setup controls should only appear for users with Plus or an active trial."

Dev: "Should onboarding require a subscription before the user can use Pillie?"

Domain Expert: "No. Pillie uses a Soft Onboarding Paywall: the Plus offer can highlight the annual trial and coarse personalized benefits, but the user must still have a clear free path."

Dev: "Can the onboarding summary say Pillie built a personalized health plan?"

Domain Expert: "No. It is a Reminder Plan: method, cycle position, reminder time, and behavioral support focus. Pillie should not imply medical optimization or risk reduction."

Dev: "Can the app-blocking onboarding summary call itself a Pill Protection Plan?"

Domain Expert: "Yes, if it is about protecting pill time from selected distracting apps. It must not imply medical protection, contraceptive efficacy, or reduced health risk."

Dev: "If the user selects TikTok or Other before the paywall, has Pillie saved the blocked apps?"

Domain Expert: "No. That is only a Draft Pill Protection Plan. The real app selection is saved later through Screen Time app selection after authorization."

Dev: "Are Distraction Choices and Draft Blocked App Choices the same thing?"

Domain Expert: "No. Distraction Choices diagnose what gets in the way; Draft Blocked App Choices describe what the user intends Pillie to block before the native Screen Time picker."

Dev: "If the user picks TikTok, YouTube, and Other, can the diagnosis still name one biggest risk?"

Domain Expert: "Yes. Pillie can use a Primary Distraction for personalized copy while keeping all selected Distraction Choices in the Draft Pill Protection Plan."

Dev: "Should onboarding ask for a broad personal goal or what delay usually feels like?"

Domain Expert: "Ask for the Delay Consequence. It gives Pillie emotionally specific personalization without implying medical risk or health optimization."

Dev: "If the user says they drift within five minutes, should Pillie delay blocking for five minutes?"

Domain Expert: "No. In v1 that is a Risk Window for personalization copy. Blocking still starts from the due action reminder time once the real blocker config is saved."

Dev: "Can a user who skipped Screen Time authorization be called activated?"

Domain Expert: "No. That is Reminder-Only Onboarding Completion. Protection Plan Activation requires onboarding completion, saved blocker configuration, and completed Screen Time authorization."

Dev: "If a user starts a Plus trial but denies Screen Time, are they a free user?"

Domain Expert: "No. They have Plus entitlement, but they still have Reminder-Only Onboarding Completion until app blocking is authorized and configured."

Dev: "Should onboarding explain Pillie with a list of features before setup questions?"

Domain Expert: "No. Use a Product Demo Moment that shows the real value loop: reminder, completion logging, and schedule or history feedback."

Dev: "Should the protection-plan onboarding include the shake challenge preview?"

Domain Expert: "No. The Plus Challenge Demo is not part of protection-plan onboarding v1. Keep the proof and paywall centered on app blocking during Due Action Time."

Dev: "Should we test every schedule using the currently installed simulator data?"

Domain Expert: "No. Use a Controlled Simulator State for each scenario family, then reset when the next family needs a different baseline."

Dev: "Are daylight saving and month-end checks overkill?"

Domain Expert: "No. They are Date/Time Boundary Flows because Pillie is only trustworthy if schedule behavior survives local clock and calendar boundaries."
