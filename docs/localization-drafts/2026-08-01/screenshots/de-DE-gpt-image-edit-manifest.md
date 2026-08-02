# German App Store screenshot edit manifest

Prepared: 2026-08-01
Storefront/localization: Germany (`de-DE`) only
Status: review-ready local artifacts; **not uploaded to App Store Connect**

## Source provenance

The five inputs are the current `en-US` `APP_IPHONE_67` screenshots downloaded read-only from App Store Connect version 2.0.5. They were edited with GPT Image 2 using composition-preserving text-localization prompts, following the accepted Italian workflow.

- Version localization ID: `8e8c8f37-9d02-473b-884c-48afe53a9c92`
- Screenshot set ID: `3ee04cc8-e4dd-427b-92b9-6bd470433a98`
- Display type: `APP_IPHONE_67`
- Source directory: `/private/tmp/pillie-german-screenshot-source-2026-08-01/APP_IPHONE_67`

| Order | Source asset | Source SHA-256 |
| --- | --- | --- |
| 1 | `01_a4358e14-5e98-4383-97b4-fe8df2bda3f4_01-never-miss-birth-control.png` | `3d383d764ae1e7eecd8d206310d99f49316b1db9065db977b6a041b4f1fea163` |
| 2 | `02_dd2d771d-49ff-498d-bae7-bb0f3f731208_02-set-up-your-pill-alarm.png` | `6bf89df78d26a6b17d2c4fd46c7707fff9701f90fc6ea4354681f7263fcf5de1` |
| 3 | `03_d1a77a99-b893-4427-81be-838b874ef7c1_03-take-it-unlock-everything.png` | `02182d35258647c4455834365853262ef3f262d984df805548a6d91819332d12` |
| 4 | `04_6b002bb1-daf7-46fb-8481-fc3e2bef1408_04-track-every-dose.png` | `7e54d77673ab5cb5fdd0b16795dae3797a113bea41b57d10397c051b0c8f4124` |
| 5 | `05_74b8e1f8-3c40-453b-94f5-53ba68cb15f3_05-shake-to-confirm.png` | `cb2453b9d6e251a5c1c8034332f8059eba7952b5d2da92404fb2befc630650f4` |

## German final set

| Order | Final asset | Marketing headline | Final SHA-256 |
| --- | --- | --- | --- |
| 1 | `APP_IPHONE_67/01-pillen-erinnerungen.png` | Pillen-Erinnerungen, die dranbleiben | `d0ef481fdab048580915fbaa890695e3e893158f8476de813c2f1c497964d695` |
| 2 | `APP_IPHONE_67/02-zeitplan-alltag.png` | Ein Zeitplan, der in den Alltag passt | `c007c395d5a979f8ab22f185c43f4efebc20233ea33f823c332a176de84767a6` |
| 3 | `APP_IPHONE_67/03-protokollieren-apps.png` | Protokollieren. Apps weiter nutzen. | `469b39df78abc26fc07d94eabb992800aceb543b30344c4e588beb9128e8045f` |
| 4 | `APP_IPHONE_67/04-verlauf-ueberblick.png` | Der Verlauf auf einen Blick | `d1ced0c4eec3d85974c46c03514785342dbcbab1d16e79d61c884bf7e811dd39` |
| 5 | `APP_IPHONE_67/05-zum-bestaetigen-schuetteln.png` | Zum Bestätigen schütteln | `119d2882570347c4d3a2a4ce5d967e38e8f3cf1ec78ceba4bd5ccc135dc37b1e` |

`de-DE/review-contact-sheet.png` is a review convenience only and is not part of the upload directory.

## German replacement matrix

### Frame 1

| Source text | German replacement |
| --- | --- |
| Never miss your birth control. | Pillen-Erinnerungen, die dranbleiben |
| Pillie blocks distractions until your pill is handled. | Für Routinen mit Pille, Pflaster und Ring. |
| Friday, May 29 | Freitag, 29. Mai |
| Today | Heute |
| 8:00 AM | 08:00 |
| Take Pill | Pille einnehmen |
| PILL | PILLE |
| Pill 1 · Day 1 | Pille 1 · Tag 1 |
| Pack 1 · 21/7 CYCLE | Packung 1 · 21/7-ZYKLUS |
| DAY 1 OF 28 | TAG 1 VON 28 |
| DAY STREAK | AKTUELLE SERIE |
| Active | Aktiv |
| BLOCKING | APP-PAUSE |
| Apps paused | Apps pausiert |
| Blocked until pill is taken | Pausiert, bis du die Pille protokollierst |
| Mark Pill as Taken | Als erledigt markieren |
| no scrolling yet → | noch nicht scrollen → |

