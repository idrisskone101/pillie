# Adaptive Reminder Time Suggestion is on-device and suggest-only

We are adding an **Adaptive Reminder Time Suggestion**: a Pillie Plus feature that detects when a user consistently logs at a different time than their reminder fires and proposes shifting the reminder toward their real rhythm. The detection runs entirely on-device from a newly persisted per-log timestamp, it only ever **suggests** (the user confirms the change), and it surfaces as a dismissible in-app card rather than a push notification.

## Considered Options

- **Auto-adjust the reminder time silently** (rejected): reminder time is a Schedule-Critical Setting that also anchors the app-blocking window. Silently moving it would change when blocking starts and surprise the user — too much trust risk for a contraception app. Suggest-and-confirm keeps the user in control.
- **Mine log times from Product Analytics Telemetry** (rejected): dose outcomes and routine timing are excluded from telemetry by construction (ADR 0001 / CONTEXT.md). The signal must stay on-device.
- **Deliver the suggestion as a push** (rejected for v1): acting on it is an in-app action, and a push for a low-urgency settings tweak competes with the actual reminders and adds notification fatigue.

## Consequences

- **New persisted data:** `PillDay` gains a `takenAt` timestamp (a SwiftData `@Model` schema migration). This is the hard, not-easily-reversible part — it changes the stored data shape and is the prerequisite for the whole feature.
- **Privacy boundary:** the log-time signal is on-device only and is never sent as Product Analytics Telemetry; only coarse adoption signals (suggestion shown / accepted / dismissed) may be captured.
- **Detection (tunable):** over the last ~10–14 logged due actions, if the median log-vs-reminder offset is ≥ ~30 min with low spread, suggest shifting toward the median (rounded to 5 min). One suggestion at a time, dismissible, ~14-day cooldown, no re-pitch of the same delta after a dismissal.
- It does not add or change any Smart Reminders re-fire; it only proposes moving the primary reminder time.
