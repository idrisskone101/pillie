//
//  AnalyticsManager.swift
//  Pillie
//

import Foundation
import PostHog
import os

enum AnalyticsPropertyValue: Equatable {
  case string(String)
  case bool(Bool)
  case int(Int)

  var postHogValue: Any {
    switch self {
    case .string(let value):
      return value
    case .bool(let value):
      return value
    case .int(let value):
      return value
    }
  }
}

struct ProductAnalyticsConfiguration: Equatable {
  let projectToken: String
  let host: String
  let captureApplicationLifecycleEvents: Bool
  let captureScreenViews: Bool
  let captureElementInteractions: Bool
  let enableSwizzling: Bool
  let sendFeatureFlagEvent: Bool
  let preloadFeatureFlags: Bool
  let setDefaultPersonProperties: Bool
  let sessionReplay: Bool
  /// PostHog captures SwiftUI replay via periodic screenshots; wireframe mode
  /// cannot see SwiftUI content, so replay requires screenshot mode here.
  let sessionReplayScreenshotMode: Bool
  // Masking controls (#175). This is a health app: pill names, schedules, and
  // health answers must never appear in a recording, so every masking control
  // ships engaged.
  let sessionReplayMaskAllTextInputs: Bool
  let sessionReplayMaskAllImages: Bool
  let sessionReplayMaskAllSandboxedViews: Bool
  let surveys: Bool
  let isOptedOut: Bool
  /// Process person profiles for every event (PostHog `personProfiles = .always`).
  /// Required so that person properties set via `$set` — notably `acquisition_source`
  /// — stick for anonymous users (we never call `identify`, per ADR 0001), letting the
  /// funnel be broken down by source. Default PostHog behavior (`.identifiedOnly`) drops
  /// `$set` for users who never identify.
  let personProfilesAlways: Bool
  /// Auto-capture uncaught NSExceptions / Swift errors as `$exception` events
  /// (PostHog `errorTrackingConfig.autoCapture`), giving the founder dashboard a
  /// crash-rate signal (#179).
  let captureExceptions: Bool
}

protocol ProductAnalyticsClient: AnyObject {
  func configure(_ configuration: ProductAnalyticsConfiguration)
  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  )
  /// Capture a handled error as a `$exception` event so it groups in PostHog
  /// Error Tracking with a stack-classified fingerprint (#179).
  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue])
  /// The current anonymous distinct id, used to join server-side RevenueCat events
  /// to the same PostHog person. `nil` before the SDK is configured.
  func distinctId() -> String?
  func flush()
}

/// The failing subsystem carried as `domain` on `app_error`, kept a closed
/// low-cardinality enum (never a raw string) so the "Errors by domain" dashboard
/// panel stays plottable and no free-form text can leak PII (#179).
enum AppErrorDomain: String {
  /// StoreKit / RevenueCat purchase flow failures (excluding user cancels).
  case purchase
  /// RevenueCat restore-purchases failures.
  case restore
  /// RevenueCat offerings fetch failures (paywall spinner dead-ends).
  case offerings
  /// Screen Time / FamilyControls authorization and monitoring failures.
  case screenTime = "screen_time"
  /// Local notification authorization and scheduling failures.
  case notifications
  /// Deliberate QA errors fired from the DEBUG smoke deep link.
  case debug
}

/// Coarse severity on `app_error` so the dashboard can split noise (`warning`)
/// from real failures (`error`) and crashes surfaced manually (`fatal`).
enum AppErrorSeverity: String {
  case warning
  case error
  case fatal
}

// The client grew `captureException` for #179; a default no-op keeps the many
// test spies compiling. `PostHogAnalyticsClient` overrides it for real capture.
extension ProductAnalyticsClient {
  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue]) {}
}

