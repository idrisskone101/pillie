# Paywalls

Every paid-access surface funnels into `HonestPaywallHost` ->
`HonestPaywallScreen`, which renders one of a small set of "boards" from
`HonestPaywallBoard`. A separate, transient `commerceAccessVerification`
screen can appear while the app resolves RevenueCat/trial access. Copy and
CTAs change often; this file names the mechanism, not the wording.
`Views/Paywall/*.swift`, `Services/Paywall/*.swift`.

## Sub-features

Every board shares one layout (S3, Oct 2026): a pink backdrop with a
decorative iPhone showing the app-blocking shield (`PaywallPhoneMockup.swift`;
its clock is the user's reminder time), and a cream sheet over it with the
board's title, subtitle, plan cards, one 5-star App Store review quote, the
CTA, a reassurance line, and Restore · Terms · Privacy. The board is a
`HonestPaywallMoment` plus a `HonestPaywallStory` (title, subtitle, review).

- `paywall-during-trial` (moment `duringTrial`) — "Keep Plus after your
  trial ends." with the live active-day count, or the ends-tonight line on
  the last day. Under the CTA: "You’re charged today. Cancel anytime in
  Settings." Reached from Home's trial chip (`entry: .trialStatus`) or debug
  `board=duringTrial`. Dismissible (Close).
- `paywall-settings-free` (moment `settingsFree`) — Get Plus: "Lock your
  apps until you take your pill." (patch and ring get their own title).
  Reached from Settings' "Pillie Plus" row or a `PlusUpsellSheet`'s
  "Get Pillie Plus" CTA. Dismissible (Close).
- `paywall-trial-ended` (moment `trialEnded(terms)`) — shown once a trial has
  expired:
  - hard (post-cutover): "Get your reminders and app blocking back."
    **Not dismissible**: no Close, purchase/restore is the only way out.
    Debug `board=trialEndedReturningHard`.
  - legacy (grandfathered, who keep free daily reminders): the Get Plus story
    with the Keep verb, Close, and "Continue with free reminders". Debug
    `board=trialEndedReturningLegacy`.
  `HonestPaywallStoryFactory.swift`, `HonestPaywallBoard.swift`
  (`HonestPaywallMoment.chrome`).
- `paywall-plus-upsell` — the compact `PlusUpsellSheet` (not a
  `HonestPaywallBoard`) opened from a locked Settings row
  (Reminder messages / Interval & Repeats / Your apps) on a free account.
  Its own "Get Pillie Plus" opens the full paywall
  (`entry: paywallSurface.paywallEntry`); "Not now" just dismisses; "Restore"
  runs a restore with the same alerts as the honest paywall.
  `Views/Components/PlusUpsellSheet.swift`.
- `paywall-restore` (ENG-74) — Restore on any honest paywall or the upsell
  sheet ends in one `RestoreOutcome`: restored (paywall dismisses, Plus on),
  no active purchase ("No subscription found" with Contact support and OK),
  or failed ("Couldn’t restore your purchases" with Try again, Contact support,
  and Not now). Contact support opens the "Pillie — Restore Purchases" Open
  Line mail, or the copy-address fallback when Mail can't open. Analytics:
  `restore_succeeded`, `restore_completed` with `reason`, `restore_failed`
  with `error_category`, all with `surface`. `Views/Paywall/PaywallAlert.swift`,
  `Services/RestoreOutcome.swift`.
- `paywall-checkout-stack` (ENG-155) — three side-by-side plan cards: Month
  (`#paywallTile.monthly`), Year (`#paywallTile.annual`, selected by default,
  with the SAVE badge and per-month price), and Lifetime
  (`#paywallTile.lifetime`) only when the offering exposes a lifetime
  package. The selected card is what the CTA buys and fires
  `paywall_plan_selected` with its `plan`. The reassurance
  (`#paywallReassurance`) is plain text: "Cancel anytime in Settings", the
  in-trial "You’re charged today…" line, or "One payment. No renewal." for
  Lifetime. The footer's "Restore" (`#paywallRestoreButton`, a11y label
  "Restore purchases") is the only control that restores; Terms
  (`#paywallTermsLink`) and Privacy (`#paywallPrivacyLink`) open the GitHub
  Pages legal docs. `Services/Paywall/PaywallCheckoutBuilder.swift`,
  `Views/Paywall/HonestPaywallView.swift`.
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
  jumps straight to one board; `pillie://debug/trial-end-paywall` opens the
  real trial-end wall from Home (hard by default,
  `terms=soft` for the closable wall). Don't relaunch after it: a relaunch
  drops the debug clock that keeps the trial expired.
  `references/state-setup.md`.

