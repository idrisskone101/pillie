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
First-party app usage signals collected to understand whether Pillie flows are working and where users drop off. It excludes Apple-defined Tracking, advertising identifiers, cross-app or cross-site matching, and routine details such as contraception history, reminder times, app-blocking selections, or dose outcomes unless those details are separately approved. Capture is always on and begins at app launch; the protection boundary is the PII-free event taxonomy, not a consent gate (see ADR 0004).
_Avoid_: Tracking, surveillance, behavioral ads

**Analytics Consent**:
Retired (ADR 0004). The onboarding consent step and the Settings opt-out were removed in favor of always-on, PII-free-by-construction analytics; capture begins at launch with no consent gate. Kept as a historical term — it once meant the user's onboarding choice to allow or decline analytics, with no events sent before a grant.
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
A same-day follow-up reminder for an untaken due action, scheduled at the user's selected retry interval. It is the automatic part of [[Smart Reminders]] and requires a Pillie Plus entitlement. It does not define the primary reminder time.
_Avoid_: Reminder time, snooze interval, free-tier follow-up

**Smart Reminders**:
The Pillie Plus feature covering every same-day re-fire of a Due Action Reminder after the first: the automatic Auto-Reminder Retry escalation, the user-initiated Snooze re-fire, and the [[Last Call Reminder]] end-of-day backstop. Free users receive a single Due Action Reminder per due action with no retries, no Snooze action, and no Last Call Reminder. Smart Reminders is a behavioral nudge enhancement; it does not change the primary reminder time and is not a medical or efficacy claim. The free-tier "Daily reminders" benefit refers only to the primary Due Action Reminder, not to Smart Reminders.
_Avoid_: Daily reminders, smart notifications for free users, never-miss reminders

**Last Call Reminder**:
A single same-day end-of-day re-fire of a Due Action Reminder that fires only when the due action is still untaken, as a final backstop before the day rolls over and the action becomes missed. It is a member of [[Smart Reminders]] and requires a Pillie Plus entitlement, but it is its own concept with its own on/off toggle and fires independently of the Auto-Reminder Retry cadence — it still fires when the retry limit is 0 or after retries are exhausted, and it does not fire when the Auto-Reminder Retry has already converted the action to taken. There is at most one Last Call Reminder per due action per day. It does not change the primary reminder time and is not a medical or efficacy claim.
_Avoid_: Auto-Reminder Retry, final retry, missed-dose alert, daily summary, free-tier backstop

**Adaptive Reminder Time Suggestion**:
A Pillie Plus, on-device suggestion that the user shift their primary reminder time toward when they actually log, derived from the gap between the Due Action Time and recent real log times. It only ever suggests — the user confirms the change; Pillie never silently moves the reminder time, because reminder time is a Schedule-Critical Setting that also anchors the blocking window. It surfaces as a dismissible in-app suggestion, not a push notification, and its log-time signal stays on-device and is never sent as Product Analytics Telemetry. It does not add or change Smart Reminders re-fires.
_Avoid_: Auto-adjust reminder, silent reschedule, smart push, learned reminder notification

**Supply Reminder**:
A local reminder about remaining contraception supply: pill refills or patch restocks. Ring routines do not currently expose a supply reminder setting in the launched app.
_Avoid_: Due action reminder, ring refill reminder

**Cycle Transition Notice**:
A free, informational local notification fired at the start of a break/off week — the placebo week for pills, the patch-free or ring-free week for those methods — that explains the upcoming silence and names the date the active phase resumes. It exists to remove the "did the app break?" confusion when expected due actions stop for several days, and fires at the user's reminder time on the first break day, filling the slot a Due Action Reminder would otherwise occupy. It is not a member of [[Smart Reminders]] and is not gated by Pillie Plus, because it is not a same-day re-fire of a due action; it is a one-per-transition clarity notice, not a nudge escalation. It only covers the break-week start, not the new-pack/active-phase start, which is already a Due Action. Its default copy is Pillie-authored and obeys the medical-claims copy rules; it is not part of the Custom Reminder Message perk and is not user-customizable in v1.
_Avoid_: Smart reminder, due action reminder, new-pack reminder, supply reminder, missed-dose alert

