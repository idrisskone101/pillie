# Home Review Prompt — Two-Step Sentiment Gate

Pillie will grow App Store ratings with a **Review Prompt** on Home: a two-step ask shown only after a user reaches **Review Prompt Eligibility**. Step one is a **Sentiment Gate** ("Enjoying Pillie?"); a positive response fires a **Native Review Request** (Apple's `requestReview`) and a negative response opens a **Feedback Escape Hatch** (a pre-filled Mail composer to `pillieapp@gmail.com`). It is shown to free and Plus users alike and never gates app use.

## Context

Pillie has very few ratings, which suppresses store conversion and discovery. There is no in-app rating path today and no support/feedback channel; `StoreKit` is imported in Settings but unused.

An earlier attempt — the in-onboarding `reviewPrompt` step described in ADR 0003 — asked for a rating right after the value-proof screen, before the user had completed a single due action. It was retired (the enum case survives only to keep persisted `onboardingStep` values stable; it is dropped from `displayOrder` and renders `Color.clear`). Its failure mode is the whole motivation here: **asking before demonstrated success burns goodwill and Apple's prompt budget on users who have no reason yet to be happy.**

## Decision

**Two-step gate, never a direct prompt.** The Home card asks sentiment first. Only a positive response reaches Apple's native prompt; negatives are diverted to private feedback. This protects the public star average and Apple's cap of three system prompts per user per 365 days by spending prompts only on users who self-report as happy.

**Eligibility is an unbroken Streak crossing a method-aware threshold** — pill `>= 3`, patch `>= 1`, ring `>= 2`. Because a Streak counts completed due actions (not calendar days) and due-action cadence differs by method (pill daily, patch weekly, ring cyclic), a single fixed threshold would ask pill users in a week and effectively never ask ring users. Method-aware thresholds target roughly the same "~1–2 weeks of demonstrated success" across methods. Ring is `>= 2` rather than `>= 1` specifically so the day-one ring insertion does not fire the prompt at setup. A Streak inherently encodes calendar tenure, so there is no separate days-since-install floor.

**Lifecycle.** A positive or negative response suppresses the prompt permanently. A soft dismiss (the close control) starts a 90-day cooldown and is permanently suppressed after 3 total appearances. The 90-day cooldown is far longer than the Adaptive Reminder card's ~14 days on purpose — a rating ask is higher-stakes and shares Apple's annual budget.

**Negative path is `mailto:` only.** Pillie has no backend, so the Feedback Escape Hatch opens the native Mail composer pre-addressed to `pillieapp@gmail.com`. A device without a configured Mail account is tolerated (the prompt is still marked answered), not blocked on.

**Yields to other Home cards.** The Review Prompt is the lowest-priority Home card and shows at most one "ask" per visit: it stays hidden when the Refill, Adaptive Reminder, or Blocking card would render. It sits after `StatsRow` so it never pushes the pill/cycle card down.

**Telemetry stays PII-free (ADR 0001/0004).** Four flat, property-free events — `reviewPromptShown`, `reviewPromptPositiveTapped`, `reviewPromptNegativeTapped`, `reviewPromptDismissed`. Contraception method, Streak value, appearance ordinal, and feedback text are never sent.

**Highest testable seam.** Eligibility is a pure `ReviewPromptEligibility.evaluate(for: State) -> Decision` value type (mirroring `ProtectionPlanCompletion.outcome(for:)`), with the card-competition rule folded in as a `higherPriorityCardShowing` input so every branch — thresholds, cooldown, lifetime cap, permanent suppression, yielding — is value-type tested without hosted XCTest.

## Consequences

- The star average and Apple's 3/365 prompt budget are protected; only self-identified happy users reach the public rating flow.
- Unhappy users get a private channel, and the maintainer receives real qualitative feedback by email.
- Ratings volume is deliberately traded down in exchange for rating quality: unhappy users are routed away from the store, and positive/negative responders are never re-asked even after Apple's annual quota resets.
- Method-aware thresholds add a small amount of branching but are the only way to ask non-daily-method users within a reasonable window.
- The `requestReview` fire and Mail composer are best-effort imperative shims; Pillie never assumes the system sheet appeared or that a rating was left, and these are verified by simulator/real-device proof rather than unit tests.

## Alternatives Considered

- **Direct `requestReview` for everyone.** Simplest, but spends scarce prompts on frustrated users and can drag the star average down. Rejected.
- **Deep link to the App Store write-a-review page.** Unlimited asks, but high-friction (leaves the app, full review form) and converts far worse than the native sheet. Rejected.
- **A single fixed Streak threshold across methods.** Simple, but asks pill users in ~1 week and ring users in ~6 months (effectively never). Rejected for method-aware thresholds.
- **A days-since-install eligibility floor.** "Installed a while" says nothing about whether Pillie is working; an idle user would qualify. Rejected — Streak both proves success and encodes tenure.
- **In-onboarding rating ask** (the retired `reviewPrompt` step). Asks before any success. Rejected; this ADR is its successor.