## Driving it with flows

- `flows/paywall-restore.flow` — every restore outcome without RevenueCat,
  through `pillie://debug/restore-outcome?result=error|none|restored|clear`.
  On the hard trial-end board: error alert, then Try again into the
  no-subscription alert, then a restore that drops the wall. Then the
  Settings > Pillie Plus door: error alert and Contact support into the mail
  fallback. `log start` / `log stop` keep the analytics mirror in `app.log`;
  grep it for `restore_` to see `surface`, `reason`, and `error_category`.
- `flows/paywall-trial-end-link.flow` opens the hard and the closable trial-end
  walls from Home through `/trial-end-paywall`, with no developer menu.
- `flows/paywall-extend-offer.flow` (ENG-172) — the hard trial-end wall rises
  straight into the one-time extend offer through
  `pillie://debug/trial-end-extend?trigger=cancel|restore&notifications=on|off&clear=1`.
  Shots: the cancel card, Not now dropping it back to the plans, the restore
  card with its chip, the notifications-off card ("Last day to cancel"), and
  de, fi and ru for truncation. `clear=1` re-arms the Keychain phase; the
  Test Store serves no extend SKU, so a $29.99 one-week fixture stands in and
  "Start my free week" cannot complete a purchase there. The Test Store does
  serve `com.idrisskone.pillie.plus.annual.extend` (US$29.99, one week free)
  as of 2026-10-06, so the shots show the real product, not the fixture. For
  the real path, open the link with `trigger=none`, then cancel the Test Store
  sheet (its Cancel button sits outside the app tree, at about 201,643 on the
  iPhone 17 Pro) and the card rises; a second cancel must not raise it again.
- `flows/paywall-lifetime-tile.flow` — on the hard trial-end board: three
  tiles with Year selected; a tap on "Cancel anytime" with a restore outcome
  armed raises no alert and logs no `restore_started`; the Lifetime tile
  turns the CTA into "… one-time …" with "One payment. No renewal." and logs
  `paywall_plan_selected plan=lifetime`; Restore purchases raises "No
  Subscription Found". Then the Settings > Pillie Plus door's three tiles.
  The Test Store offering has no lifetime package, so the flow stands one in
  with `pillie://debug/paywall-lifetime?price=…` and clears it at the end.
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
  - Known red on main as of 2026-10-06 on the Namespace simulator:
    `paywall-restore.flow` at its "Try again" step (the no-subscription
    alert never shows after Try again). Compare with main before blaming a
    branch. `paywall-trial-end-link.flow` was red too: a deep link landing
    while the wall was up re-presented it before the old cover's late
    onDismiss cleared it. HomeView now waits for that onDismiss (ENG-172
    branch); the flow passes locally.

## Gotchas

- **Never tap** `paywall.action.upgrade` ("Get Pillie Plus"), a recurrence
  toggle's underlying purchase button, `#commerceAccessRestoreButton`, or a
  `PlusUpsellSheet`'s "Restore" — the scheme's `Configuration.storekit` has
  real sandbox products, and a completed purchase/restore flips
  `SubscriptionManager.shared.hasEntitlement` for the rest of the run.
  The CTA counts too, on every tile: it opens a RevenueCat Test Store
  purchase sheet. With `/paywall-lifetime` set, a Lifetime CTA tap shows the
  offerings-unavailable alert, since no real lifetime package backs it.
  The one exception: after `pillie://debug/restore-outcome?result=…`, a
  Restore tap never reaches RevenueCat until `result=clear` or a relaunch.
- On a free Home the "Pillie+, App blocking" card (@206,816) overlaps the
  Settings tab's center, and a center tap can open the paywall with its
  purchase CTA under your next tap. `paywall-restore.flow` taps the tab at
  `-x 319 -y 800`. If a "Test Store Purchase" sheet ever appears, tap its
  Cancel.
- An install that already holds the hard-board state does not re-present it
  from the `board=trialEndedReturningHard` link alone; relaunch after the
  link (`paywall-restore.flow` does).
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
