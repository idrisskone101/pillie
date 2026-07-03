//
//  ProductAnalyticsTelemetryPaywallTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class ProductAnalyticsTelemetryPaywallTests: XCTestCase {
    func testPaywallPlanSelectionCapturesOnlyApprovedCoarseValues() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.planSelection"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let analytics = AnalyticsManager(
            defaults: UserDefaults(suiteName: defaultsName)!,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        let telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: { false })

        analytics.configure()
        telemetry.paywallPlanSelected(plan: .annual, isFromOnboarding: true)

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "paywall_plan_selected")
        XCTAssertEqual(client.events.first?.properties["source"], .string("onboarding"))
        XCTAssertEqual(client.events.first?.properties["plan"], .string("annual"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(false))
        XCTAssertEqual(client.events.first?.properties.count, 3)
        XCTAssertNotNil(client.events.first?.properties["source"])
        XCTAssertNotNil(client.events.first?.properties["plan"])
        XCTAssertNotNil(client.events.first?.properties["is_plus"])
    }

    func testPurchaseAndRestoreOutcomesCaptureApprovedResults() {
        let recorder = AnalyticsRecorder()

        telemetry(recorder, isPlus: false).purchaseStarted(plan: .monthly, isFromOnboarding: true)
        telemetry(recorder, isPlus: true).purchaseCompleted(plan: .monthly, isFromOnboarding: true)
        telemetry(recorder, isPlus: false).purchaseFailed(plan: .monthly, isFromOnboarding: true)
        telemetry(recorder, isPlus: false).purchaseCancelled(plan: .monthly, isFromOnboarding: true)
        telemetry(recorder, isPlus: false).upsellRestoreStarted()
        telemetry(recorder, isPlus: true).upsellRestoreCompleted()
        telemetry(recorder, isPlus: false).upsellRestoreFailed()

        XCTAssertEqual(recorder.events.map(\.event), [
            .purchaseStarted,
            .purchaseCompleted,
            .purchaseFailed,
            .purchaseCancelled,
            .restoreStarted,
            .restoreCompleted,
            .restoreFailed
        ])
        XCTAssertEqual(recorder.events.map(\.source), [.onboarding, .onboarding, .onboarding, .onboarding, .upsell, .upsell, .upsell])
        XCTAssertEqual(recorder.events.map(\.plan), [.monthly, .monthly, .monthly, .monthly, nil, nil, nil])
        XCTAssertEqual(recorder.events.map(\.result), [nil, .completed, .failed, .cancelled, nil, .completed, .failed])
        XCTAssertEqual(recorder.events.map(\.isPlus), [false, true, false, false, false, true, false])
    }

    func testPaywallContinueFreeAndUpsellActionsCaptureApprovedContext() {
        let recorder = AnalyticsRecorder()

        telemetry(recorder, isPlus: false).paywallViewed(isFromOnboarding: true)
        telemetry(recorder, isPlus: true).paywallViewed(isFromOnboarding: false)
        telemetry(recorder, isPlus: false).continueFreeSelected(isFromOnboarding: true)
        telemetry(recorder, isPlus: false).plusUpsellViewed()
        telemetry(recorder, isPlus: false).plusUpsellDismissed()
        telemetry(recorder, isPlus: false).plusUpsellUpgradeTapped()

        XCTAssertEqual(recorder.events.map(\.event), [
            .paywallViewed,
            .paywallViewed,
            .continueFreeSelected,
            .plusUpsellViewed,
            .plusUpsellDismissed,
            .plusUpsellUpgradeTapped
        ])
        XCTAssertEqual(recorder.events.map(\.source), [.onboarding, .settings, .onboarding, .upsell, .upsell, .upsell])
        XCTAssertEqual(recorder.events.map(\.step), [.paywall, nil, .paywall, nil, nil, nil])
        XCTAssertEqual(recorder.events.map(\.isPlus), [false, true, false, false, false, false])
    }

    private func telemetry(_ analytics: AnalyticsRecorder, isPlus: Bool) -> ProductAnalyticsTelemetry {
        ProductAnalyticsTelemetry(analytics: analytics, isPlus: { isPlus })
    }
}

private final class ProductAnalyticsSpy: ProductAnalyticsClient {
    struct Event: Equatable {
        let name: String
        let properties: [String: AnalyticsPropertyValue]
        let personProperties: [String: AnalyticsPropertyValue]
    }

    private(set) var configurations: [ProductAnalyticsConfiguration] = []
    private(set) var events: [Event] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {
        configurations.append(configuration)
    }

    func capture(
        event: String,
        properties: [String: AnalyticsPropertyValue],
        personProperties: [String: AnalyticsPropertyValue]
    ) {
        events.append(Event(name: event, properties: properties, personProperties: personProperties))
    }

    func distinctId() -> String? { nil }

    func flush() {}
}

private final class AnalyticsRecorder: AnalyticsTracking {
    struct Event: Equatable {
        let event: AnalyticsEvent
        let source: AnalyticsSource?
        let step: AnalyticsStep?
        let plan: AnalyticsPlan?
        let result: AnalyticsResult?
        let isPlus: Bool?

        init(
            event: AnalyticsEvent,
            source: AnalyticsSource?,
            step: AnalyticsStep? = nil,
            plan: AnalyticsPlan?,
            result: AnalyticsResult?,
            isPlus: Bool?
        ) {
            self.event = event
            self.source = source
            self.step = step
            self.plan = plan
            self.result = result
            self.isPlus = isPlus
        }
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
        titleCustomized: Bool?,
        bodyCustomized: Bool?,
        retryTitleCustomized: Bool?,
        retryBodyCustomized: Bool?,
        lastCallTitleCustomized: Bool?,
        lastCallBodyCustomized: Bool?
    ) {
        events.append(Event(event: event, source: source, step: step, plan: plan, result: result, isPlus: isPlus))
    }
}
