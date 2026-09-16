# Soft paywall

The soft paywall is the Plus purchase sheet from onboarding and from Settings. Copy and CTAs change often.

## Sub-features

- `paywall-open` shows the paywall chrome.
- `paywall-commerce` shows `commerceAccessVerification` when the store is checking access.
- `paywall-restore` exposes `commerceAccessRestoreButton`.
- `paywall-retry` exposes `commerceAccessRetryButton` after a store failure.

## How to get to it (user POV)

- Finish onboarding until the paywall appears.
- Open Settings and choose the Plus / upgrade row when that row is on screen.

## Driving it with axe

Preconditions:

- Launch finished. Doctor passed.
- The axe dump or PNG already shows paywall chrome, or you opened it from Settings.

- **Confirm paywall.** Run `axe describe-ui --udid "$UDID"`. Look for Plus copy, `commerceAccessVerification`, or a purchase CTA. The dump is the source of truth for the current CTA string.
- **Restore.** If `commerceAccessRestoreButton` is present, tap it only when restore is the task. Watch for a visible result, not a silent return.
- **Retry.** If `commerceAccessRetryButton` is present, the store failed. Capture that state before you retry.
- **Proof.** Recapture. The 1x PNG shows the paywall, not Today behind a dismissed sheet. The axe dump contains the CTA you claim you changed.

## Gotchas

- CTA strings are localized and rewritten often. Never hard-code English from memory. Read the dump.
- A compile plus the launch PNG is not paywall proof.
- Simulator purchases need StoreKit testing. If checkout cannot run, say so and keep the rendered paywall as the proof.
- `humanizer` owns paywall prose. This skill only proves what is on screen.