**Custom Reminder Message**:
A Pillie Plus perk that lets the user replace the default reminder copy with their own free text. It covers the Due Action Reminder, the Auto-Reminder Retry, and the [[Last Call Reminder]] — each with its own title and body (six fields total) — and does not cover the Supply Reminder. It personalizes message content only: it does not change reminder timing, auto-reminder cadence, retry limits, or supply thresholds, and each field independently falls back to the default method-aware copy when left blank. It is additive — free users keep every existing reminder setting. It is a named Pillie Plus perk listed as a comparison row on the Soft Onboarding Paywall (and the Settings paywall, which share the same content), but it is a supporting perk — Plus App Blocking remains the differentiator and the paywall hero. As a Personalization Setting it survives a contraception method change and is not part of a Tracking Data Reset, mirroring how Reminder Time persists; the user edits it themselves if the wording no longer matches their method. Because it is the user's own private, on-device reminder to themselves (never shown to others, never leaving the device), it is not Pillie-authored copy and is not held to Pillie's medical-claims copy rules; the constraints that matter are display length and graceful fallback. Its text is private routine content and must never be sent as Product Analytics Telemetry; only coarse funnel and adoption signals (upsell viewed/tapped, editor opened, a boolean of whether each field is customized) may be captured.
_Avoid_: Custom reminder time, custom schedule, voice pack, Pillie-authored copy, custom supply reminder

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
The Pillie Plus feature that blocks selected apps after a due action remains untaken. Users should not be led to believe app blocking is active without [[Plus Access]], and setup controls should only appear for users with Plus Access (a Plus entitlement or an active [[Reverse Trial]]).
_Avoid_: Free app blocking, enabled blocking for free users

**Soft Onboarding Paywall**:
Retired (Reverse Trial). The in-onboarding Plus purchase offer was replaced by the [[Trial Granted Moment]] — onboarding no longer contains any purchase UI, because every new user receives a [[Reverse Trial]] instead. Kept as a historical term — it once meant an optional Plus offer shown during onboarding with a clear free path. The Settings-initiated paywall and the [[Trial-End Paywall]] are separate surfaces and are not retired.
_Avoid_: Hard paywall, required subscription gate, onboarding purchase step (current app)

**Trial Granted Moment**:
The onboarding screen that replaces the retired [[Soft Onboarding Paywall]]: a non-purchase announcement that the user's [[Reverse Trial]] has started — full Plus, free for 14 days, no payment details — shown before blocker setup. Its jobs are honesty (the user knows a clock is running) and priming the day-14 keep-your-protection framing. It must state the trial's duration, what turns off when it ends, and the post-trial price of keeping Plus — App Review's required pre-trial disclosures — but this is one line of plain disclosure, not purchase UI. It offers nothing to buy and has no decline path, because there is nothing to decline.
_Avoid_: Paywall, offer screen, plan picker, silent trial start, undisclosed post-trial price

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

**Review Prompt**:
Pillie's two-step in-app ask for an App Store rating, shown as a Home card to free and Plus users alike once they reach [[Review Prompt Eligibility]]. Step one is a [[Sentiment Gate]]; only a positive response advances to the [[Native Review Request]], and a negative response opens the [[Feedback Escape Hatch]]. It is never a hard gate on app use and is not a Pillie Plus perk. Distinct from the retired in-onboarding review request (the `reviewPrompt` onboarding step, now dead and never rendered) which asked for a rating before the user had any demonstrated success; this Home Review Prompt is its success-gated successor, which is the whole point of [[Review Prompt Eligibility]].
_Avoid_: Review module, rating popup, feedback form, in-onboarding review step

**Sentiment Gate**:
Step one of the [[Review Prompt]]: a low-stakes Home card asking how the user feels about Pillie (a positive/negative choice, not stars). It exists to keep unhappy users out of Apple's public rating flow, so its only job is to branch to the [[Native Review Request]] or the [[Feedback Escape Hatch]]. It is itself a [[Read-Only Schedule Surface]] consumer — it shows because of schedule success but never edits schedule data.
_Avoid_: Star picker, in-app rating, NPS survey

