//
//  EarlyValueProofTelemetryTests.swift
//  PillieTests
//
//  Covers the Early Value Proof demo funnel instrumentation (#175): the three
//  interactive demo stages (drag-the-dot, shake tutorial, unlocked/continue)
//  fire `onboarding_step_viewed` with step_index 1–3, closing the 0→4 blind spot
//  between welcome and pain_points.
//
//  Deliberately a plain (non-`@MainActor`) XCTestCase exercising value-type
//  telemetry, to avoid the Xcode 27 hosted-XCTest @MainActor deinit crash.
//

import XCTest

@testable import Pillie

final class EarlyValueProofTelemetryTests: XCTestCase {

  func testDragStageViewedFiresStepViewedWithDemoDragAtIndexOne() {
    let recorder = DemoFunnelRecorder()
    var telemetry = EarlyValueProofTelemetry(analytics: recorder, isPlus: { false })

    telemetry.stageViewed(.drag)

    let viewed = recorder.events.first { $0.event == .onboardingStepViewed }
    XCTAssertEqual(viewed?.step, .demoDrag)
    XCTAssertEqual(viewed?.stepIndex, 1)
    XCTAssertEqual(viewed?.source, .onboarding)
  }

  func testShakeAndUnlockedStagesFillIndicesTwoAndThree() {
    let recorder = DemoFunnelRecorder()
    var telemetry = EarlyValueProofTelemetry(analytics: recorder, isPlus: { false })

    telemetry.stageViewed(.shake)
    telemetry.stageViewed(.unlocked)

    let viewed = recorder.events.filter { $0.event == .onboardingStepViewed }
    XCTAssertEqual(viewed.map(\.step), [.demoShake, .demoUnlocked])
    XCTAssertEqual(viewed.map(\.stepIndex), [2, 3])
  }

  func testRevisitedStageFiresOnlyOnce() {
    // The drag↔shake latch is reversible (hysteresis), so the user can bounce
    // between stages; the funnel wants one view per stage per screen visit.
    let recorder = DemoFunnelRecorder()
    var telemetry = EarlyValueProofTelemetry(analytics: recorder, isPlus: { false })

    telemetry.stageViewed(.drag)
    telemetry.stageViewed(.shake)
    telemetry.stageViewed(.drag)
    telemetry.stageViewed(.shake)

    let viewed = recorder.events.filter { $0.event == .onboardingStepViewed }
    XCTAssertEqual(viewed.map(\.step), [.demoDrag, .demoShake])
  }

  func testShakeCheckInCompletedCarriesRealShakeCount() {
    // The CTA tap is a check-in fallback (no CoreMotion on simulator, not
    // everyone can shake), so the count reports real shakes performed before
    // resolution — 0–3 — letting the funnel see mid-shake abandonment.
    let recorder = DemoFunnelRecorder()
    let telemetry = EarlyValueProofTelemetry(analytics: recorder, isPlus: { false })

    telemetry.shakeCheckInCompleted(shakeCount: 2)

    let completed = recorder.events.first { $0.event == .demoShakeCompleted }
    XCTAssertEqual(completed?.step, .demoShake)
    XCTAssertEqual(completed?.source, .onboarding)
    XCTAssertEqual(completed?.shakeCount, 2)
  }

  func testShakeCountRidesThePayloadAsAnInt() {
    let payload = AnalyticsPayload(shakeCount: 3)
    XCTAssertEqual(payload.properties["shake_count"], .int(3))
    XCTAssertNil(AnalyticsPayload().properties["shake_count"])
  }

  func testSkipReportsDedicatedDemoSkippedEvent() {
    let recorder = DemoFunnelRecorder()
    let telemetry = EarlyValueProofTelemetry(analytics: recorder, isPlus: { false })

    telemetry.demoSkipped()

    let skipped = recorder.events.first { $0.event == .demoSkipped }
    XCTAssertEqual(skipped?.source, .onboarding)
    XCTAssertEqual(skipped?.step, .demoDrag)
  }
}

// MARK: - Recorder

final class DemoFunnelRecorder: AnalyticsTracking {
  struct Event: Equatable {
    let event: AnalyticsEvent
    let source: AnalyticsSource?
    let step: AnalyticsStep?
    let stepIndex: Int?
    let result: AnalyticsResult?
    let shakeCount: Int?
  }

  // Hosted XCTest on the Xcode 27 beta aborts when a class deallocates while a
  // test invocation is on the stack. Retaining every recorder for the process
  // lifetime defers deallocation past the invocation.
  private static var keepAlive: [DemoFunnelRecorder] = []

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
        event: event, source: source, step: step, stepIndex: stepIndex, result: result,
        shakeCount: shakeCount))
  }
}
