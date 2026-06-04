//
//  AnalyticsManagerTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

@MainActor
final class AnalyticsManagerTests: XCTestCase {
  private var defaultsSuiteName: String!
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    defaultsSuiteName = "AnalyticsManagerTests-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: defaultsSuiteName)!
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    defaults = nil
    defaultsSuiteName = nil
    super.tearDown()
  }

  func testBlankProjectTokenLeavesAnalyticsUnconfiguredAndCaptureNoOps() {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "   ")

    manager.configure()
    manager.track(.appLaunched, source: .home, isPlus: false)

    XCTAssertTrue(client.configurations.isEmpty)
    XCTAssertTrue(client.captures.isEmpty)
  }

  func testConfiguredAnalyticsDisablesAutomaticPostHogCaptureFeatures() throws {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.configure()

    let configuration = try XCTUnwrap(client.configurations.first)
    XCTAssertEqual(configuration.projectToken, "phc_test_token")
    XCTAssertEqual(configuration.host, "https://us.i.posthog.com")
    XCTAssertFalse(configuration.captureApplicationLifecycleEvents)
    XCTAssertFalse(configuration.captureScreenViews)
    XCTAssertFalse(configuration.captureElementInteractions)
    XCTAssertFalse(configuration.enableSwizzling)
    XCTAssertFalse(configuration.sendFeatureFlagEvent)
    XCTAssertFalse(configuration.preloadFeatureFlags)
    XCTAssertFalse(configuration.setDefaultPersonProperties)
    XCTAssertFalse(configuration.sessionReplay)
    XCTAssertFalse(configuration.surveys)
    XCTAssertTrue(configuration.isOptedOut)
  }

  func testFreshInstallDropsPreConsentEventsAndCapturesOnlyAfterExplicitConsent() {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.configure()
    manager.track(.appLaunched, source: .home, isPlus: false)
    manager.track(.onboardingStepViewed, source: .onboarding, step: .welcome, isPlus: false)
    manager.setAnalyticsEnabled(true)
    manager.track(.onboardingStepViewed, source: .onboarding, step: .painPoints, isPlus: false)

    XCTAssertEqual(client.optOutChanges, [false])
    XCTAssertEqual(client.captures.map(\.event), ["onboarding_step_viewed"])
    XCTAssertEqual(
      client.captures.first?.properties,
      [
        "source": .string("onboarding"),
        "step": .string("pain_points"),
        "is_plus": .bool(false),
      ])
  }

  func testCaptureUsesTypedAllowedLowCardinalityProperties() throws {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.configure()
    manager.track(
      .settingsChangeSaved,
      source: .settings,
      step: .reminderTime,
      screen: .settings,
      plan: .annual,
      result: .completed,
      setting: .reminderTime,
      isPlus: true,
      hasBlockingSelection: false
    )

    let capture = try XCTUnwrap(client.captures.first)
    XCTAssertEqual(capture.event, "settings_change_saved")
    XCTAssertEqual(
      capture.properties,
      [
        "source": .string("settings"),
        "step": .string("reminder_time"),
        "screen": .string("settings"),
        "plan": .string("annual"),
        "result": .string("completed"),
        "setting": .string("reminder_time"),
        "is_plus": .bool(true),
        "has_blocking_selection": .bool(false),
      ])
  }

  func testOnboardingPermissionTelemetryUsesApprovedCoarsePropertiesOnly() {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.setAnalyticsEnabled(true)
    manager.configure()
    manager.track(.onboardingStepViewed, source: .onboarding, step: .welcome, isPlus: false)
    manager.track(.onboardingStepCompleted, source: .onboarding, step: .reminderTime, isPlus: false)
    manager.track(.onboardingBackTapped, source: .onboarding, step: .method, isPlus: false)
    manager.track(.onboardingCompleted, source: .onboarding, isPlus: false)
    manager.track(
      .notificationPermissionRequested, source: .onboarding, step: .reminderTime, isPlus: false)
    manager.track(
      .screenTimePermissionRequested, source: .onboarding, step: .appBlocking, isPlus: true)
    manager.track(
      .screenTimePermissionCompleted, source: .onboarding, step: .appBlocking, result: .granted,
      isPlus: true)
    manager.track(
      .screenTimePermissionCompleted, source: .onboarding, step: .appBlocking, result: .denied,
      isPlus: true)

    XCTAssertEqual(
      client.captures.map(\.event),
      [
        "onboarding_step_viewed",
        "onboarding_step_completed",
        "onboarding_back_tapped",
        "onboarding_completed",
        "notification_permission_requested",
        "screen_time_permission_requested",
        "screen_time_permission_completed",
        "screen_time_permission_completed",
      ])
    XCTAssertEqual(
      client.captures.map(\.properties),
      [
        ["source": .string("onboarding"), "step": .string("welcome"), "is_plus": .bool(false)],
        [
          "source": .string("onboarding"), "step": .string("reminder_time"),
          "is_plus": .bool(false),
        ],
        ["source": .string("onboarding"), "step": .string("method"), "is_plus": .bool(false)],
        ["source": .string("onboarding"), "is_plus": .bool(false)],
        [
          "source": .string("onboarding"), "step": .string("reminder_time"),
          "is_plus": .bool(false),
        ],
        ["source": .string("onboarding"), "step": .string("app_blocking"), "is_plus": .bool(true)],
        [
          "source": .string("onboarding"), "step": .string("app_blocking"),
          "result": .string("granted"), "is_plus": .bool(true),
        ],
        [
          "source": .string("onboarding"), "step": .string("app_blocking"),
          "result": .string("denied"), "is_plus": .bool(true),
        ],
      ])
  }

  func testAcquisitionSourceTelemetryUsesApprovedValueAndRequiresConsent() throws {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.configure()
    manager.track(
      .onboardingStepCompleted,
      source: .onboarding,
      step: .acquisitionSource,
      acquisitionSource: .reddit,
      isPlus: false
    )
    manager.setAnalyticsEnabled(true)
    manager.track(
      .onboardingStepCompleted,
      source: .onboarding,
      step: .acquisitionSource,
      acquisitionSource: .reddit,
      isPlus: false
    )

    let capture = try XCTUnwrap(client.captures.first)
    XCTAssertEqual(client.captures.count, 1)
    XCTAssertEqual(capture.event, "onboarding_step_completed")
    XCTAssertEqual(
      capture.properties,
      [
        "source": .string("onboarding"),
        "step": .string("acquisition_source"),
        "acquisition_source": .string("reddit"),
        "is_plus": .bool(false),
      ])
  }

  func testOnboardingStepMappingPlacesRealSetupBeforePaywall() throws {
    XCTAssertEqual(AnalyticsStep(onboardingStep: 0), .welcome)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 1), .analyticsConsent)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 2), .productDemo)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 3), .reviewPrompt)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 4), .painPoints)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 5), .goal)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 6), .missFrequency)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 7), .acquisitionSource)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 8), .method)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 9), .schedule)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 10), .reminderTime)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 11), .reminderPlan)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 12), .paywall)
    XCTAssertEqual(AnalyticsStep(onboardingStep: 13), .appBlocking)
  }

  func testOnboardingCompletedFiresOnlyAfterFinalOnboardingStep() {
    let recorder = RecordingAnalyticsTracker()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false })

    telemetry.stepCompleted(from: 9, to: 10)
    telemetry.stepCompleted(from: 13, to: 14)

    XCTAssertEqual(
      recorder.events,
      [
        .onboardingStepCompleted,
        .onboardingStepCompleted,
        .onboardingCompleted,
      ])
    XCTAssertEqual(recorder.steps, [.schedule, .appBlocking, nil])
  }

  func testOptOutStopsFutureCaptureAndCanOptBackIn() {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.configure()
    manager.setAnalyticsEnabled(false)
    manager.track(.appBecameActive, source: .home)
    manager.setAnalyticsEnabled(true)
    manager.track(.appBecameActive, source: .home)

    XCTAssertEqual(client.optOutChanges, [true, false])
    XCTAssertEqual(client.captures.map(\.event), ["app_became_active"])
  }

  func testFlushOnlyRunsWhenAnalyticsIsConfiguredAndEnabled() {
    let configuredClient = RecordingAnalyticsClient()
    let configuredManager = makeManager(client: configuredClient, token: "phc_test_token")

    configuredManager.configure()
    configuredManager.flush()

    let unconfiguredClient = RecordingAnalyticsClient()
    let unconfiguredManager = makeManager(client: unconfiguredClient, token: " ")
    unconfiguredManager.configure()
    unconfiguredManager.flush()

    configuredManager.setAnalyticsEnabled(false)
    configuredManager.flush()

    XCTAssertEqual(configuredClient.flushCount, 1)
    XCTAssertEqual(unconfiguredClient.flushCount, 0)
  }

  private func makeManager(
    client: RecordingAnalyticsClient,
    token: String,
    host: String = "https://us.i.posthog.com"
  ) -> AnalyticsManager {
    AnalyticsManager(
      defaults: defaults,
      client: client,
      infoDictionary: [
        "PostHogProjectToken": token,
        "PostHogHost": host,
      ]
    )
  }
}

private final class RecordingAnalyticsClient: ProductAnalyticsClient {
  private(set) var configurations: [ProductAnalyticsConfiguration] = []
  private(set) var optOutChanges: [Bool] = []
  private(set) var captures: [(event: String, properties: [String: AnalyticsPropertyValue])] = []
  private(set) var flushCount = 0

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    configurations.append(configuration)
  }

  func setOptedOut(_ isOptedOut: Bool) {
    optOutChanges.append(isOptedOut)
  }

  func capture(event: String, properties: [String: AnalyticsPropertyValue]) {
    captures.append((event, properties))
  }

  func flush() {
    flushCount += 1
  }
}

private final class RecordingAnalyticsTracker: AnalyticsTracking {
  private(set) var events: [AnalyticsEvent] = []
  private(set) var steps: [AnalyticsStep?] = []

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    step: AnalyticsStep?,
    screen: AnalyticsScreen?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    setting: AnalyticsSetting?,
    acquisitionSource: AcquisitionSource?,
    isPlus: Bool?,
    hasBlockingSelection: Bool?
  ) {
    events.append(event)
    steps.append(step)
  }
}
