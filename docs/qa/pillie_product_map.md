# Pillie product map (live sim, 15 Sep 2026)

Screenshots are not in this repo. They are on the Cloud Agent artifacts path listed at the bottom, and embedded on the draft PR.

Walked a first-open session on Namespace Mac `pillie-ios` (iPhone 17 Pro, iOS 27, DEBUG build `com.idrisskone.pillie`). No Screen Time grant. Reminder-only completion via **Not now** on the blocking step.

Sim stayed booted. Devbox left running (`KEEP=1`).

## What Pillie is, from the screens

Pillie is a contraception check-in app. The first-open story is: a reminder you cannot swipe away, then selected apps pause until you mark the dose taken. The live flow grants a 14-day Reverse Trial (Plus) during onboarding. App blocking still needs Apple Screen Time. Skipping that lands you in reminders-only, with a home card asking you to finish setup.

Tabs after onboarding: **Today**, **History**, **Settings**.

## Day-0 path walked

| # | Screen | Purpose | What I did |
|---|---|---|---|
| 1 | Welcome | Pitch: “The alarm clock for your pill.” Hero shows nightly check-in at 9:00 PM locking apps. CTA **Get started**. | Tapped Get started. |
| 2 | See how Pillie works | Optional drag demo (“Drag this onto your apps”). Progress: section 1 of 3. Skip CTA **Not now**. | Skipped. No Continue until the demo plays. |
| 3 | What’s in the way? | Multi-select distractions (TikTok, Instagram, YouTube, Messages, dismiss, busy, forget, Other) plus “What would help more?” outcomes. Continue stays off until both sides have a pick. | TikTok + Less stress. |
| 4 | How often / how soon | Miss frequency chips and delay chips. Same Continue gate. | Rarely + Right after the reminder. |
| 5 | Where did you find Pillie? | Optional acquisition. **Continue** or **Not now**. | Not now. |
| 6 | Pick your method | Pill / Patch / Ring. Pill is preselected. Live “Your reminder plan” card. | Continued on Pill. |
| 7 | Where are you in your routine? | Cycle position, day, regimen (Standard 21/7, 24/4, Continuous, Custom). Defaults: Just starting, Day 1, Standard. | Continued on defaults. |
| 8 | Pick a time | Time wheel. Defaults to **8:00 AM**. Morning / Evening presets. CTA **Continue to notification settings**. | Evening → 8:00 PM. |
| 9 | System notification alert | “Pillie Would Like to Send You Notifications.” Don’t Allow / Allow. | Allow. |
| 10 | Your reminder plan | Confirm evening 8:00 PM, 21/7, current cycle. Blocking is promised, not configured. | Continue. |
| 11 | Pick the apps to pause | Screen Time primer. Primary **Allow pausing**. Skip **Not now**. | Not now. Did not request Screen Time. |
| 12 | Today (reminder-only) | Due card, blocking incomplete card, cycle strip, **Take pill**. Trial chip: “Set up app blocking · 14 days left.” | Logged a dose. |
| 13 | Shake to Confirm | Full-screen. 0/3 shakes. **Tap to Confirm Instead** and Cancel. | Tap fallback. |
| 14 | Today after log | Check on 8:00 PM. “Your next one is on Wednesday, September 16.” CTA becomes “That’s logged. Tap to undo.” Streak 1. Blocking card still up. | Opened History, then Settings. |
| 15 | History | September 2026 calendar. Day 15 = Done. Days 1–14 = Not logged. “1 check-in”, “100% logged”, “1/1”. | — |
| 16 | Settings | My Pillie (method, reminder time, messages, supply), Reminders (interval 10 min, repeats 3), Routine, App blocking (Your apps Off), Account (Pillie Plus, Trial active), language, support. | Opened blocking sheet and Plus paywall. |

DEBUG-only hammer button sits on every onboarding CTA and on Today. Not in release.

## Skip / empty states hit

