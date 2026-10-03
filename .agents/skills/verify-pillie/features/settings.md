# Settings

Settings is the third tab. It is where a person sets their method/schedule,
smart-reminder tuning, app blocking, subscription, and app language, plus two
support mailto rows and (debug builds only) the developer menu.
`Views/Settings/SettingsView.swift`.

## Sub-features

- `settings-open` selects the Settings tab; nav title `settings.navigation.title`
  -> "Settings" (`PillieTabBar.swift:13,22`; `SettingsView.swift:44-51`).
- `settings-method` — "Method" row opens `ProtocolEditor`: contraceptive
  method, pill regimen, and a cycle-day stepper, gated behind a destructive
  confirm alert on Save. `SettingsView.swift:61-70,436-440,728-1001`.
- `settings-reminder-time` — "Reminder time" row opens `ReminderTimeEditor`
  (wheel picker). `SettingsView.swift:73-89,412-417,1005-1058`.
- `settings-reminder-messages` — "Reminder messages" row opens
  `CustomReminderMessagesEditor` for Plus accounts (title/body per reminder,
  live notification preview); a free account gets a `PlusUpsellSheet` instead.
  `SettingsView.swift:91-117,455-460`; `CustomReminderMessagesEditor.swift`.
- `settings-supply-reminder` — "Pill supply reminder" (or the patch restock
  equivalent; hidden entirely for the ring method) opens
  `RefillReminderThresholdEditor`. `SettingsView.swift:118-127,430-435,1195-1271`.
- `settings-smart-reminders` — "Interval" and "Repeats" rows open
  `AutoReminderIntervalEditor` / `AutoReminderRetryLimitEditor` for Plus
  accounts; a free account gets a `PlusUpsellSheet` on either row.
  `SettingsView.swift:138-192,418-429,1062-1191`.
- `settings-cycle-day` — "Cycle day" row opens `CycleDayEditor`; the
  "Break-week notice" toggle beside it is free for everyone (no lock).
  `SettingsView.swift:201-219,441-448,1275-1333`.
- `settings-blocking` — "Your apps" row opens `BlockedAppsEditor` for Plus
  accounts (status toggle + FamilyActivityPicker); a free account gets a
  `PlusUpsellSheet`. `SettingsView.swift:228-266,449-454`; `BlockedAppsEditor.swift`.
- `settings-subscription` — "Pillie Plus" row opens the system manage-
  subscriptions sheet for an active subscriber, or the honest paywall
  (`entry: .settingsSubscription`) for everyone else.
  `SettingsView.swift:275-294,461-468`.
- `settings-language` — "Language" row (`#settingsLanguageRow`) opens
  `LanguagePickerSheet`. `SettingsView.swift:303-322,406-411`.
- `settings-support` — "Share an idea" / "Report a problem" rows open a
  `mailto:` composer via `OpenLine`, with a copy-address fallback alert when
  no mail client is configured. `SettingsView.swift:335-364,469-486`.
- `settings-developer` (Debug builds only) — "Jump to a QA state" row
  (`#settingsDeveloperMenuRow`) opens the developer menu.
  `SettingsView.swift:366-383`. See `features/developer-menu.md`.

## How to get to it (user POV)

- Tap the Settings tab.
- Scroll down: Cycle day, Break-week ping, Your apps, Pillie Plus, Language,
  Support, and (debug) Developer sit below the first screen's fold.
- Tap any row to open its editor sheet; each editor has its own Save/Done/
  Cancel, or (a few) no button at all — see Gotchas.

## Driving it with flows

- `flows/settings-editors.flow` — lands on Settings via `/plus-home` (so the
  Plus-gated rows show their real editor, not a `PlusUpsellSheet`), then opens
  Method, Reminder time, Reminder messages, Pill supply reminder, Interval,
  Repeats, Cycle day, and Your apps in turn, shooting each open sheet and
  closing it without saving.
- `flows/settings-language.flow` — opens the Language row, switches to
  German, proves German strings appear (nav title "Einstellungen", sheet
  header "Sprache"), then switches back to English.
- Not driven by a flow, and why:
  - `settings-subscription`'s paywall branch (free/trial accounts) is the
    same `HonestPaywallBoard.settingsFree` covered by
    `flows/paywall-boards.flow` (`board=settingsFree`); this file's flow
    doesn't re-open it from the Pillie Plus row too.
  - `settings-subscription`'s manage-subscription branch (an active
    subscriber) opens `.manageSubscriptionsSheet`, a system StoreKit sheet
    with no accessibility identifiers Pillie owns, that also needs a real
    completed sandbox purchase to reach — not reachable from a debug deep
    link, so not scripted.
  - `settings-support`'s mailto rows hand off to Mail.app or the system
    "no mail account" alert, outside Pillie's own ax tree.
  - `settings-reminder-messages` / `settings-smart-reminders` /
    `settings-blocking`'s free-account `PlusUpsellSheet` branch is covered by
    `features/paywalls.md`'s paywalls doc, not repeated here.
  - `settings-developer` is covered by `flows/developer-menu.flow`.

## Gotchas

- `ProtocolEditor` and `CustomReminderMessagesEditor` present at
  `.presentationDetents([.large])` and have an explicit "Cancel" button
  (`global.action.cancel` -> "Cancel") — use it to close without saving.
- `ReminderTimeEditor`, `AutoReminderIntervalEditor`,
  `AutoReminderRetryLimitEditor`, `RefillReminderThresholdEditor`, and
  `CycleDayEditor` present at a partial `.height(N)` detent with no Cancel or
  Close button and no `.interactiveDismissDisabled()` — dismiss by tapping
  the dimmed area above the sheet, not by hunting for a label that isn't
  there.
- `BlockedAppsEditor`'s "Done" button (`global.action.done` -> "Done") calls
  `saveSelectionAndReconcile` even with an empty selection — prefer the
  scrim-tap dismiss above if you only want to look at it.
- The Reminder messages / Interval / Repeats / Your apps rows render a
  `PlusUpsellSheet` instead of their real editor whenever
  `SubscriptionManager.shared.hasPlusAccess` is false — land on `/plus-home`
  first if you want the editor, not the upsell.
- The whole `#settingsDeveloperMenuRow` section only exists behind
  `#if DEBUG` (`SettingsView.swift:366`) — it is not in a release build.
- The pill-supply row's title and options switch on `store.pack.method`
  (`SettingsPresentation.supplyReminderTitle`) — it reads "Pill supply
  reminder" for pill/ring and a patch-specific string for patch, and is
  missing entirely for ring. Match whichever method the deep link you used
  seeded, not the `.qa-artifacts/flows/smoke/03-settings.ax.txt` outline's
  pill-method labels by default.
- Row and section labels are localized (`PillieLocalization.string`, default
  table `Localizable.xcstrings`); match the dump for the active language, not
  the English text in this file, once you've changed `?lang=`.
