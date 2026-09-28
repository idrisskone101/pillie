# Today

Today is the home tab: the due action, this cycle's pill strip, the
blocking/trial status surfaces, and (when eligible) the review ask.

## Sub-features

- `today-open` shows the home tab after launch, with the due action
  reflected in the status card and the floating CTA.
- `today-status-card` shows the reminder time and the due-action line; it
  goes coral and reads "That's logged. Tap to undo." once taken.
- `today-pill-pack-card` shows the V1 pack card for pill users
  (`HomePackCard`, ENG-145): "Pill 12 of 28" header, weekdays, grid, today
  ringed, an untaken pill past its reminder late (amber) and missed once the
  next reminder fires (ENG-148), "…" menu (`#homePackOptions`) with Change pack type
  (`#homePackChangeType`, the onboarding pack sheet) and Start new. A log pops today's
  tile once Home is visible again.
- `today-countdown-card` shows the V4 countdown card for patch and ring
  users (`HomeCountdownCard`, ENG-149): gauge with the patch, sachet or ring
  art, a day countdown or "Today" / "Late" / "Missed", and the milestone
  track (Patch 1, Patch 2, Patch 3, Off, New pack; or In, Out, Back in).
  States come from `HomeCountdownProgress`. The "…" menu
  (`#homeCountdownOptions`) starts a new cycle. It has no log button.
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
  with a physical shake, or its "Tap to Confirm Instead" fallback for
  accessibility.
- Tap "That's logged. Tap to undo." to undo a mistaken tap.
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
- `flows/today-pack-card.flow` — the pack card's last hormone pill, sugar
  week, and finished pack headers via `/trial-eve-of-break`,
  `/trial-break-week`, and `/fixed-now` one day later.
- `flows/today-late-missed.flow` — pins the clock to midday, then
  `/trial-eve-of-break` leaves pill 21 untaken past its reminder: the tile is
  late and the header reads "Late · still time until 8:00 AM tomorrow". One
  live day later (`/fixed-now`) pill 21 is missed ("Pill 21 missed
  yesterday"), its tile `#packTile.21` opens the History day sheet, and
  marking it taken redraws the card.
- `flows/today-change-pack.flow` — the "…" menu's Change pack type opens
  the pack sheet, then the Settings "Reset Tracking Data?" confirmation.
  Cancel keeps the pack; Reset & Save starts the new pack at pill 1 today.
- `flows/today-patch-countdown.flow` — `/routine-day?method=patch&day=N`
  plus `/fixed-now` walks the patch card: wearing (day 10), late change
  (day 15), logged through the real CTA ("On today"), missed the next day
  (Home's button reads "nothing due today"), late off day, patch-free week,
  day 29 new cycle due, and "Start new" from the card menu (patch 1 due under
  the start-day grace).
- `flows/today-ring-countdown.flow` — the same for the ring: wearing, late
  out, logged out, ring-free week, the day-29 reinsert (late, then logged,
  which starts the next cycle), day 30 new cycle due, and a missed insertion.
- `pillie://debug/countdown-card` opens a gallery of the 16 Paper lifecycle
  cards built from fixed `HomeCountdownProgress` values.
- `flows/today-long-pack.flow` — onboarding picks a Custom 88 + 3 pack, then
  Home opens its card on the page with today ("Weeks 5 to 8 of 13").
- `flows/today-sugar-pill.flow` — a 21 + 7 sugar day is due ("Take pill"),
  logs, undoes and logs again without moving the streak; History reads the
  open sugar day as "Not logged" (never "Break") and as "Done" once taken; a
  21 only pill-free day stays "Nothing to take".
- `flows/today-notification-complete.flow` — `/notification-complete` runs
  the reminder's Complete action while Home is open; the status card, CTA and
  pack card all flip to taken.
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
  `#shakeTapToConfirmFallback` ("Tap to Confirm Instead").
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
- A fresh install's default pack lands on its break day ("Day 28 of 28", "There's nothing due today."). `today-home.flow` pins the clock and applies the `missedRecentDays` scenario to get a due pill. Verified live.
- Developer-menu row ids leak onto the row's child texts and icon. The runner taps the first on-screen match, so `tap --id developerScenario.<name>` works in a flow; raw `axe tap --id` would see 3 matches.
