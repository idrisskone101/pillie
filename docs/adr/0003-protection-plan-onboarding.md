# Protection Plan Onboarding

Pillie's onboarding revamp will shift from generic reminder setup to a personalized protection-plan builder centered on the app-blocking differentiator. The flow will build a Draft Pill Protection Plan before monetization, then only request Screen Time authorization and save the real blocker configuration after the user has Plus, starts a trial, restores Plus, or already has entitlement.

The locked high-level order is: Welcome, Analytics Consent, Early Value Proof, Review Prompt, Distraction Choices, Delay Consequence, Failure Frequency, Risk Window, Draft Blocked Apps, Acquisition Source, Routine Basics, Reminder Time, Personalized Diagnosis / Draft Pill Protection Plan, Mechanism Proof, Paywall, then branch. The free branch shows Reminder Plan Ready. The Plus branch proceeds through Screen Time Primer, native Screen Time authorization, real FamilyControls app selection, and Pill Protection Plan Ready, falling back to Reminder Plan Ready if Screen Time is skipped or denied.

The revamp keeps Analytics Consent immediately after Welcome so PostHog capture remains consent-gated and events before consent are still dropped rather than buffered. The proof-before-permission pattern applies to Screen Time access, not Product Analytics Telemetry. The review prompt remains soft and skippable, placed after the early value-proof screen and before the first personal question.

Draft blocker choices are not real Screen Time selections. The draft flow can collect multiple Distraction Choices, including named app chips such as TikTok, Instagram, YouTube, Messages, X, Snapchat, and Other, plus broader behavior or category choices such as short videos, social feeds, games, snoozing, being busy, and forgetting. Pillie may derive one Primary Distraction for personalized copy, but the native FamilyControls picker later remains the source of truth for saved app blocking.

Implementation should add explicit stored onboarding answer types for the new protection-plan concepts: Distraction Choice, Delay Consequence, Risk Window, and Draft Blocked App Choice. Keep the existing MissFrequency storage with updated display labels, keep AcquisitionSource, and leave the old PersonalGoal model for compatibility without using it in the new flow.

The flow uses two proof screens. The early value-proof screen shows the moment Pillie catches the drift: a due action reminder, attention moving toward distracting apps, Pillie turning that moment into a pill-time checkpoint, and the home state updating after the due action is marked taken. The later mechanism-proof screen shows the lock only opens after the pill is handled: reminder rings, selected apps are blocked, and marking the due action taken unlocks them. Both must be truthful and avoid fake stats, testimonials, or medical claims.

The paywall appears before the Screen Time primer. It sells the user's Draft Pill Protection Plan with copy tied directly to app blocking for due-action time. Users who continue free skip Screen Time permission and enter reminder-only mode with blocking incomplete. Plus entitlement and blocker activation remain separate states: a Plus user who denies or skips Screen Time still has Reminder-Only Onboarding Completion, not Protection Plan Activation.

The protection-plan paywall should lead with Plus app blocking. The headline should be direct, such as `Unlock app blocking for pill time`, and benefits should focus on chosen apps staying locked until the due action is marked taken, on-device Screen Time handling, and editable setup. Keep one small free-path reassurance near the free CTA that daily reminders and tracking remain free.

The existing shake-to-confirm or shake-to-unlock Plus benefit should be removed from onboarding v1. It should not appear as a demo, headline, or paywall benefit in this protection-plan flow because it competes with the app-blocking differentiator.

The final saved blocker summary should show a generic selected-app count or state, not resolved app names. Draft diagnosis copy may mention the Primary Distraction from onboarding, but the real FamilyControls saved-selection summary should not depend on app-name resolution and should remain privacy-safe.

If the native FamilyControls picker returns with no apps or categories selected, Pillie should not mark blocker configuration as saved. The app selection step should keep the primary CTA disabled or show an inline empty state asking the user to choose at least one app, while preserving a `Skip for now` path to Reminder-Only Onboarding Completion.

If Screen Time authorization is denied, Pillie should show one denial recovery screen before completion. The screen should say app blocking is not enabled yet, offer a primary `Try again` action, and offer a secondary `Continue with reminders` path into Reminder-Only Onboarding Completion.

Protection Plan Activation requires onboarding completion, saved blocker configuration, and completed Screen Time authorization. Onboarding completion alone is not activation. Reminder-Only Onboarding Completion means reminders are ready and app blocking remains incomplete.

The visible progress indicator covers the plan-building calibration steps, not paywall, purchase, or native permission prompts. After the paywall, the Plus branch uses setup-status language for enabling Screen Time, choosing apps, and plan ready.

The design should evolve Pillie's existing soft premium brand rather than copying the Mobbin references directly. Keep Pillie's brand colors and premium feel, while improving pacing, hierarchy, fixed CTA behavior, segmented progress, selected states, and plan-reveal polish. Implement the calibration steps with a shared plan-builder question layout; keep Welcome, Analytics Consent, Review Prompt, proof screens, paywall, native permission, and final ready states bespoke.

The static Superdesign drafts are composition references, not the ceiling for the shipped experience. The implementation should add a SwiftUI-native interaction layer across the full flow using Pillie's existing semantic motion, haptics, performance-tier fallbacks, and iOS 17 SwiftUI APIs such as matched geometry, content transitions, phase/keyframe animation, TimelineView, and Canvas where appropriate. The early value-proof and mechanism-proof screens should be especially interactive: they should demonstrate Pillie catching post-reminder drift and locking distracting apps until the due action is marked taken. Every spatial animation must have Reduce Motion and constrained-performance fallbacks.
