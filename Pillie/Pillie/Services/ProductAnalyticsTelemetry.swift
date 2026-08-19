//
//  ProductAnalyticsTelemetry.swift
//  Pillie
//

import Foundation

struct ProductAnalyticsTelemetry {
  static let live = ProductAnalyticsTelemetry()

  enum MainTab {
    case today
    case history
    case settings

    var analyticsScreen: AnalyticsScreen {
      switch self {
      case .today: return .home
      case .history: return .calendar
      case .settings: return .settings
      }
    }
  }

  private let analytics: AnalyticsTracking
  private let isPlus: () -> Bool
  private let acquisitionSource: () -> AcquisitionSource?
  private let trialTermsCohort: () -> TrialTermsCohort?

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.hasPlusAccess },
    acquisitionSource: @escaping () -> AcquisitionSource? = {
      AcquisitionSource(
        rawValue: UserDefaults.standard.string(forKey: PillStore.acquisitionSourceKey) ?? "")
    },
    trialTermsCohort: @escaping () -> TrialTermsCohort? = {
      SubscriptionManager.shared.trialTermsCohort
    }
  ) {
    self.analytics = analytics
    self.isPlus = isPlus
    self.acquisitionSource = acquisitionSource
    self.trialTermsCohort = trialTermsCohort
  }

  // The activation funnel can only be split by channel if `acquisition_source` rides
  // a guaranteed-fire event, not just the deep "how'd you hear" step that most installs
  // never reach. Attaching the persisted answer here `$set`s it on the person for every
  // user who has answered — including those who drop before completing onboarding (#140).
  func appLaunched(source: AnalyticsSource? = nil) {
    track(.appLaunched, source: source, acquisitionSource: acquisitionSource())
  }

  func appBecameActive() {
    track(.appBecameActive, acquisitionSource: acquisitionSource())
  }

  func onboardingStarted(step: AnalyticsStep) {
    track(.onboardingStarted, source: .onboarding, step: step)
  }

  func onboardingStepViewed(_ step: AnalyticsStep, stepIndex: Int? = nil) {
    track(.onboardingStepViewed, source: .onboarding, step: step, stepIndex: stepIndex)
  }

  func onboardingStepCompleted(_ step: AnalyticsStep, stepIndex: Int? = nil) {
    track(.onboardingStepCompleted, source: .onboarding, step: step, stepIndex: stepIndex)
  }

  func onboardingBackTapped(_ step: AnalyticsStep, stepIndex: Int? = nil) {
    track(.onboardingBackTapped, source: .onboarding, step: step, stepIndex: stepIndex)
  }

  func onboardingCompleted() {
    track(.onboardingCompleted, source: .onboarding, step: .reminderPlan)
    // af_complete_registration — onboarding is Pillie's "registration" milestone.
    AppsFlyerManager.shared.logCompleteRegistration()
  }

  /// Reports the stable core-onboarding boundary before trial or blocker setup.
  /// `onboarding_completed` remains alongside it as a compatibility event for
  /// existing PostHog dashboards and lifecycle automation.
  func coreOnboardingCompleted() {
    track(.coreOnboardingCompleted, source: .onboarding, step: .reminderPlan)
    onboardingCompleted()
  }

  /// Reports the terminal completion classification. Fires exactly one event —
  /// `protection_plan_activated` only when app blocking is genuinely activated, and
  /// `reminder_only_completion` otherwise. Reminder-only completion never emits an
  /// activation event. Both carry only coarse, consent-safe context (`source`,
  /// stable `step`, `is_plus`); no personalization answers, app names, or counts.
  func onboardingOutcomeClassified(_ outcome: ProtectionPlanCompletion.Outcome) {
    track(
      outcome.analyticsEvent,
      source: .onboarding,
      step: outcome == .protectionPlanActivated ? .protectionPlanReady : .appBlocking
    )
  }

  func onboardingAcquisitionSourceCompleted(_ source: AcquisitionSource) {
    track(
      .onboardingStepCompleted,
      source: .onboarding,
      step: .acquisitionSource,
      acquisitionSource: source
    )
  }

  /// Distraction Choices answered. The selected choices are sensitive and
  /// high-cardinality, so only the funnel step is sent — never the choices.
  func onboardingDistractionChoicesCompleted() {
    track(.onboardingStepCompleted, source: .onboarding, step: .distractionChoices)
  }

  /// Delay Consequence answered. The emotional answer is sensitive, so only the
  /// funnel step is sent — never the answer value.
  func onboardingDelayConsequenceCompleted() {
    track(.onboardingStepCompleted, source: .onboarding, step: .delayConsequence)
  }

  /// The Early Value Proof shake check-in resolved (#175). `shakeCount` is the
  /// number of real shakes performed before resolution (0–3) — the CTA tap is a
  /// fallback (no CoreMotion on simulator, not everyone can shake), so a low
  /// count with a resolution means the fallback was used.
  func demoShakeCompleted(shakeCount: Int) {
    track(.demoShakeCompleted, source: .onboarding, step: .demoShake, shakeCount: shakeCount)
  }

  func demoSkipped() {
    track(.demoSkipped, source: .onboarding, step: .demoDrag)
  }

  func notificationPermissionRequested() {
    track(.notificationPermissionRequested, source: .onboarding, step: .reminderTime)
  }

  /// The system notification prompt resolved (#175). Same step as the request
  /// so the pair lines up in the funnel, with the coarse granted/denied result
  /// — mirroring `screenTimePermissionCompleted`.
  func notificationPermissionCompleted(granted: Bool) {
    track(
      .notificationPermissionCompleted,
      source: .onboarding,
      step: .reminderTime,
      result: granted ? .granted : .denied
    )
  }

  func screenTimePermissionRequested() {
    track(.screenTimePermissionRequested, source: .onboarding, step: .appBlocking)
  }

  func screenTimePermissionCompleted(isAuthorized: Bool) {
    track(
      .screenTimePermissionCompleted,
      source: .onboarding,
      step: .appBlocking,
      result: isAuthorized ? .granted : .denied
    )
  }

  /// A valid app selection saved its blocker configuration during onboarding.
  /// Fires the dedicated `blocker_config_saved` event with only the coarse
  /// selection bit — never app names, tokens, or a count (the payload schema has
  /// no slot for them). The dedicated event is why no `setting` is attached.
  func onboardingBlockerConfigSaved(hasSelection: Bool) {
    track(
      .blockerConfigSaved,
      source: .onboarding,
      step: .appBlocking,
      hasBlockingSelection: hasSelection
    )
  }

  /// Screen Time authorization requested from the Settings blocker editor. Same
  /// event name as the onboarding request but `source: settings`, so the
  /// day-1 activation funnel can split the two surfaces (#163).
  func settingsScreenTimePermissionRequested() {
    track(.screenTimePermissionRequested, source: .settings)
  }

  /// The Settings-side Screen Time authorization request resolved. Carries the
  /// same coarse granted/denied result as onboarding, with `source: settings`.
  func settingsScreenTimePermissionCompleted(isAuthorized: Bool) {
    track(
      .screenTimePermissionCompleted,
      source: .settings,
      result: isAuthorized ? .granted : .denied
    )
  }

  /// The Settings blocker editor saved its configuration. Fires the same dedicated
  /// `blocker_config_saved` event as onboarding but with `source: settings`, so the
  /// activation metric can tell day-1 onboarding setup apart from later Settings
  /// setup (#163). Same PII boundary: only the coarse selection bit, never app
  /// names, tokens, or a count.
  func settingsBlockerConfigSaved(hasSelection: Bool) {
    track(
      .blockerConfigSaved,
      source: .settings,
      hasBlockingSelection: hasSelection
    )
  }

  /// Shield intercepts accumulated in the App Group flushed on app open
  /// (#161 / ADR 0007). The shield extension cannot send events itself, so one
  /// aggregated event carries the count — never one event per intercept, and
  /// never app names or routine details (coarse counts only).
  func blockerInterventionFired(count: Int) {
    track(.blockerInterventionFired, interventionCount: count)
  }

  /// A Reverse Trial grant was written when app-blocking setup appeared (#204 /
  /// ADR 0007). Fired only when the grant is actually written — revisiting setup
  /// never re-emits it. Never fires `trial_started`, which keeps its
  /// StoreKit-intro-offer meaning.
  func trialGranted() {
    track(.trialGranted, source: .onboarding, step: .appBlocking)
  }

  func trialOfferViewed() {
    track(.trialOfferViewed, source: .onboarding, step: .trialGranted)
  }

  /// Reports successful Reverse Trial activation and keeps the pre-existing
  /// `trial_granted` event for ADR 0007 dashboards. `trial_granted` is emitted
  /// first so ordered funnels preserve the grant → activation lifecycle (#265).
  func trialActivated() {
    trialGranted()
    track(.trialActivated, source: .onboarding, step: .appBlocking)
  }

  func blockerSetupStarted() {
    track(.blockerSetupStarted, source: .onboarding, step: .appBlocking)
  }

  func blockerSetupSkipped(authorizationState: AnalyticsAuthorizationState) {
    analytics.track(
      .blockerSetupSkipped,
      source: .onboarding,
      step: .appBlocking,
      authorizationState: authorizationState,
      isPlus: isPlus()
    )
  }

  func blockerSetupCompleted() {
    track(.blockerSetupCompleted, source: .onboarding, step: .appBlocking)
  }

  /// A Reverse Trial grant was written for an existing onboarded free user on
  /// first launch after the introducing update (#165 / ADR 0007). Same event as
  /// the onboarding grant with `source: update`, so the two grant cohorts split
  /// cleanly. Fired only when the grant is actually written.
  func updateTrialGranted() {
    track(.trialGranted, source: .update)
  }

  /// A Reverse Trial's Plus Access ended without conversion (#167 / ADR 0007).
  /// Fired exactly once, on the first app open at-or-after expiry — the
  /// decision and one-shot flag live in `TrialExpiredEvent`.
  func trialExpired() {
    analytics.track(
      .trialExpired,
      source: nil,
      surface: nil,
      plan: nil,
      result: nil,
      trialTermsCohort: trialTermsCohort(),
      isPlus: isPlus()
    )
  }

  func trialBadgeTapped() {
    track(.trialBadgeTapped, source: .home)
  }

  func trialStatusSheetViewed() {
    track(.trialStatusSheetViewed, source: .home)
  }

  func trialStatusFeatureTapped(
    _ feature: AnalyticsTrialStatusFeature,
    status: AnalyticsTrialActivationStatus,
    isRecommended: Bool
  ) {
    analytics.track(
      .trialStatusFeatureTapped,
      source: .home,
      trialStatusFeature: feature,
      trialActivationStatus: status,
      isRecommended: isRecommended,
      isPlus: isPlus()
    )
  }

  func smartReminderRetryScheduled(count: Int) {
    guard count > 0 else { return }
    analytics.track(
      .smartReminderRetryScheduled,
      retryCount: count,
      isPlus: isPlus()
    )
  }

  func smartReminderRetryFired() {
    track(.smartReminderRetryFired)
  }

  func smartReminderOutcome(_ outcome: AnalyticsSmartReminderOutcome) {
    analytics.track(
      .smartReminderOutcome,
      smartReminderOutcome: outcome,
      isPlus: isPlus()
    )
  }

  /// A day-10/13 trial expiry warning was delivered or handled (#168 /
  /// ADR 0007). `day` is the trial day the warning belongs to (10 or 13);
  /// the once-per-day dedupe lives in `TrialExpiryWarningDelivery`.
  func trialExpiryWarningSent(day: Int) {
    track(.trialExpiryWarningSent, trialWarningDay: day)
  }

  // MARK: - Trial-End Paywall (#169)
  //
  // The post-expiry purchase ask carries `source: trial_end` on every funnel
  // event so it splits cleanly from onboarding and Settings paywall traffic.
  // `paywall_viewed` additionally carries the coarse `cohort` property
  // (blocker_configured | reminder_only); the user's own stats shown on the
  // sheet (blocks, doses, streak) are never attached.

  func trialEndPaywallViewed(
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    analytics.track(
      .paywallViewed,
      source: .trialEnd,
      surface: .trialEnd,
      trialTermsCohort: termsCohort ?? TrialTermsCohort(terms: terms),
      trialEndCohort: cohort,
      isPlus: isPlus()
    )
  }

  func trialEndPlanSelected(
    plan: AnalyticsPlan,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .paywallPlanSelected,
      plan: plan,
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
  }

  func trialEndPurchaseStarted(
    plan: AnalyticsPlan,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .purchaseStarted, plan: plan, cohort: cohort, terms: terms, termsCohort: termsCohort)
  }

  /// StoreKit classified the conversion as a trial start (sandbox aside, the
  /// trial-end offer has no intro trial after #162 — kept for completeness).
  func trialEndTrialStarted(
    plan: AnalyticsPlan,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .trialStarted, plan: plan, cohort: cohort, terms: terms, termsCohort: termsCohort)
  }

  func trialEndPurchaseCompleted(
    plan: AnalyticsPlan,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .purchaseCompleted,
      plan: plan,
      result: .completed,
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
  }

  func trialEndPurchaseFailed(
    plan: AnalyticsPlan,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .purchaseFailed,
      plan: plan,
      result: .failed,
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
  }

  func trialEndPurchaseCancelled(
    plan: AnalyticsPlan,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .purchaseCancelled,
      plan: plan,
      result: .cancelled,
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
  }

  func trialEndRestoreStarted(
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .restoreStarted, cohort: cohort, terms: terms, termsCohort: termsCohort)
  }

  func trialEndRestoreCompleted(
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .restoreCompleted,
      result: .completed,
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
  }

  func trialEndRestoreFailed(
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .restoreFailed,
      result: .failed,
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
  }

  /// The explicit non-purchase action on the Trial-End Paywall.
  func trialEndContinueFreeSelected(
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    trackTrialEndPaywall(
      .continueFreeSelected, cohort: cohort, terms: terms, termsCohort: termsCohort)
  }

  private func trackTrialEndPaywall(
    _ event: AnalyticsEvent,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil,
    cohort: TrialEndPaywallCohort,
    terms: TrialEndAccessTerms,
    termsCohort: TrialTermsCohort? = nil
  ) {
    analytics.track(
      event,
      source: .trialEnd,
      surface: .trialEnd,
      plan: plan,
      result: result,
      trialTermsCohort: termsCohort ?? TrialTermsCohort(terms: terms),
      trialEndCohort: cohort,
      isPlus: isPlus()
    )
  }

  func trialDeclineFeedbackViewed() {
    trackTrialDeclineFeedback(.viewed)
  }

  func trialDeclineFeedbackSkipped() {
    trackTrialDeclineFeedback(.skipped)
  }

  func trialDeclineFeedbackReasonSelected(_ reason: TrialDeclineFeedbackReason) {
    trackTrialDeclineFeedback(.reasonSelected(reason))
  }

  func trialDeclineFeedbackSubmitted(_ reason: TrialDeclineFeedbackReason) {
    trialDeclineFeedbackSubmitted(
      TrialDeclineFeedbackSubmission(reason: reason, hasText: false)
    )
  }

  func trialDeclineFeedbackSubmitted(_ submission: TrialDeclineFeedbackSubmission) {
    if submission.hasText {
      trackTrialDeclineFeedback(.textSubmitted(submission.reason))
    }
    trackTrialDeclineFeedback(.completedSubmitted(submission))
  }

  func trialDeclineFeedbackCompleted(outcome: AnalyticsTrialDeclineFeedbackOutcome) {
    guard outcome == .skipped else { return }
    trackTrialDeclineFeedback(.completedSkipped)
  }

  private func trackTrialDeclineFeedback(_ event: TrialDeclineFeedbackTelemetryEvent) {
    analytics.track(
      event.analyticsEvent,
      declineFeedbackOutcome: event.outcome,
      declineFeedbackReason: event.reason,
      declineFeedbackHasText: event.hasText,
      isPlus: isPlus()
    )
  }

  func paywallViewed(isFromOnboarding: Bool) {
    track(
      .paywallViewed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      step: isFromOnboarding ? .paywall : nil
    )
  }

  func paywallViewed(surface: AnalyticsPaywallSurface) {
    analytics.track(
      .paywallViewed,
      source: source(for: surface),
      surface: surface,
      plan: nil,
      result: nil,
      trialTermsCohort: trialTermsCohort(),
      isPlus: isPlus()
    )
  }

  func paywallPlanSelected(
    plan: AnalyticsPlan,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .paywallPlanSelected,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      plan: plan
    )
  }

  func purchaseStarted(
    plan: AnalyticsPlan,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .purchaseStarted,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      plan: plan
    )
  }

  /// A free trial began. Distinct from `purchaseCompleted` (a real paid conversion) so
  /// the funnel can see trial starts as their own step — the dominant drop‑off given
  /// how few installs reach a paid charge. Fired only for non‑sandbox transactions.
  func trialStarted(
    plan: AnalyticsPlan,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .trialStarted,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      plan: plan
    )
  }

  func purchaseCompleted(
    plan: AnalyticsPlan,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .purchaseCompleted,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      plan: plan,
      result: .completed
    )
  }

  func purchaseFailed(
    plan: AnalyticsPlan,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .purchaseFailed,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      plan: plan,
      result: .failed
    )
  }

  func purchaseCancelled(
    plan: AnalyticsPlan,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .purchaseCancelled,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      plan: plan,
      result: .cancelled
    )
  }

  func restoreStarted(
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .restoreStarted,
      isFromOnboarding: isFromOnboarding,
      surface: surface
    )
  }

  func restoreCompleted(
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .restoreCompleted,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      result: .completed
    )
  }

  func restoreFailed(
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .restoreFailed,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      result: .failed
    )
  }

  func continueFreeSelected(
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface? = nil
  ) {
    trackPaywall(
      .continueFreeSelected,
      isFromOnboarding: isFromOnboarding,
      surface: surface,
      step: isFromOnboarding ? .paywall : nil
    )
  }

  private func trackPaywall(
    _ event: AnalyticsEvent,
    isFromOnboarding: Bool,
    surface: AnalyticsPaywallSurface?,
    step: AnalyticsStep? = nil,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil
  ) {
    guard let surface else {
      track(
        event,
        source: paywallSource(isFromOnboarding: isFromOnboarding),
        step: step,
        plan: plan,
        result: result
      )
      return
    }
    analytics.track(
      event,
      source: source(for: surface),
      surface: surface,
      plan: plan,
      result: result,
      trialTermsCohort: trialTermsCohort(),
      isPlus: isPlus()
    )
  }

  private func source(for surface: AnalyticsPaywallSurface) -> AnalyticsSource {
    switch surface {
    case .trialStatus, .protectionOffCard, .homeBlockingCard:
      return .home
    case .settingsSubscription:
      return .settings
    case .trialEnd:
      return .trialEnd
    case .plusUpsell:
      return .upsell
    }
  }

  func plusUpsellViewed() {
    trackPlusUpsell(.plusUpsellViewed)
  }

  func plusUpsellDismissed() {
    trackPlusUpsell(.plusUpsellDismissed)
  }

  func plusUpsellUpgradeTapped() {
    trackPlusUpsell(.plusUpsellUpgradeTapped)
  }

  private func trackPlusUpsell(_ event: AnalyticsEvent) {
    analytics.track(
      event,
      source: .upsell,
      surface: .plusUpsell,
      plan: nil,
      result: nil,
      isPlus: isPlus()
    )
  }

  func upsellRestoreStarted() {
    track(.restoreStarted, source: .upsell)
  }

  func upsellRestoreCompleted() {
    track(.restoreCompleted, source: .upsell, result: .completed)
  }

  func upsellRestoreFailed() {
    track(.restoreFailed, source: .upsell, result: .failed)
  }

  func mainTabSelected(_ tab: MainTab) {
    track(.tabSelected, screen: tab.analyticsScreen)
  }

  func protocolSettingsOpened() {
    settingsSheetOpened(.protocol)
  }

  func reminderTimeSettingsOpened() {
    settingsSheetOpened(.reminderTime)
  }

  func autoReminderIntervalSettingsOpened() {
    settingsSheetOpened(.autoReminderInterval)
  }

  func autoReminderRetryLimitSettingsOpened() {
    settingsSheetOpened(.autoReminderRetryLimit)
  }

  func supplyReminderSettingsOpened() {
    settingsSheetOpened(.supplyReminder)
  }

  func cycleDaySettingsOpened() {
    settingsSheetOpened(.cycleDay)
  }

  func blockedAppsSettingsOpened(hasSelection: Bool) {
    settingsSheetOpened(.blockedApps, hasBlockingSelection: hasSelection)
  }

  func customRemindersSettingsOpened() {
    settingsSheetOpened(.customReminders)
  }

  func subscriptionSettingsOpened() {
    settingsSheetOpened(.subscription)
  }

  func protocolChangeSaved() {
    settingsChangeSaved(.protocol)
  }

  func protocolChangeCancelled() {
    track(.settingsChangeCancelled, source: .settings, setting: .protocol)
  }

  func reminderTimeSaved() {
    settingsChangeSaved(.reminderTime)
  }

  func autoReminderIntervalSaved() {
    settingsChangeSaved(.autoReminderInterval)
  }

  func autoReminderRetryLimitSaved() {
    settingsChangeSaved(.autoReminderRetryLimit)
  }

  func supplyReminderSaved() {
    settingsChangeSaved(.supplyReminder)
  }

  func cycleDaySaved() {
    settingsChangeSaved(.cycleDay)
  }

  func blockedAppsSaved(hasSelection: Bool) {
    settingsChangeSaved(.blockedApps, hasBlockingSelection: hasSelection)
  }

  /// The Custom Reminder Messages editor saved. Carries only coarse booleans, the
  /// low-cardinality preset id, and whether that preset was edited — never message text.
  func customRemindersSaved(
    titleCustomized: Bool,
    bodyCustomized: Bool,
    retryTitleCustomized: Bool,
    retryBodyCustomized: Bool,
    lastCallTitleCustomized: Bool,
    lastCallBodyCustomized: Bool,
    preset: CustomReminderPreset?,
    editedAfterPreset: Bool
  ) {
    analytics.trackCustomReminderSave(
      isPlus: isPlus(),
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized,
      preset: preset,
      editedAfterPreset: editedAfterPreset
    )
  }

  func todayActionStarted() {
    track(.todayActionStarted, source: .home)
  }

  func todayActionCompleted() {
    track(.todayActionCompleted, source: .home)
  }

  func todayActionUndone() {
    track(.todayActionUndone, source: .home)
  }

  func newPackOrCyclePrompted() {
    track(.newPackOrCyclePrompted, source: .home)
  }

  func newPackOrCycleStarted() {
    track(.newPackOrCycleStarted, source: .home)
  }

  // MARK: - Adaptive Reminder Time Suggestion (#126)
  //
  // The Home suggestion card captures only its lifecycle — shown / accepted /
  // dismissed. No suggested time, delta, or log-time signal is ever attached; the
  // on-device `takenAt` data that drives the suggestion never leaves the device.

  func adaptiveReminderSuggestionShown() {
    track(.adaptiveReminderSuggestionShown, source: .home)
  }

  func adaptiveReminderSuggestionAccepted() {
    track(.adaptiveReminderSuggestionAccepted, source: .home)
  }

  func adaptiveReminderSuggestionDismissed() {
    track(.adaptiveReminderSuggestionDismissed, source: .home)
  }

  // MARK: - Home Review Prompt (#132 / #133)
  //
  // The Sentiment Gate captures only its lifecycle — shown / positive / negative /
  // dismissed. All four are flat and property-free: the contraception method, the
  // Streak value, the appearance ordinal, and the feedback email text are never
  // attached (PRD #132 / ADR 0001/0004). There is no payload field for any of them, so
  // none can leak; the Native Review Request firing and Feedback Escape Hatch text are
  // never reported beyond this coarse funnel signal.

  func reviewPromptShown() {
    track(.reviewPromptShown, source: .home)
  }

  func reviewPromptPositiveTapped() {
    track(.reviewPromptPositiveTapped, source: .home)
  }

  func reviewPromptNegativeTapped() {
    track(.reviewPromptNegativeTapped, source: .home)
  }

  func reviewPromptDismissed() {
    track(.reviewPromptDismissed, source: .home)
  }

  // MARK: - Open Line (#152 / #153)
  //
  // One coarse event per Open Line row tap — the standard envelope and nothing
  // else. iOS never reports whether an email was actually sent, so the tap is by
  // design the only funnel signal; what the user types stays between them and the
  // developer and is never attached here.

  func openLineSuggestionTapped() {
    track(.openLineSuggestionTapped, source: .settings)
  }

  func openLineIssueReportTapped() {
    track(.openLineIssueReportTapped, source: .settings)
  }

  // MARK: - Error tracking (#179)

  /// Report a handled failure so it counts toward the founder dashboard's error
  /// rate. Captures `app_error` (flat `domain`/`message`/`code`/`severity`) and
  /// mirrors the raw error into PostHog Error Tracking as `$exception`.
  /// PII boundary: `domain` is a closed enum and `context` values must be
  /// low-cardinality labels (e.g. `operation: schedule`) — never user content,
  /// tokens, or free-form input. Expected user cancellations (StoreKit
  /// `.userCancelled`) keep their product events and must not be routed here.
  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String] = [:],
    severity: AppErrorSeverity = .error
  ) {
    analytics.trackError(domain, error: error, context: context, severity: severity)
  }

  private func paywallSource(isFromOnboarding: Bool) -> AnalyticsSource {
    isFromOnboarding ? .onboarding : .settings
  }

  private func settingsSheetOpened(_ setting: AnalyticsSetting, hasBlockingSelection: Bool? = nil) {
    track(
      .settingsSheetOpened,
      source: .settings,
      setting: setting,
      hasBlockingSelection: hasBlockingSelection
    )
  }

  private func settingsChangeSaved(_ setting: AnalyticsSetting, hasBlockingSelection: Bool? = nil) {
    track(
      .settingsChangeSaved,
      source: .settings,
      setting: setting,
      hasBlockingSelection: hasBlockingSelection
    )
  }

  private func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil,
    stepIndex: Int? = nil,
    screen: AnalyticsScreen? = nil,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil,
    setting: AnalyticsSetting? = nil,
    acquisitionSource: AcquisitionSource? = nil,
    hasBlockingSelection: Bool? = nil,
    interventionCount: Int? = nil,
    shakeCount: Int? = nil,
    trialWarningDay: Int? = nil,
    trialEndCohort: TrialEndPaywallCohort? = nil,
    titleCustomized: Bool? = nil,
    bodyCustomized: Bool? = nil,
    retryTitleCustomized: Bool? = nil,
    retryBodyCustomized: Bool? = nil,
    lastCallTitleCustomized: Bool? = nil,
    lastCallBodyCustomized: Bool? = nil
  ) {
    analytics.track(
      event,
      source: source,
      step: step,
      stepIndex: stepIndex,
      screen: screen,
      plan: plan,
      result: result,
      setting: setting,
      acquisitionSource: acquisitionSource,
      isPlus: isPlus(),
      hasBlockingSelection: hasBlockingSelection,
      interventionCount: interventionCount,
      shakeCount: shakeCount,
      trialWarningDay: trialWarningDay,
      trialEndCohort: trialEndCohort,
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized
    )
  }
}
