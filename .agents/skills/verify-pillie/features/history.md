# History

History is the calendar tab. It shows past days and logged actions.

## Sub-features

- `history-open` selects the History tab.
- `history-chrome` shows the History navigation title.

## How to get to it (user POV)

- Tap the History tab.

## Driving it with axe

Preconditions:

- Launch finished. Doctor passed.
- Today is visible, or the tab bar is on screen.

- **Open History.** Run `axe tap --udid "$UDID" --label History` (or `Cronologia` / `Verlauf`). The next `axe describe-ui` contains that title.
- **Proof.** Recapture. The 1x PNG shows the History tab selected and calendar chrome, not Today.

## Gotchas

- The tab label is localized. Read the dump before you pick `--label`.
- Coordinate-tapping the tab bar without a fresh 1x PNG misses the coral capsule.
