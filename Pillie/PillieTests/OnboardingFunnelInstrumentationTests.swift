//
//  OnboardingFunnelInstrumentationTests.swift
//  PillieTests
//
//  Covers the onboarding→trial funnel instrumentation fixes (#140): a reliable
//  once-per-install `onboarding_started`, an ordered `step_index` on every step
//  event, a loud signal when analytics fails to configure, and `acquisition_source`
//  attached to every user — not just those who answer the "how'd you hear" step.
//
//  Deliberately a plain (non-`@MainActor`) XCTestCase exercising value-type telemetry
//  and a plain AnalyticsManager, to avoid the Xcode 27 hosted-XCTest @MainActor deinit
//  crash.
//

import XCTest

@testable import Pillie

final class OnboardingFunnelInstrumentationTests: XCTestCase {

  // MARK: - step_index payload

  func testPayloadEmitsStepIndexAsIntWhenPresent() {
    let payload = AnalyticsPayload(step: .painPoints, stepIndex: 4)
    XCTAssertEqual(payload.properties["step_index"], .int(4))
  }

  func testPayloadOmitsStepIndexWhenAbsent() {
    let payload = AnalyticsPayload(step: .painPoints)
    XCTAssertNil(payload.properties["step_index"])
  }

  // MARK: - Ordered step events

