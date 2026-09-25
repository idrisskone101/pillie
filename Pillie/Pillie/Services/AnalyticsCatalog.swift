import Foundation

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
  case protectionOffCard = "protection_off_card"
  case homeBlockingCard = "home_blocking_card"
  case trialEnd = "trial_end"
  case plusUpsell = "plus_upsell"
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
  case lifetime
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
  /// The Trial-End Paywall presentation variant carried as the compatibility
  /// `cohort` key and the explicit `paywall_variant` alias (#169 / ADR 0007).
  let trialEndCohort: TrialEndPaywallCohort?
  /// The immutable pre/post-cutover trial cohort for issue #257.
  let trialTermsCohort: TrialTermsCohort?
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
    trialTermsCohort: TrialTermsCohort? = nil,
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
    self.trialTermsCohort = trialTermsCohort
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
      properties["paywall_variant"] = .string(trialEndCohort.rawValue)
    }
    if let trialTermsCohort {
      properties["trial_terms_cohort"] = .string(trialTermsCohort.rawValue)
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
