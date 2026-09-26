# Pillie voice

Status: approved. Voice B (warm and clear), chosen on the review page.

Pillie sounds like a friend who is good at routines. It is warm and it is plain. The warmth goes around the instruction. It never replaces the noun or verb that tells the person what happens.

A quick test for any line: could someone who has never opened Pillie say what will happen after they read it? If not, the line is too cute or too vague. Would a friend say it out loud? If not, it is too stiff.

## Rules

1. **Say what happens, then be kind about it.** "Paused until you check in" names the state. "This app will be waiting" is the kind part. Keep both.
2. **Name the step the person does.** Take your pill, change your patch, insert your ring. Use "check in" only when the method is unknown. Never write "action", "due action", or "log the action".
3. **Talk to one person.** Use "you", contractions, and short sentences. Use "we" only for Pillie the team (support, feedback, billing). Pillie the app is "Pillie".
4. **No pressure.** No guilt, no loss framing ("don't lose"), no fake urgency. Dates and counts are real or absent. The paywall says what Plus does and what stays free.
5. **No health promises.** Pillie reminds. It does not protect. Never write "protected", "protection", "never miss", "safe", or anything about how well contraception works.
6. **Be exact about time.** The trial is "14 active days", never "two weeks". Calendar lines stay calendar lines ("ends tonight", "ends on %@").
7. **Errors say what happened and what to do.** No blame. Say "Try again", not "Please try again". Don't guess at a cause the code doesn't know.
8. **Destructive steps stay blunt.** A reset says exactly what it deletes and that it can't be undone. Warmth doesn't soften a warning.

## Mechanics

- Sentence case everywhere, including buttons, titles, and alerts.
- Write strings in normal case. Eyebrows and badges become uppercase in SwiftUI with `.textCase(.uppercase)`, so scripts without case still work.
- Use the typographic apostrophe `’`.
- No em or en dashes in prose. Use a period or a comma. Number ranges keep the en dash (`Days 23–28`).
- Sentences end with a period. Buttons, labels, and titles without a verb don't.
- At most one exclamation mark on a screen. None in errors, warnings, or notifications.
- No emoji in Pillie-authored copy.

## Glossary

One word per idea. Translate each term once per locale, then reuse that translation everywhere.

| Say | For | Don't say |
|---|---|---|
| check in, check-in | confirming today's step in Pillie | log, mark as completed, confirm, action |
| take your pill / change your patch / insert your ring | the method step, when the method is known | log your pill, handle it |
| reminder | any notification that asks for today's step | ping, alert, nudge |
| follow-up reminders | the Plus feature that repeats a reminder until you check in | Smart reminders, extra pings, smart notifications |
| App blocking | the Plus feature, as a name | app pause, blocklist, protection |
| pause, paused, open again | what happens to the chosen apps | block, lock, intercept, unlock |
| Pillie Plus, then Plus | the paid plan | premium, pro |
| active days | days with a hormone step; trial length | two weeks, trial days |
| break days, break week | placebo or patch-free or ring-free days | off days, rest days |
| streak | consecutive completed check-ins | daily streak |

## Locales

Rewrite each locale from the new English meaning, not from the old translation.

- Use the everyday informal register where consumer apps normally use it (`du`, `tu`, `tú`, `jij`, `ty`, `sen`).
- Hindi, Bengali, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu, and Urdu use the formal register (for example `आप`, not `तुम`).
- Arabic addresses the reader in the feminine form.
- Japanese uses polite です・ます without greetings. Korean uses 해요체.
- Translate "check in" as a native verb. Don't borrow the English word unless that locale's users say it.
- Keep `%@`, `%lld`, and `%1$@` placeholders and their order rules intact.
- `onboarding.regimen.21_7` owns the wording for active days in each locale.
- A native speaker reviews German, Italian, French, and Spanish before release. Other locales get a back-translation check.

## Tools

- `python3 Pillie/scripts/copy-rewrite/copy-inventory.py --summary` lists every string, its locale coverage, and whether Swift reads it.
- `python3 Pillie/scripts/copy-rewrite/copy-voice-lint.py` flags English lines that break the mechanical rules and the glossary. It can't judge warmth. A person still reads the copy.
- `python3 Pillie/scripts/copy-rewrite/check-translated-copy.py` checks active-day wording in every locale.