  func testStepViewedCarriesDisplayOrderStepIndex() {
    let recorder = FunnelRecorder()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false })

    telemetry.stepViewed(OnboardingFlow.Step.painPoints.rawValue)

    let viewed = recorder.events.first { $0.event == .onboardingStepViewed }
    XCTAssertEqual(viewed?.step, .painPoints)
    // painPoints is the 5th screen in displayOrder → 0-based index 4.
    XCTAssertEqual(viewed?.stepIndex, 4)
  }

  func testStepCompletedCarriesDisplayOrderIndexOfCompletedStep() {
    let recorder = FunnelRecorder()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false })

    // Advancing painPoints → goal completes (leaves) painPoints.
    telemetry.stepCompleted(
      from: OnboardingFlow.Step.painPoints.rawValue,
      to: OnboardingFlow.Step.goal.rawValue)

    let completed = recorder.events.first { $0.event == .onboardingStepCompleted }
    XCTAssertEqual(completed?.step, .painPoints)
    XCTAssertEqual(completed?.stepIndex, 4)
  }

  // MARK: - onboarding_started once-per-install latch

  func testOnboardingStartedFiresExactlyOnceAndBeforeTheFirstStepView() {
    let recorder = FunnelRecorder()
    let telemetry = OnboardingTelemetry(
      analytics: recorder, isPlus: { false }, defaults: makeDefaults())

    telemetry.stepViewed(OnboardingFlow.Step.welcome.rawValue)
    telemetry.stepViewed(OnboardingFlow.Step.acquisitionSource.rawValue)

    XCTAssertEqual(recorder.events.filter { $0.event == .onboardingStarted }.count, 1)
    // It is the very first event — the funnel entry precedes any step view.
    XCTAssertEqual(recorder.events.first?.event, .onboardingStarted)
  }

  func testOnboardingStartedFiresForUserResumedPastTheFirstScreen() {
    // The legacy `step == 0` gate never fired for users resumed mid-onboarding
    // (persisted step ≥ 1) even though they complete — the headline #140 regression.
    let recorder = FunnelRecorder()
    let telemetry = OnboardingTelemetry(
      analytics: recorder, isPlus: { false }, defaults: makeDefaults())

    telemetry.stepViewed(OnboardingFlow.Step.acquisitionSource.rawValue)

    XCTAssertEqual(recorder.events.filter { $0.event == .onboardingStarted }.count, 1)
    XCTAssertEqual(recorder.events.first?.event, .onboardingStarted)
  }

  func testOnboardingStartedDoesNotRefireOnALaterLaunchSharingPersistedState() {
    let defaults = makeDefaults()

    let firstLaunch = FunnelRecorder()
    OnboardingTelemetry(analytics: firstLaunch, isPlus: { false }, defaults: defaults)
      .stepViewed(OnboardingFlow.Step.welcome.rawValue)

    // A later launch is a fresh telemetry instance over the same persisted defaults.
    let secondLaunch = FunnelRecorder()
    OnboardingTelemetry(analytics: secondLaunch, isPlus: { false }, defaults: defaults)
      .stepViewed(OnboardingFlow.Step.welcome.rawValue)

    XCTAssertEqual(firstLaunch.events.filter { $0.event == .onboardingStarted }.count, 1)
    XCTAssertEqual(secondLaunch.events.filter { $0.event == .onboardingStarted }.count, 0)
  }

  func testReturningUserWithLatchSetStillViewsStepsButNeverRefiresStarted() {
    // A real returning user: the latch is already persisted true. The step view must
    // still fire (we keep measuring per-step drop-off) but onboarding_started must not.
    let defaults = makeDefaults()
    defaults.set(true, forKey: OnboardingTelemetry.onboardingStartedEmittedKey)
    let recorder = FunnelRecorder()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false }, defaults: defaults)

    telemetry.stepViewed(OnboardingFlow.Step.acquisitionSource.rawValue)

    XCTAssertEqual(recorder.events.filter { $0.event == .onboardingStarted }.count, 0)
    XCTAssertEqual(recorder.events.filter { $0.event == .onboardingStepViewed }.count, 1)
  }

  func testOnboardedUserViewingTerminalStepFiresNothingAndLeavesLatchUnset() {
    // After onboarding completes, ContentView still calls stepViewed(onboardingStep)
    // with the terminal `complete` step on every launch. That maps to no analytics
    // step, so it must emit nothing and must never arm the once-per-install latch —
    // otherwise an onboarded user would be miscounted as entering onboarding.
    let defaults = makeDefaults()
    let recorder = FunnelRecorder()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false }, defaults: defaults)

    telemetry.stepViewed(OnboardingFlow.Step.complete.rawValue)

    XCTAssertTrue(recorder.events.isEmpty)
    XCTAssertFalse(defaults.bool(forKey: OnboardingTelemetry.onboardingStartedEmittedKey))
  }

  // MARK: - acquisition_source for every user

  func testAppLaunchedAttachesPersistedAcquisitionSourceWhenKnown() {
    let recorder = FunnelRecorder()
    let telemetry = ProductAnalyticsTelemetry(
      analytics: recorder, isPlus: { false }, acquisitionSource: { .tiktok })

    telemetry.appLaunched()

    // app_launched is a guaranteed-fire event, so it carries the source for every
    // install that has answered — even one that dropped before completing onboarding.
    let launched = recorder.events.first { $0.event == .appLaunched }
    XCTAssertEqual(launched?.acquisitionSource, .tiktok)
  }

  func testAppBecameActiveAttachesPersistedAcquisitionSourceWhenKnown() {
    let recorder = FunnelRecorder()
    let telemetry = ProductAnalyticsTelemetry(
      analytics: recorder, isPlus: { false }, acquisitionSource: { .reddit })

    telemetry.appBecameActive()

    let active = recorder.events.first { $0.event == .appBecameActive }
    XCTAssertEqual(active?.acquisitionSource, .reddit)
  }

  func testGuaranteedFireEventsOmitAcquisitionSourceWhenUnknown() {
    // A user who never answered "how'd you hear" has no source — we attach nothing
    // rather than a synthetic value (no empty `$set`).
    let recorder = FunnelRecorder()
    let telemetry = ProductAnalyticsTelemetry(
      analytics: recorder, isPlus: { false }, acquisitionSource: { nil })

    telemetry.appLaunched()

    let launched = recorder.events.first { $0.event == .appLaunched }
    XCTAssertNil(launched?.acquisitionSource)
  }

  func testAppLaunchedSetsAcquisitionSourceAsPersonPropertyEndToEnd() {
    // End-to-end through the real AnalyticsManager (not just the recorder): a
    // guaranteed-fire event `$set`s acquisition_source on the PostHog person, so the
    // funnel can be split by channel for every user who answered — even droppers.
    let client = SpyAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_valid_token")
    manager.configure()
    let telemetry = ProductAnalyticsTelemetry(
      analytics: manager, isPlus: { false }, acquisitionSource: { .tiktok })

    telemetry.appLaunched()

    let launched = client.captures.first { $0.event == "app_launched" }
    XCTAssertEqual(launched?.personProperties["acquisition_source"], .string("tiktok"))
  }

  // MARK: - Loud configuration failure (coverage)

  func testConfigureFlagsFailureLoudlyWhenTokenIsMissing() {
    let client = SpyAnalyticsClient()
    let manager = makeManager(client: client, token: "   ")

    manager.configure()

    // The silent no-op that dropped ~75% of installs' events is now an observable,
    // loud failure — and nothing is configured or captured.
    XCTAssertTrue(manager.didFailConfiguration)
    XCTAssertTrue(client.configurations.isEmpty)
    XCTAssertNil(manager.distinctId)
  }

  func testConfigureDoesNotFlagFailureWithAValidToken() {
    let client = SpyAnalyticsClient()
    let manager = makeManager(client: client, token: "phc_valid_token")

    manager.configure()

    XCTAssertFalse(manager.didFailConfiguration)
    XCTAssertEqual(client.configurations.count, 1)
  }

  // MARK: - Helpers

  private static var keptObjects: [AnyObject] = []

  private func makeManager(client: SpyAnalyticsClient, token: String) -> AnalyticsManager {
    let manager = AnalyticsManager(
      defaults: makeDefaults(),
      client: client,
      infoDictionary: ["PostHogProjectToken": token, "PostHogHost": "https://us.i.posthog.com"])
    Self.keptObjects.append(manager)
    return manager
  }

  private static var keptDefaults: [UserDefaults] = []

  /// A fresh, isolated UserDefaults suite. Retained for the process lifetime to keep
  /// the instance from deallocating mid-invocation (the Xcode 27 hosted-XCTest abort).
  private func makeDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: "OnboardingFunnelTests-\(UUID().uuidString)")!
    Self.keptDefaults.append(defaults)
    return defaults
  }
}

