//
//  ReverseTrialAnalyticsTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class ReverseTrialAnalyticsTests: XCTestCase {
    private static var keptObjects: [AnyObject] = []

    func testTrialBadgeTapEmitsDedicatedCoarseEvent() {
        let (telemetry, client) = makeTelemetry()

        telemetry.trialBadgeTapped()

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "trial_badge_tapped")
        XCTAssertEqual(client.events.first?.properties["source"], .string("home"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 2)
    }

    func testTrialStatusSheetExposureEmitsDedicatedEvent() {
        let (telemetry, client) = makeTelemetry()

        telemetry.trialStatusSheetViewed()

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "trial_status_sheet_viewed")
        XCTAssertEqual(client.events.first?.properties["source"], .string("home"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 2)
    }

    func testTrialStatusFeatureTapCarriesOnlyStableFeatureValue() {
        let (telemetry, client) = makeTelemetry()

        telemetry.trialStatusFeatureTapped(.smartReminders)

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "trial_status_feature_tapped")
        XCTAssertEqual(client.events.first?.properties["source"], .string("home"))
        XCTAssertEqual(client.events.first?.properties["feature"], .string("smart_reminders"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 3)
        XCTAssertEqual(
            AnalyticsTrialStatusFeature.allCases.map(\.rawValue),
            ["app_blocking", "shake_to_confirm", "smart_reminders", "custom_messages"]
        )
    }

    func testBlockerSetupSkipCarriesAuthorizationStateWithoutSelectionData() {
        let (telemetry, client) = makeTelemetry()

        telemetry.blockerSetupSkipped(authorizationState: .denied)

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "blocker_setup_skipped")
        XCTAssertEqual(client.events.first?.properties["source"], .string("onboarding"))
        XCTAssertEqual(client.events.first?.properties["step"], .string("app_blocking"))
        XCTAssertEqual(client.events.first?.properties["authorization_state"], .string("denied"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties["app_version"], .string("9.9"))
        XCTAssertEqual(client.events.first?.properties["app_build"], .string("999"))
        XCTAssertNotNil(client.events.first?.properties["session_id"])
        XCTAssertEqual(client.events.first?.properties.count, 7)
        XCTAssertEqual(
            AnalyticsAuthorizationState.allCases.map(\.rawValue),
            ["not_requested", "denied", "authorized"]
        )
    }

    func testSmartReminderRetrySchedulingCarriesOnlyAggregateCount() {
        let (telemetry, client) = makeTelemetry()

        telemetry.smartReminderRetryScheduled(count: 3)

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "smart_reminder_retry_scheduled")
        XCTAssertEqual(client.events.first?.properties["retry_count"], .int(3))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 2)
    }

    func testSmartReminderRetryFireEmitsDedicatedContentFreeEvent() {
        let (telemetry, client) = makeTelemetry()

        telemetry.smartReminderRetryFired()

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "smart_reminder_retry_fired")
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 1)
    }

    func testSmartReminderOutcomeCarriesOnlyApprovedStableEnum() {
        let (telemetry, client) = makeTelemetry()

        telemetry.smartReminderOutcome(.completed)

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "smart_reminder_outcome")
        XCTAssertEqual(client.events.first?.properties["outcome"], .string("completed"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 2)
        XCTAssertEqual(
            AnalyticsSmartReminderOutcome.allCases.map(\.rawValue),
            ["opened", "completed", "snoozed"]
        )
    }

    func testRetryFireDecisionDeduplicatesByRequestAndIgnoresOtherNotifications() {
        XCTAssertTrue(SmartReminderDelivery.shouldRecordFire(
            requestIdentifier: "retry-1",
            requestKind: "retry",
            alreadyRecordedRequestIdentifiers: []
        ))
        XCTAssertFalse(SmartReminderDelivery.shouldRecordFire(
            requestIdentifier: "retry-1",
            requestKind: "retry",
            alreadyRecordedRequestIdentifiers: ["retry-1"]
        ))
        XCTAssertFalse(SmartReminderDelivery.shouldRecordFire(
            requestIdentifier: "base-1",
            requestKind: "base",
            alreadyRecordedRequestIdentifiers: []
        ))
    }

    func testRetryResponseMapsOnlySupportedActionsToStableOutcomes() {
        XCTAssertEqual(
            SmartReminderDelivery.outcome(
                requestKind: "retry",
                actionIdentifier: "mark",
                markTakenActionIdentifier: "mark",
                snoozeActionIdentifier: "snooze",
                defaultActionIdentifier: "open"
            ),
            .completed
        )
        XCTAssertEqual(
            SmartReminderDelivery.outcome(
                requestKind: "retry",
                actionIdentifier: "snooze",
                markTakenActionIdentifier: "mark",
                snoozeActionIdentifier: "snooze",
                defaultActionIdentifier: "open"
            ),
            .snoozed
        )
        XCTAssertEqual(
            SmartReminderDelivery.outcome(
                requestKind: "retry",
                actionIdentifier: "open",
                markTakenActionIdentifier: "mark",
                snoozeActionIdentifier: "snooze",
                defaultActionIdentifier: "open"
            ),
            .opened
        )
        XCTAssertNil(
            SmartReminderDelivery.outcome(
                requestKind: "base",
                actionIdentifier: "mark",
                markTakenActionIdentifier: "mark",
                snoozeActionIdentifier: "snooze",
                defaultActionIdentifier: "open"
            )
        )
    }

    private func makeTelemetry() -> (ProductAnalyticsTelemetry, ProductAnalyticsSpy) {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ReverseTrialAnalyticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
                "CFBundleShortVersionString": "9.9",
                "CFBundleVersion": "999"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        analytics.configure()
        return (ProductAnalyticsTelemetry(analytics: analytics, isPlus: { true }), client)
    }
}