final class PostHogAnalyticsClient: ProductAnalyticsClient {
  /// PostHog's capture pipeline does non-trivial synchronous work on the calling
  /// thread. Every call site is a UI action on the main thread, and that work was
  /// measured at ~15ms per event on iOS 27 — enough to drop the first frame of any
  /// animation started in the same interaction (e.g. the tab-switch slide). A serial
  /// queue keeps events ordered while keeping their cost off the render-critical path.
  private let captureQueue = DispatchQueue(
    label: "com.idrisskone.pillie.posthog-capture",
    qos: .utility
  )

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host)
    config.captureApplicationLifecycleEvents = configuration.captureApplicationLifecycleEvents
    config.captureScreenViews = configuration.captureScreenViews
    config.enableSwizzling = configuration.enableSwizzling
    config.sendFeatureFlagEvent = configuration.sendFeatureFlagEvent
    config.preloadFeatureFlags = configuration.preloadFeatureFlags
    config.setDefaultPersonProperties = configuration.setDefaultPersonProperties
    config.optOut = configuration.isOptedOut
    config.personProfiles = configuration.personProfilesAlways ? .always : .identifiedOnly
    config.errorTrackingConfig.autoCapture = configuration.captureExceptions

    #if os(iOS)
      config.captureElementInteractions = configuration.captureElementInteractions
      config.sessionReplay = configuration.sessionReplay
      config.sessionReplayConfig.screenshotMode = configuration.sessionReplayScreenshotMode
      config.sessionReplayConfig.maskAllTextInputs = configuration.sessionReplayMaskAllTextInputs
      config.sessionReplayConfig.maskAllImages = configuration.sessionReplayMaskAllImages
      config.sessionReplayConfig.maskAllSandboxedViews =
        configuration.sessionReplayMaskAllSandboxedViews
      if #available(iOS 15.0, *) {
        config.surveys = configuration.surveys
      }
    #endif

    PostHogSDK.shared.setup(config)
  }

  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  ) {
    captureQueue.async {
      PostHogSDK.shared.capture(
        event,
        properties: properties.mapValues(\.postHogValue),
        userProperties: personProperties.isEmpty
          ? nil
          : personProperties.mapValues(\.postHogValue)
      )
    }
  }

  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue]) {
    captureQueue.async {
      PostHogSDK.shared.captureException(
        error,
        properties: properties.mapValues(\.postHogValue)
      )
    }
  }

  func distinctId() -> String? {
    PostHogSDK.shared.getDistinctId()
  }

  func flush() {
    captureQueue.async {
      PostHogSDK.shared.flush()
    }
  }
}

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
    lastCallTitleCustomized: Bool?,
    lastCallBodyCustomized: Bool?
  )

  func trackCustomReminderSave(
    isPlus: Bool,
    titleCustomized: Bool,
    bodyCustomized: Bool,
    retryTitleCustomized: Bool,
    retryBodyCustomized: Bool,
    lastCallTitleCustomized: Bool,
    lastCallBodyCustomized: Bool,
    preset: CustomReminderPreset?,
    editedAfterPreset: Bool
  )

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface,
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
    lastCallTitleCustomized: Bool,
    lastCallBodyCustomized: Bool,
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
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized
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
    surface: AnalyticsPaywallSurface,
    isPlus: Bool?
  ) {
    trackLegacy(event, source: source, isPlus: isPlus)
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
      lastCallTitleCustomized: nil,
      lastCallBodyCustomized: nil
    )
  }

  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String],
    severity: AppErrorSeverity
  ) {}
}

