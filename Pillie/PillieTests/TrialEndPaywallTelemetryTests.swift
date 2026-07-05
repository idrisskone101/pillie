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

    func testTrialEndPaywallViewedCarriesTrialEndSourceAndCohort() {
        let (telemetry, client) = makeTelemetry(name: "viewed")

        telemetry.trialEndPaywallViewed(cohort: .blockerConfigured)
        telemetry.trialEndPaywallViewed(cohort: .reminderOnly)

        XCTAssertEqual(client.events.map(\.name), ["paywall_viewed", "paywall_viewed"])
        XCTAssertEqual(client.events[0].properties["source"], .string("trial_end"))
        XCTAssertEqual(client.events[0].properties["cohort"], .string("blocker_configured"))
        XCTAssertEqual(client.events[1].properties["cohort"], .string("reminder_only"))
        // Only the approved coarse values: source, cohort, is_plus.
        XCTAssertEqual(client.events[0].properties.count, 3)
    }

    func testTrialEndPurchaseFunnelIsAttributedToTrialEndSource() {
        let (telemetry, client) = makeTelemetry(name: "funnel")

        telemetry.trialEndPlanSelected(plan: .annual)
        telemetry.trialEndPurchaseStarted(plan: .annual)
        telemetry.trialEndPurchaseCompleted(plan: .annual)
        telemetry.trialEndPurchaseFailed(plan: .monthly)
        telemetry.trialEndPurchaseCancelled(plan: .monthly)
        telemetry.trialEndRestoreStarted()
        telemetry.trialEndRestoreCompleted()
        telemetry.trialEndRestoreFailed()
        telemetry.trialEndNotNowSelected()

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
        }
        XCTAssertEqual(client.events[2].properties["plan"], .string("annual"))
        XCTAssertEqual(client.events[2].properties["result"], .string("completed"))
    }

    private func makeTelemetry(
        name: String
    ) -> (ProductAnalyticsTelemetry, TrialEndAnalyticsClientSpy) {
        let client = TrialEndAnalyticsClientSpy()
        let defaultsName = "TrialEndPaywallTelemetryTests.\(name)"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let analytics = AnalyticsManager(
            defaults: UserDefaults(suiteName: defaultsName)!,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
            ]
        )
        analytics.configure()
        return (ProductAnalyticsTelemetry(analytics: analytics, isPlus: { false }), client)
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
