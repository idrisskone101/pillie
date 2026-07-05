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

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.hasEntitlement },
    acquisitionSource: @escaping () -> AcquisitionSource? = {
      AcquisitionSource(
        rawValue: UserDefaults.standard.string(forKey: PillStore.acquisitionSourceKey) ?? "")
    }
  ) {
    self.analytics = analytics
    self.isPlus = isPlus
    self.acquisitionSource = acquisitionSource
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
    track(.onboardingCompleted, source: .onboarding)
    // af_complete_registration — onboarding is Pillie's "registration" milestone.
    AppsFlyerManager.shared.logCompleteRegistration()
  }

  /// Reports the terminal completion classification. Fires exactly one event —
  /// `protection_plan_activated` only when app blocking is genuinely activated, and
  /// `reminder_only_completion` otherwise. Reminder-only completion never emits an
  /// activation event. Both carry only coarse, consent-safe context (`source`,
  /// `is_plus`); no personalization answers, app names, or counts.
  func onboardingOutcomeClassified(_ outcome: ProtectionPlanCompletion.Outcome) {
    track(outcome.analyticsEvent, source: .onboarding)
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

  func notificationPermissionRequested() {
    track(.notificationPermissionRequested, source: .onboarding, step: .reminderTime)
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

  /// A Reverse Trial grant was written at the Trial Granted Moment (#164 /
  /// ADR 0007). Fired only when the grant is actually written — revisiting the
  /// screen never re-emits it. Never fires `trial_started`, which keeps its
  /// StoreKit-intro-offer meaning.
  func trialGranted() {
    track(.trialGranted, source: .onboarding)
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
    track(.trialExpired)
  }

  /// A day-10/13 trial expiry warning was delivered or handled (#168 /
  /// ADR 0007). `day` is the trial day the warning belongs to (10 or 13);
  /// the once-per-day dedupe lives in `TrialExpiryWarningDelivery`.
  func trialExpiryWarningSent(day: Int) {
    track(.trialExpiryWarningSent, trialWarningDay: day)
  }

  func paywallViewed(isFromOnboarding: Bool) {
    track(
      .paywallViewed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      step: isFromOnboarding ? .paywall : nil
    )
  }

  func paywallPlanSelected(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(.paywallPlanSelected, source: paywallSource(isFromOnboarding: isFromOnboarding), plan: plan)
  }

  func purchaseStarted(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(.purchaseStarted, source: paywallSource(isFromOnboarding: isFromOnboarding), plan: plan)
  }

  /// A free trial began. Distinct from `purchaseCompleted` (a real paid conversion) so
  /// the funnel can see trial starts as their own step — the dominant drop‑off given
  /// how few installs reach a paid charge. Fired only for non‑sandbox transactions.
  func trialStarted(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(.trialStarted, source: paywallSource(isFromOnboarding: isFromOnboarding), plan: plan)
  }

  func purchaseCompleted(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(
      .purchaseCompleted,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      plan: plan,
      result: .completed
    )
  }

  func purchaseFailed(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(
      .purchaseFailed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      plan: plan,
      result: .failed
    )
  }

  func purchaseCancelled(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(
      .purchaseCancelled,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      plan: plan,
      result: .cancelled
    )
  }

  func restoreStarted(isFromOnboarding: Bool) {
    track(.restoreStarted, source: paywallSource(isFromOnboarding: isFromOnboarding))
  }

  func restoreCompleted(isFromOnboarding: Bool) {
    track(
      .restoreCompleted,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      result: .completed
    )
  }

  func restoreFailed(isFromOnboarding: Bool) {
    track(
      .restoreFailed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      result: .failed
    )
  }

  func continueFreeSelected(isFromOnboarding: Bool) {
    track(
      .continueFreeSelected,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      step: isFromOnboarding ? .paywall : nil
    )
  }

  func plusUpsellViewed() {
    track(.plusUpsellViewed, source: .upsell)
  }

  func settingsBlockingUpsellViewed() {
    track(.plusUpsellViewed, source: .settings)
  }

  func settingsSmartRemindersUpsellViewed() {
    track(.plusUpsellViewed, source: .settings)
  }

  func settingsCustomRemindersUpsellViewed() {
    track(.plusUpsellViewed, source: .settings)
  }

  func plusUpsellDismissed() {
    track(.plusUpsellDismissed, source: .upsell)
  }

  func plusUpsellUpgradeTapped() {
    track(.plusUpsellUpgradeTapped, source: .upsell)
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

  /// The Custom Reminder Messages editor saved. Carries only coarse booleans — whether
  /// each of the six fields ended up customized — never the strings or their lengths.
  func customRemindersSaved(
    titleCustomized: Bool,
    bodyCustomized: Bool,
    retryTitleCustomized: Bool,
    retryBodyCustomized: Bool,
    lastCallTitleCustomized: Bool,
    lastCallBodyCustomized: Bool
  ) {
    track(
      .settingsChangeSaved,
      source: .settings,
      setting: .customReminders,
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized
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
    trialWarningDay: Int? = nil,
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
      trialWarningDay: trialWarningDay,
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized
    )
  }
}
