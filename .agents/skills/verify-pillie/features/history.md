# History

History is the calendar tab. It shows a scrolling month grid of past, today,
and future days, a legend, an adherence summary card, and — for a past due
day the user can still correct — a bottom sheet to rewrite that day's status.

## Sub-features

- `history-open` selects the History tab and shows its title and subtitle.
  `Views/Calendar/HistoryView.swift:18-42`.
- `history-grid` renders the current month as a fixed 6x7 grid of day cells,
  colored by status (taken/missed/break/upcoming) per the active method
  (pill/patch/ring). `Views/Calendar/CalendarGrid.swift`,
  `Shared/CalendarMonthLayout.swift`.
- `history-pager` swipes (or steps via the chevron buttons in
  `Views/Calendar/HistoryMonthSlideHost.swift:62-89`) one month at a time. The
  strip is UIKit-driven so a drag doesn't rebuild the title/legend/card.
  `Views/Calendar/HistoryMonthPager.swift`.
- `history-adherence-card` shows completed/due count and percentage for the
  displayed month below the grid. `Views/Calendar/AdherenceCard.swift`.
- `history-discovery-banner` is a one-shot "Days are tappable now" banner
  shown until dismissed (pip clears both the banner and a Today badge).
  `Views/Calendar/HistoryDiscoveryBanner.swift`,
  `Services/HistoryDiscoveryAnnouncement.swift`.
- `history-day-correction` — tapping a past day that `DayCorrectionPolicy`
  allows editing opens a sheet to rewrite it to Taken / Not checked in / Break.
  `Views/Calendar/CalendarGrid.swift:217-243`,
  `Views/Calendar/HistoryDayCorrectionSheet.swift`, `Models/DayCorrection.swift`.
  Only past days with a due, non-break action and no ring-reinsert record are
  editable; future days and most break days render inert.

## How to get to it (user POV)

- Tap the History tab.
- Swipe the month grid left/right, or tap a chevron next to the month name,
  to change months.
- Tap a past day cell that shows a colored dot: a sheet opens to say what
  really happened that day. Pick Taken, Not checked in, or Break; the sheet closes
  and the cell's color and dot update immediately.
- A first-time coral banner above the legend explains the day-tap gesture
  until dismissed with its X.

## Driving it with flows

- `flows/history-calendar.flow` — pins the clock
  (`pillie://debug/fixed-now?at=...`) so the month header is deterministic,
  opens History from a Plus Home deep link, proves the grid and month header
  render, then swipes to the previous month and back. Proof is the month
  header text (e.g. "September 2026" / "August 2026"), not pixel color.
- `flows/history-correction.flow` — seeds `developerScenario.missedRecentDays`
  from the developer menu (`#developerMenuAvatarButton` on Home), which marks
  the two most recent due days missed, opens the day-correction sheet for one
  of those days (`historyEditableDay.<monthID>.<day>`), picks
  `historyDayCorrection.taken`, and proves the day's accessibility label
  changed from "...: Not checked in" to "...: Done" — the calendar actually
  changed, not just that the sheet closed.
- `monthID` is `MonthCursor.identity(for:)` — `"\(year)-\(month)"`, no
  zero-padding (`Shared/MonthCursor.swift:27-30`), e.g. `2026-9` for
  September 2026, not `2026-09`.
- Not driven by a flow: `history-adherence-card` has no accessibility
  identifier and its text is data-dependent (count/percentage), so it is
  proved only by eyeballing the shot, not asserted on. `history-discovery
  -banner` is order-dependent (a fresh install seeds it already dismissed;
  an existing-state install shows it once) — neither flow asserts on its
  presence, only on `HistoryDiscoveryBanner`'s
  `historyDayCorrectionBannerDismiss` id if a coordinator needs to clear it
  out of a shot.
- Both flows depend on `/fixed-now` and `/plus-home` being reachable from any
  app state (they mutate `PillieClock`/store directly, independent of the
  current screen), and on `DEBUG`-only identifiers
  (`developerMenuAvatarButton`, `developerScenario.<rawValue>`) staying off
  release builds.

## Gotchas

- The tab label, "Your month so far" subtitle, and month header are all
  localized. Match the dump for the active language, not the English text in
  this file, when `lang` isn't pinned to `en`.
- `historyEditableDay.<monthID>.<day>` only exists for a day
  `DayCorrectionPolicy.options` allows editing — a future day, a day with no
  due action, a day already resolved by a break-week shift to Break-only, or
  either face of a ring reinsert renders an inert (non-Button) cell with no
  identifier. Don't assume every visible day is tappable.
- The flows here pin `/fixed-now` to `2026-09-15T15:00:00Z` and assume the
  simulator's local calendar day from that instant is still September 15
  (true for any device timezone from roughly UTC-15 to UTC+9). If the
  simulator runs a timezone east of that, the seeded "missed" days and the
  `historyEditableDay.2026-9.14` target will be off by a day — check the
  `history-seeded` shot's day-13/14 cells before trusting the id in
  `history-correction.flow`.
- The two "September 14, 2026: ..." / month-header wait-text lines in both
  flows are the coordinator's best inference of `Date.FormatStyle` output for
  locale `en`, not a literal string from source — confirm the exact wording
  and field order against a live ax dump before relying on them unattended.
- `history-pager`'s drag only recognizes a horizontal pan that starts inside
  the grid's bounds and is more horizontal than vertical
  (`Views/Calendar/HistoryMonthSlideHost.swift:349-358`); a swipe elsewhere on
  the screen scrolls the page instead of changing months.
- Don't hand-roll a scenario the developer menu already has:
  `developerScenario.missedRecentDays` / `.marketingCalendar` seed realistic
  pack history without touching SwiftData by hand.
