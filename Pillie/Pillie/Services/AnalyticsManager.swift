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
  let surveys: Bool
  let isOptedOut: Bool
  /// Process person profiles for every event (PostHog `personProfiles = .always`).
  /// Required so that person properties set via `$set` — notably `acquisition_source`
  /// — stick for anonymous users (we never call `identify`, per ADR 0001), letting the
  /// funnel be broken down by source. Default PostHog behavior (`.identifiedOnly`) drops
  /// `$set` for users who never identify.
  let personProfilesAlways: Bool
}

protocol ProductAnalyticsClient: AnyObject {
  func configure(_ configuration: ProductAnalyticsConfiguration)
  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  )
  /// The current anonymous distinct id, used to join server-side RevenueCat events
  /// to the same PostHog person. `nil` before the SDK is configured.
  func distinctId() -> String?
  func flush()
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

    #if os(iOS)
      config.captureElementInteractions = configuration.captureElementInteractions
      config.sessionReplay = configuration.sessionReplay
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
    trialWarningDay: Int?,
    titleCustomized: Bool?,
    bodyCustomized: Bool?,
    retryTitleCustomized: Bool?,
    retryBodyCustomized: Bool?,
    lastCallTitleCustomized: Bool?,
    lastCallBodyCustomized: Bool?
  )
}

enum AnalyticsEvent: String, CaseIterable {
  case appLaunched = "app_launched"
  case appBecameActive = "app_became_active"
  case onboardingStarted = "onboarding_started"
  case onboardingStepViewed = "onboarding_step_viewed"
  case onboardingStepCompleted = "onboarding_step_completed"
  case onboardingBackTapped = "onboarding_back_tapped"
  case onboardingCompleted = "onboarding_completed"
  case reminderOnlyCompletion = "reminder_only_completion"
  case protectionPlanActivated = "protection_plan_activated"
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
  case notificationPermissionRequested = "notification_permission_requested"
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
  /// The trial day (10 or 13) carried as `day` by `trial_expiry_warning_sent`
  /// (#168 / ADR 0007).
  let trialWarningDay: Int?
  let titleCustomized: Bool?
  let bodyCustomized: Bool?
  let retryTitleCustomized: Bool?
  let retryBodyCustomized: Bool?
  let lastCallTitleCustomized: Bool?
  let lastCallBodyCustomized: Bool?

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
    trialWarningDay: Int? = nil,
    titleCustomized: Bool? = nil,
    bodyCustomized: Bool? = nil,
    retryTitleCustomized: Bool? = nil,
    retryBodyCustomized: Bool? = nil,
    lastCallTitleCustomized: Bool? = nil,
    lastCallBodyCustomized: Bool? = nil
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
    self.trialWarningDay = trialWarningDay
    self.titleCustomized = titleCustomized
    self.bodyCustomized = bodyCustomized
    self.retryTitleCustomized = retryTitleCustomized
    self.retryBodyCustomized = retryBodyCustomized
    self.lastCallTitleCustomized = lastCallTitleCustomized
    self.lastCallBodyCustomized = lastCallBodyCustomized
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
    if let trialWarningDay {
      properties["day"] = .int(trialWarningDay)
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

  /// `true` when `configure()` ran but found no usable `PostHogProjectToken`, so the
  /// SDK was never set up and every event is dropped. Surfaced (not silent) because a
  /// missing token is what reduced PostHog install coverage to ~25% (#140). Observable
  /// for tests and asserted loudly in DEBUG.
  private(set) var didFailConfiguration = false

  init(
    defaults: UserDefaults = .standard,
    client: ProductAnalyticsClient = PostHogAnalyticsClient(),
    infoDictionary: [String: Any]? = nil
  ) {
    self.defaults = defaults
    self.client = client
    self.infoDictionary = infoDictionary
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
        enableSwizzling: false,
        sendFeatureFlagEvent: false,
        preloadFeatureFlags: false,
        setDefaultPersonProperties: false,
        sessionReplay: false,
        surveys: false,
        isOptedOut: !isAnalyticsEnabled,
        personProfilesAlways: true
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
    trialWarningDay: Int? = nil,
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
      trialWarningDay: trialWarningDay,
      titleCustomized: titleCustomized,
      bodyCustomized: bodyCustomized,
      retryTitleCustomized: retryTitleCustomized,
      retryBodyCustomized: retryBodyCustomized,
      lastCallTitleCustomized: lastCallTitleCustomized,
      lastCallBodyCustomized: lastCallBodyCustomized
    )

    #if DEBUG
      // Debug builds ship without a PostHog token, so captures are dropped and
      // otherwise invisible. Mirror every track into OSLog so simulator QA can
      // verify events (name + coarse properties; the payload is PII-free by
      // construction). Stream with:
      //   log stream --predicate 'subsystem == "com.idrisskone.pillie"' --level debug
      Logger(subsystem: "com.idrisskone.pillie", category: "analytics")
        .debug(
          "Pillie analytics capture: \(event.rawValue, privacy: .public) \(payload.properties.map { "\($0.key)=\($0.value.postHogValue)" }.sorted().joined(separator: " "), privacy: .public)"
        )
    #endif

    guard isConfigured, isAnalyticsEnabled else { return }
    client.capture(
      event: event.rawValue,
      properties: payload.properties,
      personProperties: payload.personProperties
    )
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
