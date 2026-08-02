# German App Store approval diff

Status: **review package only; no App Store Connect mutation authorized.**

Target: German storefront (`de-DE`) for version 2.0.6.

Read-only App Store Connect preflight on 2026-08-01 resolved:

- Version ID `b1440d5c-9b53-4bc0-98ec-8b0f40de0dec`, state `PREPARE_FOR_SUBMISSION`.
- App Info ID `d03b4450-ab0c-45fd-94b7-3c36edb33b09`, state `PREPARE_FOR_SUBMISSION`.
- `de-DE` is supported and currently absent from both App Info and Version Localization.

The exact operation after approval is therefore an additive `de-DE` create for both localization records, followed by a five-image `APP_IPHONE_67` upload to the newly created German Version Localization. No existing locale field or screenshot is replaced.

## App Info localization

| Field | Proposed value | Delta from 2026-07-26 German draft |
| --- | --- | --- |
| Locale | Create `de-DE` | Add |
| Name | `Pillie: Pillen-Erinnerung` | Add |
| Subtitle | `Pille, Ring & Pflaster` | Add |
| Privacy policy URL | `https://idrisskone101.github.io/pillie/privacy-policy` | Add |

## Version Localization

| Field | Proposed action | Delta from 2026-07-26 German draft |
| --- | --- | --- |
| Locale | Create `de-DE` only | Add |
| Description | Add the 1,350-character copy in `de-DE-storefront.json` | Add |
| Keywords | Add the final Astro-informed field, 100 characters | Add; locally validated; **explicit user approval still required** |
| What's New | Add the 125-character German-localization release note | Add |
| Promotional text | Add the 98-character text below | Add |
| Marketing URL | `https://idrisskone101.github.io/pillie/` | Add |
| Support URL | `https://idrisskone101.github.io/pillie/support` | Add |

### Exact promotional text

> Erinnerungen für Pille, Pflaster und Ring – mit Verlauf und optionaler App-Pause für Ihren Alltag.

### Exact What's New

> Pillie ist jetzt vollständig auf Deutsch verfügbar. Außerdem wurden Texte und Layouts verbessert und kleinere Fehler behoben.

### Exact keyword field currently staged for review

```text
pillenalarm,zyklus,tracker,medikamente,medikamenten,tabletten,einnahme,antibabypille,vergessen,dosis
```

Astro Germany evidence is recorded in `de-DE-aso-keywords.md`. The field is the locked recommendation, but remains unapproved and unapplied.

## Screenshot addition

After the new German Version Localization exists, create one `APP_IPHONE_67` set and add these reviewed files in order:

1. `01-pillen-erinnerungen.png`
2. `02-zeitplan-alltag.png`
3. `03-protokollieren-apps.png`
4. `04-verlauf-ueberblick.png`
5. `05-zum-bestaetigen-schuetteln.png`

All five are 1320×2868 RGB PNGs and passed `asc screenshots validate` with zero errors and warnings. Exact source provenance, replacement copy, final hashes, and visual QA are in `../screenshots/de-DE-gpt-image-edit-manifest.md`.

## Explicit no-ops outside `de-DE`

- No `en-US`, `en-GB`, Italian, or other storefront field.
- No pricing, availability, subscription, privacy declaration, age rating, category, copyright, release option, build, or review-submission field.
- No screenshot upload, deletion, reordering, or replacement.

## Approval statement required before execution

The user must explicitly approve all three items together or individually:

1. The exact App Info and Version Localization copy.
2. The final Astro-informed keyword string.
3. The final five German `APP_IPHONE_67` screenshots and order.

Only after approval should the coordinator reconfirm the two live IDs/states, apply this additive `de-DE` diff, upload the five reviewed screenshots in order, and read every field and screenshot back from App Store Connect.
