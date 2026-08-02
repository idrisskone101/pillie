//
//  ProductAnalyticsTelemetryPaywallTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class ProductAnalyticsTelemetryPaywallTests: XCTestCase {
    // Xcode 27 beta hosted-XCTest workaround: deallocating any @MainActor class
    // mid-invocation aborts in libmalloc (isolated-deinit back-deploy bug), which
    // crashed the host app once per test in this suite. Retain every class
    // instance a test creates for the process lifetime — same pattern as
    // OnboardingFunnelInstrumentationTests (#140).
    private static var keptObjects: [AnyObject] = []

    func testPaywallPlanSelectionCapturesOnlyApprovedCoarseValues() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.planSelection"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
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

    func testTrialStatusPaywallViewCarriesStableSurfaceContext() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.trialStatusSurface"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        let telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: { true })

        analytics.configure()
        telemetry.paywallViewed(surface: .trialStatus)

        XCTAssertEqual(client.events.count, 1)
        XCTAssertEqual(client.events.first?.name, "paywall_viewed")
        XCTAssertEqual(client.events.first?.properties["source"], .string("home"))
        XCTAssertEqual(client.events.first?.properties["surface"], .string("trial_status"))
        XCTAssertEqual(client.events.first?.properties["is_plus"], .bool(true))
        XCTAssertEqual(client.events.first?.properties.count, 3)
    }

    func testOrdinaryPaywallViewCarriesPostCutoverTrialTermsCohort() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.trialTermsCohort"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { false },
            trialTermsCohort: { .postCutover }
        )

        analytics.configure()
        telemetry.paywallViewed(surface: .trialStatus)

        XCTAssertEqual(
            client.events.first?.properties["trial_terms_cohort"],
            .string("post_cutover")
        )
    }

    func testOrdinaryPaywallPurchasesCarryPostCutoverTrialTermsCohort() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.purchaseTrialTermsCohort"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { false },
            trialTermsCohort: { .postCutover }
        )

        analytics.configure()
        telemetry.purchaseStarted(
            plan: .lifetime,
            isFromOnboarding: false,
            surface: .settingsSubscription
        )
        telemetry.purchaseCompleted(
            plan: .lifetime,
            isFromOnboarding: false,
            surface: .settingsSubscription
        )

        XCTAssertEqual(client.events.map(\.name), ["purchase_started", "purchase_completed"])
        XCTAssertEqual(
            client.events.map { $0.properties["trial_terms_cohort"] },
            [.string("post_cutover"), .string("post_cutover")]
        )
    }

    func testOrdinaryPaywallRestoreCarriesSurfaceAndPostCutoverCohort() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.restoreTrialTermsCohort"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { false },
            trialTermsCohort: { .postCutover }
        )

        analytics.configure()
        telemetry.restoreCompleted(
            isFromOnboarding: false,
            surface: .settingsSubscription
        )

        XCTAssertEqual(client.events.first?.name, "restore_completed")
        XCTAssertEqual(client.events.first?.properties["surface"], .string("settings_subscription"))
        XCTAssertEqual(
            client.events.first?.properties["trial_terms_cohort"],
            .string("post_cutover")
        )
    }

    func testTrialExpiredCarriesPostCutoverTrialTermsCohort() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.expiredTrialTermsCohort"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { false },
            trialTermsCohort: { .postCutover }
        )

        analytics.configure()
        telemetry.trialExpired()

        XCTAssertEqual(client.events.first?.name, "trial_expired")
        XCTAssertEqual(
            client.events.first?.properties["trial_terms_cohort"],
            .string("post_cutover")
        )
    }

    func testPaywallSurfaceTaxonomyUsesOnlyApprovedStableValues() {
        XCTAssertEqual(
            AnalyticsPaywallSurface.allCases.map(\.rawValue),
            [
                AnalyticsPaywallSurface.trialStatus,
                .settingsSubscription,
                .protectionOffCard,
                .homeBlockingCard,
                .trialEnd,
                .plusUpsell
            ].map(\.rawValue)
        )
    }

    func testPaywallFunnelCarriesSurfaceAndResolvesPlusAtCaptureTime() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.surfaceFunnel"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        var hasPlusAccess = false
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { hasPlusAccess }
        )

        analytics.configure()
        telemetry.paywallViewed(surface: .settingsSubscription)
        hasPlusAccess = true
        telemetry.paywallPlanSelected(
            plan: .annual,
            isFromOnboarding: false,
            surface: .settingsSubscription
        )
        telemetry.purchaseStarted(
            plan: .annual,
            isFromOnboarding: false,
            surface: .settingsSubscription
        )
        telemetry.purchaseCompleted(
            plan: .annual,
            isFromOnboarding: false,
            surface: .settingsSubscription
        )
        telemetry.purchaseCancelled(
            plan: .annual,
            isFromOnboarding: false,
            surface: .settingsSubscription
        )
        telemetry.continueFreeSelected(
            isFromOnboarding: false,
            surface: .settingsSubscription
        )

        XCTAssertEqual(client.events.map(\.name), [
            "paywall_viewed",
            "paywall_plan_selected",
            "purchase_started",
            "purchase_completed",
            "purchase_cancelled",
            "continue_free_selected"
        ])
        XCTAssertEqual(
            client.events.map { $0.properties["surface"] },
            Array(repeating: .string("settings_subscription"), count: 6)
        )
        XCTAssertEqual(
            client.events.map { $0.properties["source"] },
            Array(repeating: .string("settings"), count: 6)
        )
        XCTAssertEqual(
            client.events.map { $0.properties["is_plus"] },
            [.bool(false), .bool(true), .bool(true), .bool(true), .bool(true), .bool(true)]
        )
        XCTAssertEqual(client.events[1].properties["plan"], .string("annual"))
        XCTAssertEqual(client.events[3].properties["result"], .string("completed"))
        XCTAssertEqual(client.events[4].properties["result"], .string("cancelled"))
    }

    func testPlusUpsellActionsShareOneSurfaceContract() {
        let client = ProductAnalyticsSpy()
        let defaultsName = "ProductAnalyticsTelemetryPaywallTests.plusUpsell"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com"
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        let telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: { false })

        analytics.configure()
        telemetry.plusUpsellViewed()
        telemetry.plusUpsellUpgradeTapped()
        telemetry.plusUpsellDismissed()

        XCTAssertEqual(client.events.map(\.name), [
            "plus_upsell_viewed",
            "plus_upsell_upgrade_tapped",
            "plus_upsell_dismissed"
        ])
        for event in client.events {
            XCTAssertEqual(event.properties, [
                "source": .string("upsell"),
                "surface": .string("plus_upsell"),
                "is_plus": .bool(false)
            ])
        }
    }

    func testEveryPaywallSurfaceMapsToOneApprovedSource() {
        let recorder = AnalyticsRecorder()
        let telemetry = ProductAnalyticsTelemetry(analytics: recorder, isPlus: { true })

        let surfaces = AnalyticsPaywallSurface.allCases
        for surface in surfaces {
            telemetry.paywallViewed(surface: surface)
        }

        XCTAssertEqual(recorder.surfaceEvents.map { $0.surface }, surfaces)
        XCTAssertEqual(recorder.surfaceEvents.map { $0.source }, [
            .home,
            .settings,
            .home,
            .home,
            .trialEnd,
            .upsell
        ])
        XCTAssertEqual(recorder.surfaceEvents.map { $0.isPlus }, Array(repeating: true, count: 6))
    }

    func testAppLaunchReadsResolvedPlusAccessAtCaptureTime() {
        let recorder = AnalyticsRecorder()
        var hasPlusAccess = false
        let telemetry = ProductAnalyticsTelemetry(
            analytics: recorder,
            isPlus: { hasPlusAccess }
        )
        hasPlusAccess = true

        telemetry.appLaunched()

        XCTAssertEqual(recorder.events.map(\.event), [.appLaunched])
        XCTAssertEqual(recorder.events.first?.isPlus, true)
    }

    private func telemetry(_ analytics: AnalyticsRecorder, isPlus: Bool) -> ProductAnalyticsTelemetry {
        ProductAnalyticsTelemetry(analytics: analytics, isPlus: { isPlus })
    }
}