### Frame 2

| Source text | German replacement |
| --- | --- |
| Set up your pill alarm. | Ein Zeitplan, der in den Alltag passt |
| Choose your schedule once. Pillie handles the nudging. | Schema, Uhrzeit und Folgeerinnerungen frei wählen. |
| Pick your pill time | Wähle eine Erinnerungszeit |
| Next dose | Nächste Einnahme |
| 8:00 AM | 08:00 |
| Daily reminder | Tägliche Erinnerung |
| Every day at the same time. | Jeden Tag zur gleichen Zeit. |
| S M T W T F S | S M D M D F S |
| Set Alarm | Erinnerung festlegen |
| your new bestie → | deine neue Begleiterin → |

### Frame 3

| Source text | German replacement |
| --- | --- |
| Take it. Unlock everything. | Protokollieren. Apps weiter nutzen. |
| Once you confirm, your blocked apps come back. | Pillie Plus kann ausgewählte Apps pausieren. |
| Friday, May 29 | Freitag, 29. Mai |
| Today | Heute |
| 8:00 AM | 08:00 |
| TAKEN | ERLEDIGT |
| Take Pill | Aktion erledigt |
| Pill 1 · Day 1 | Pille 1 · Tag 1 |
| Pack 1 · 21/7 CYCLE | Packung 1 · 21/7-ZYKLUS |
| DAY 1 OF 28 | TAG 1 VON 28 |
| DAY STREAK | AKTUELLE SERIE |
| Unlocked | Verfügbar |
| APPS | APPS |
| Apps unlocked | Apps wieder verfügbar |
| Available after pill confirmed | Nach dem Protokollieren der Aktion |
| all set ✨ | alles erledigt ✨ |
| Pill Taken | Aktion protokolliert |

### Frame 4

| Source text | German replacement |
| --- | --- |
| Track every dose. | Der Verlauf auf einen Blick |
| See what you took, missed, and where your routine stands. | Erledigte, offene und Pausentage im Überblick. |
| History | Verlauf |
| Your tracking overview | Dein Protokoll im Überblick |
| Taken | Erledigt |
| Missed | Nicht protokolliert |
| Break | Pause |
| May 2026 | Mai 2026 |
| SU MO TU WE TH FR SA | SO MO DI MI DO FR SA |
| Your Monthly Care | Dein Monatsüberblick |
| This month | Dieser Monat |
| Home | Heute |
| Calendar | Verlauf |
| Settings | Einstellungen |

### Frame 5

| Source text | German replacement |
| --- | --- |
| Shake to confirm. | Zum Bestätigen schütteln |
| A tiny extra step for the reminders you usually swipe away. | Ein optionaler Extra-Schritt für die Routine. |
| Shake to Confirm | Zum Bestätigen schütteln |
| Give your phone a shake to mark today’s dose | Schüttle dein iPhone, um die heutige Aktion zu protokollieren |
| Tap to Confirm Instead | Zum Bestätigen tippen |
| Cancel | Abbrechen |

Leave `0 / 3` unchanged.

Raw GPT Image 2 results are retained under `APP_IPHONE_67/raw/`. Each final was normalized with the same transform used for the Italian set:

```sh
magick INPUT -filter Lanczos -resize '1320x2868^' -gravity center \
  -extent 1320x2868 -colorspace sRGB -alpha off -strip OUTPUT
```

## Text coverage

- Frame 1: German marketing copy, date, Today card, pill/pack/day labels, streak, App-Pause state, app-pause explanation, handwritten note, and completion CTA.
- Frame 2: German marketing copy, handwritten note, reminder-time title, next dose, daily schedule, localized weekday initials, and CTA.
- Frame 3: German marketing copy, completed action state, pack/day labels, streak, available apps state, handwritten note, and completed CTA.
- Frame 4: German marketing copy, history title/legend/month/weekdays/monthly card, and all three tab labels.
- Frame 5: German marketing copy, shake-confirmation title/body, fallback CTA, and cancel action. The source English marketing blocks were removed; the final contains exactly one headline block and one support block.

## Validation evidence

- All five finals were visually inspected after the final center crop for clipping, wrapping, duplicated copy, and residual English.
- All five are non-interlaced 1320×2868 sRGB RGB PNGs.
- `asc screenshots validate --path …/APP_IPHONE_67 --device-type APP_IPHONE_67 --output json` reports `5/5` ready, `0` errors, and `0` warnings.
- No screenshot was uploaded and no App Store Connect record was mutated.
