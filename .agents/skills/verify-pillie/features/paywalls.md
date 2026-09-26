# Paywalls

Every paid-access surface funnels into `HonestPaywallHost` ->
`HonestPaywallScreen`, which renders one of a small set of "boards" from
`HonestPaywallBoard`. A separate, transient `commerceAccessVerification`
screen can appear while the app resolves RevenueCat/trial access. Copy and
CTAs change often; this file names the mechanism, not the wording.
`Views/Paywall/*.swift`, `Services/Paywall/*.swift`.

## Sub-features

- `paywall-during-trial` (board `duringTrial`) — shown while a Reverse Trial
  is active; "keep it" framing with three benefit chips. Reached from Home's
  trial chip (`entry: .trialStatus`) or debug `board=duringTrial`.
  `HonestPaywallBoard.swift:20-34`; `HonestPaywallBoardResolver.swift:20-28`;
  `HonestPaywallStoryFactory.swift` `duringTrial(...)`. Dismissible (Close).
- `paywall-settings-free` (board `settingsFree`) — the no-trial-grant,
  free-account board ("Daily reminders are free."). Reached from Settings'
  "Pillie Plus" row (`entry: .settingsSubscription`) or a `PlusUpsellSheet`'s
  "Get Pillie Plus" CTA, or debug `board=settingsFree`.
  `HonestPaywallBoardResolver.swift:44-47`; `HonestPaywallStoryFactory.swift`
  `settingsFree(...)`. Dismissible (Close).
- `paywall-trial-ended` (board `trialEnded`) — shown once a trial has expired.
  Its body varies with `TrialEndOwnStats`/terms: an own-record stats/
  comparison/chips variant for a trial that just ended on this device, or —
  the two boards this skill's debug deep link exposes — a no-stats
  "returning" variant after a fresh reinstall:
  - `trialEndedReturningHard` (post-cutover terms): "Your trial already
    ended." **Not dismissible** — no Close row, purchase/restore is the only
    way out.
  - `trialEndedReturningLegacy` (pre-cutover terms): "Welcome back." —
    dismissible, and also shows a "Keep reminders free" continue-free CTA.
  `HonestPaywallStoryFactory.swift` `trialEnded(...)`, `chrome(for:)`;
  `Services/DebugQA.swift` `trialExpiredNewUserReturning` /
  `trialExpiredGrandfatherReturning`.
- `paywall-plus-upsell` — the compact `PlusUpsellSheet` (not a
  `HonestPaywallBoard`) opened from a locked Settings row
  (Reminder messages / Interval & Repeats / Your apps) on a free account.
  Its own "Get Pillie Plus" opens the full paywall
  (`entry: paywallSurface.paywallEntry`); "Not now" just dismisses; "Restore"
  runs a silent restore. `Views/Components/PlusUpsellSheet.swift`.
- `paywall-commerce-access-verification` — a transient full-screen loading
  gate (`#commerceAccessVerification`) shown (a) at the app root right after
  onboarding, before `MainTabView`, while RevenueCat resolves, and (b) inside
  onboarding's app-blocking step, while trial activation resolves. On
  failure it shows `#commerceAccessRetryButton` and
  `#commerceAccessRestoreButton`. `ContentView.swift:363-372,616-624,878-951`.

## How to get to it (user POV)

- Settings > "Pillie Plus" row, on a trial or free account: opens the honest
  paywall.
- Settings > a locked Plus row (Reminder messages / Interval / Repeats /
  Your apps) on a free account: opens the compact upsell sheet first; its
  "Get Pillie Plus" button opens the full paywall.
- Home's trial chip, while a Reverse Trial is active: opens the "keep it"
  board directly.
- Debug-only, no clicking through: `pillie://debug/honest-paywall?board=
  duringTrial|settingsFree|trialEndedReturningHard|trialEndedReturningLegacy`
  jumps straight to one board; `pillie://debug/trial-end-paywall?...` seeds
  richer own-record trial-ended stats/cohort combinations instead.
  `references/state-setup.md`.

