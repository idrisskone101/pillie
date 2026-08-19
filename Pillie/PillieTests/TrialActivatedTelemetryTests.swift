//
//  TrialActivatedTelemetryTests.swift
//  PillieTests
//
//  #265: reverse-trial telemetry must preserve lifecycle order —
//  `trial_granted` before `trial_activated`. Ordered onboarding funnels
//  undercount successful activation when the events arrive inverted.
//  Recorder + keep-alive style (no AnalyticsManager instance) per the hosted
//  XCTest @MainActor-deinit instability on the Xcode 27 beta.
//

import XCTest

@testable import Pillie

final class TrialActivatedTelemetryTests: XCTestCase {

    // Held for the whole process: deallocating any Swift class inside a hosted
    // test aborts on the Xcode 27 beta (@MainActor deinit crash).
    private static let recorder = TrialActivatedAnalyticsRecorder()

    private func makeTelemetry() -> ProductAnalyticsTelemetry {
        ProductAnalyticsTelemetry(analytics: Self.recorder, isPlus: { false })
    }

    func testTrialActivatedEmitsGrantBeforeActivation() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().trialActivated()

        let events = recorder.events.dropFirst(before).map(\.event)
        XCTAssertEqual(events, [.trialGranted, .trialActivated])
    }

    func testTrialActivatedEmitsEachEventExactlyOnce() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().trialActivated()

        let events = recorder.events.dropFirst(before).map(\.event)
        XCTAssertEqual(events.filter { $0 == .trialGranted }.count, 1)
        XCTAssertEqual(events.filter { $0 == .trialActivated }.count, 1)
    }

    func testTrialActivatedKeepsOnboardingSourceAndAppBlockingStep() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().trialActivated()

        let events = recorder.events.dropFirst(before)
        for event in events {
            XCTAssertEqual(event.source, .onboarding)
            XCTAssertEqual(event.step, .appBlocking)
        }
    }
}

private final class TrialActivatedAnalyticsRecorder: AnalyticsTracking {
    struct Event: Equatable {
        let event: AnalyticsEvent
        let source: AnalyticsSource?
        let step: AnalyticsStep?
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
        events.append(Event(event: event, source: source, step: step))
    }
}
