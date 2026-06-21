# Onboarding Soft Paywall Plan Mix

Pillie's redesigned onboarding will keep a soft paywall with annual trial, monthly fallback, and a clear free path. It will not add weekly or lifetime plans in this redesign pass.

Research from mobile onboarding and paywall examples suggests that broader plan mixes can improve price anchoring, especially weekly plus yearly plus lifetime. Pillie's current subscription surface, however, is already implemented around annual and monthly RevenueCat products, with annual selected by default and a free onboarding path available. Adding weekly or lifetime products would require App Store Connect and RevenueCat configuration, pricing decisions, copy changes, tests, and a separate monetization experiment.

The onboarding redesign is focused on sequencing and value presentation: ask for Analytics Consent, show a truthful Product Demo Moment with an integrated Plus Challenge Demo, collect setup context, summarize a Reminder Plan, then present Pillie Plus as optional. Annual with trial remains the primary CTA, monthly remains the secondary paid fallback, and free use remains explicit. Future pricing experiments can revisit weekly or lifetime plans after the new funnel is measurable.

Analytics Consent must appear immediately after Welcome and before any PostHog capture starts. Welcome may render without analytics capture. The consent screen offers `Allow Analytics` and `Not Now`; either choice continues onboarding. Declining consent must not block the Product Demo Moment, the free plan, or Pillie Plus purchase flow. The consent screen should describe first-party product analytics in plain language, not Apple ATT Tracking.

The protection-plan onboarding revamp preserves this placement: Analytics Consent still appears immediately after Welcome, before the longer calibration sequence. The Recime-style proof-before-permission moment applies to Screen Time access, not Product Analytics Telemetry, because PostHog capture remains consent-gated and events before consent are dropped rather than buffered.

The Reminder Plan screen appears before the Soft Onboarding Paywall. This keeps the setup valuable on the free path and makes the Plus offer an optional enhancement to an already-created reminder setup rather than a gate before value.

Pillie will not add an exit or closing offer in this v1 redesign. When a user chooses the free path, onboarding should respect that choice and may show a simple free-plan confirmation. Discounts, roulette-style offers, or second paywall asks should be treated as separate experiments because they change the trust posture of a contraception reminder app.

After `Continue for Free`, onboarding will show a short free-plan confirmation with one primary action to start using Pillie. It may clarify that daily reminders and tracking are active on the free plan and that Pillie Plus can be explored later in Settings, but it should not present another upgrade ask.

Plus App Blocking setup will only appear during onboarding for users who start the annual trial, subscribe, restore Plus, or already have Plus. Free users should finish onboarding after the free-plan confirmation and enter the app; app blocking can remain discoverable later through Settings or Plus upsells without implying that blocking is active on the free plan.

The protection-plan revamp may build a Draft Pill Protection Plan before the paywall using broad distraction choices, including an `Other` option for apps Pillie does not name directly. Real Screen Time authorization, the FamilyControls picker, and saved blocker configuration happen only after the user has Plus, starts a trial, restores Plus, or already has entitlement. This keeps the paywall tied to the user's intended plan without implying that app blocking is active on the free path.

The paywall appears before the Screen Time primer in the actual Plus setup branch. The draft plan and mechanism proof explain the value first, the paywall sells app blocking for pill time, and only users who start a trial, purchase, restore Plus, or already have Plus proceed to Screen Time primer, native authorization, real app selection, and blocker config save. Users who continue free skip Screen Time permission and enter reminder-only mode with blocking incomplete.

Onboarding completion has two visible completion states. Plus or trial users who complete Screen Time authorization and save blocker configuration see a `Pill Protection Plan Ready` state with reminder time, selected app count, blocking rule, and unlock action. Free, skipped, or denied users see a `Reminder Plan Ready` state with reminders active and app blocking clearly incomplete, plus a path to enable blocking later from Settings.

Plus entitlement and blocker activation are separate states. A user who starts a trial, purchases, restores, or already has Plus but skips or denies Screen Time still lands in reminder-only completion with blocking incomplete; the UI should not describe them as free, but should clearly offer a path to enable app blocking later.

The revamped failure-frequency screen keeps the existing four stored miss-frequency buckets for compatibility, while changing the displayed calibration copy. `rarely` displays as `Rarely`, `sometimes` as `A few times a month`, `often` as `Weekly`, and `almostDaily` as `Multiple times a week`.

The draft blocked-apps step should use grouped choices before Screen Time authorization. The named-app group includes concrete app chips such as TikTok, Instagram, YouTube, Messages, X, Snapchat, and Other. The broader behavior/category group covers patterns such as short videos, social feeds, messages, games, snoozing, being busy, and forgetting. These selections personalize the Draft Pill Protection Plan only; the native FamilyControls picker later provides the real saved selection.

The current-routine segment keeps Pillie's launched method coverage for Pill, Patch, and Ring. The redesign should compress the existing method, regimen or cycle-position, and reminder-time setup into a lighter routine-basics segment instead of removing Patch or Ring support. Pill-specific copy can be used for the common pill path, but method-specific setup remains intact.

Back navigation must restore committed onboarding answers from persisted state. A screen's local selection can remain uncommitted until the user taps Continue; if the user backs out before Continue, the app does not need to preserve that uncommitted local tap. Each step should initialize from the stored answer when one exists.

App interruption follows the same committed-answer boundary. If the app is killed mid-screen before Continue, onboarding may return to the last committed step and answer state. The real FamilyControls selection is an exception: changes made in the native picker should persist through the existing Screen Time selection binding because that picker is the saved configuration step.

