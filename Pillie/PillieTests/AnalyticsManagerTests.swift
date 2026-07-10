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

  // Xcode 27 beta hosted-XCTest workaround: deallocating any @MainActor class
  // mid-invocation aborts in libmalloc (isolated-deinit back-deploy bug), which
  // crashed the host app once per test in this suite. Retain every class
  // instance a test creates for the process lifetime so nothing deallocates
  // while an invocation is on the stack — same pattern as
  // OnboardingFunnelInstrumentationTests (#140).
  private static var keptObjects: [AnyObject] = []

  override func setUp() {
    super.setUp()
    defaultsSuiteName = "AnalyticsManagerTests-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: defaultsSuiteName)!
    Self.keptObjects.append(defaults)
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
    // Swizzling stays enabled solely because PostHogReplayIntegration requires it;
    // the capture-feature flags above are all false, so nothing else auto-captures.
    XCTAssertTrue(configuration.enableSwizzling)
    XCTAssertFalse(configuration.sendFeatureFlagEvent)
    XCTAssertFalse(configuration.preloadFeatureFlags)
    XCTAssertFalse(configuration.setDefaultPersonProperties)
    XCTAssertFalse(configuration.surveys)
    // Analytics is collected for everyone, so configure opts in (never opted out).
    XCTAssertFalse(configuration.isOptedOut)
  }

  func testEventsAreCapturedImmediatelyAfterConfigureWithoutConsent() {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    // Analytics is collected for everyone — every event flows from launch, with no
    // consent gate to drop the early ones.
    manager.configure()
    manager.track(.appLaunched, source: .home, isPlus: false)
    manager.track(.onboardingStepViewed, source: .onboarding, step: .welcome, isPlus: false)
    manager.track(.onboardingStepViewed, source: .onboarding, step: .painPoints, isPlus: false)

    XCTAssertEqual(client.captures.count, 3)
    XCTAssertEqual(client.captures.last?.event, "onboarding_step_viewed")
    XCTAssertEqual(
      client.captures.last?.properties,
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

  func testAcquisitionSourceTelemetryUsesApprovedValue() throws {
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

  func testAcquisitionSourceIsAlsoPromotedToPersonProperty() throws {
    let client = RecordingAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_test_token")

    manager.configure()
    manager.track(.appLaunched, source: .home, isPlus: false)
    manager.track(
      .onboardingStepCompleted,
      source: .onboarding,
      step: .acquisitionSource,
      acquisitionSource: .reddit,
      isPlus: false
    )

    // app_launched carries no acquisition source, so it sets no person properties.
    XCTAssertEqual(client.captures.first?.personProperties, [:])
    // The acquisition-source step promotes the coarse value to a person property
    // ($set) so the funnel can be broken down by source — without identify().
    let acquisition = try XCTUnwrap(client.captures.last)
    XCTAssertEqual(acquisition.properties["acquisition_source"], .string("reddit"))
    XCTAssertEqual(acquisition.personProperties, ["acquisition_source": .string("reddit")])
  }

  func testTrialStartedAndPurchaseCompletedAreDistinctEvents() {
    let recorder = RecordingAnalyticsTracker()
    let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { true })

    telemetry.trialStarted(plan: .annual, isFromOnboarding: true)
    telemetry.purchaseCompleted(plan: .monthly, isFromOnboarding: false)

    XCTAssertEqual(recorder.events, [.trialStarted, .purchaseCompleted])
    XCTAssertEqual(recorder.sources, [.onboarding, .settings])
  }

  func testOnboardingStartedFiresOnceWhenEnteringTheFirstStep() {
    let recorder = RecordingAnalyticsTracker()
    // Inject the per-test defaults suite so the once-per-install latch starts clean
    // and never leaks across runs via `.standard`.
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false }, defaults: defaults)

    // Entering step 0 (welcome) starts the activation funnel exactly once...
    telemetry.stepViewed(0)
    // ...and viewing a later step never re-fires onboarding_started.
    telemetry.stepViewed(OnboardingFlow.Step.acquisitionSource.rawValue)

    XCTAssertEqual(recorder.events.filter { $0 == .onboardingStarted }.count, 1)
    XCTAssertEqual(recorder.events.first, .onboardingStarted)
  }

  func testOnboardingCompletedFiresOnlyAfterFinalOnboardingStep() {
    let recorder = RecordingAnalyticsTracker()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false })

    telemetry.stepCompleted(from: 9, to: 10)
    telemetry.stepCompleted(from: 14, to: 16)

    XCTAssertEqual(
      recorder.events,
      [
        .onboardingStepCompleted,
        .onboardingStepCompleted,
        .onboardingCompleted,
      ])
    // Step 9 is `.method` (step 10 is `.schedule`); a forward transition records the
    // step it left. The earlier `.schedule` expectation was stale after the onboarding
    // step renumbering — unrelated to this ticket's analytics work.
    XCTAssertEqual(recorder.steps, [.method, .freePlanConfirmation, nil])
  }

  func testProductAnalyticsTelemetryMapsDomainEventsToApprovedCoarseProperties() {
    let recorder = RecordingAnalyticsTracker()
    let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { true })

    telemetry.blockedAppsSettingsOpened(hasSelection: false)
    telemetry.blockedAppsSaved(hasSelection: true)
    telemetry.onboardingBlockerConfigSaved(hasSelection: true)
    telemetry.mainTabSelected(.history)
    telemetry.todayActionCompleted()
    telemetry.onboardingAcquisitionSourceCompleted(.reddit)

    XCTAssertEqual(
      recorder.events,
      [
        .settingsSheetOpened,
        .settingsChangeSaved,
        .blockerConfigSaved,
        .tabSelected,
        .todayActionCompleted,
        .onboardingStepCompleted,
      ])
    XCTAssertEqual(recorder.sources, [.settings, .settings, .onboarding, nil, .home, .onboarding])
    XCTAssertEqual(recorder.steps, [nil, nil, .appBlocking, nil, nil, .acquisitionSource])
    XCTAssertEqual(recorder.screens, [nil, nil, nil, .calendar, nil, nil])
    // The onboarding blocker save fires the dedicated event, so it carries no
    // `setting` (the event itself means "blocked apps saved"); the Settings-side
    // save still reuses settings_change_saved with setting=blocked_apps.
    XCTAssertEqual(recorder.settings, [.blockedApps, .blockedApps, nil, nil, nil, nil])
    XCTAssertEqual(recorder.acquisitionSources, [nil, nil, nil, nil, nil, .reddit])
    XCTAssertEqual(recorder.isPlusValues, [true, true, true, true, true, true])
    XCTAssertEqual(recorder.hasBlockingSelectionValues, [false, true, true, nil, nil, nil])
  }

  func testOnboardingBlockerConfigSaveFiresDedicatedCoarseEvent() {
    // AC4/AC6: a valid save in onboarding fires `blocker_config_saved` with only
    // coarse, consent-safe context — the selection bit, never names/tokens/counts.
    let recorder = RecordingAnalyticsTracker()
    let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { true })

    telemetry.onboardingBlockerConfigSaved(hasSelection: true)

    XCTAssertEqual(recorder.events, [.blockerConfigSaved])
    XCTAssertEqual(recorder.sources, [.onboarding])
    XCTAssertEqual(recorder.steps, [.appBlocking])
    XCTAssertEqual(recorder.settings, [nil])
    XCTAssertEqual(recorder.hasBlockingSelectionValues, [true])
    XCTAssertEqual(recorder.isPlusValues, [true])
  }

  func testProductAnalyticsTelemetryDoesNotAddMotionHapticOrAnimationEvents() {
    let disallowedEventTerms = ["animation", "feedback", "haptic", "motion"]
    let eventNames = AnalyticsEvent.allCases.map(\.rawValue)

    for eventName in eventNames {
      for term in disallowedEventTerms {
        XCTAssertFalse(
          eventName.contains(term),
          "\(eventName) should not be captured as Product Analytics Telemetry"
        )
      }
    }
  }

  func testFlushOnlyRunsWhenConfigured() {
    let configuredClient = RecordingAnalyticsClient()
    let configuredManager = makeManager(client: configuredClient, token: "phc_test_token")

    configuredManager.configure()
    configuredManager.flush()

    let unconfiguredClient = RecordingAnalyticsClient()
    let unconfiguredManager = makeManager(client: unconfiguredClient, token: " ")
    unconfiguredManager.configure()
    unconfiguredManager.flush()

    XCTAssertEqual(configuredClient.flushCount, 1)
    XCTAssertEqual(unconfiguredClient.flushCount, 0)
  }

  private func makeManager(
    client: RecordingAnalyticsClient,
    token: String,
    host: String = "https://us.i.posthog.com"
  ) -> AnalyticsManager {
    let manager = AnalyticsManager(
      defaults: defaults,
      client: client,
      infoDictionary: [
        "PostHogProjectToken": token,
        "PostHogHost": host,
      ]
    )
    Self.keptObjects.append(manager)
    return manager
  }
}

