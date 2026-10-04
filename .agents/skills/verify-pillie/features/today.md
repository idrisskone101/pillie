# Today

Today is the home tab: the due action, this cycle's pill strip, the
blocking/trial status surfaces, and (when eligible) the review ask.

## Sub-features

- `today-open` shows the home tab after launch, with the due action
  reflected in the status card and the floating CTA.
- `today-status-card` shows the reminder time and the due-action line; it
  goes coral and reads "Checked in. Tap to undo." once taken.
- `today-pill-pack-card` shows the V1 pack card for pill users
  (`HomePackCard`, ENG-145): "Pill 12 of 28" header, weekdays, grid, today
  ringed, an untaken pill past its reminder late (amber) and missed once the
  next reminder fires (ENG-148), "…" menu (`#homePackOptions`) with Change pack type
  (`#homePackChangeType`, the onboarding pack sheet) and Start new. A log pops today's
  tile once Home is visible again.
- `today-countdown-card` shows the V4 countdown card for patch and ring
  users (`HomeCountdownCard`, ENG-149): gauge with the patch, sachet or ring
  art, a day countdown or "Today" / "Late" / "Overdue", and the milestone
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
  Trial and opens `TrialStatusSheet`. It reads a plain countdown ("14 active
  days left") until blocking is on, then "Plus is on · …".
- `today-trial-sheet` is status and commerce only: countdown hero, expiry
  date, a 14-day bar, a "What happens next" timeline (day-10 and day-13
  notices, then the expiry day), and the quiet `#trialKeepPlus` buy-early CTA.
- `today-plus-setup` shows `#plusSetupStrip` under the status card during
  the trial until setup is complete or the sheet reaches Done. It opens the
  Plus setup sheet: Blocking, Messages, Reminders (inline
  `#plusSetupIntervalMenu` / `#plusSetupRepeatsMenu`), then Done. Steps carry
  `#plusSetupStep_<name>`, buttons `#plusSetupSkip` / `#plusSetupPrimary`,
  and Done `#plusSetupDone`. While the trial runs, the strip replaces the
  "You haven't set up app blocking yet" card.

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
- `flows/today-plus-setup.flow` — `/trial-activation-hub?state=unconfigured`
  for a 1/3 strip and countdown badge, then Skip through Blocking and
  Messages, change the interval on Reminders, Save, prove Done, and prove the
  strip is gone. FamilyActivityPicker never returns tokens on a simulator,
  so Blocking is skipped, not completed.
- `flows/today-plus-setup-onboarding.flow` — `/trial-activation-hub?state=partial`
  stands in for finishing onboarding with blocking on. Proves the strip reads
  1 of 3 and the sheet checks Blocking but not Reminders, since the default
  follow-up nudges are not a choice the user made.
- `flows/today-review-prompt.flow` — `/review-prompt` seeds an eligible
  Streak. The flow dismisses the blocking card first (it always renders on
  a fresh, unconfigured pack and outranks the review ask) before proving
  `homeReviewPromptCard`, then dismisses it.
- `flows/today-first-reminder.flow` — real onboarding on pill 1 with "Not yet"
  at a pinned 12:30 PM and an 8 PM reminder. Today's status card reads "8:00 PM" over
  "First reminder" and the floating bar says "Your first reminder is tonight"
  with a `#firstReminderTookIt` chip, which goes through shake confirm to the
  logged state. The bar itself is not a button.
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
  the pack sheet, then the Settings "Clear your history?" confirmation.
  Cancel keeps the pack; Reset & Save starts the new pack at pill 1 today.
- `flows/today-patch-countdown.flow` — `/routine-day?method=patch&day=N`
  plus `/fixed-now` walks the patch card: wearing (day 10), late change
  (day 15), logged through the real CTA ("On today"), missed the next day
  (Home's button still reads "Change patch"), late off day, patch-free week,
  day 29 new cycle due, and "Start new" from the card menu (patch 1 due under
  the start-day grace).
- `flows/today-ring-countdown.flow` — the same for the ring: wearing, late
  out, logged out, ring-free week, the day-29 reinsert (late, then logged,
  which starts the next cycle), day 30 new cycle due, and a missed insertion.
- `flows/today-ring-start-day.flow` onboards a ring routine answered "Not yet"
  with an evening reminder and, before that reminder, logs the day-1 insert
  from Home. The streak starts at 1.
- `flows/today-catch-up.flow` — a missed patch change stays loggable from
  Home until the next task day: day 16 reads Overdue with "Change patch" on
  the button, the Shake fallback logs it late ("On today"), undo restores
  Overdue, day 17 shows "Was due Sep 28" and logs again, and the History
  sheet for the missed day says "Checked in 2 days late" (`#historyDayCatchUp`)
  while the day stays "Missed".
- `pillie://debug/countdown-card` opens a gallery of the 16 Paper lifecycle
  cards built from fixed `HomeCountdownProgress` values.
- `flows/today-long-pack.flow` — onboarding picks a Custom 88 + 3 pack, then
  Home opens its card on the page with today ("Weeks 5 to 8 of 13").
- `flows/today-sugar-pill.flow` — a 21 + 7 sugar day is due ("Take pill"),
  logs, undoes and logs again without moving the streak; History reads the
  open sugar day as "Missed" (never "Break") and as "Done" once taken; a
  21 only pill-free day stays "Nothing to take".
- `flows/today-notification-complete.flow` — `/notification-complete` runs
  the reminder's Complete action while Home is open; the status card, CTA and
  pack card all flip to taken.
- `flows/shake-confirm-stages.flow` steps the shake confirm's stop-motion clip
  for every method (pill with and without a streak, patch apply, change and
  remove, ring insert and remove, sugar pill), one shot per shake, then the streak
  reveal and its logged note. A tap on `#shakeConfirmStage` counts as one
  shake.
- `flows/smoke.flow` covers the plain tab bar (Today/History/Settings) with
  `/plus-home`.
- `flows/tab-bar-rtl.flow` — the same tab bar in Arabic: taps and edge
  swipes land on the tab in the mirrored order, and each shot shows the pink
  indicator under the selected tab.
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
- Shake detection cannot be driven on the simulator. Tap
  `#shakeConfirmStage` once per shake to step the stages, or
  `#shakeTapToConfirmFallback` ("Tap to check in instead") to finish at once.
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
