//
//  PaywallSubscriptionTelemetryTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class PaywallSubscriptionTelemetryTests: XCTestCase {
    func testPaywallPlanSelectionCapturesOnlyApprovedCoarseValues() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "PaywallSubscriptionTelemetryTests.planSelection"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let analytics = AnalyticsManager(
            defaults: UserDefaults(suiteName: defaultsName)!,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )

        analytics.configure()
        analytics.track(
            .paywallPlanSelected,
            source: .onboarding,
            step: .paywall,
            plan: .annual,
            isPlus: false
        )

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "paywall_plan_selected")
        XCTAssertEqual(client.events.first?.properties["source"], .string("onboarding"))
        XCTAssertEqual(client.events.first?.properties["step"], .string("paywall"))
        XCTAssertEqual(client.events.first?.properties["plan"], .string("annual"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(false))
        XCTAssertEqual(client.events.first?.properties.count, 4)
        XCTAssertNotNil(client.events.first?.properties["source"])
        XCTAssertNotNil(client.events.first?.properties["step"])
        XCTAssertNotNil(client.events.first?.properties["plan"])
        XCTAssertNotNil(client.events.first?.properties["is_plus"])
    }

    func testPurchaseAndRestoreOutcomesCaptureApprovedResults() {
        let recorder = AnalyticsRecorder()
        let telemetry = PaywallSubscriptionTelemetry(analytics: recorder)

        telemetry.purchaseStarted(source: .onboarding, plan: .monthly, isPlus: false)
        telemetry.purchaseCompleted(source: .onboarding, plan: .monthly, isPlus: true)
        telemetry.purchaseFailed(source: .onboarding, plan: .monthly, isPlus: false)
        telemetry.purchaseCancelled(source: .onboarding, plan: .monthly, isPlus: false)
        telemetry.restoreStarted(source: .upsell, isPlus: false)
        telemetry.restoreCompleted(source: .upsell, isPlus: true)
        telemetry.restoreFailed(source: .upsell, isPlus: false)

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
        let telemetry = PaywallSubscriptionTelemetry(analytics: recorder)

        telemetry.paywallViewed(source: .onboarding, isFromOnboarding: true, isPlus: false)
        telemetry.paywallViewed(source: .settings, isFromOnboarding: false, isPlus: true)
        telemetry.continueFreeSelected(source: .onboarding, isFromOnboarding: true, isPlus: false)
        telemetry.plusUpsellViewed(isPlus: false)
        telemetry.plusUpsellDismissed(isPlus: false)
        telemetry.plusUpsellUpgradeTapped(isPlus: false)

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
}

private final class ProductAnalyticsSpy: ProductAnalyticsClient {
    struct Event: Equatable {
        let name: String
        let properties: [String: AnalyticsPropertyValue]
    }

    private(set) var configurations: [ProductAnalyticsConfiguration] = []
    private(set) var events: [Event] = []
    private(set) var optOutStates: [Bool] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {
        configurations.append(configuration)
    }

    func setOptedOut(_ isOptedOut: Bool) {
        optOutStates.append(isOptedOut)
    }

    func capture(event: String, properties: [String: AnalyticsPropertyValue]) {
        events.append(Event(name: event, properties: properties))
    }
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
        screen: AnalyticsScreen?,
        plan: AnalyticsPlan?,
        result: AnalyticsResult?,
        setting: AnalyticsSetting?,
        isPlus: Bool?,
        hasBlockingSelection: Bool?
    ) {
        events.append(Event(event: event, source: source, step: step, plan: plan, result: result, isPlus: isPlus))
    }
}