final class ProductAnalyticsSpy: ProductAnalyticsClient {
    struct Event: Equatable {
        let name: String
        let properties: [String: AnalyticsPropertyValue]
        let personProperties: [String: AnalyticsPropertyValue]
    }

    // Process-lifetime retention: see keptObjects on ProductAnalyticsTelemetryPaywallTests.
    private static var keepAlive: [ProductAnalyticsSpy] = []

    init() {
        Self.keepAlive.append(self)
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

    // Process-lifetime retention: see keptObjects on ProductAnalyticsTelemetryPaywallTests.
    private static var keepAlive: [AnalyticsRecorder] = []

    init() {
        Self.keepAlive.append(self)
    }

    private(set) var events: [Event] = []
    private(set) var surfaceEvents: [(
        source: AnalyticsSource?,
        surface: AnalyticsPaywallSurface?,
        isPlus: Bool?
    )] = []

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
        events.append(Event(event: event, source: source, step: step, plan: plan, result: result, isPlus: isPlus))
    }

    func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource?,
        surface: AnalyticsPaywallSurface?,
        plan: AnalyticsPlan?,
        result: AnalyticsResult?,
        isPlus: Bool?
    ) {
        events.append(Event(
            event: event,
            source: source,
            plan: plan,
            result: result,
            isPlus: isPlus
        ))
        surfaceEvents.append((source, surface, isPlus))
    }
}
