# Locale rewrite brief

This is the contract for anyone, person or agent, who writes a Pillie locale. Read `docs/copy/voice.md` first. This page adds what's specific to translation.

## Input and output

- Input is one JSON object per locale. Each key is `Table:key`. Each value holds `en` (the new English), `current` (today's translation), an optional `en_before` (the English it replaced), and an optional `comment` (where the string appears).
- Output is `Pillie/scripts/copy-rewrite/voice-plan/<lang>.json`. It maps every input key to the final string for that locale. Include every key, including the ones you keep as they are.
- `python3 Pillie/scripts/copy-rewrite/apply-voice-plan.py check` must pass before anything is applied.

## How to decide each string

1. Read `en` and `comment`. Work out what the person sees and what happens next.
2. Keep `current` when it already says what `en` says, in the voice, with the glossary term for the locale. Don't rewrite a good line just to make it different.
3. Rewrite when `en_before` is present and the meaning moved, when `current` is a calque of English, or when it breaks the rules below.
4. Keep the result about as long as the English, or up to 30% longer. Buttons and labels stay short enough to fit on one line on an iPhone.

## Rules

- Glossary first. Before writing any string, pick one native term for each glossary idea in `docs/copy/voice.md` (check in, reminder, follow-up reminders, App blocking, pause, active days, break days, streak). Use that term every time. Write the choices at the top of your notes.
- "Check in" is a native verb or phrase, not the English word. Borrow the English only if that locale's users really say it.
- Register:
  - Informal in European languages where consumer apps use it (`du`, `tu`, `tú`, `jij`, `ty`, `sen`, and so on).
  - Formal in Hindi, Bengali, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu, and Urdu (`आप`, `আপনি`, `તમે`, `ನೀವು`, `നിങ്ങൾ`, `तुम्ही`, `ଆପଣ`, `ਤੁਸੀਂ`, `நீங்கள்`, `మీరు`, `آپ`).
  - Arabic addresses the reader in the feminine form.
  - Japanese uses です・ます and no greetings. Korean uses 해요체. Chinese uses 你.
- Keep every placeholder (`%@`, `%lld`, `%1$@`, `%%`) exactly. You may move a placeholder within the sentence.
- `Pillie`, `Pillie Plus`, and `Plus` are never translated.
- Active days: reuse the wording in `Localizable:onboarding.regimen.21_7` for that locale. The trial is always counted in active days.
- Calendar lines stay calendar lines ("tonight", "tomorrow night", "in 5 days", "on %@").
- No em dashes. No ALL CAPS in the string. The app uppercases eyebrows and badges itself.
- No greetings in notifications ("Hey", "Hallo", "こんにちは"). Lead with the step.
- No health promises. Never "protected", "safe", "never miss", or anything about how well contraception works.
- Use the locale's normal punctuation and quotation marks. French keeps the narrow space before `?`, `!`, `:`, and `;`.

## Review

A second reader translates each changed string back into English without seeing `en`, then compares. Any string whose back-translation changes the meaning gets fixed.
