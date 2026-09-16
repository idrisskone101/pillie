# Today

Today is the home tab. It shows the due action, trial or blocking status, and the tab bar.

## Sub-features

- `today-open` shows the home tab after launch.
- `today-tabs` keeps Today, History, and Settings on the tab bar.
- `today-blocking` shows `homeBlockingStatusCard` when protection is on.
- `today-protection-off` shows `homeProtectionOffCard` when protection is off.

## How to get to it (user POV)

- Launch the app. Today is the default tab.
- Tap the Today tab label if another tab is selected.

## Driving it with axe

Preconditions:

- Launch finished. Doctor passed.
- `UDID=$(make -s udid)` (on Linux, run axe through `make ns-mac-exec`).

- **Confirm home.** Run `axe describe-ui --udid "$UDID"`. The dump contains `Today` (or `Oggi` / `Heute` / `Hoy`) and is not an empty launch tree.
- **Tab bar.** The dump also contains `History` and `Settings` (or the locale pair in `sim-qa.sh`).
- **Blocking card.** If protection is on, the dump contains `homeBlockingStatusCard`. Tap `homeBlockingStatusCardCTA` only when that id is present.
- **Protection off.** If protection is off, the dump contains `homeProtectionOffCard`. Tap `homeProtectionOffCardCTA` only when that id is present.
- **Proof.** `SKIP_BUILD=1 make ns-mac-qa` or `SKIP_BUILD=1 make qa`. The 1x PNG shows the home tab coral indicator and the status card that matched the dump.

## Gotchas

- First launch can land on onboarding or the soft paywall. Finish or skip that path before you claim Today.
- A launch-screen PNG after a short sleep is not Today. Wait for `pillie_qa.json` `ready=true` or labels in the axe dump.
- Locale changes the tab strings. Match the dump, not the English words in your head.
- `developerMenuAvatarButton` is debug-only. Do not treat it as a user path.
