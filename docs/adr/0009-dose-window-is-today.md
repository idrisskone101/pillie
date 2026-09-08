# The live day is the 24-hour reminder window, not midnight

Status: accepted (supersedes [ADR 0005](0005-last-call-reminder.md) and midnight-as-today rollover)

A due action stays completable until the next Due Action Reminder, not civil midnight. Home, History, Settings cycle day, streak, blocking, and reminder catch-up share that same `today`. Last Call / Last ping is retired; Interval and Repeats remain the Smart Reminders follow-up path.

## Decisions and reasons

**One clock.** `PillStore.today` is the open dose day. Remapping only Home while leaving cycle identity, streak, and History on midnight created two clocks and a silent cycle-day shift. The window is the definition of today, not a special case on top of the calendar.

**Missed at the next reminder.** Yesterday becomes `.missed` when the next reminder arrives still untaken. Passive days use the same close rule.

**Last Call is gone.** The end-of-day backstop existed to catch doses before midnight rollover. The window makes that backstop unnecessary. Custom Reminder Message is four fields (daily + follow-up).

**Blocking follows the window.** DeviceActivity runs from reminder time to one minute before the next reminder, wrapping midnight, so shields stay up through the late window. The handled stamp is written for the live dose day.

## Consequences

- After midnight and before the next reminder, Settings cycle day, the pack strip, and History's "today" ring can show yesterday when that dose is still open.
- Changing reminder time uses the same refresh as crossing the window (`refreshDayContext(force: true)`).
- Civil midnight remains an implementation detail of window math (`DoseWindow`) and of fire-date construction. It is not product today.
