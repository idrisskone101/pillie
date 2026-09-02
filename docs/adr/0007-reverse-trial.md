# Reverse Trial Replaces the Onboarding Paywall

Status: accepted (supersedes the paywall placement in [ADR 0002](0002-onboarding-soft-paywall-plan-mix.md) in part)

The 2026-07-02 marketing audit showed the onboarding paywall converting at zero (54 viewers, 36 chose free, 9 sheet attempts, 0 completed purchases) while ~98% of users never experienced Plus App Blocking — the feature all acquisition sells. We decided to stop selling before value is felt: every user without a Plus entitlement receives a Reverse Trial — 14 full local calendar days of full Plus Access, granted automatically with no payment details — and the purchase ask moves to a loss-framed Trial-End Paywall after the user has lived with the blocker. PRD: issue #158.

## Decisions and reasons

**Full Plus, one predicate.** The trial unlocks everything Plus does (blocking, Smart Reminders, Custom Reminder Messages) through a single Plus Access gate (`entitlement || trialActive`). No per-feature trial flags — the trial must feel exactly like Plus, and scattered `isPlus` call sites get consolidated behind one choke point.

**Client-side trial state (Keychain), not RevenueCat promotional entitlements.** RC promotional entitlements would unify gating and analytics with real subscriptions, but the grant requires a server-side call with the secret API key, and Pillie deliberately has no backend. Trial state therefore lives on-device: a grant timestamp in the Keychain (survives reinstall well enough; some abuse leakage is accepted for v1) — this is the app's first Keychain use; everything else is UserDefaults, which reinstall would wipe. Trial users are invisible to RevenueCat dashboards; PostHog events carry the cohort instead. **Migration trigger:** if trial→paid conversion clears the ≥3% keep-going bar, invest in the RC promotional-entitlement path (cloud function grant) for cross-device consistency and RC cohort analytics.

**Not a StoreKit trial.** The existing 7-day StoreKit intro offer is removed from the products and the "starts with a 7-day free trial" paywall copy goes with it. The Reverse Trial replaces it, so the trial-end purchase sheet is a clean direct buy with no nested trial. The pre-existing `trial_started` analytics event keeps its StoreKit meaning; the Reverse Trial fires a distinct `trial_granted` event.

**Grant at app-blocking setup, not onboarding completion.** Issue #204 retires the Trial Granted Moment as a mandatory gate after production data showed it was the flow's largest conversion leak. The reminder-plan diagnosis now proceeds directly to app-blocking setup, where a compact disclosure says Plus is unlocked for 14 days with no card required and trial state is written on appearance. Blocker setup therefore still runs under real Plus Access with no promissory special case; onboarding abandoners burn trial days, which we accept. Existing free users are granted on first launch after the introducing update, announced with a one-time sheet that deep-links into blocker setup (they are the warmest PMF cohort — 36 users explicitly took the free door).

**Expiry at local midnight after day 14.** Never mid-blocking-window: the last trial day is fully protected and warning copy can honestly say "tonight." Blocking must never outlive Plus Access even if the app is not opened after expiry — the shield/DeviceActivity side gets a coarse access-valid-until date mirrored into the App Group so it can self-disable; the Keychain copy stays authoritative.

**Zero proactive pressure during the trial.** No upsell surfaces before the day-10 warning; the N-days-left indicator is informational, with passive buy-early paths (indicator tap-through, Settings upgrade row). Day-10/13 local notifications are scheduled at grant and cancelled on purchase.

**Trial end: one dismissible sheet + persistent Protection Off State card, cohort-framed.** Users with blocker configuration get loss framing around their own trial record (blocks intercepted, on-time doses, streak); users who never configured the blocker get a gain-framed offer instead — they have nothing to lose yet. No launch-loop paywall; reminders stay free forever and the app is never hard-gated.

**Pricing: $29.99/year lead, $4.99/month.** Chosen over the higher end of the tested range because 7 of 9 purchase attempts died at the App Store payment sheet at $9.99/month, and the base (~175 new users/28d) is too small for a real price A/B inside the 6-week window. The cheap price is deliberate: a miss on the ≥3% bar should read as "won't pay for this product," not "won't pay this price." Revenue per user is not the question yet; PMF is.

**Kill criteria.** ≥3% trial→paid = keep going; ~0% after ~6 weeks = the honest kill signal — if people feel the blocker for 14 days and still won't pay, that answers the PMF question.

## App Review posture

