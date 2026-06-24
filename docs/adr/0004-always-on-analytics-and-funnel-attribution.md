# Always-On Analytics and Funnel Attribution

Supersedes the consent-gating parts of [ADR 0001](0001-posthog-product-analytics-telemetry.md). The PII-free event taxonomy and "no Apple-defined Tracking" boundary from 0001 still hold; what changes is that capture is no longer gated on an onboarding Analytics Consent step.

## Decision

Pillie collects first-party Product Analytics Telemetry for everyone, starting at app launch — there is no Analytics Consent screen and no opt-out. The protection boundary is now the event taxonomy alone: the payload is PII-free by construction (low-cardinality labels only; no contraception method, reminder times, app names, answer values, or free text — see `AnalyticsPayload`). The onboarding consent step and the in-app opt-out were retired because the data they gated was small and the taxonomy is already safe. The PostHog wrapper still disables capture only when the project token is missing.

This makes the funnel readable end to end. Capture begins at launch, so `app_launched` is the top of the activation funnel and fires for every install — there is no consent gate to drop the early steps. `onboarding_started` likewise fires for every new onboarding entry (the historical undercount was the old gate dropping the pre-consent start event while the post-consent completion survived).

## Funnel and install reconciliation

The canonical activation funnel is `app_launched → onboarding_started → onboarding_completed → paywall_viewed → trial_started → purchase_completed`.

PostHog cannot see total install volume — there is no pre-launch event to count, and `Application installed` will read zero. Total installs come from **App Store Connect**, reconciled against PostHog's `app_launched` periodically. The consent opt-in rate that earlier scoping treated as the key lever is no longer a metric: there is no consent screen to opt into.

## Paid conversions: trial vs paid, sandbox excluded

`purchase_completed` and `trial_started` are distinct funnel steps, classified from the purchased entitlement's RevenueCat `periodType` (`.trial` → `trial_started`; otherwise `purchase_completed`). A trial start is the dominant drop-off given how few installs reach a paid charge, so it must be visible on its own.

Sandbox transactions (`EntitlementInfo.isSandbox` — development, TestFlight, App Review) never count as real conversions and emit no analytics event, so they cannot inflate paid metrics. The classification lives in a pure value type (`PurchaseOutcome.conversionEvent`) so it is unit-tested without RevenueCat.

In-app `purchase_completed` therefore counts only immediate paid charges; it cannot see later trial→paid conversions or renewals (the app is not running then). RevenueCat's native PostHog integration is enabled to deliver those server-side as the source of truth for real-payer, renewal, and conversion counts. RevenueCat's events carry their own names and are kept distinct from the in-app events so a single funnel never double-counts. The two are joined to the same person by setting the PostHog distinct id as RevenueCat's reserved `$posthogUserId` subscriber attribute at configure time.

## Acquisition source

`acquisition_source` is captured both as an event property (as before) and promoted to a PostHog **person property** via `$set` — so the funnel can be broken down by source — and to a RevenueCat **subscriber attribute** — so paid conversions segment by source and flow to PostHog via the integration. The person property is set without `identify()` (preserving 0001's no-cross-device-identifier stance); because users never identify, `personProfiles` is set to `.always` so the `$set` sticks for anonymous users. As acquisition source is only known mid-onboarding, funnel steps before that step do not carry it.

## Consequences

- Privacy disclosures (App Store Connect answers, privacy policy) must continue to describe first-party PostHog analytics, now without a consent gate; the taxonomy boundary is what keeps this out of Apple-defined Tracking.
- `personProfiles = .always` creates a person profile for every anonymous user (negligible at current volume).
- The retired consent UI (`AnalyticsConsentView`, `ProtectionPlanAnalyticsConsentView`), the unused `setOptedOut` opt-out path, and the persisted `AnalyticsConsentDecision` have been removed as dead code. The `analyticsConsent` onboarding step *case* is retained only so persisted step values migrate forward; it is never rendered.

## Instrumentation hardening (#140)

A funnel investigation found the events were untrustworthy — incoherent ordering (`onboarding_completed` > `onboarding_started`, `paywall_viewed` > `app_launched`) and only ~25% of installs visible in PostHog versus RevenueCat. Four refinements harden the taxonomy above without changing its privacy boundary.

### Coverage: a missing token must be loud, not silent

The dominant cause of the coverage gap was a missing `PostHogProjectToken`: `configure()` returned early and **every** `track()` no-opped silently, so any build channel without the (gitignored) `Secrets.xcconfig` shipped a fully dark client. Decisions:

- The token — a write-only PostHog *ingestion* key, safe to ship in the client binary — is committed to `Config/Release.xcconfig` so every Release/TestFlight/App Store build emits. Debug builds intentionally stay token-less so developer/simulator runs never pollute the production funnel.
- A missing/empty token is no longer silent: `AnalyticsManager` fault-logs (`os_log(.fault)`) and exposes `didFailConfiguration` for tests/diagnostics. (Debug is token-less by design, so this is a log + flag, not a crashing assertion.)
- Buffered events are flushed when the app enters the background (`scenePhase == .background`). TikTok installs that bounce mid-onboarding previously lost their early funnel events (`app_launched`, `onboarding_started`) before PostHog's periodic flush.

### `onboarding_started` fires exactly once per install

Previously `onboarding_started` fired only when the *legacy* `onboardingStep` integer was exactly `0`. After the two-step-machine split (the new Protection Plan intro shell owns the first screens while `onboardingStep` stays `0`, then the handoff jumps `0 → painPoints`), this missed resumed-mid-onboarding users entirely and was fragile for new installs — so it lagged far behind `onboarding_completed`. It is now gated by a **persisted once-per-install latch** (`UserDefaults` key `onboarding_started_emitted`): the first time onboarding is entered — at whatever step the user lands on — it fires exactly once and survives app restarts, view re-mounts, and step migration. Already-onboarded users (whose terminal step maps to no analytics step) never arm the latch.

### `step_index` and how to build the funnel

Every onboarding step event (`onboarding_step_viewed`/`_completed`) now carries a `step_index`: the step's 0-based position in `OnboardingFlow.displayOrder` (`OnboardingFlow.displayIndex(for:)`), the canonical render order — not the frozen raw value, which has migration gaps. **Build the per-step funnel on `step_index`, not the `step` label.** Two consequences to know when building it:

- The bespoke answer-commit events (`distraction_choices`, `delay_consequence`) re-label the painPoints/goal screen completions and are intentionally **index-less** — they are supplementary answer signals, not funnel steps, so an index-keyed funnel excludes them cleanly.
- The new intro-shell screens live in a separate step machine and do not emit per-screen step events, so a new install's index sequence is `0` (welcome) then `4`+ — a **gap at indices 1–3**. Per-screen drop-off across the intro shell is not yet measurable; instrumenting `ProtectionPlanStep` transitions is a follow-up.

### `acquisition_source` for every answered user

The acquisition answer is persisted on device (`pillie_acquisition_source`). It is now `$set` on the guaranteed-fire `app_launched`/`app_became_active` events whenever known — not only on the deep "how'd you hear" step — so a user who answers and then drops before completing onboarding is still attributed. When unanswered it is omitted (no synthetic value). This refines the earlier note that "funnel steps before that step do not carry it": the value still cannot exist before the user answers, but once answered it rides every subsequent launch.
