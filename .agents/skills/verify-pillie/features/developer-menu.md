# Developer menu

A debug-only sheet that jumps straight to a QA state by rewriting local pack
history, trial grant, and paywall flags — no clicking through onboarding or
waiting on a trial clock. `Views/Developer/DeveloperMenuView.swift`,
`Services/DebugQA.swift`. The whole feature is wrapped in `#if DEBUG` and does
not exist in a release build.

## Sub-features

- `developer-menu-open` — two entry points present the same
  `DeveloperMenuView` sheet: `#developerMenuAvatarButton` on Home
  (`HomeView.swift:360-368`) and `#settingsDeveloperMenuRow` on Settings
  ("Jump to a QA state", `SettingsView.swift:370-382`).
- `developer-menu-sections` — four sections (Pack & calendar / Trial — new
  users / Trial — grandfathered / Other), each row identified
  `#developerScenario.<rawValue>`. `DeveloperMenuView.swift:50-116`;
  `DebugQAScenario` cases and titles, `DebugQA.swift:22-40,63-81`.
- `developer-menu-apply` — tapping a row calls `DebugQA.apply(scenario:)`
  then dismisses the sheet immediately; there is no confirm step and no
  undo row. `DeveloperMenuView.swift:44-47`.
- `developer-menu-done` — the toolbar "Done" button dismisses without
  applying anything. `DeveloperMenuView.swift:30-39`.

## How to get to it (user POV)

- Settings tab > DEVELOPER section > "Jump to a QA state" row (debug builds
  only).
- Or the hammer-badge/avatar button in the Today header.
- Tap any scenario row: the sheet closes immediately and the app is already
  in that state — the underlying `PillStore`/`SubscriptionManager`/
  `AppBlockingManager` objects are `@Observable`, so whichever screen you
  land on next reflects it without a relaunch.

## Driving it with flows

- `flows/developer-menu.flow` — opens the menu from Settings
  (`#settingsDeveloperMenuRow`), shoots the sheet, taps
  `developerScenario.packComplete` (harmless: it only rewrites the local
  pack to a fully-elapsed 21/7 pack), and — back on Today — proves the
  floating CTA switched to "Start new"
  (`today.pack.start_new.confirm`, `TodayActionState.swift:9,42-43`), i.e.
  the scenario actually changed Home, not just that a sheet closed.
- Not driven by a flow, and why: the other ~20 scenarios (trial/paywall
  states) are exercised indirectly by `flows/paywall-boards.flow` and the
  trial-related deep links in `references/state-setup.md`, which call the
  same `DebugQA.apply` cases without going through this sheet. Clicking
  through every remaining row here would duplicate that coverage and blow
  well past a single flow's step budget.

## Gotchas

- Everything here is `#if DEBUG` (`DeveloperMenuView.swift:1`,
  `DebugQA.swift:1`) — none of these identifiers exist in a release build.
- Applying a scenario has no confirmation and no undo — it silently rewrites
  store/subscription/blocking state. If a task needs a specific state,
  prefer applying the matching scenario over reconstructing it by hand.
- Row titles and details are `Text(verbatim:)`
  (`DeveloperMenuRowView`, `DeveloperMenuView.swift:95,99`) — always
  English, never localized, even under `?lang=de`. Don't wait for a
  translated string here.
- Tapping a row dismisses the sheet whether or not you meant to look at more
  than one scenario — one row per open; reopen the menu for the next one.
- Several scenarios (e.g. `trialExpiredNewUserReturning`,
  `trialExpiredGrandfatherReturning`) are the same `DebugQA.apply` cases the
  `/honest-paywall?board=...` debug deep links call — see
  `features/paywalls.md` — so proving those through this sheet instead
  of the deep link is redundant, not an alternative path worth its own flow.