**Native Review Request**:
The positive-path outcome of the [[Sentiment Gate]]: a single call to Apple's StoreKit `requestReview`, which the system may or may not display and which is capped by Apple at three prompts per user per 365 days. Pillie treats firing it as best-effort and never assumes the system sheet appeared or that a rating was left.
_Avoid_: Guaranteed prompt, App Store write-review deep link, unlimited rating ask

**Feedback Escape Hatch**:
The negative-path outcome of the [[Sentiment Gate]]: a pre-filled native Mail composer to Pillie support (`pillieapp@gmail.com`) that captures dissatisfaction privately instead of sending the user to the public App Store rating. Its purpose is to protect the star average and give unhappy users a place to be heard; the email body the user types is private and is never sent as [[Product Analytics Telemetry]] (only a coarse "negative chosen" funnel signal may be). A missing Mail account is tolerated, not blocked on. Distinct from the [[Open Line]], which is the always-available Settings channel the user reaches on their own initiative rather than via a prompt.
_Avoid_: Public review, App Store redirect, server-side ticket system, logging feedback text, general contact button

**Open Line**:
Pillie's always-available two-way support channel: two warm-labeled rows in a Settings support section — one for sharing a feature idea, one for reporting something not working — each opening a pre-addressed email to Pillie support (`pillieapp@gmail.com`) with an intent-specific subject. Email is the channel precisely because it is two-way: Pillie has no backend, and the reply-able thread *is* the open line. The issue-report intent may pre-seed a device/app diagnostics footer (app version, iOS version, device model) but must never pre-seed routine details such as contraception method or cycle position; the idea intent seeds no body at all. What the user types is private and is never sent as [[Product Analytics Telemetry]] — only a coarse per-intent "row tapped" funnel signal may be. A device that cannot open the email composer gets a visible fallback that shows the support address to copy, never a silent no-op. Distinct from the [[Feedback Escape Hatch]], which is prompt-driven and reserved for the [[Sentiment Gate]]'s negative path.
_Avoid_: Feedback Escape Hatch, feedback form, in-app ticket system, server-side inbox, shake to report, logging message text

**Reverse Trial**:
A 14-day period of full [[Plus Access]] granted automatically and without payment details to every user who lacks a Plus entitlement: new users at the [[Trial Granted Moment]] during onboarding (the clock starts there, not at onboarding completion — blocker setup then runs under real Plus Access), existing free users on first launch after the update that introduces it. It is a Pillie product state, not a StoreKit introductory offer — no purchase, card, or App Store sheet is involved in starting it. Fourteen days is deliberate: it covers at least two due actions for every Supported Contraception Method, so patch and ring users also feel Plus App Blocking before being asked to pay. The trial covers 14 full local calendar days from the grant and expires at the local-day rollover after day 14 — never mid-blocking-window, so the last trial day is fully protected and expiry copy can honestly say "tonight." Blocking must never outlive Plus Access, even if the app is not opened after expiry. At expiry the user keeps their saved configuration (blocker selection, custom reminder text) but the Plus features gate off; nothing the user set up is deleted.
_Avoid_: Free trial (StoreKit sense), intro offer, 7-day trial, blocker-only trial, config wipe at expiry

**Trial-End Paywall**:
The Plus offer shown once, as a dismissible full-screen sheet, on first launch after a [[Reverse Trial]] expires. For users with [[Protection Plan Activation]] it is loss-framed around their own trial record (blocks intercepted, on-time doses, streak) — "keep your protection," not a generic feature list. For users who never configured the blocker it is gain-framed instead, and it always states plainly that reminders stay free. It is never a hard gate on app use and never repeats on every launch; after dismissal the [[Protection Off State]] Home card is the way back to it.
_Avoid_: Hard paywall, launch-loop paywall, generic feature list for protection users, loss framing for reminder-only users

**Protection Off State**:
The clearly visible in-app state after a [[Reverse Trial]] expires without purchase for a user who had blocker configuration: the saved blocker config is preserved but inert, blocking has stopped, and a persistent Home card says so and reopens the [[Trial-End Paywall]]. It exists so lapsing is never silent — the user should never believe blocking is active when it is not.
_Avoid_: Config wipe, silent lapse, disabled account, error state

