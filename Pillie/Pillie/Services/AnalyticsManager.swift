//
//  AnalyticsManager.swift
//  Pillie
//

import Foundation
import os

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

  func track(_ event: AnalyticsEvent, payload: AnalyticsPayload) {
    var properties = payload.properties
    if payload.source == .onboarding, payload.step != nil, event.carriesSplitOnboardingContext {
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