private final class RecordingAnalyticsClient: ProductAnalyticsClient {
  // Process-lifetime retention: see keptObjects on AnalyticsManagerTests.
  private static var keepAlive: [RecordingAnalyticsClient] = []

  init() {
    Self.keepAlive.append(self)
  }

  private(set) var configurations: [ProductAnalyticsConfiguration] = []
  private(set) var captures: [(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  )] = []
  private(set) var flushCount = 0

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    configurations.append(configuration)
  }

  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  ) {
    captures.append((event, properties, personProperties))
  }

  func distinctId() -> String? { "test-distinct-id" }

  func flush() {
    flushCount += 1
  }
}

private final class RecordingAnalyticsTracker: AnalyticsTracking {
  // Process-lifetime retention: see keptObjects on AnalyticsManagerTests.
  private static var keepAlive: [RecordingAnalyticsTracker] = []

  init() {
    Self.keepAlive.append(self)
  }

  private(set) var events: [AnalyticsEvent] = []
  private(set) var sources: [AnalyticsSource?] = []
  private(set) var steps: [AnalyticsStep?] = []
  private(set) var stepIndices: [Int?] = []
  private(set) var screens: [AnalyticsScreen?] = []
  private(set) var settings: [AnalyticsSetting?] = []
  private(set) var acquisitionSources: [AcquisitionSource?] = []
  private(set) var isPlusValues: [Bool?] = []
  private(set) var hasBlockingSelectionValues: [Bool?] = []
  private(set) var titleCustomizedValues: [Bool?] = []
  private(set) var bodyCustomizedValues: [Bool?] = []
  private(set) var lastCallTitleCustomizedValues: [Bool?] = []
  private(set) var lastCallBodyCustomizedValues: [Bool?] = []

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
  ) {
    events.append(event)
    sources.append(source)
    steps.append(step)
    stepIndices.append(stepIndex)
    screens.append(screen)
    settings.append(setting)
    acquisitionSources.append(acquisitionSource)
    isPlusValues.append(isPlus)
    hasBlockingSelectionValues.append(hasBlockingSelection)
    titleCustomizedValues.append(titleCustomized)
    bodyCustomizedValues.append(bodyCustomized)
    lastCallTitleCustomizedValues.append(lastCallTitleCustomized)
    lastCallBodyCustomizedValues.append(lastCallBodyCustomized)
  }
}