enum AnalyticsEvent: String, CaseIterable {
  case appLaunched = "app_launched"
  case appBecameActive = "app_became_active"
  case onboardingStarted = "onboarding_started"
  case onboardingStepViewed = "onboarding_step_viewed"
  case onboardingStepCompleted = "onboarding_step_completed"
  case onboardingBackTapped = "onboarding_back_tapped"
  /// The user finished Pillie's core reminder setup: method, schedule, reminder
  /// time, notification decision, and generated reminder plan. This boundary is
  /// intentionally before the optional Reverse Trial and app-blocking branch.
  case coreOnboardingCompleted = "core_onboarding_completed"
  /// Compatibility alias for dashboards and lifecycle automation. New analysis
  /// should use `core_onboarding_completed`; this event has the same core boundary.
  case onboardingCompleted = "onboarding_completed"
  case reminderOnlyCompletion = "reminder_only_completion"
  case protectionPlanActivated = "protection_plan_activated"
  /// The Reverse Trial announcement became visible. This is exposure only; it
  /// does not imply that a trial grant was successfully written.
  case trialOfferViewed = "trial_offer_viewed"
  /// Pillie's Reverse Trial grant was successfully written during onboarding.
  /// `trial_granted` remains as the compatibility event used by ADR 0007.
  case trialActivated = "trial_activated"
  /// The optional Screen Time/app-selection branch became visible.
  case blockerSetupStarted = "blocker_setup_started"
  /// The user entered the app without finishing optional app blocking.
  case blockerSetupSkipped = "blocker_setup_skipped"
  /// A valid app selection was saved after Screen Time authorization. This
  /// setup milestone is distinct from the terminal protection activation.
  case blockerSetupCompleted = "blocker_setup_completed"
  case blockerConfigSaved = "blocker_config_saved"
  case blockerInterventionFired = "blocker_intervention_fired"
  case paywallViewed = "paywall_viewed"
  case paywallPlanSelected = "paywall_plan_selected"
  case purchaseStarted = "purchase_started"
  case trialStarted = "trial_started"
  /// A Reverse Trial grant was written (ADR 0007). Distinct from `trialStarted`,
  /// which keeps its StoreKit-intro-offer meaning.
  case trialGranted = "trial_granted"
  /// A Reverse Trial's Plus Access ended without conversion (#167 / ADR 0007).
  /// Recorded once, on the first app open at-or-after expiry.
  case trialExpired = "trial_expired"
  case trialBadgeTapped = "trial_badge_tapped"
  case trialStatusSheetViewed = "trial_status_sheet_viewed"
  case trialStatusFeatureTapped = "trial_status_feature_tapped"
  case smartReminderRetryScheduled = "smart_reminder_retry_scheduled"
  case smartReminderRetryFired = "smart_reminder_retry_fired"
  case smartReminderOutcome = "smart_reminder_outcome"
  /// A day-10/13 trial expiry warning notification was delivered or handled
  /// (#168 / ADR 0007). Carries `day: 10 | 13`; recorded at most once per day
  /// value (`TrialExpiryWarningDelivery`).
  case trialExpiryWarningSent = "trial_expiry_warning_sent"
  case purchaseCompleted = "purchase_completed"
  case purchaseFailed = "purchase_failed"
  case purchaseCancelled = "purchase_cancelled"
  case restoreStarted = "restore_started"
  case restoreCompleted = "restore_completed"
  case restoreFailed = "restore_failed"
  case continueFreeSelected = "continue_free_selected"
  case trialDeclineFeedbackViewed = "trial_decline_feedback_viewed"
  case trialDeclineFeedbackReasonSelected = "trial_decline_feedback_reason_selected"
  case trialDeclineFeedbackTextSubmitted = "trial_decline_feedback_text_submitted"
  case trialDeclineFeedbackSkipped = "trial_decline_feedback_skipped"
  case trialDeclineFeedbackCompleted = "trial_decline_feedback_completed"
  case notificationPermissionRequested = "notification_permission_requested"
  /// The notification authorization prompt resolved (#175). Carries
  /// `result: granted | denied` — the symmetric partner of the requested
  /// event, mirroring the screen_time pair.
  case notificationPermissionCompleted = "notification_permission_completed"
  case screenTimePermissionRequested = "screen_time_permission_requested"
  case screenTimePermissionCompleted = "screen_time_permission_completed"
  case tabSelected = "tab_selected"
  case settingsSheetOpened = "settings_sheet_opened"
  case settingsChangeSaved = "settings_change_saved"
  case settingsChangeCancelled = "settings_change_cancelled"
  case todayActionStarted = "today_action_started"
  case todayActionCompleted = "today_action_completed"
  case todayActionUndone = "today_action_undone"
  case newPackOrCyclePrompted = "new_pack_or_cycle_prompted"
  case newPackOrCycleStarted = "new_pack_or_cycle_started"
  case plusUpsellViewed = "plus_upsell_viewed"
  case plusUpsellDismissed = "plus_upsell_dismissed"
  case plusUpsellUpgradeTapped = "plus_upsell_upgrade_tapped"
  case adaptiveReminderSuggestionShown = "adaptive_reminder_suggestion_shown"
  case adaptiveReminderSuggestionAccepted = "adaptive_reminder_suggestion_accepted"
  case adaptiveReminderSuggestionDismissed = "adaptive_reminder_suggestion_dismissed"
  case reviewPromptShown = "review_prompt_shown"
  case reviewPromptPositiveTapped = "review_prompt_positive_tapped"
  case reviewPromptNegativeTapped = "review_prompt_negative_tapped"
  case reviewPromptDismissed = "review_prompt_dismissed"
  case openLineSuggestionTapped = "open_line_suggestion_tapped"
  case openLineIssueReportTapped = "open_line_issue_report_tapped"
  /// The Early Value Proof shake check-in resolved (#175). Carries `shake_count`
  /// (0–3): how many real shakes happened before resolution, so the funnel can
  /// see the CTA-tap fallback and mid-shake abandonment.
  case demoShakeCompleted = "demo_shake_completed"
  /// The user chose the visible tap-only escape from the optional Early Value
  /// Proof interaction (#206).
  case demoSkipped = "demo_skipped"
  /// A handled failure (#179). Carries `domain` + `message` + `code` + `severity`
  /// via `trackError`, never through the `AnalyticsPayload` envelope.
  case appError = "app_error"
}

enum AnalyticsSource: String {
  case onboarding
  case settings
  case home
  case upsell
  /// The one-time Smart Reminders migration notice shown to pre-existing free users
  /// when Smart Reminders moves to Pillie+ (ADR 0004 / #104).
  case migration
  /// The existing-user Reverse Trial grant on first launch after the introducing
  /// update (#165 / ADR 0007), so it splits from `onboarding` grants in the funnel.
  case update
  /// The Trial-End Paywall shown after Reverse Trial expiry (#169 / ADR 0007),
  /// so its funnel splits from onboarding and Settings paywall traffic.
  case trialEnd = "trial_end"
}

enum AnalyticsPaywallSurface: String, CaseIterable {
  case trialStatus = "trial_status"
  case settingsSubscription = "settings_subscription"
  case blockingGate = "blocking_gate"
  case smartReminderGate = "smart_reminder_gate"
}

enum AnalyticsTrialStatusFeature: String, CaseIterable {
  case appBlocking = "app_blocking"
  case shakeToConfirm = "shake_to_confirm"
  case smartReminders = "smart_reminders"
  case customMessages = "custom_messages"
}

