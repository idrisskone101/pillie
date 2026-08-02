# Cohort-Gated Hard Paywall After the Reverse Trial

Status: accepted (supersedes ADR 0007's free-forever and one-shot trial-end decisions for post-cutover cohorts)

Production evidence through 2026-08-01 showed that retained users value Pillie, but the optional free exit removes the purchase decision: 35 of 35 expired-trial users chose Continue Free and none purchased. Pillie will keep the 14-day Reverse Trial and end the free tier only for trials granted on or after **2026-08-14 00:00 America/Montreal**. PRD: issue #257.

## Decisions and reasons

**Terms are fixed when the grant is persisted.** `trialGrantDate` remains the read-only Keychain-backed clock input. A grant before `2026-08-14 04:00:00Z` keeps legacy terms; a fresh post-cutover install receives hard-paywall terms. The app records an immutable install assignment before onboarding state can change, and recognizes pre-existing onboarding state as a legacy installation. That assignment is persisted beside the grant in the Keychain, so an existing installation or trial never changes cohorts mid-trial or after reinstall. Existing-user update grants are explicitly legacy.

**The 14-day Reverse Trial and `pillie_plus` entitlement stay unchanged.** Both cohorts receive the same full Plus trial. Active monthly, annual, or lifetime purchases unlock the same existing `pillie_plus` entitlement; there is no entitlement migration and no feature-specific paid predicate.

**Legacy remains legacy.** A pre-cutover trial still reaches the dismissible trial-end offer, may Continue Free, and retains the existing reminder-only behavior. Already-expired users remain usable and can reach the lifetime option from ordinary Plus upsells.

**Post-cutover expiry is a hard wall.** The expired-trial cover has no close or Continue Free action, ignores ADR 0007's one-shot shown flag, and reappears on launch until Plus is active. Foreground access reconciliation also re-runs presentation when a trial expires while Pillie was suspended. Restore Purchases remains available on the wall.

**RevenueCat offering metadata is the kill switch.** The current offering's Boolean `hard_paywall_enabled` is refreshed on launch. Explicit `false` restores legacy terms for post-cutover grants without an app update, including a one-time legacy expiry surface after a hard wall was previously shown. Missing or malformed metadata keeps the ratified cutover enabled. Auto-presentation waits for the first configuration refresh so an active rollback cannot briefly show the hard wall from stale launch state.

**Lifetime is a secondary bridge, not a new entitlement.** `com.idrisskone.pillie.plus.lifetime` is a USD 69.99 non-consumable. RevenueCat must expose it as the current offering's lifetime package and map it to `pillie_plus`. Trial-end and ordinary Plus upsell surfaces resolve that same product identifier and use the same purchase and restore validation as subscriptions.

## Measurement and privacy

Trial-end `paywall_viewed`, plan-selection, purchase, and restore events carry the closed `trial_terms_cohort = pre_cutover | post_cutover` property. The existing `cohort = blocker_configured | reminder_only` wire contract remains intact, with the same value also exposed as the explicit `paywall_variant` alias. No grant date, schedule, health data, user text, or other identifier is captured. RevenueCat remains authoritative for completed paid conversion and renewal data.

## Consequences

- Shipping before the cutover is safe because the immutable installation/grant assignment selects terms before the hard wall can apply.
- An offline or failed RevenueCat offerings refresh uses the ratified enabled default; a successful later launch still picks up an operator rollback.
- App Store Connect configuration and RevenueCat package/entitlement mapping are operational release dependencies; attaching a build or submitting a version is not part of this decision.
- ADR 0007 continues to govern trial granting, duration, Plus Access, warnings, and legacy expiry behavior.
