//
//  UpdateTrialGrantTelemetryTests.swift
//  PillieTests
//
//  Issue #165 (Reverse Trial 6/10): the existing-user grant on first launch
//  after the introducing update fires the same `trial_granted` event as the
//  onboarding Trial Granted Moment, but with `source: update` so the two grant
//  cohorts split cleanly in the funnel. `trial_started` keeps its
//  StoreKit-intro-offer meaning and is never emitted by this flow (ADR 0007).
//  Recorder + keep-alive style (no AnalyticsManager instance) per the hosted
//  XCTest @MainActor-deinit instability on the Xcode 27 beta.
//

import XCTest

@testable import Pillie

final class UpdateTrialGrantTelemetryTests: XCTestCase {

    // Held for the whole process: deallocating any Swift class inside a hosted
    // test aborts on the Xcode 27 beta (@MainActor deinit crash).
    private static let recorder = UpdateTrialGrantAnalyticsRecorder()

    private func makeTelemetry() -> ProductAnalyticsTelemetry {
        ProductAnalyticsTelemetry(analytics: Self.recorder, isPlus: { false })
    }

    func testUpdateTrialGrantedFiresWithUpdateSource() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().updateTrialGranted()

        let events = recorder.events.dropFirst(before)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.event, .trialGranted)
        XCTAssertEqual(events.first?.source, .update)
    }

    func testUpdateSourceSerializesAsUpdate() {
        XCTAssertEqual(AnalyticsSource.update.rawValue, "update")
    }

    func testUpdateGrantNeverEmitsTheStoreKitTrialStartedEvent() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().updateTrialGranted()

        let events = recorder.events.dropFirst(before)
        XCTAssertFalse(events.contains { $0.event == .trialStarted })
    }
}

private final class UpdateTrialGrantAnalyticsRecorder: AnalyticsTracking {
    struct Event: Equatable {
        let event: AnalyticsEvent
        let source: AnalyticsSource?
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
    ) {
        events.append(Event(event: event, source: source))
    }
}