enum AnalyticsTrialActivationStatus: String, CaseIterable {
  case setUp = "set_up"
  case active
  case activeAutomatically = "active_automatically"
  case personalize
  case customized
  case on
}

enum AnalyticsAuthorizationState: String, CaseIterable {
  case notRequested = "not_requested"
  case denied
  case authorized
}

enum AnalyticsSmartReminderOutcome: String, CaseIterable {
  case opened
  case completed
  case snoozed
}

enum AnalyticsTrialDeclineFeedbackOutcome: String, Equatable {
  case skipped
  case submitted
}

enum TrialDeclineFeedbackTelemetryEvent {
  case viewed
  case reasonSelected(TrialDeclineFeedbackReason)
  case textSubmitted(TrialDeclineFeedbackReason)
  case skipped
  case completedSkipped
  case completedSubmitted(TrialDeclineFeedbackSubmission)

  var analyticsEvent: AnalyticsEvent {
    switch self {
    case .viewed: return .trialDeclineFeedbackViewed
    case .reasonSelected: return .trialDeclineFeedbackReasonSelected
    case .textSubmitted: return .trialDeclineFeedbackTextSubmitted
    case .skipped: return .trialDeclineFeedbackSkipped
    case .completedSkipped, .completedSubmitted: return .trialDeclineFeedbackCompleted
    }
  }

  var outcome: AnalyticsTrialDeclineFeedbackOutcome? {
    switch self {
    case .viewed, .reasonSelected, .textSubmitted, .skipped: return nil
    case .completedSkipped: return .skipped
    case .completedSubmitted: return .submitted
    }
  }

  var reason: TrialDeclineFeedbackReason? {
    switch self {
    case .reasonSelected(let reason), .textSubmitted(let reason):
      return reason
    case .completedSubmitted(let submission):
      return submission.reason
    case .viewed, .skipped, .completedSkipped: return nil
    }
  }

  var hasText: Bool? {
    switch self {
    case .textSubmitted: return true
    case .completedSubmitted(let submission): return submission.hasText
    case .viewed, .reasonSelected, .skipped, .completedSkipped: return nil
    }
  }

  func payload(isPlus: Bool) -> AnalyticsPayload {
    AnalyticsPayload(
      source: .trialEnd,
      isPlus: isPlus,
      declineFeedbackOutcome: outcome,
      declineFeedbackReason: reason,
      declineFeedbackHasText: hasText
    )
  }
}

enum AnalyticsStep: String {
  case welcome
  case analyticsConsent = "analytics_consent"
  case productDemo = "product_demo"
  case plusBlockingDemo = "plus_blocking_demo"
  case reviewPrompt = "review_prompt"
  case painPoints = "pain_points"
  case distractionChoices = "distraction_choices"
  case delayConsequence = "delay_consequence"
  case goal
  case missFrequency = "miss_frequency"
  case riskWindow = "risk_window"
  case draftBlockedApps = "draft_blocked_apps"
  case acquisitionSource = "acquisition_source"
  // The three Early Value Proof demo stages (#175). They fill the funnel gap
  // between welcome (step_index 0) and pain_points (step_index 4): the stages
  // are phases of one screen, not `OnboardingFlow` steps, so their indices are
  // owned by `EarlyValueProofStage`, not `displayOrder`.
  case demoDrag = "demo_drag"
  case demoShake = "demo_shake"
  case demoUnlocked = "demo_unlocked"
  case paywall
  case method
  case schedule
  case reminderTime = "reminder_time"
  case reminderPlan = "reminder_plan"
  case mechanismProof = "mechanism_proof"
  case freePlanConfirmation = "free_plan_confirmation"
  case appBlocking = "app_blocking"
  case protectionPlanReady = "protection_plan_ready"
  // The step label is `trial_granted_moment` (the screen); the `trial_granted`
  // event name stays reserved for the grant itself.
  case trialGranted = "trial_granted_moment"

  init?(onboardingStep: Int) {
    guard let analyticsStep = OnboardingFlow.analyticsStep(for: onboardingStep) else { return nil }
    self = analyticsStep
  }
}

enum AnalyticsScreen: String {
  case home
  case calendar
  case settings
}

enum AnalyticsPlan: String {
  case annual
  case monthly
}

enum AnalyticsResult: String {
  case granted
  case denied
  case failed
  case cancelled
  case completed
}

enum AnalyticsSetting: String {
  case reminderTime = "reminder_time"
  case autoReminderInterval = "auto_reminder_interval"
  case autoReminderRetryLimit = "auto_reminder_retry_limit"
  case supplyReminder = "supply_reminder"
  case `protocol`
  case cycleDay = "cycle_day"
  case blockedApps = "blocked_apps"
  case customReminders = "custom_reminders"
  case subscription
}

