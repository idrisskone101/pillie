# Today

Today is the home tab: the due action, this cycle's pill strip, the
blocking/trial status surfaces, and (when eligible) the review ask.

## Sub-features

- `today-open` shows the home tab after launch, with the due action
  reflected in the status card and the floating CTA.
- `today-status-card` shows the reminder time and the due-action line; it
  goes coral and reads "Checked in. Tap to undo." once taken.
- `today-pill-pack-card` shows this cycle's pill strip and the "This cycle"
  header.
- `today-mark-taken` is the real user path: tap the floating CTA, then
  Shake to Confirm (or its tap-to-confirm fallback), which marks today taken
  — and the same button undoes it.
- `today-blocking-card` shows `homeBlockingStatusCard` while app blocking
  isn't set up yet; dismissible, and it does not come back once dismissed.
- `today-protection-off` shows `homeProtectionOffCard` once Plus Access ends
  for a user who had saved blocker config — persistent, no dismissal.
- `today-refill-banner` shows the refill/new-cycle card once the pack is
  fully elapsed.
- `today-review-prompt` shows `homeReviewPromptCard` once an unbroken Streak
  clears the method-aware threshold and no higher-priority card is showing;
  it can be soft-dismissed.
- `today-trial-indicator` shows `#trialIndicator` during an active Reverse
  Trial and opens `TrialStatusSheet`.
- `today-trial-sheet` shows the activation checklist, the "after trial"
  rows, and the quiet `#trialKeepPlus` buy-early CTA.

## How to get to it (user POV)

- Launch the app. Today is the default tab.
- Tap the floating action button to log today's dose. Plus users confirm
  with a physical shake, or its "Tap to check in instead" fallback for
  accessibility.
- Tap "Checked in. Tap to undo." to undo a mistaken tap.
- Tap the small trial chip near the top (only visible during an active
  Reverse Trial) to open its status sheet; its own "Keep Plus" button is a
  real, quiet buy-early entry point.
- Tap "Set up app blocking" on the blocking card, or a card's own CTA, to
  continue those flows — out of scope here, see Gotchas.

## Driving it with flows

- `flows/today-home.flow` — `fresh` + `/plus-home` for a deterministic
  day-1 due pill (a fresh pack always starts untaken). Proves the status
  card, the pill pack card, and the blocking card, then marks the pill
  taken through the real path (floating CTA -> Shake to Confirm -> its tap
  fallback), proves the taken state, and undoes it.
- `flows/today-trial.flow` — `/trial-eve-of-break` for the pack's last
  hormone-active day, then `/trial-clear` + `/trial-grant` +
  `/trial-age?days=5` for a deterministic mid-trial day. Proves
  `#trialIndicator` and `TrialStatusSheet` in both states. Never taps
  `#trialKeepPlus`.
- `flows/today-review-prompt.flow` — `/review-prompt` seeds an eligible
  Streak. The flow dismisses the blocking card first (it always renders on
  a fresh, unconfigured pack and outranks the review ask) before proving
  `homeReviewPromptCard`, then dismisses it.
- `flows/smoke.flow` covers the plain tab bar (Today/History/Settings) with
  `/plus-home`.
- Not covered by an authored flow, and why: `ProtectionOffCard` needs an
  expired trial with a saved blocker config (reachable by combining
  `/trial-eve-of-break` with a larger `/trial-age?days=N`, past the 14-day
  clock); `RefillBannerCard` needs the pack's last elapsed day (reachable
  via `/trial-break-week`, which lands on cycle day 28 of a 21/7 pack); and
  `TrialDeclineFeedbackView` sits behind the Trial-End Paywall's "Continue
  Free" path, several steps past what these three flows set up.

## Gotchas

- The floating CTA and the StatusCard subtitle can show the identical
  due-action label (e.g. "Take pill") on screen at once; only the floating
  Button answers hit testing, the same shape already proven for the
  Today/History/Settings tab labels, so `tap --label` still resolves to the
  CTA.
- Shake detection cannot be driven on the simulator. Always use
  `#shakeTapToConfirmFallback` ("Tap to check in instead").
- `homeBlockingStatusCardDismissed` is a persistent `@AppStorage` flag that
  survives `launch`. Start a flow from `fresh` whenever it needs the
  blocking card in its default (not dismissed) state.
- The Review Prompt card is gated behind every higher-priority card
  (`ProtectionOffCard`, `BlockingStatusCard`, the refill banner) — dismiss
  those first or the review card never renders.
- `/trial-eve-of-break` and `/trial-break-week` are about the pill pack's
  break week (hormone-active vs. placebo days), not the trial clock. Don't
  confuse them with `/trial-age`, which ages the Reverse Trial itself.
- `developerMenuAvatarButton` is debug-only. Do not treat it as a user path.
- Never tap `#trialKeepPlus` or any other purchase/subscribe control — they
  open `HonestPaywallHost`/StoreKit, which the simulator cannot complete.
- A fresh install's default pack lands on its break day ("Day 28 of 28", "Nothing to do today."). `today-home.flow` pins the clock and applies the `missedRecentDays` scenario to get a due pill. Verified live.
- Developer-menu row ids leak onto the row's child texts and icon. The runner taps the first on-screen match, so `tap --id developerScenario.<name>` works in a flow; raw `axe tap --id` would see 3 matches.
