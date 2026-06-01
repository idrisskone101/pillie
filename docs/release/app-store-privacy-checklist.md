# App Store Privacy Checklist

Use this checklist when preparing a Pillie release that includes Product Analytics Telemetry.

## Product Analytics Telemetry

- Data category: Usage Data
- Data type: Product Interaction
- Purpose: Analytics
- Linked to the user: No
- Used for tracking: No
- Tracking domains: None
- Analytics provider: PostHog

## Boundary

Product analytics telemetry is limited to first-party app usage signals such as app launches, onboarding progress, paywall actions, permission prompt outcomes, tab selection, settings area opens or saves, and coarse feature usage events.

Do not include private routine details, reminder values, app-blocking selections, adherence values, free text, advertising identifiers, account identifiers, or third-party cross-app or cross-site tracking in Product Analytics Telemetry.

## Release Owner Checks

- Confirm `Pillie/Pillie/PrivacyInfo.xcprivacy` declares `NSPrivacyCollectedDataTypeProductInteraction` for `NSPrivacyCollectedDataTypePurposeAnalytics`.
- Confirm Product Interaction data is marked not linked to the user.
- Confirm Product Interaction data is marked not used for tracking.
- Confirm `NSPrivacyTracking` is false and tracking domains are empty.
- Confirm the public privacy policy discloses limited product analytics telemetry and names PostHog as an analytics provider.
- Confirm the public privacy policy excludes private routine details, reminder values, app-blocking selections, adherence values, and free text from telemetry.
