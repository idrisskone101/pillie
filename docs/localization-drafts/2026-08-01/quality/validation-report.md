# German storefront validation report

Result: **PASS**

Validated: 2026-08-01

## Validator output

```text
de-DE name: 25/30
de-DE subtitle: 22/30
de-DE keywords: 100/100
de-DE description: 1350/4000
de-DE whatsNew: 125/4000
de-DE promotionalText: 98/170
de-DE keyword candidate FINAL: 100/100 (recommended-final-astro)
en-US control SHA-256: d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d
target locales: de-DE
protected locales: en-US
keyword status: FINAL_ASTRO_VALIDATED_REQUIRES_EXPLICIT_USER_APPROVAL
ASC mutation: none
RESULT: PASS
```

## Validated guarantees

- App Info and Version Localization use separate, complete field sets.
- Canonical JSON and both review-only `.strings` inputs contain identical values.
- Every Apple field stays within its Unicode character limit.
- The final keyword field contains no empty or duplicate token, no exact app-name/subtitle token, and no third-party brand.
- The recorded Astro signal set targets Germany and explicitly excludes `nuvaring` and `refill`.
- The live 2.0.6 Version and App Info IDs are recorded as editable, and the proposed German diff is additive because both `de-DE` localization records were absent at read-only preflight.
- Copy is consistently formal German and rejects guarantee, contraceptive-efficacy, absolute-efficacy, and “always protected” claims.
- The 2026-07-26 `en-US` control fixture remains byte-identical.
- The package targets `de-DE` only, explicitly protects `en-US`, keeps every field behind explicit user approval, and records that no App Store Connect mutation occurred.

## Remaining decision

The Astro-informed 100-character recommendation is structurally final. The user must still review and explicitly approve this exact keyword field, the metadata copy, and the five screenshots before any App Store Connect write.