A developer-granted free period involves no payment, so guideline 3.1.1's IAP requirement is not triggered; the only purchase in the flow is a standard StoreKit buy at the Trial-End Paywall. This is the established promotional-access pattern (RevenueCat promotional entitlements, referral and win-back programs). App-blocking setup clearly states the 14-day duration and that no card is required without turning setup into purchase UI; the in-app trial-status surface carries expiry detail, and the Trial-End Paywall meets the usual 3.1.2 subscription-paywall requirements (price, term, auto-renewal disclosure, restore, ToS/privacy links). The Tier-0 "XX-day Trial" non-consumable described in 3.1.1 is a permissive mechanism addressed to non-subscription apps, not a requirement here.

## Consequences

- `blocker_intervention_fired` cannot be a live event (the shield extension is sandboxed, no network); interventions are counted in the App Group and flushed on next app open. The same counter feeds the Trial-End Paywall's own-stats.
- Lapsed former subscribers count as "without Plus" and receive a Reverse Trial; the cohort is tiny and this is accepted.
- ADR 0002's paywall sequencing (paywall before the Screen Time branch, free-plan confirmation branch) is superseded; its calibration-step ordering and truthful-copy rules stand.

## Measurement taxonomy and interpretation guardrails (#217)

The Reverse Trial value funnel is interpreted as:

`trial_granted → blocker activation → realized value → trial_expired → trial-end paywall → purchase_started → rc_initial_purchase`

RevenueCat remains authoritative for a real initial purchase. `purchase_started` is intent, and neither it nor an in-app completion event should be treated as subscription truth.

| Event | Required coarse context | Interpretation |
| --- | --- | --- |
| `trial_badge_tapped` | `source = home`, `is_plus` | The passive Home indicator was deliberately opened. |
| `trial_status_sheet_viewed` | `source = home`, `is_plus` | The status sheet became visible; it is not a purchase impression. |
| `trial_status_feature_tapped` | `feature = app_blocking \| shake_to_confirm \| smart_reminders \| custom_messages` | Interest in one named Pillie-authored perk, never user content. |
| `paywall_viewed` | Existing `source` plus `surface = trial_status \| settings_subscription \| blocking_gate \| smart_reminder_gate` where applicable | `source` stays backward-compatible; use `surface` to distinguish the concrete entry point. |
| `blocker_setup_skipped` | `authorization_state = not_requested \| denied \| authorized` | Segments the setup boundary without selected apps, categories, or token counts. |
| `smart_reminder_retry_scheduled` | `retry_count` | Count of newly queued retry requests in one scheduler diff, not every reschedule attempt. |
| `smart_reminder_retry_fired` | `is_plus` | A retry was delivered in the foreground or later handled; request ids are used only for local dedupe and are never captured. |
| `smart_reminder_outcome` | `outcome = opened \| completed \| snoozed`, `is_plus` | The action taken on that retry notification. It does not claim medication adherence beyond the recorded app action. |

Do not attach reminder title/body, medication or regimen data, reminder times, FamilyControls selections/tokens/counts, notification request identifiers, or session-replay identifiers to these events. Counts and closed enums are the privacy boundary.

### Production-safe verification plan

Use a Debug build and the analytics OSLog mirror; do not send simulator or TestFlight QA traffic to production PostHog. Start from a fresh local analytics state, perform one interaction at a time, and verify exactly one matching log line before continuing:

1. Tap the Home trial badge once; expect one `trial_badge_tapped`, then one `trial_status_sheet_viewed` when the sheet appears.
2. Tap one unlocked feature item; expect one `trial_status_feature_tapped` with only its approved `feature` value.
3. Tap **Keep Pillie Plus**, the Settings subscription row, a blocking gate, and the Smart Reminders gate in separate runs; each `paywall_viewed` keeps its legacy `source` and has the matching stable `surface`.
4. Exercise blocker skip before requesting Screen Time, after denial, and after authorization; expect one persisted `blocker_setup_skipped` per onboarding install with the matching `authorization_state` and no selection data.
5. Trigger one authorized reminder rebuild with newly missing retries; expect one `smart_reminder_retry_scheduled` whose `retry_count` equals the newly queued retry requests. A no-op rebuild must emit none.
6. Deliver or handle one retry request; expect one deduplicated `smart_reminder_retry_fired`. Open, mark complete, or snooze it; expect one `smart_reminder_outcome` with the corresponding enum and no notification content or identifier.
