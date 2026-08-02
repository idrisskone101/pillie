# App Store source evidence available to the German package

This file records evidence supplied to this task; producing the metadata package did not access or mutate App Store Connect.

## Immutable metadata control

The existing repository fixture at `../../2026-07-26/source/en-US-control.json` records:

- App ID: `6759352439`
- Bundle ID: `com.idrisskone.pillie`
- Source locale: `en-US`
- Source version: `2.0.5` (`READY_FOR_DISTRIBUTION`)
- Version ID: `e46094a1-f9c6-4cfd-9515-04dc17592c66`
- App Info localization ID: `e8d1d2bf-f316-483d-bf30-fac345df730d`
- Version localization ID: `8e8c8f37-9d02-473b-884c-48afe53a9c92`
- Fixture SHA-256: `d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d`

## Reconfirmed screenshot source

Read-only evidence supplied on 2026-08-01 reconfirmed the same `en-US` 2.0.5 Version Localization ID and its source screenshot set:

- Screenshot set ID: `3ee04cc8-e4dd-427b-92b9-6bd470433a98`
- Display type: `APP_IPHONE_67`
- Source frames: five, all `COMPLETE`, each `1320 × 2868`

Those exact five frames—not newly invented compositions—are the source for the German screenshot lane.

## Required approval-time preflight

The final read-only preflight on 2026-08-01 resolved:

- Version 2.0.6 ID: `b1440d5c-9b53-4bc0-98ec-8b0f40de0dec` (`PREPARE_FOR_SUBMISSION`).
- Current App Info ID: `d03b4450-ab0c-45fd-94b7-3c36edb33b09` (`PREPARE_FOR_SUBMISSION`).
- German is supported, but `de-DE` is not configured on the version.
- A filtered live read returned no `de-DE` Version Localization and no `de-DE` App Info localization.

No write command was run. Immediately before any future approved write:

1. Reconfirm the two live IDs remain editable and `de-DE` remains absent.
2. Reconfirm the final Astro-informed keyword string.
3. Obtain explicit user approval for metadata, screenshots, and the final keyword field.
4. Create only the two `de-DE` localization records and upload only the reviewed German screenshots.
5. Read every resulting field and screenshot back from App Store Connect.