**Plus Access**:
The single gate every Pillie Plus feature checks: a user has Plus Access iff they hold a Plus entitlement or an active [[Reverse Trial]]. All Plus features — Plus App Blocking, [[Smart Reminders]], [[Custom Reminder Message]], [[Adaptive Reminder Time Suggestion]] — honor the same gate; there is no per-feature trial gating and no "blocker-only trial" tier.
_Avoid_: Plus entitlement (when trial should also count), blocker-only trial, per-feature trial flags

**Review Prompt Eligibility**:
The on-device condition that makes a user "successful for a bit" enough to see the [[Review Prompt]], derived purely from an unbroken [[Streak]] crossing a method-aware threshold: pill `>= 3`, patch `>= 1`, ring `>= 2`. The thresholds target roughly the same "demonstrated success" tenure across methods despite different due-action cadences (pill daily, patch weekly, ring cyclic); ring is `>= 2` rather than `>= 1` specifically so the day-one insertion does not fire the prompt at setup. Because a streak inherently encodes calendar tenure, there is no separate days-since-install floor — the streak is the whole eligibility signal. Cooldown after dismissal and re-show policy are defined in [the Review Prompt ADR]. Eligibility math stays on-device; only coarse funnel signals may become [[Product Analytics Telemetry]].
_Avoid_: Days-since-install floor, fixed cross-method threshold, adherence percentage sent to analytics, server-side targeting

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

Dev: "Can Pillie send onboarding analytics before the user has answered an analytics consent screen?"

Domain Expert: "There is no consent screen — analytics is always on and begins at app launch (ADR 0004). The protection is the PII-free event taxonomy, not a consent gate; declining was retired along with the screen."

Dev: "Does a ring-free day count toward the streak?"

Domain Expert: "No. The Streak counts consecutive completed due actions, so passive days and break days are neutral."

Dev: "If a user changes the auto-reminder interval, did they change the morning reminder time?"

Domain Expert: "No. The Due Action Reminder time and Auto-Reminder Retry cadence are separate reminder concepts."

Dev: "We promised daily reminders stay free, so doesn't gating the auto-reminder settings break that promise?"

Domain Expert: "No. The free 'Daily reminders' benefit is the single Due Action Reminder. Smart Reminders are the same-day follow-ups after it — the Auto-Reminder Retry escalation and the Snooze re-fire — and those are Pillie Plus only."

Dev: "Can a free user still tap Snooze on a reminder?"

Domain Expert: "No. Snooze is part of Smart Reminders. Free users get one Due Action Reminder per due action with no Snooze action and no retries. Supply Reminders stay free."

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

Dev: "A Plus user typed their own reminder text — do we run it through our medical-claims copy rules?"

Domain Expert: "No. That is a Custom Reminder Message: the user's private, on-device reminder to themselves. It is not Pillie-authored copy, so our medical-claims rules don't apply. The real constraints are display length, enforced at input, and falling back to the default method-aware copy when a field is blank."

Dev: "A user switched from Pill to Patch — should their custom reminder text get wiped with the Tracking Data Reset?"

Domain Expert: "No. A Custom Reminder Message is a Personalization Setting, so it persists across method changes just like Reminder Time. A Tracking Data Reset only clears tracking history and schedule math. If the wording no longer fits, the user edits it."

Dev: "Can we log what the user wrote in their custom reminder to see how people personalize?"

Domain Expert: "No. The text is private routine content and must never be sent as Product Analytics Telemetry. You may capture coarse funnel and adoption signals only — upsell viewed or tapped, editor opened, and a boolean of whether a field is customized."

Dev: "A user tapped 'Something Not Working?' in Settings — did they use the Feedback Escape Hatch?"

Domain Expert: "No. That is the Open Line, the always-available Settings channel the user reaches on their own initiative. The Feedback Escape Hatch is only the Sentiment Gate's negative path."

Dev: "The issue-report email pre-fills diagnostics — can it include the user's method and cycle day so schedule bugs are easier to triage?"

Domain Expert: "No. The Open Line's diagnostics footer is device and app info only. Routine details are never pre-seeded; if a bug is schedule-related, ask in the reply — that is the two-way channel working as intended."