- Demo skip: **Not now** (no “Skip demo” wording).
- Acquisition skip: **Not now**.
- Screen Time skip: **Not now**. Lands in reminder-only. Copy on Today: “You haven’t set up app blocking yet.” / “Daily reminders are already on.”
- Blocking editor (Settings → Your apps): toggle can read **On** while the list says **No apps selected**. Settings row still **Off**. **Choose Apps** is the real Screen Time picker; not completed here.
- History before day 0: earlier days in the month show **Not logged** (orange), even though the user just installed.

## Day-0 habit friction

### First dose

The first **Take pill** is after a long setup (welcome, demo, two personalize screens, optional source, method, schedule, time, notification, plan, blocking). A new user can spend several minutes before logging anything.

Default reminder time is **8:00 AM**. Welcome and the demo sell **9:00 PM**. Evening is one tap, but tapping through leaves a morning alarm for a product that presents itself as a nightly check-in.

Logging is a two-step: **Take pill** then **Shake to Confirm** (3 shakes). The tap fallback is visible. Extra motion after the user already committed.

After the first log, the blocking setup card and the 14-day trial chip still own the top of Today. The success state is the due card check plus an undo CTA. Easy to miss that the habit started.

History paints the rest of the month as **Not logged**. That can read as missed doses on day 0.

### Blocking setup

The differentiator is last, after the plan is “ready.” Primary CTA is **Allow pausing** (Apple Screen Time). **Not now** is a text link under a large black button, so skip is easy.

Skip does not fail the trial. Plus is already active for 14 days. Home then nags setup (“Set up app blocking · 14 days left” plus a dismissible card). Settings still shows Your apps **Off**.

The Settings sheet can show blocking **On** with **No apps selected**. That empty state is easy to misread.

Real app selection needs Screen Time. Simulator cannot finish Protection Plan Activation. Reminder-only is the honest guest path.

### Reminders

Notification permission is a system alert on the time step, labeled **Continue to notification settings**. Don’t Allow would kill the habit loop with no in-app recovery on that screen.

Once allowed, Settings already has a working reminder: **8:00 PM**, interval **Every 10 minutes**, **3** repeats, supply reminder **5**, break-week ping. That is enough for day 0 if the user allowed notifications and did not leave 8:00 AM in place.

Reminder messages stay **Default**. Custom messages sit behind Plus (trial is on, so the row is reachable).

## Paywall entry (Settings)

Settings → **Pillie Plus, Trial active** opens the keep-Plus sheet:

- “You still have Pillie Plus.”
- 14 days left
- Reminders stay on / Blocking stays on / Your history stays here
- Year $2.50/mo billed $29.99/year, SAVE 50%
- Month $4.99, cancel anytime
- CTA **Keep Pillie Plus · $29.99 billed yearly**
- Lifetime $69.99
- Cancel anytime · Restore

Onboarding no longer has a purchase gate. The first paid ask is this mid-trial keep sheet, or the home “Set up app blocking” path.

## Screenshot files

Saved under `/opt/cursor/artifacts/`:

| File | Screen |
|---|---|
| `onboarding_welcome.png` | First open |
| `onboarding_demo.png` | Demo + Not now |
| `onboarding_personalize.png` | What’s in the way |
| `onboarding_reminder_time.png` | Evening 8:00 PM |
| `onboarding_notification_permission.png` | System Allow dialog |
| `onboarding_plan_reveal.png` | Reminder plan ready |
| `onboarding_screen_time_skip.png` | Allow pausing / Not now |
| `today_home_reminder_only.png` | Today after skip |
| `today_shake_confirm.png` | Shake / tap fallback |
| `today_dose_logged.png` | First dose logged |
| `history_calendar.png` | History month |
| `settings_reminders.png` | Settings top |
| `settings_blocking_plus.png` | Settings blocking + Plus |
| `settings_blocking_empty.png` | No apps selected sheet |
| `settings_paywall.png` | Keep Plus |

1x copies: `walk_*_1x.png`. Full walk dumps: `walk_*.png` and `walk_*.txt` on the Mac at `/Users/runner/pillie-walk/`.