struct AnalyticsPayload {
  let source: AnalyticsSource?
  let step: AnalyticsStep?
  let stepIndex: Int?
  let screen: AnalyticsScreen?
  let plan: AnalyticsPlan?
  let result: AnalyticsResult?
  let setting: AnalyticsSetting?
  let acquisitionSource: AcquisitionSource?
  let isPlus: Bool?
  let hasBlockingSelection: Bool?
  /// Aggregated shield-intercept count carried by `blocker_intervention_fired`
  /// — one event per flush, never one per intercept (#161).
  let interventionCount: Int?
  /// Real shakes performed before the Early Value Proof check-in resolved,
  /// carried as `shake_count` by `demo_shake_completed` (#175).
  let shakeCount: Int?
  /// The trial day (10 or 13) carried as `day` by `trial_expiry_warning_sent`
  /// (#168 / ADR 0007).
  let trialWarningDay: Int?
  /// The Trial-End Paywall cohort carried as `cohort` by `paywall_viewed`
  /// with `source: trial_end` (#169 / ADR 0007).
  let trialEndCohort: TrialEndPaywallCohort?
  let paywallSurface: AnalyticsPaywallSurface?
  let trialStatusFeature: AnalyticsTrialStatusFeature?
  let trialActivationStatus: AnalyticsTrialActivationStatus?
  let isRecommended: Bool?
  let authorizationState: AnalyticsAuthorizationState?
  let retryCount: Int?
  let smartReminderOutcome: AnalyticsSmartReminderOutcome?
  let declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?
  let declineFeedbackReason: TrialDeclineFeedbackReason?
  let declineFeedbackHasText: Bool?
  let titleCustomized: Bool?
  let bodyCustomized: Bool?
  let retryTitleCustomized: Bool?
  let retryBodyCustomized: Bool?
  let lastCallTitleCustomized: Bool?
  let lastCallBodyCustomized: Bool?
  let reminderPreset: CustomReminderPreset?
  let reminderPresetEdited: Bool?

  init(
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil,
    stepIndex: Int? = nil,
    screen: AnalyticsScreen? = nil,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil,
    setting: AnalyticsSetting? = nil,
    acquisitionSource: AcquisitionSource? = nil,
    isPlus: Bool? = nil,
    hasBlockingSelection: Bool? = nil,
    interventionCount: Int? = nil,
    shakeCount: Int? = nil,
    trialWarningDay: Int? = nil,
    trialEndCohort: TrialEndPaywallCohort? = nil,
    paywallSurface: AnalyticsPaywallSurface? = nil,
    trialStatusFeature: AnalyticsTrialStatusFeature? = nil,
    trialActivationStatus: AnalyticsTrialActivationStatus? = nil,
    isRecommended: Bool? = nil,
    authorizationState: AnalyticsAuthorizationState? = nil,
    retryCount: Int? = nil,
    smartReminderOutcome: AnalyticsSmartReminderOutcome? = nil,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome? = nil,
    declineFeedbackReason: TrialDeclineFeedbackReason? = nil,
    declineFeedbackHasText: Bool? = nil,
    titleCustomized: Bool? = nil,
    bodyCustomized: Bool? = nil,
    retryTitleCustomized: Bool? = nil,
    retryBodyCustomized: Bool? = nil,
    lastCallTitleCustomized: Bool? = nil,
    lastCallBodyCustomized: Bool? = nil,
    reminderPreset: CustomReminderPreset? = nil,
    reminderPresetEdited: Bool? = nil
  ) {
    self.source = source
    self.step = step
    self.stepIndex = stepIndex
    self.screen = screen
    self.plan = plan
    self.result = result
    self.setting = setting
    self.acquisitionSource = acquisitionSource
    self.isPlus = isPlus
    self.hasBlockingSelection = hasBlockingSelection
    self.interventionCount = interventionCount
    self.shakeCount = shakeCount
    self.trialWarningDay = trialWarningDay
    self.trialEndCohort = trialEndCohort
    self.paywallSurface = paywallSurface
    self.trialStatusFeature = trialStatusFeature
    self.trialActivationStatus = trialActivationStatus
    self.isRecommended = isRecommended
    self.authorizationState = authorizationState
    self.retryCount = retryCount
    self.smartReminderOutcome = smartReminderOutcome
    self.declineFeedbackOutcome = declineFeedbackOutcome
    self.declineFeedbackReason = declineFeedbackReason
    self.declineFeedbackHasText = declineFeedbackHasText
    self.titleCustomized = titleCustomized
    self.bodyCustomized = bodyCustomized
    self.retryTitleCustomized = retryTitleCustomized
    self.retryBodyCustomized = retryBodyCustomized
    self.lastCallTitleCustomized = lastCallTitleCustomized
    self.lastCallBodyCustomized = lastCallBodyCustomized
    self.reminderPreset = reminderPreset
    self.reminderPresetEdited = reminderPresetEdited
  }

