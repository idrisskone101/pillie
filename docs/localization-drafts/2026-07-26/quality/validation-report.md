# en-GB storefront validation report

Result: **PASS**

Validated: 2026-07-26

## Validator output

```text
en-GB name: 30/30
en-GB subtitle: 27/30
en-GB keywords: 100/100
en-GB description: 1171/4000
en-GB whatsNew: 102/4000
en-GB screenshot overlays: 5/5
en-US control SHA-256: d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d
additive locales: en-GB
RESULT: PASS
```

## Automated behavior coverage

- The en-US control is byte-locked and exactly one additive en-GB record is allowed.
- Apple limits use Ruby Unicode string character counts.
- Keywords reject empty, duplicate and Pillie tokens.
- The exact approved name, subtitle and 100-character keyword string are locked.
- Guarantee, contraceptive-efficacy and always/stay-protected claims are rejected.
- The generated preview is additions-only and cannot target en-US.
- The optional overlay lane contains exactly five ordered frames and passes 48/80-character copy caps.

The behavior suite passes with 7 tests and 43 assertions.

## Review boundary

The complete future App Info and Version Localization values are in `../metadata/en-GB-storefront.json`; the human-readable additions-only preview is in `../metadata/additive-diff.md`.

The screenshot overlays are copy-only review material using English UI captures. This is a nonvisual repository change, so simulator screenshots are not relevant evidence for this PR.

No App Store Connect, Astro, Swift, Xcode project, app asset or production localization mutation was performed.
