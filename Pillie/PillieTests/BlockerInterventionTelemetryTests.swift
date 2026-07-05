//
//  BlockerInterventionTelemetryTests.swift
//  PillieTests
//
//  blocker_intervention_fired (#161 / ADR 0007) is the aha-moment signal:
//  aggregated on next app open, one event carrying the accumulated count.
//  Payload stays inside the Product Analytics Telemetry boundary — a coarse
//  count and the standard envelope; never app names or routine details.
//  Value-type + recorder style (no AnalyticsManager instance) per the hosted
//  XCTest @MainActor-deinit instability on the Xcode 27 beta.
//

import XCTest

@testable import Pillie

final class BlockerInterventionTelemetryTests: XCTestCase {

    func testBlockerInterventionFiredUsesApprovedEventName() {
        XCTAssertEqual(
            AnalyticsEvent.blockerInterventionFired.rawValue,
            "blocker_intervention_fired"
        )
    }

    func testBlockerInterventionPayloadCarriesAggregatedCountOnly() {
        let properties = AnalyticsPayload(isPlus: false, interventionCount: 4).properties

        XCTAssertEqual(Set(properties.keys), ["is_plus", "intervention_count"])
        XCTAssertEqual(properties["intervention_count"], .int(4))
        XCTAssertEqual(properties["is_plus"], .bool(false))
    }

    // Held for the whole process: deallocating any Swift class inside a hosted
    // test aborts on the Xcode 27 beta (@MainActor deinit crash) — the same
    // failure currently affecting ProductAnalyticsTelemetryPaywallTests.
    private static let recorder = InterventionAnalyticsRecorder()

    func testTelemetryReportsTheAccumulatedCountAsOneAggregatedEvent() {
        let recorder = Self.recorder
        let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { true })

        telemetry.blockerInterventionFired(count: 7)

        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertEqual(recorder.events.first?.event, .blockerInterventionFired)
        XCTAssertEqual(recorder.events.first?.interventionCount, 7)
        XCTAssertEqual(recorder.events.first?.isPlus, true)
    }
}

private final class InterventionAnalyticsRecorder: AnalyticsTracking {
    struct Event: Equatable {
        let event: AnalyticsEvent
        let interventionCount: Int?
        let isPlus: Bool?
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
        events.append(Event(event: event, interventionCount: interventionCount, isPlus: isPlus))
    }
}