  var properties: [String: AnalyticsPropertyValue] {
    var properties: [String: AnalyticsPropertyValue] = [:]
    if let source { properties["source"] = .string(source.rawValue) }
    if let step { properties["step"] = .string(step.rawValue) }
    if let stepIndex { properties["step_index"] = .int(stepIndex) }
    if let screen { properties["screen"] = .string(screen.rawValue) }
    if let plan { properties["plan"] = .string(plan.rawValue) }
    if let result { properties["result"] = .string(result.rawValue) }
    if let setting { properties["setting"] = .string(setting.rawValue) }
    if let acquisitionSource {
      properties["acquisition_source"] = .string(acquisitionSource.rawValue)
    }
    if let isPlus { properties["is_plus"] = .bool(isPlus) }
    if let hasBlockingSelection {
      properties["has_blocking_selection"] = .bool(hasBlockingSelection)
    }
    if let interventionCount {
      properties["intervention_count"] = .int(interventionCount)
    }
    if let shakeCount {
      properties["shake_count"] = .int(shakeCount)
    }
    if let trialWarningDay {
      properties["day"] = .int(trialWarningDay)
    }
    if let trialEndCohort {
      properties["cohort"] = .string(trialEndCohort.rawValue)
    }
    if let paywallSurface {
      properties["surface"] = .string(paywallSurface.rawValue)
    }
    if let trialStatusFeature {
      properties["feature"] = .string(trialStatusFeature.rawValue)
    }
    if let trialActivationStatus {
      properties["status"] = .string(trialActivationStatus.rawValue)
    }
    if let isRecommended {
      properties["is_recommended"] = .bool(isRecommended)
    }
    if let authorizationState {
      properties["authorization_state"] = .string(authorizationState.rawValue)
    }
    if let retryCount {
      properties["retry_count"] = .int(retryCount)
    }
    if let smartReminderOutcome {
      properties["outcome"] = .string(smartReminderOutcome.rawValue)
    }
    if let declineFeedbackOutcome {
      properties["outcome"] = .string(declineFeedbackOutcome.rawValue)
    }
    if let declineFeedbackReason {
      properties["reason"] = .string(declineFeedbackReason.analyticsValue)
    }
    if let declineFeedbackHasText {
      properties["has_text"] = .bool(declineFeedbackHasText)
    }
    if let titleCustomized {
      properties["title_customized"] = .bool(titleCustomized)
    }
    if let bodyCustomized {
      properties["body_customized"] = .bool(bodyCustomized)
    }
    if let retryTitleCustomized {
      properties["retry_title_customized"] = .bool(retryTitleCustomized)
    }
    if let retryBodyCustomized {
      properties["retry_body_customized"] = .bool(retryBodyCustomized)
    }
    if let lastCallTitleCustomized {
      properties["last_call_title_customized"] = .bool(lastCallTitleCustomized)
    }
    if let lastCallBodyCustomized {
      properties["last_call_body_customized"] = .bool(lastCallBodyCustomized)
    }
    if let reminderPreset {
      properties["reminder_preset"] = .string(reminderPreset.rawValue)
    }
    if let reminderPresetEdited {
      properties["reminder_preset_edited"] = .bool(reminderPresetEdited)
    }
    return properties
  }

  /// Person properties (`$set`) to attach to the event. `acquisition_source` is
  /// promoted from an event-only property to a person property so the funnel can be
  /// broken down by source. It rides the event that already carries it (the
  /// acquisition-source onboarding step) — no extra event, no `identify`.
  var personProperties: [String: AnalyticsPropertyValue] {
    var properties: [String: AnalyticsPropertyValue] = [:]
    if let acquisitionSource {
      properties["acquisition_source"] = .string(acquisitionSource.rawValue)
    }
    return properties
  }
}

final class AnalyticsManager: AnalyticsTracking {
  static let shared = AnalyticsManager()

  private var isConfigured = false
  private let defaults: UserDefaults
  private let client: ProductAnalyticsClient
  private let infoDictionary: [String: Any]?
  private let sessionID: String

  /// `true` when `configure()` ran but found no usable `PostHogProjectToken`, so the
  /// SDK was never set up and every event is dropped. Surfaced (not silent) because a
  /// missing token is what reduced PostHog install coverage to ~25% (#140). Observable
  /// for tests and asserted loudly in DEBUG.
  private(set) var didFailConfiguration = false

  init(
    defaults: UserDefaults = .standard,
    client: ProductAnalyticsClient = PostHogAnalyticsClient(),
    infoDictionary: [String: Any]? = nil,
    sessionID: String = UUID().uuidString
  ) {
    self.defaults = defaults
    self.client = client
    self.infoDictionary = infoDictionary
    self.sessionID = sessionID
  }

  // Product analytics is collected for everyone — there is no consent gate or
  // opt-out. The telemetry payload is PII-free by construction (low-cardinality
  // labels only; see AnalyticsPayload), so capture is always enabled.
  var isAnalyticsEnabled: Bool { true }

