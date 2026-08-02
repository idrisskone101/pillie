# German ASO keyword recommendation

Status: **Astro-informed final recommendation; explicit user approval is still required before any App Store Connect change.**

## Final recommendation

```text
pillenalarm,zyklus,tracker,medikamente,medikamenten,tabletten,einnahme,antibabypille,vergessen,dosis
```

Length: **100 / 100 characters**.

The exact tokens do not duplicate any complete indexed token in the German name `Pillie: Pillen-Erinnerung` or subtitle `Pille, Ring & Pflaster`. `antibabypille` and `pillenalarm` are distinct high-intent German compounds, not redundant standalone `pille`, `pillen`, `erinnerung`, `ring`, or `pflaster` entries.

## Astro Germany evidence

| Query | Popularity | Difficulty | Additional signal |
| --- | ---: | ---: | --- |
| `pillenalarm` | 34 | 48 | Pillie rank improved 119 → 105; strongest owned-term signal |
| `zyklus tracker` | 53 | 70 | Highest popularity, but competitive |
| `medikamente` | 22 | 58 | Useful broader discovery term; listing remains explicit about Pillie's contraception-routine scope |
| `medikamenten erinnerung` | 9 | 43 | Both non-title token components retained through `medikamenten` plus indexed `erinnerung` |
| `tabletten erinnerung` | 7 | 42 | `tabletten` retained; `erinnerung` is already indexed by the title |
| `einnahme erinnerung` | 5 | 7 | Low-difficulty intent; `einnahme` retained |
| `antibabypille erinnerung` | 5 | — | Only 25 competing apps; `antibabypille` retained |

Competitor extraction from `pillenalarm` produced no additional useful combinations.

## Selection rationale

- Prioritizes `pillenalarm`, the strongest existing Pillie signal, as the exact compound measured by Astro.
- Preserves both parts of the high-popularity `zyklus tracker` query without spending a space.
- Uses the indexed title token `erinnerung` to combine with `medikamenten`, `tabletten`, `einnahme`, and `antibabypille`, avoiding four repeated copies of the same word.
- Adds `vergessen` and `dosis` as product-accurate reminder intent while staying within exactly 100 characters.
- Excludes standalone `pillie`, `pille`, `pillen`, `erinnerung`, `ring`, and `pflaster` because the name/subtitle already index them.
- Excludes `nuvaring`: it is a third-party brand and there is no need to use it opportunistically when the subtitle already covers `Ring` generically.
- Excludes `refill`: it is English and a secondary feature, while the German listing uses the accurate term `Vorratserinnerungen`.

This recommendation is locked for review. It must not be written to App Store Connect until the user explicitly approves the exact field.
