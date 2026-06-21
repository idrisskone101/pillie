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
