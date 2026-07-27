# Issue #236 German localization QA

Date: 2026-07-26
Branch: `codex/issue-236-german-localization`

## Scope delivered

- Added German (`de`) translations to all 383 rows across the main UI,
  notifications, commerce, DeviceActivityMonitor shield, and
  ShieldConfiguration catalogs.
- Added German-aware presentation for singular history/follow-up copy, every pill
  regimen, trial and blocking states, custom reminder presets, and method-aware
  pack/cycle nouns.
- Kept user-authored custom reminder text byte-for-byte unchanged.
- Added an additive, review-only `de-DE` storefront package. It does not mutate
  `en-US`, App Store Connect, pricing, builds, or release state.

## Vertical TDD evidence

Each slice started with one failing behavior before the minimum production change:

| Slice | RED | GREEN |
| --- | --- | --- |
| Setup/catalog seam | 14 incorrect or fallback strings | German setup, methods, reminder actions |
| Onboarding, shields | 2 fallback strings | Main and both extension targets |
| Dates, plurals, commerce | 7 formatting failures | German date, number, price, and period copy |
| Singular grammar | 2 failures (`1 Einträge`, `Alle 1 Minuten`) | `1 Eintrag`, `Jede Minute` |
| Reminder presets | English defaults returned | German preset defaults; authored text preserved |
| Regimens | 26/2, 84/7, and 365/0 fallback/wrong summary | All seven regimen summaries |
| Trial/blocking states | 11 English fallbacks | German trial, paywall, blocking, and actions |
| Pack/cycle nouns | Missing public presentation seam | `Packung` for pill; `Zyklus` for patch/ring |
| Accessibility layout inputs | 5 long-label failures | Compact German question, choices, and outcome |
| Storefront package | Missing validator module/fixture | Additive-only package and immutable `en-US` control |

The final German contract contains 12 value/presentation tests, including catalog,
notification, Screen Time, Today, history, settings, commerce, claim, custom-copy,
and accessibility-layout behavior.

## Automated verification

- `GermanLocalizationContractTests`: green.
- Affected English trial/blocking presentation tests: 39 green with an isolated
  English simulator locale; the pre-existing Italian simulator locale was restored.
- Italian localization contracts: 13 green.
- `scripts/validate-german-localization.rb`: 383 rows / 5 catalogs, green.
- `scripts/validate-italian-setup-localization.rb`: green.
- `scripts/validate-italian-daily-localization.rb`: 189 rows, green.
- `german_storefront_package_test.rb`: 2 runs / 10 assertions, green.
- Pillie Debug simulator build: green, 0 errors, 0 warnings.

The shared pinned simulator began in Italian. English-default presentation tests
therefore require a temporary English simulator locale; the verification operation
restored the original Italian language/region in a trap. No shared simulator was
erased or replaced.

## Locked simulator matrix

Pinned simulator: iPhone 17 Pro, `124DC75F-0771-4C81-841D-F13655138260`.

| Surface | Default | Accessibility Large |
| --- | --- | --- |
| Personalization onboarding | Pass; title, chips, outcome labels, CTA readable | German question and choices readable after compact-copy TDD fix |
| Today | Pass; German date, Today state, cycle/status copy | Existing global fixed-height scaling baseline applies |
| Trial activation/status sheet | Pass; four features, states, actions, expiry, CTA | Fixed-height scaffold behavior is unchanged from the approved Italian baseline |
| Settings | Pass; German section/row copy and wrapped reminder-reset row | Existing global fixed-height scaling baseline applies |

Rendered evidence:

- `post-rebase-onboarding-de.png` (fresh post-rebase pinned-simulator proof)
- `onboarding-default-de.png`
- `onboarding-accessibility-large-de.png`
- `trial-status-de.png`

The critical German compound labels are readable at Accessibility Large. The
shared onboarding progress header and fixed-height CTA still clip at accessibility
sizes in the same way as the approved Italian/English scaffold baseline; resolving
that cross-locale component behavior is intentionally not hidden inside this
localization change.

## Storefront review package

Review-only field lengths:

- Name: 25 / 30
- Subtitle: 22 / 30
- Keywords: 87 / 100
- Description: 1,450 / 4,000
- What's New: 128 / 4,000

The app uses friendly neutral German `du`; storefront copy uses formal `Sie`.
Claim lint rejects guarantees, contraceptive-efficacy claims, “always protected”
language, and judgmental missed-action copy.

## Deliberately gated work

No German App Store screenshot candidates, Astro evidence, GPT Image variants,
resizing/cropping, ASC locale, metadata upload, screenshot upload, build attachment,
pricing change, or submission was started.

Per the worker contract, App Store screenshot and live storefront work may begin
only after this implementation is merged **and** a maintainer explicitly approves
the storefront copy and five-frame direction. The future screenshot order remains:
routine reminders; tailored schedule; log and resume apps; history; Shake to
Confirm.
