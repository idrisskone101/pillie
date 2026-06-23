# Last Call Reminder is a distinct end-of-day Smart Reminders sub-feature

We are adding a **Last Call Reminder**: a single same-day end-of-day re-fire of a Due Action Reminder that fires only when the due action is still untaken, as a final backstop before the day rolls over and the action becomes `.missed` at midnight. It is a Pillie Plus feature under the [[Smart Reminders]] umbrella, but it is modeled as its own concept with its own on/off toggle, **not** as a configuration of the existing Auto-Reminder Retry cadence. It fires at a configurable time (default 9:00 PM local) and adds a title+body pair to the Custom Reminder Message perk (now six fields total).

## Considered Options

- **Fold it into Auto-Reminder Retry** (rejected): the retry cadence is interval-driven and capped by the retry limit, and stops well before end-of-day for morning reminders. A user with retry limit 0, or whose retries are exhausted, would get no backstop — which is exactly the case the Last Call exists to cover.
- **Make it free** (rejected): consistent with ADR 0004, every same-day re-fire after the first is a Smart Reminder, and Smart Reminders are Pillie Plus. Keeping Last Call Plus preserves that boundary and the differentiator story.

## Consequences

- **Fires independently of the retry limit.** This is the surprising part: a Plus user with Auto-Reminder Retry off still gets a Last Call. The independence is deliberate — Last Call is a backstop, not the tail of the retry escalation.
- **Suppression rule:** only scheduled if its time is ≥ 60 min after the reminder time (kills the evening-reminder and naggy cases), and any retry firing within ~15 min of it is dropped to avoid back-to-back notifications.
- **Pre-scheduled per upcoming due-action day** (7-day horizon, mirroring base reminders) so the backstop survives the app being closed. Total pending stays ~20, well under the 64 cap.
- Applies to all methods with method-aware copy; Pillie-authored defaults obey the medical-claims copy rules.
- Gating follows ADR 0004: enforced at notification build time via the `pillie_plus` entitlement, stored settings never mutated.
