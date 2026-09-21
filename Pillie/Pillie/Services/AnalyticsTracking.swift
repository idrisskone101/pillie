import Foundation

protocol AnalyticsTracking {
  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    step: AnalyticsStep?,
    stepIndex: Int?,
    screen: AnalyticsScreen?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    setting: AnalyticsSetting?,
    acquisitionSource: AcquisitionSource?,
    isPlus: Bool?,
    hasBlockingSelection: Bool?,
    interventionCount: Int?,
    shakeCount: Int?,
    trialWarningDay: Int?,
    trialEndCohort: TrialEndPaywallCohort?,
    titleCustomized: Bool?,
    bodyCustomized: Bool?,
    retryTitleCustomized: Bool?,
    retryBodyCustomized: Bool?,
  )

  func trackCustomReminderSave(
    isPlus: Bool,
    titleCustomized: Bool,
    bodyCustomized: Bool,
    retryTitleCustomized: Bool,
    retryBodyCustomized: Bool,
    preset: CustomReminderPreset?,
    editedAfterPreset: Bool
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    trialTermsCohort: TrialTermsCohort?,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface,
    trialTermsCohort: TrialTermsCohort,
    trialEndCohort: TrialEndPaywallCohort,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    trialTermsCohort: TrialTermsCohort,
    trialEndCohort: TrialEndPaywallCohort,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    trialStatusFeature: AnalyticsTrialStatusFeature,
    trialActivationStatus: AnalyticsTrialActivationStatus,
    isRecommended: Bool,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    step: AnalyticsStep?,
    authorizationState: AnalyticsAuthorizationState,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    retryCount: Int,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    smartReminderOutcome: AnalyticsSmartReminderOutcome,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
    isPlus: Bool?
  )

  func track(
    _ event: AnalyticsEvent,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
    declineFeedbackReason: TrialDeclineFeedbackReason?,
    declineFeedbackHasText: Bool?,
    isPlus: Bool?
  )

  /// Report a handled failure as `app_error` + `$exception` (#179).
  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String],
    severity: AppErrorSeverity
  )
}

// Default no-op so the funnel-focused test recorders that only care about
// track() keep compiling; `AnalyticsManager` provides the real implementation.
extension AnalyticsTracking {
  func trackCustomReminderSave(
    isPlus: Bool,
    titleCustomized: Bool,
    bodyCustomized: Bool,
    retryTitleCustomized: Bool,
    retryBodyCustomized: Bool,
    preset: CustomReminderPreset?,
    editedAfterPreset: Bool
  ) {
    track(
      .settingsChangeSaved,
      source: .settings,
      step: nil,
      stepIndex: nil,
      screen: nil,
      plan: nil,
      result: nil,
      setting: .customReminders,
      acquisitionSource: nil,
      isPlus: isPlus,
      hasBlockingSelection: nil,
      interventionCount: nil,
      shakeCount: nil,
      trialWarningDay: nil,
      trialEndCohort: nil,
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
    )
  }

  func track(
    _ event: AnalyticsEvent,
    smartReminderOutcome: AnalyticsSmartReminderOutcome,
    isPlus: Bool?
  ) {
    trackLegacy(event, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
    isPlus: Bool?
  ) {
    trackLegacy(event, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
    declineFeedbackReason: TrialDeclineFeedbackReason?,
    declineFeedbackHasText: Bool?,
    isPlus: Bool?
  ) {
    trackLegacy(event, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    retryCount: Int,
    isPlus: Bool?
  ) {
    trackLegacy(event, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    step: AnalyticsStep?,
    authorizationState: AnalyticsAuthorizationState,
    isPlus: Bool?
  ) {
    trackLegacy(event, source: source, step: step, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    trialStatusFeature: AnalyticsTrialStatusFeature,
    trialActivationStatus: AnalyticsTrialActivationStatus,
    isRecommended: Bool,
    isPlus: Bool?
  ) {
    trackLegacy(event, source: source, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    isPlus: Bool?
  ) {
    trackLegacy(event, source: source, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    trialTermsCohort: TrialTermsCohort?,
    isPlus: Bool?
  ) {
    track(
      event,
      source: source,
      surface: surface,
      plan: plan,
      result: result,
      isPlus: isPlus
    )
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface,
    trialTermsCohort: TrialTermsCohort,
    trialEndCohort: TrialEndPaywallCohort,
    isPlus: Bool?
  ) {
    trackLegacy(event, source: source, isPlus: isPlus)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    trialTermsCohort: TrialTermsCohort,
    trialEndCohort: TrialEndPaywallCohort,
    isPlus: Bool?
  ) {
    track(
      event,
      source: source,
      surface: surface,
      plan: plan,
      result: result,
      isPlus: isPlus
    )
  }

  private func trackLegacy(
    _ event: AnalyticsEvent,
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil,
    isPlus: Bool?
  ) {
    track(
      event,
      source: source,
      step: step,
      stepIndex: nil,
      screen: nil,
      plan: nil,
      result: nil,
      setting: nil,
      acquisitionSource: nil,
      isPlus: isPlus,
      hasBlockingSelection: nil,
      interventionCount: nil,
      shakeCount: nil,
      trialWarningDay: nil,
      trialEndCohort: nil,
      titleCustomized: nil,
      bodyCustomized: nil,
      retryTitleCustomized: nil,
      retryBodyCustomized: nil,
    )
  }

  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String],
    severity: AppErrorSeverity
  ) {}
}
