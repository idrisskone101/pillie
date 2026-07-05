//
//  TrialExpiryWarningTelemetryTests.swift
//  PillieTests
//
//  `trial_expiry_warning_sent` (#168 / ADR 0007): fired when a day-10/13 trial
//  expiry warning is delivered or handled, carrying `day: 10 | 13`. The
//  delivery decision is a pure value type (userInfo + already-sent days →
//  day-to-record) so foreground presentation and a later tap on the same
//  notification can never double-count.
//  Recorder + keep-alive style per the hosted XCTest @MainActor-deinit
//  instability on the Xcode 27 beta.
//

import XCTest

@testable import Pillie

final class TrialExpiryWarningTelemetryTests: XCTestCase {

    // Held for the whole process: deallocating any Swift class inside a hosted
    // test aborts on the Xcode 27 beta (@MainActor deinit crash).
    private static let recorder = TrialWarningAnalyticsRecorder()

    private func warningUserInfo(day: Int) -> [AnyHashable: Any] {
        [
            "requestKind": "trialExpiryWarning",
            "trialWarningDay": day,
        ]
    }

    func testPayloadCarriesDayProperty() {
        let properties = AnalyticsPayload(trialWarningDay: 13).properties
        XCTAssertEqual(properties["day"], .int(13))

        XCTAssertNil(AnalyticsPayload().properties["day"])
    }

    func testTelemetryFiresEventWithDay() {
        let recorder = Self.recorder
        let before = recorder.events.count

        let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { false })
        telemetry.trialExpiryWarningSent(day: 10)

        let events = recorder.events.dropFirst(before)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.event, .trialExpiryWarningSent)
        XCTAssertEqual(events.first?.trialWarningDay, 10)
        XCTAssertEqual(AnalyticsEvent.trialExpiryWarningSent.rawValue, "trial_expiry_warning_sent")
    }

    func testDeliveryDecisionReadsDayFromWarningPayload() {
        XCTAssertEqual(
            TrialExpiryWarningDelivery.day(fromUserInfo: warningUserInfo(day: 10), alreadySentDays: []),
            10
        )
        XCTAssertEqual(
            TrialExpiryWarningDelivery.day(fromUserInfo: warningUserInfo(day: 13), alreadySentDays: [10]),
            13
        )
    }

    func testDeliveryDecisionIgnoresOtherNotifications() {
        XCTAssertNil(TrialExpiryWarningDelivery.day(
            fromUserInfo: ["requestKind": "base", "dueDayEpoch": 1_780_000_000],
            alreadySentDays: []
        ))
        XCTAssertNil(TrialExpiryWarningDelivery.day(fromUserInfo: [:], alreadySentDays: []))
    }

    func testDeliveryDecisionIsOncePerDay() {
        // A warning presented in the foreground and later tapped reports once.
        XCTAssertNil(TrialExpiryWarningDelivery.day(
            fromUserInfo: warningUserInfo(day: 10),
            alreadySentDays: [10]
        ))
    }
}

private final class TrialWarningAnalyticsRecorder: AnalyticsTracking {
    struct Event: Equatable {
        let event: AnalyticsEvent
        let trialWarningDay: Int?
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
        trialWarningDay: Int?,
        titleCustomized: Bool?,
        bodyCustomized: Bool?,
        retryTitleCustomized: Bool?,
        retryBodyCustomized: Bool?,
        lastCallTitleCustomized: Bool?,
        lastCallBodyCustomized: Bool?
    ) {
        events.append(Event(event: event, trialWarningDay: trialWarningDay))
    }
}