  func configure() {
    guard !isConfigured else { return }
    guard let projectToken = infoDictionaryString("PostHogProjectToken"), !projectToken.isEmpty
    else {
      reportConfigurationFailure()
      return
    }

    let host = infoDictionaryString("PostHogHost") ?? "https://us.i.posthog.com"
    client.configure(
      ProductAnalyticsConfiguration(
        projectToken: projectToken,
        host: host,
        captureApplicationLifecycleEvents: false,
        captureScreenViews: false,
        captureElementInteractions: false,
        // PostHogReplayIntegration.requiresSwizzling — with swizzling off the SDK
        // silently skips installing session replay even when sessionReplay is true.
        // Auto-capture stays off regardless: lifecycle/screen-view/element/survey
        // flags below are what actually enable the other swizzling integrations.
        enableSwizzling: true,
        sendFeatureFlagEvent: false,
        preloadFeatureFlags: false,
        setDefaultPersonProperties: false,
        sessionReplay: true,
        sessionReplayScreenshotMode: true,
        sessionReplayMaskAllTextInputs: true,
        sessionReplayMaskAllImages: true,
        sessionReplayMaskAllSandboxedViews: true,
        surveys: false,
        isOptedOut: !isAnalyticsEnabled,
        personProfilesAlways: true,
        captureExceptions: true
      ))
    isConfigured = true
  }

  /// The PostHog anonymous distinct id, exposed so RevenueCat can tag the subscriber
  /// with it and join server-side subscription events to the same person. `nil` until
  /// PostHog is configured.
  var distinctId: String? {
    guard isConfigured else { return nil }
    return client.distinctId()
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil,
    stepIndex: Int? = nil,
    screen: AnalyticsScreen? = nil,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil,
    setting: AnalyticsSetting? = nil,
    acquisitionSource: AcquisitionSource? = nil,
    isPlus: Bool? = nil,
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
    let payload = AnalyticsPayload(
      source: source,
      step: step,
      stepIndex: stepIndex,
      screen: screen,
      plan: plan,
      result: result,
      setting: setting,
      acquisitionSource: acquisitionSource,
      isPlus: isPlus,
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

    capture(event, payload: payload, source: source, step: step)
  }

  func trackCustomReminderSave(
    isPlus: Bool,
    titleCustomized: Bool,
    bodyCustomized: Bool,
    retryTitleCustomized: Bool,
    retryBodyCustomized: Bool,
    lastCallTitleCustomized: Bool,
    lastCallBodyCustomized: Bool,
    preset: CustomReminderPreset?,
    editedAfterPreset: Bool
  ) {
    let payload = AnalyticsPayload(
      source: .settings,
      setting: .customReminders,
      isPlus: isPlus,
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized,
      reminderPreset: preset,
      reminderPresetEdited: preset == nil ? nil : editedAfterPreset
    )
    capture(.settingsChangeSaved, payload: payload, source: .settings)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    surface: AnalyticsPaywallSurface,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      source: source,
      isPlus: isPlus,
      paywallSurface: surface
    )

    capture(event, payload: payload, source: source)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    trialStatusFeature: AnalyticsTrialStatusFeature,
    trialActivationStatus: AnalyticsTrialActivationStatus,
    isRecommended: Bool,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      source: source,
      isPlus: isPlus,
      trialStatusFeature: trialStatusFeature,
      trialActivationStatus: trialActivationStatus,
      isRecommended: isRecommended
    )