## Driving it with flows

- `flows/paywall-boards.flow` — for each of `duringTrial`, `settingsFree`,
  `trialEndedReturningLegacy`, `trialEndedReturningHard`: `launch`, open the
  debug deep link (each call completes onboarding and seeds its own
  `DebugQA` scenario, so no `/plus-home` landing step is needed first), wait
  for the board's title, shoot it, and dismiss (Close) the three dismissible
  boards. The hard-paywall board is deliberately left on screen — it isn't
  dismissible — and the next board starts from a fresh `launch` instead of
  trying to leave it.
- Not driven by a flow, and why:
  - `paywall-plus-upsell` is reachable only from `features/settings.md`'s
    locked rows on a free account, not from a debug deep link, and its
    "Get Pillie Plus"/"Restore" buttons lead into real purchase/restore code
    — `flows/settings-editors.flow`'s shots of the locked rows are the only
    proof, and even those don't tap into the sheet.
  - `paywall-commerce-access-verification` has no debug deep link or
    developer-menu scenario that forces it to stay visible — it resolves
    inside a `.task` almost immediately against `Configuration.storekit`, and
    nothing in this app toggles RevenueCat offline from a URL. Any shot of it
    is incidental, not a repeatable proof; don't write a flow that assumes
    it's still on screen after a `wait`.
  - `paywall-trial-ended`'s own-record stats/comparison/chips body (a trial
    that expired on this same device, as opposed to the "returning" no-stats
    copy above) needs `/trial-end-paywall` with a real aged-out trial and
    matching `cohort`/`terms` — out of this skill's four fixed boards; see
    `references/state-setup.md` if a task needs it.

## Gotchas

- **Never tap** `paywall.action.upgrade` ("Get Pillie Plus"), a recurrence
  toggle's underlying purchase button, `#commerceAccessRestoreButton`, or a
  `PlusUpsellSheet`'s "Restore" — the scheme's `Configuration.storekit` has
  real sandbox products, and a completed purchase/restore flips
  `SubscriptionManager.shared.hasEntitlement` for the rest of the run.
- `board=trialEndedReturningHard` resolves to
  `HonestPaywallChrome(showsClose: false, allowsInteractiveDismiss: false)`
  (`HonestPaywallStoryFactory.swift` `chrome(for:)`) — don't add a Close tap
  or a swipe-dismiss step for it.
- `board=duringTrial` / `settingsFree` present through a `NotificationCenter`
  post (`.pillieDebugPresentHonestPaywall`, `PillieApp.swift`, observed in
  `HomeView.swift:644-654`), which needs `HomeView` mounted to receive it;
  `board=trialEndedReturningHard` / `trialEndedReturningLegacy` present
  through the ordinary auto-present path
  (`HomeView.autoPresentTrialEndPaywallIfNeeded`, `HomeView.swift:180-201,
  511`) once `DebugQA`'s scenario clears the one-shot flag. Both paths land
  through Home's own view lifecycle — a deep link opened before onboarding
  has ever completed on this install has nothing mounted to react, so it may
  need a first `/plus-home` (or any onboarding-completing) pass on a truly
  fresh install.
- Copy is generated per board from live localized strings
  (`HonestPaywallStoryFactory`, `CommercePresentation`) — the strings cited
  here are the `en` values in `Commerce.xcstrings` at the time of writing;
  re-read the dump before trusting them for another locale or after a copy
  change.
- `pillie://debug/honest-paywall?board=settingsFree` is unreliable: it applies `existingUserTrialAnnouncement`, whose one-shot announcement sheet ("Your next two weeks are on us.") can cover the paywall, and after the first run the sheet no longer shows either. `paywall-boards.flow` skips that board. Verified live 2026-09-26.
- The duringTrial post can land before Home subscribes. `paywall-boards.flow` waits for `Today` after every `launch`, before the link.
