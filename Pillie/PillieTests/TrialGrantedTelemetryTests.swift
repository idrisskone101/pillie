//
//  TrialGrantedTelemetryTests.swift
//  PillieTests
//
//  #164 (Reverse Trial 5/10): writing the trial grant at the Trial Granted Moment
//  fires a dedicated `trial_granted` event with `source: onboarding`. The
//  pre-existing `trial_started` event keeps its StoreKit-intro-offer meaning and
//  is never emitted by this flow (ADR 0007).
//  Recorder + keep-alive style (no AnalyticsManager instance) per the hosted
//  XCTest @MainActor-deinit instability on the Xcode 27 beta.
//

import XCTest

@testable import Pillie

final class TrialGrantedTelemetryTests: XCTestCase {

    // Held for the whole process: deallocating any Swift class inside a hosted
    // test aborts on the Xcode 27 beta (@MainActor deinit crash).
    private static let recorder = TrialGrantedAnalyticsRecorder()

    private func makeTelemetry() -> ProductAnalyticsTelemetry {
        ProductAnalyticsTelemetry(analytics: Self.recorder, isPlus: { false })
    }

    func testTrialGrantedFiresWithOnboardingSource() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().trialGranted()

        let events = recorder.events.dropFirst(before)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.event, .trialGranted)
        XCTAssertEqual(events.first?.source, .onboarding)
    }

    func testTrialGrantedEventNameIsDistinctFromStoreKitTrialStarted() {
        // `trial_started` keeps its StoreKit meaning; the Reverse Trial grant is
        // its own event so the two funnels never blend.
        XCTAssertEqual(AnalyticsEvent.trialGranted.rawValue, "trial_granted")
        XCTAssertNotEqual(AnalyticsEvent.trialGranted, AnalyticsEvent.trialStarted)
    }

    func testGrantingNeverEmitsTheStoreKitTrialStartedEvent() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().trialGranted()

        let events = recorder.events.dropFirst(before)
        XCTAssertFalse(events.contains { $0.event == .trialStarted })
    }
}

private final class TrialGrantedAnalyticsRecorder: AnalyticsTracking {
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
