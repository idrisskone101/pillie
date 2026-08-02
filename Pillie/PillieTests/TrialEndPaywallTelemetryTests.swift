//
//  TrialEndPaywallTelemetryTests.swift
//  PillieTests
//
//  The Trial-End Paywall's funnel events (issue #169 / ADR 0007):
//  `paywall_viewed` with `source: trial_end` plus the cohort property, and the
//  purchase/restore funnel attributed to the same source. Client-level spy so
//  the exact wire payload (names + coarse values, nothing else) is pinned.
//

import XCTest

@testable import Pillie

final class TrialEndPaywallTelemetryTests: XCTestCase {
    private static var keptObjects: [AnyObject] = []

    func testTrialEndPaywallViewedCarriesTrialEndSourceAndCohort() {
        let (telemetry, client) = makeTelemetry(name: "viewed")

        telemetry.trialEndPaywallViewed(cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndPaywallViewed(cohort: .reminderOnly, terms: .legacy)

        XCTAssertEqual(client.events.map(\.name), ["paywall_viewed", "paywall_viewed"])
        XCTAssertEqual(client.events[0].properties["source"], .string("trial_end"))
        XCTAssertEqual(client.events[0].properties["surface"], .string("trial_end"))
        XCTAssertEqual(client.events[0].properties["cohort"], .string("post_cutover"))
        XCTAssertEqual(client.events[1].properties["cohort"], .string("pre_cutover"))
        XCTAssertEqual(
            client.events[0].properties["paywall_variant"],
            .string("blocker_configured")
        )
        XCTAssertEqual(client.events[1].properties["paywall_variant"], .string("reminder_only"))
        // Only approved coarse values: source, surface, cohort, variant, is_plus.
        XCTAssertEqual(client.events[0].properties.count, 5)
    }

    func testTrialEndPurchaseFunnelIsAttributedToTrialEndSource() {
        let (telemetry, client) = makeTelemetry(name: "funnel")

        telemetry.trialEndPlanSelected(plan: .annual, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndPurchaseStarted(plan: .annual, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndPurchaseCompleted(plan: .annual, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndPurchaseFailed(plan: .monthly, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndPurchaseCancelled(plan: .monthly, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndRestoreStarted(cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndRestoreCompleted(cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndRestoreFailed(cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndContinueFreeSelected(cohort: .reminderOnly, terms: .legacy)

        XCTAssertEqual(client.events.map(\.name), [
            "paywall_plan_selected",
            "purchase_started",
            "purchase_completed",
            "purchase_failed",
            "purchase_cancelled",
            "restore_started",
            "restore_completed",
            "restore_failed",
            "continue_free_selected",
        ])
        for event in client.events {
            XCTAssertEqual(event.properties["source"], .string("trial_end"), event.name)
            XCTAssertEqual(event.properties["surface"], .string("trial_end"), event.name)
        }
        for event in client.events.dropLast() {
            XCTAssertEqual(event.properties["cohort"], .string("post_cutover"), event.name)
            XCTAssertEqual(
                event.properties["paywall_variant"],
                .string("blocker_configured"),
                event.name
            )
        }
        XCTAssertEqual(client.events.last?.properties["cohort"], .string("pre_cutover"))
        XCTAssertEqual(client.events[2].properties["plan"], .string("annual"))
        XCTAssertEqual(client.events[2].properties["result"], .string("completed"))
    }

    func testTrialDeclineFeedbackSkipEmitsOnlyApprovedWirePayloads() {
        let events: [TrialDeclineFeedbackTelemetryEvent] = [
            .viewed,
            .skipped,
            .completedSkipped,
        ]

        XCTAssertEqual(events.map(\.analyticsEvent.rawValue), [
            "trial_decline_feedback_viewed",
            "trial_decline_feedback_skipped",
            "trial_decline_feedback_completed",
        ])
        let properties = events.map { $0.payload(isPlus: false).properties }
        for payload in properties {
            XCTAssertEqual(payload["source"], .string("trial_end"))
            XCTAssertEqual(payload["is_plus"], .bool(false))
        }
        XCTAssertEqual(properties[0].count, 2)
        XCTAssertEqual(properties[1].count, 2)
        XCTAssertEqual(properties[2], [
            "source": .string("trial_end"),
            "is_plus": .bool(false),
            "outcome": .string("skipped"),
        ])
    }

    func testSubmittedDeclineReasonEmitsOnlyClosedPrivacySafeWirePayloads() {
        let events: [TrialDeclineFeedbackTelemetryEvent] = [
            .reasonSelected(.tooExpensive),
            .completedSubmitted(
                TrialDeclineFeedbackSubmission(reason: .tooExpensive, hasText: false)
            ),
        ]

        XCTAssertEqual(events.map(\.analyticsEvent.rawValue), [
            "trial_decline_feedback_reason_selected",
            "trial_decline_feedback_completed",
        ])
        XCTAssertEqual(events[0].payload(isPlus: false).properties, [
            "source": .string("trial_end"),
            "is_plus": .bool(false),
            "reason": .string("too_expensive"),
        ])
        XCTAssertEqual(events[1].payload(isPlus: false).properties, [
            "source": .string("trial_end"),
            "is_plus": .bool(false),
            "outcome": .string("submitted"),
            "reason": .string("too_expensive"),
            "has_text": .bool(false),
        ])
    }

    func testOptionalDetailSubmissionEmitsOnlyClosedPresenceMetadata() {
        let event = TrialDeclineFeedbackTelemetryEvent.textSubmitted(.missingFeature)

        XCTAssertEqual(
            event.analyticsEvent.rawValue,
            "trial_decline_feedback_text_submitted"
        )
        XCTAssertEqual(event.payload(isPlus: false).properties, [
            "source": .string("trial_end"),
            "is_plus": .bool(false),
            "reason": .string("missing_feature"),
            "has_text": .bool(true),
        ])
    }

    func testCompletedSubmissionCarriesOnlyClosedReasonAndPresenceMetadata() {
        let event = TrialDeclineFeedbackTelemetryEvent.completedSubmitted(
            TrialDeclineFeedbackSubmission(reason: .other, hasText: true)
        )

        XCTAssertEqual(event.payload(isPlus: false).properties, [
            "source": .string("trial_end"),
            "is_plus": .bool(false),
            "outcome": .string("submitted"),
            "reason": .string("other"),
            "has_text": .bool(true),
        ])
    }

    func testSubmittedDeclineJourneyCapturesSelectionThenOneTerminalCompletion() {
        let recorder = TrialDeclineFeedbackAnalyticsRecorder()
        let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { false })

        telemetry.trialDeclineFeedbackReasonSelected(.missingFeature)
        telemetry.trialDeclineFeedbackSubmitted(.missingFeature)

        XCTAssertEqual(recorder.events, [
            .init(
                event: .trialDeclineFeedbackReasonSelected,
                outcome: nil,
                reason: .missingFeature,
                hasText: nil,
                isPlus: false
            ),
            .init(
                event: .trialDeclineFeedbackCompleted,
                outcome: .submitted,
                reason: .missingFeature,
                hasText: false,
                isPlus: false
            ),
        ])
    }

    func testSubmittedOptionalDetailJourneyCapturesPresenceThenOneTerminalCompletion() {
        let recorder = TrialDeclineFeedbackAnalyticsRecorder()
        let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { false })
        let submission = TrialDeclineFeedbackSubmission(
            reason: .missingFeature,
            hasText: true
        )

        telemetry.trialDeclineFeedbackSubmitted(submission)

        XCTAssertEqual(recorder.events, [
            .init(
                event: .trialDeclineFeedbackTextSubmitted,
                outcome: nil,
                reason: .missingFeature,
                hasText: true,
                isPlus: false
            ),
            .init(
                event: .trialDeclineFeedbackCompleted,
                outcome: .submitted,
                reason: .missingFeature,
                hasText: true,
                isPlus: false
            ),
        ])
    }

    private func makeTelemetry(
        name: String
    ) -> (ProductAnalyticsTelemetry, TrialEndAnalyticsClientSpy) {
        let client = TrialEndAnalyticsClientSpy()
        let defaultsName = "TrialEndPaywallTelemetryTests.\(name)"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(client)
        Self.keptObjects.append(analytics)
        analytics.configure()
        return (ProductAnalyticsTelemetry(analytics: analytics, isPlus: { false }), client)
    }
}

private final class TrialDeclineFeedbackAnalyticsRecorder: AnalyticsTracking {
    // Xcode 27's hosted XCTest runner can crash while tearing down class test
    // doubles. Keep the recorder alive for the process, matching the existing
    // analytics-test seam elsewhere in this target.
    private static var keepAlive: [TrialDeclineFeedbackAnalyticsRecorder] = []

    struct Event: Equatable {
        let event: AnalyticsEvent
        let outcome: AnalyticsTrialDeclineFeedbackOutcome?
        let reason: TrialDeclineFeedbackReason?
        let hasText: Bool?
        let isPlus: Bool?
    }

    private(set) var events: [Event] = []

    init() {
        Self.keepAlive.append(self)
    }

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
    ) {}

    func track(
        _ event: AnalyticsEvent,
        declineFeedbackOutcome: AnalyticsTrialDeclineFeedbackOutcome?,
        declineFeedbackReason: TrialDeclineFeedbackReason?,
        declineFeedbackHasText: Bool?,
        isPlus: Bool?
    ) {
        events.append(Event(
            event: event,
            outcome: declineFeedbackOutcome,
            reason: declineFeedbackReason,
            hasText: declineFeedbackHasText,
            isPlus: isPlus
        ))
    }
}

private final class TrialEndAnalyticsClientSpy: ProductAnalyticsClient {
    struct Event: Equatable {
        let name: String
        let properties: [String: AnalyticsPropertyValue]
    }

    private(set) var events: [Event] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {}

    func capture(
        event: String,
        properties: [String: AnalyticsPropertyValue],
        personProperties: [String: AnalyticsPropertyValue]
    ) {
        events.append(Event(name: event, properties: properties))
    }

    func distinctId() -> String? { nil }

    func flush() {}
}
