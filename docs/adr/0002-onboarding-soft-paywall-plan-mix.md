# Onboarding Soft Paywall Plan Mix

Pillie's redesigned onboarding will keep a soft paywall with annual trial, monthly fallback, and a clear free path. It will not add weekly or lifetime plans in this redesign pass.

Research from mobile onboarding and paywall examples suggests that broader plan mixes can improve price anchoring, especially weekly plus yearly plus lifetime. Pillie's current subscription surface, however, is already implemented around annual and monthly RevenueCat products, with annual selected by default and a free onboarding path available. Adding weekly or lifetime products would require App Store Connect and RevenueCat configuration, pricing decisions, copy changes, tests, and a separate monetization experiment.

The onboarding redesign is focused on sequencing and value presentation: ask for Analytics Consent, show a truthful Product Demo Moment with an integrated Plus Challenge Demo, collect setup context, summarize a Reminder Plan, then present Pillie Plus as optional. Annual with trial remains the primary CTA, monthly remains the secondary paid fallback, and free use remains explicit. Future pricing experiments can revisit weekly or lifetime plans after the new funnel is measurable.

Analytics Consent must appear immediately after Welcome and before any PostHog capture starts. Welcome may render without analytics capture. The consent screen offers `Allow Analytics` and `Not Now`; either choice continues onboarding. Declining consent must not block the Product Demo Moment, the free plan, or Pillie Plus purchase flow. The consent screen should describe first-party product analytics in plain language, not Apple ATT Tracking.

The Reminder Plan screen appears before the Soft Onboarding Paywall. This keeps the setup valuable on the free path and makes the Plus offer an optional enhancement to an already-created reminder setup rather than a gate before value.

Pillie will not add an exit or closing offer in this v1 redesign. When a user chooses the free path, onboarding should respect that choice and may show a simple free-plan confirmation. Discounts, roulette-style offers, or second paywall asks should be treated as separate experiments because they change the trust posture of a contraception reminder app.

After `Continue for Free`, onboarding will show a short free-plan confirmation with one primary action to start using Pillie. It may clarify that daily reminders and tracking are active on the free plan and that Pillie Plus can be explored later in Settings, but it should not present another upgrade ask.

Plus App Blocking setup will only appear during onboarding for users who start the annual trial, subscribe, restore Plus, or already have Plus. Free users should finish onboarding after the free-plan confirmation and enter the app; app blocking can remain discoverable later through Settings or Plus upsells without implying that blocking is active on the free plan.

The redesign will include an onboarding review prompt after the Product Demo Moment and before personalization questions. The prompt is placed after a positive value demonstration but before higher-friction setup, permissions, and monetization steps. This is a deliberate growth trade-off; if ratings quality or trust signals regress, the prompt should be revisited or moved to a post-use success moment.

The review prompt should be framed as a soft native rating request: title `Does this feel useful so far?`, body `A quick rating helps more people find Pillie.`, primary action `Rate Pillie`, and secondary action `Not now`. Implementation should use Apple's native review request mechanism and should not promise App Store navigation.

The Product Demo Moment should be one animated screen, not a swipeable carousel. It should integrate the interactive Plus Challenge Demo cleanly within the same step so users can try the shaking motion currently used by Pillie's challenge behavior without adding another onboarding screen. The challenge demo must be explicitly presented as a Pillie Plus preview so free users do not infer that app blocking or challenge mode is active on the free plan.

The combined Product Demo Moment structure should be: animated `Reminder -> Log -> Updated` mini timeline, compact live shake card labeled `Pillie Plus preview`, then one `Continue` CTA. The shake interaction is optional, and simulator builds should keep a tap-to-simulate fallback.

The v1 redesign preserves Pillie's existing personalization categories and stored enum semantics for pain points, personal goals, and miss frequency. Display copy can be refined, but new categories such as travel-specific hurdles or renamed goal concepts should be treated as separate product changes.

Paywall trust cues must be truthful and operational: the annual trial, App Store cancellation, continued free reminders and tracking, and on-device app blocking. Pillie does not run ads in any tier, so `no ads` should not be presented as a Plus-only benefit. The paywall should avoid fake social proof, fake countdowns, fake scarcity, rating claims without a live source, and medical or protection claims.

The Soft Onboarding Paywall must clearly explain what Pillie Plus includes before asking for payment. It should include a compact Plus value breakdown for App Blocking and shake-to-unlock or shake-to-confirm behavior. It should also preserve the free path by making clear that smart reminders, daily reminders, and tracking remain available without Plus.

Use a short Plus benefit list, not a full Free-vs-Plus comparison table, for the v1 paywall. The list should focus on actual Plus benefits: app blocking after an unlogged due action and shake-to-unlock or shake-to-confirm behavior. Smart reminders, daily reminders, and tracking remain available in the free tier.
