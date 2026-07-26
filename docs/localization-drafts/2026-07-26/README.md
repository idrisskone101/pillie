# en-GB App Store storefront review package

Status: deterministic offline dry run for issue #232. This directory does not create an App Store Connect locale or upload metadata or screenshots.

## Review artifacts

- `source/en-US-control.json`: byte-locked live en-US control fixture.
- `metadata/en-GB-storefront.json`: one additive en-GB App Info and Version Localization record.
- `metadata/additive-diff.md`: generated human-readable preview of the future additions.
- `screenshots/en-GB-overlays.json`: optional five-frame British-English overlay copy.
- `quality/storefront_package.rb`: pure validation and preview seam.
- `quality/storefront_package_test.rb`: behavior tests for additive-only safety, limits, keywords, claims, preview targeting and overlays.
- `quality/validate.rb`: deterministic package validator.
- `quality/validation-report.md`: checked validator output and review notes.

## Validate

```sh
ruby docs/localization-drafts/2026-07-26/quality/storefront_package_test.rb
ruby docs/localization-drafts/2026-07-26/quality/validate.rb
```

The validator fails if the en-US fixture bytes change, if the package can target en-US, or if the committed preview no longer matches the validated en-GB record.

## Safety boundary

- No live App Store Connect locale, metadata, screenshot or release mutation.
- No Astro mutation.
- No Swift, Xcode project, app asset or production localization change.
- Overlay copy is review material only; no rendered screenshot asset is included.