The visible progress indicator should cover the plan-building calibration steps, not monetization or system permission. After the paywall, the Plus setup branch switches to setup-status language such as enabling Screen Time, choosing apps, and plan ready, rather than continuing the calibration progress count through purchase and native permission prompts.

The locked high-level onboarding order is: Welcome, Analytics Consent, Early Value Proof, Review Prompt, Distraction Choices, Delay Consequence, Failure Frequency, Risk Window, Draft Blocked Apps, Acquisition Source, Routine Basics, Reminder Time, Personalized Diagnosis / Draft Pill Protection Plan, Mechanism Proof, Paywall, then branch. The free branch shows Reminder Plan Ready. The Plus branch proceeds through Screen Time Primer, native Screen Time authorization, real FamilyControls app selection, and Pill Protection Plan Ready, falling back to Reminder Plan Ready if Screen Time is skipped or denied.

The visual direction should evolve Pillie's existing soft premium brand rather than copying any Mobbin reference directly. Keep Pillie's brand colors and premium feel, but improve pacing, hierarchy, fixed CTA behavior, segmented progress, selected states, and plan-reveal polish using the references as interaction guidance. The result should still feel like Pillie, not Cal AI, ABY Journal, Duolingo ABC, Blinkist, or Recime.

Implementation should introduce a shared plan-builder question layout for calibration screens such as Distraction Choices, Delay Consequence, Failure Frequency, Risk Window, Draft Blocked Apps, and Acquisition Source. Welcome, Analytics Consent, Review Prompt, proof screens, paywall, native permission, and final ready states can remain bespoke. The shared layout owns fixed CTA behavior, progress, selected states, disabled state, spacing, and accessibility patterns.

The redesign will include an onboarding review prompt after the early value-proof screen and before personalization questions. The prompt is placed after a positive value demonstration but before higher-friction setup, permissions, and monetization steps. This is a deliberate growth trade-off; if ratings quality or trust signals regress, the prompt should be revisited or moved to a post-use success moment.

The review prompt should be framed as a soft native rating request: title `Does this feel useful so far?`, body `A quick rating helps more people find Pillie.`, primary action `Rate Pillie`, and secondary action `Not now`. Implementation should use Apple's native review request mechanism and should not promise App Store navigation.

The Product Demo Moment should be one animated screen, not a swipeable carousel. It should integrate the interactive Plus Challenge Demo cleanly within the same step so users can try the shaking motion currently used by Pillie's challenge behavior without adding another onboarding screen. The challenge demo must be explicitly presented as a Pillie Plus preview so free users do not infer that app blocking or challenge mode is active on the free plan.

The combined Product Demo Moment structure should be: animated `Reminder -> Log -> Updated` mini timeline, compact live shake card labeled `Pillie Plus preview`, then one `Continue` CTA. The shake interaction is optional, and simulator builds should keep a tap-to-simulate fallback.

The protection-plan revamp supersedes the old Product Demo Moment plus separate Plus Blocking Demo split. It should use one early value-proof screen before setup and one later app-blocking mechanism-proof screen before the Screen Time primer. The old shake demo should not compete with the main app-blocking story; if retained, it belongs as a paywall or Plus-benefit detail, not as a separate onboarding step.

The early value-proof screen should show `The moment Pillie catches the drift`: a due action reminder, the user's attention moving toward distracting apps, Pillie turning that moment into a clear pill-time checkpoint, and the home state updating after the user marks the due action taken. The later mechanism-proof screen should show `The lock only opens after the pill is handled`: reminder rings, selected apps are blocked, and marking the due action taken unlocks them. Both proof screens should be visual, truthful, and easy to understand without fake stats, testimonials, or medical claims.

The Acquisition Source screen remains a separate optional onboarding step late in calibration, after the blocker/value questions and before routine setup. It answers where the user found Pillie, not what distracts them during pill time, even when both screens mention apps such as TikTok or Instagram.

The v1 redesign preserves Pillie's existing personalization categories and stored enum semantics for pain points, personal goals, and miss frequency. Display copy can be refined, but new categories such as travel-specific hurdles or renamed goal concepts should be treated as separate product changes.

Paywall trust cues must be truthful and operational: the annual trial, App Store cancellation, continued free reminders and tracking, and on-device app blocking. Pillie does not run ads in any tier, so `no ads` should not be presented as a Plus-only benefit. The paywall should avoid fake social proof, fake countdowns, fake scarcity, rating claims without a live source, and medical or protection claims.

The Soft Onboarding Paywall must clearly explain what Pillie Plus includes before asking for payment. It should include a compact Plus value breakdown for App Blocking and shake-to-unlock or shake-to-confirm behavior. It should also preserve the free path by making clear that smart reminders, daily reminders, and tracking remain available without Plus.

Use a short Plus benefit list, not a full Free-vs-Plus comparison table, for the v1 paywall. The list should focus on actual Plus benefits: app blocking after an unlogged due action and shake-to-unlock or shake-to-confirm behavior. Smart reminders, daily reminders, and tracking remain available in the free tier.

> **Superseded in part by [ADR 0004](0004-smart-reminders-move-to-pillie-plus.md):** Smart Reminders (the Auto-Reminder Retry escalation and the Snooze re-fire) are now a Pillie Plus entitlement and are no longer free. Only the primary daily reminder (the Due Action Reminder) and Supply Reminders remain free. The paywall now includes a "Smart Reminders" benefit row.
