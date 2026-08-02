# German App Store review package

Status: **German storefront review only — explicit approval required before any App Store Connect change.**

This package prepares the `de-DE` App Info and Version Localization records for review. It does not create or update a locale, upload screenshots, attach a build, or submit a version. It intentionally contains no British storefront work.

## Review artifacts

- `metadata/de-DE-storefront.json`: canonical German metadata record and release gate.
- `metadata/app-info/de-DE.strings`: exact App Info localization input.
- `metadata/version/de-DE.strings`: exact Version Localization input using the final Astro-informed keyword recommendation.
- `metadata/de-DE-approval-diff.md`: field-by-field proposed change and no-op list.
- `metadata/de-DE-aso-keywords.md`: final 100-character German recommendation, Astro evidence, overlap rationale, and exclusions.
- `source/asc-read-only-evidence.md`: source-control and screenshot-set evidence already supplied to this task.
- `quality/validate.rb`: deterministic, offline field-limit, structure, claim, locale, and `.strings` parity validator.
- `quality/validation-report.md`: checked validator output.

## Italian release-checklist parity

The completed Italian release lane established the checklist used here:

- Keep App Info and Version Localization records separate.
- Preserve the English source listing as an immutable control.
- Validate every Apple character limit using Unicode character counts.
- Keep screenshot order and storefront copy reviewable before any upload.
- Read back the exact live locale, screenshots, and version after an approved mutation.
- Treat metadata, screenshots, build attachment, and submission as separate approval-gated operations.

German now has the same local review structure. Screenshot artifacts are owned by the sibling `screenshots/de-DE` package and remain subject to the same approval gate.

## Validate

```sh
ruby docs/localization-drafts/2026-08-01/quality/validate.rb
```

The package is content-ready, including the final 100-character Astro-informed keyword recommendation. Every field and all five screenshots still require explicit user approval before any App Store Connect write.

## Safety boundary

- Target locale: `de-DE` only.
- Protected locale: `en-US`; no source field may be edited by this package.
- No App Store Connect mutation was performed. The coordinator supplied read-only Astro Germany evidence, which is recorded in the ASO recommendation.
- Before any future write, resolve the current editable version and App Info IDs, compare the live `de-DE` state, show the exact resulting diff, and obtain explicit approval.
