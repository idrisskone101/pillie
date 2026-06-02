# PostHog Product Analytics Telemetry

Pillie will use PostHog US Cloud for consented first-party Product Analytics Telemetry, with manual event capture only and PostHog MCP as a setup and verification prerequisite. This is not Apple-defined Tracking: Pillie will not use IDFA, ATT, cross-app or cross-site matching, data brokerage, advertising use cases, session replay, or autocapture.

The v1 event taxonomy may capture coarse app-flow events such as onboarding progress, paywall actions, permission prompts, tab selection, settings sheet opens, settings saves by setting category, today action completion, new pack or cycle starts, and Plus upsell actions. It must not capture contraception method, regimen, cycle day, reminder time, reminder interval values, supply thresholds, taken or missed status, pain point selections, goal selections, miss-frequency selections, app or category names, app or category counts, calendar percentages, adherence values, or free text. Pillie will not call `identify()` or send account IDs, email addresses, RevenueCat customer IDs, or other stable cross-device user identifiers in v1.

US Cloud is accepted for lower setup friction and because the protection boundary is consent plus the event taxonomy, not regional hosting. App Store Connect privacy answers and Pillie's privacy policy must disclose first-party analytics collection and PostHog as an analytics provider while keeping tracking disabled as long as the above boundary holds. Pillie will include an onboarding Analytics Consent step before any PostHog capture starts, and Settings must let users turn future analytics capture off after consent. App code will call a small Pillie-owned analytics wrapper rather than PostHog directly from views, so event names, allowed properties, consent gating, opt-out behavior, and test no-op behavior stay centralized. The PostHog project token and host will come from build configuration, with analytics disabled when the project token is missing or Analytics Consent has not been granted.

Events that occur before Analytics Consent is granted are dropped, not buffered or backfilled. The first captured event may be the consent grant itself or the next eligible app-flow event after consent.

Analytics Consent is reversible in Settings. Turning analytics on later starts capture from that point forward only; turning it off stops future capture.

The onboarding consent screen should use plain product language, not Apple ATT language. The approved direction is:

- Title: `Help improve Pillie?`
- Body: `Share privacy-safe product analytics so we can see which screens work and where setup gets confusing. We never send your contraception method, reminder time, history, app-blocking choices, or anything you type.`
- Actions: `Allow Analytics` and `Not Now`
- Note: `You can change this anytime in Settings.`
