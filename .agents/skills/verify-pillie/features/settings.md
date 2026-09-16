# Settings

Settings is the third tab. It holds language, Plus entry, and the debug developer menu.

## Sub-features

- `settings-open` selects the Settings tab.
- `settings-language` shows `settingsLanguageRow`.
- `settings-developer` shows `settingsDeveloperMenuRow` on debug builds.

## How to get to it (user POV)

- Tap the Settings tab.

## Driving it with axe

Preconditions:

- Launch finished. Doctor passed.

- **Open Settings.** Run `axe tap --udid "$UDID" --label Settings` (or `Impostazioni` / `Einstellungen`). The dump contains `settingsLanguageRow`.
- **Language row.** The dump contains `settingsLanguageRow`. Do not change language unless that is the task.
- **Developer menu.** Debug only. `settingsDeveloperMenuRow` opens the same surface as `developerMenuAvatarButton` on Today.
- **Proof.** Recapture. The 1x PNG shows the Settings tab selected and the language row.

## Gotchas

- Settings can present the soft paywall. If it does, follow [soft-paywall.md](./soft-paywall.md) instead of calling Settings done.
- Do not tap Restore or purchase controls unless that is the task.