private final class FunnelRecorder: AnalyticsTracking {
  struct Event: Equatable {
    let event: AnalyticsEvent
    let source: AnalyticsSource?
    let step: AnalyticsStep?
    let stepIndex: Int?
    let acquisitionSource: AcquisitionSource?
  }

  // Hosted XCTest on the Xcode 27 beta aborts when a class deallocates while a test
  // invocation is on the stack (see SmartRemindersUpsellTests' struct tracker note).
  // Retaining every recorder for the process lifetime defers deallocation past the
  // invocation, so a recording fake stays usable without crashing the runner.
  private static var keepAlive: [FunnelRecorder] = []

  init() {
    Self.keepAlive.append(self)
  }

  private(set) var events: [Event] = []

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
    events.append(
      Event(
        event: event,
        source: source,
        step: step,
        stepIndex: stepIndex,
        acquisitionSource: acquisitionSource))
  }
}

private final class SpyAnalyticsClient: ProductAnalyticsClient {
  struct Capture: Equatable {
    let event: String
    let properties: [String: AnalyticsPropertyValue]
    let personProperties: [String: AnalyticsPropertyValue]
  }

  private static var keepAlive: [SpyAnalyticsClient] = []

  private(set) var configurations: [ProductAnalyticsConfiguration] = []
  private(set) var captures: [Capture] = []

  init() {
    Self.keepAlive.append(self)
  }

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    configurations.append(configuration)
  }

  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  ) {
    captures.append(Capture(event: event, properties: properties, personProperties: personProperties))
  }

  func distinctId() -> String? { "spy-distinct-id" }

  func flush() {}
}
