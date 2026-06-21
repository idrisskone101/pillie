# Smart Reminders Move to Pillie Plus

Status: accepted (reverses the "smart reminders stay free" stance in ADR 0002)

Pillie will move Smart Reminders behind Pillie Plus as an entitlement, alongside Plus App Blocking. Smart Reminders is the umbrella for every same-day re-fire of a Due Action Reminder after the first: the automatic Auto-Reminder Retry escalation (the Interval and Retry Limit settings) and the user-initiated Snooze re-fire on the reminder notification. Free users keep exactly one Due Action Reminder per due action with no retries and no Snooze action.

This is a deliberate monetization decision and a real reversal. ADR 0002 listed "smart reminders, daily reminders, and tracking" as free-tier benefits and told the paywall to keep smart reminders free. That stance is superseded here. The carve-outs keep the trust posture intact for a contraception reminder app: the primary Due Action Reminder ("Daily reminders" on the paywall) stays free, and Supply Reminders (refill/restock) stay free. Only the follow-up escalation moves.

## Scope

Gated behind the `pillie_plus` entitlement:

- Auto-Reminder Retry (the `Auto-Reminder Interval` and `Auto-Reminder Retry Limit` settings).
- The Snooze action on the Due Action Reminder notification, which re-fires using the same interval and is functionally a user-triggered follow-up.

Explicitly NOT gated (remain free):

- The primary Due Action Reminder at the user's configured reminder time.
- Supply Reminders (pill refill, patch restock) and their threshold setting.

## Naming

The user-facing perk is named "Smart Reminders." The phrase "smart reminders" is no longer a free-tier benefit. "Daily reminders" continues to mean only the primary Due Action Reminder and stays free. Paywall and upsell copy must read Smart Reminders as the escalation ("Pillie keeps reminding you until you log it"), not as the base reminder, and must avoid medical, efficacy, or "never miss" claims per ADR 0002. The paywall comparison table keeps the free "Daily reminders" row and adds an adjacent "Smart Reminders" row marked Free ✗ / Plus ✓ so the contrast is legible. See the `Smart Reminders` and `Auto-Reminder Retry` terms in CONTEXT.md.

## Gating mechanics

Gating happens at the notification-planning layer, not by mutating stored settings. `NotificationManager` reads `SubscriptionManager.shared.isPlus`; when the user is not Plus it forces the effective retry limit to 0 and registers the reminder notification category without the Snooze action. The user's stored Interval and Retry Limit values are preserved untouched, so a user's prior preferences return automatically on upgrade and are not lost while they are on the free tier.

Entitlement changes must trigger a reschedule. Nothing reschedules on an `isPlus` flip today. On upgrade, Pillie reschedules so Smart Reminders apply for the remainder of the current day; on churn, the next reschedule drops retries and Snooze. This hook lives off the `SubscriptionManager` entitlement update path.

In Settings, free users see a single locked "Smart Reminders → Pillie+" row (the Blocked Apps pattern) that opens a Smart Reminders upsell sheet. Plus users see the two granular editable rows (Interval, Retry Limit) as today.

## Migration

Free users today already receive 3 retries plus Snooze, so this change silently reduces reminder behavior for the existing free population. Pillie will show a one-time, info-first upsell sheet on the first launch after the update to affected free users only: the sheet leads with reassurance that the daily reminder is still active, then introduces Smart Reminders as Plus with an upgrade path. It is shown at most once and only to users who completed onboarding before this change and are not Plus. Plus users and brand-new signups (for whom Smart Reminders was always Plus) never see it. Detection uses a one-time migration marker set at launch: if the marker is absent and onboarding is already complete, the user is eligible for the notice; new or mid-onboarding users are not.

## Considered Options

- Gate only the customization, keep retries running free at the default — rejected as too thin a perk (selling a settings screen, not a capability).
- Reduce the free default to a single fixed retry, Plus unlocks full — rejected in favor of the cleaner, stronger gate where free is exactly one reminder.
- Keep Snooze free while gating only auto-retries — rejected because Snooze is a user-triggered follow-up that would leave the gate porous.
- Grandfather existing free users — rejected; it creates a permanent two-tier free population, needs an install-date flag, and undercuts the monetization goal.
- Silent cutover with no notice — rejected as a trust risk for a contraception app silently reducing reminder reliability.

## Consequences

- Existing free users lose follow-up reminders; the one-time notice and the always-free primary reminder are the trust mitigations. Monitor for missed-dose or churn signal after rollout.
- The notification-planning layer now depends on subscription state, and reschedules are driven by entitlement changes as well as schedule edits. QA must cover upgrade-mid-day, churn, and the preserved-preferences-on-upgrade paths.
- This is hard to reverse: it changes packaging and a public free-tier promise. Reverting would mean re-promising smart reminders as free.