    capture(event, payload: payload, source: source)
  }

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    step: AnalyticsStep?,
    authorizationState: AnalyticsAuthorizationState,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      source: source,
      step: step,
      isPlus: isPlus,
      authorizationState: authorizationState
    )

    capture(event, payload: payload, source: source, step: step)
  }

  func track(
    _ event: AnalyticsEvent,
    retryCount: Int,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      isPlus: isPlus,
      retryCount: retryCount
    )

    capture(event, payload: payload)
  }

  func track(
    _ event: AnalyticsEvent,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      source: .trialEnd,
      isPlus: isPlus,
      declineFeedbackOutcome: declineFeedbackOutcome
    )

    capture(event, payload: payload, source: .trialEnd)
  }

  func track(
    _ event: AnalyticsEvent,
    declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
    declineFeedbackReason: TrialDeclineFeedbackReason?,
    declineFeedbackHasText: Bool?,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      source: .trialEnd,
      isPlus: isPlus,
      declineFeedbackOutcome: declineFeedbackOutcome,
      declineFeedbackReason: declineFeedbackReason,
      declineFeedbackHasText: declineFeedbackHasText
    )

    capture(event, payload: payload, source: .trialEnd)
  }

  func track(
    _ event: AnalyticsEvent,
    smartReminderOutcome: AnalyticsSmartReminderOutcome,
    isPlus: Bool?
  ) {
    let payload = AnalyticsPayload(
      isPlus: isPlus,
      smartReminderOutcome: smartReminderOutcome
    )

    capture(event, payload: payload)
  }

  private func capture(
    _ event: AnalyticsEvent,
    payload: AnalyticsPayload,
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil
  ) {
    var properties = payload.properties
    if source == .onboarding, step != nil, event.carriesSplitOnboardingContext {
      properties["app_version"] = .string(
        infoDictionaryString("CFBundleShortVersionString") ?? "unknown")
      properties["app_build"] = .string(infoDictionaryString("CFBundleVersion") ?? "unknown")
      properties["session_id"] = .string(sessionID)
    }

    #if DEBUG
      // Debug builds ship without a PostHog token, so the PII-free event mirror
      // is the simulator verification surface.
      Logger(subsystem: "com.idrisskone.pillie", category: "analytics")
        .debug(
          "Pillie analytics capture: \(event.rawValue, privacy: .public) \(properties.map { "\($0.key)=\($0.value.postHogValue)" }.sorted().joined(separator: " "), privacy: .public)"
        )
    #endif

    guard isConfigured, isAnalyticsEnabled else { return }
    client.capture(
      event: event.rawValue,
      properties: properties,
      personProperties: payload.personProperties
    )
  }

  /// Report a handled failure (#179). Emits two captures:
  ///   • `app_error` — flat, dashboard-friendly (`domain`, `message`, `code`,
  ///     `severity`, plus any `context` entries), the event the founder
  ///     dashboard's error-rate panel plots.
  ///   • `$exception` — the raw error through PostHog Error Tracking, so handled
  ///     failures group by fingerprint next to autocaptured crashes.
  /// PII boundary: `domain`/`severity` are closed enums, `code` is the NSError
  /// code, and `message` is the error's own description — never user content,
  /// tokens, or free-form input. `context` values must be low-cardinality labels
  /// chosen at the call site (e.g. `operation: schedule`).
  /// Expected user cancellations (StoreKit `.userCancelled`) must NOT be routed
  /// here — they keep their product events and stay out of the error rate.
  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String] = [:],
    severity: AppErrorSeverity = .error
  ) {
    // The `$exception` capture carries only the classification labels — PostHog
    // derives message/stack from the error itself; `app_error` adds the flat
    // `message` + `code` the dashboard plots.
    var exceptionProperties: [String: AnalyticsPropertyValue] = [
      "domain": .string(domain.rawValue),
      "severity": .string(severity.rawValue),
    ]
    for (key, value) in context {
      exceptionProperties[key] = .string(value)
    }
    var properties = exceptionProperties
    properties["message"] = .string(error.localizedDescription)
    properties["code"] = .int((error as NSError).code)

    #if DEBUG
      // Same OSLog mirror as track(): debug builds have no PostHog token, so this
      // is the only way simulator QA can see the error capture.
      Logger(subsystem: "com.idrisskone.pillie", category: "analytics")
        .debug(
          "Pillie analytics capture: \(AnalyticsEvent.appError.rawValue, privacy: .public) \(properties.map { "\($0.key)=\($0.value.postHogValue)" }.sorted().joined(separator: " "), privacy: .public)"
        )
    #endif

    guard isConfigured, isAnalyticsEnabled else { return }
    client.capture(
      event: AnalyticsEvent.appError.rawValue,
      properties: properties,
      personProperties: [:]
    )
    client.captureException(error, properties: exceptionProperties)
  }

  func flush() {
    guard isConfigured, isAnalyticsEnabled else { return }
    client.flush()
  }

  /// A missing token used to fail silently — `configure()` returned, every `track`
  /// no-opped, and no one noticed until the funnel looked broken. Make it loud: flag
  /// it for observability (tests, in-app diagnostics) and fault-log it so a tokenless
  /// Release build is visible in Console instead of silently dropping every event.
  /// Debug builds intentionally ship without a token (no dev analytics, no prod
  /// pollution), so this stays a log + flag rather than a crash.
  private func reportConfigurationFailure() {
    didFailConfiguration = true
    os_log(
      .fault,
      "Pillie analytics: PostHogProjectToken missing or empty — analytics disabled and every event will be dropped. Set POSTHOG_PROJECT_TOKEN (Config/Release.xcconfig)."
    )
  }

  private func infoDictionaryString(_ key: String) -> String? {
    let rawValue = infoDictionary?[key] ?? Bundle.main.object(forInfoDictionaryKey: key)
    guard let raw = rawValue as? String else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
    return value
  }
}

private extension AnalyticsEvent {
  /// Split onboarding funnel events carry an explicit common envelope so raw
  /// exports remain joinable even outside PostHog's SDK-generated `$` fields.
  var carriesSplitOnboardingContext: Bool {
    switch self {
    case .coreOnboardingCompleted,
         .onboardingCompleted,
         .trialOfferViewed,
         .trialActivated,
         .trialGranted,
         .blockerSetupStarted,
         .blockerSetupCompleted,
         .blockerSetupSkipped,
         .reminderOnlyCompletion,
         .protectionPlanActivated:
      return true
    default:
      return false
    }
  }
}
