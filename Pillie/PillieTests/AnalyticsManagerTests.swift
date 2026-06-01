//
//  AnalyticsManagerTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class AnalyticsManagerTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "AnalyticsManagerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testBlankProjectTokenLeavesAnalyticsUnconfiguredAndCaptureNoOps() {
        let client = RecordingAnalyticsClient()
        let manager = makeManager(client: client, token: "   ")

        manager.configure()
        manager.track(.appLaunched, source: .home, isPlus: false)

        XCTAssertTrue(client.configurations.isEmpty)
        XCTAssertTrue(client.captures.isEmpty)
    }

    func testConfiguredAnalyticsDisablesAutomaticPostHogCaptureFeatures() throws {
        let client = RecordingAnalyticsClient()
        let manager = makeManager(client: client, token: "phc_test_token")

        manager.configure()

        let configuration = try XCTUnwrap(client.configurations.first)
        XCTAssertEqual(configuration.projectToken, "phc_test_token")
        XCTAssertEqual(configuration.host, "https://us.i.posthog.com")
        XCTAssertFalse(configuration.captureApplicationLifecycleEvents)
        XCTAssertFalse(configuration.captureScreenViews)
        XCTAssertFalse(configuration.captureElementInteractions)
        XCTAssertFalse(configuration.enableSwizzling)
        XCTAssertFalse(configuration.sendFeatureFlagEvent)
        XCTAssertFalse(configuration.preloadFeatureFlags)
        XCTAssertFalse(configuration.setDefaultPersonProperties)
        XCTAssertFalse(configuration.sessionReplay)
        XCTAssertFalse(configuration.surveys)
        XCTAssertFalse(configuration.isOptedOut)
    }

    func testCaptureUsesTypedAllowedLowCardinalityProperties() throws {
        let client = RecordingAnalyticsClient()
        let manager = makeManager(client: client, token: "phc_test_token")

        manager.configure()
        manager.track(
            .settingsChangeSaved,
            source: .settings,
            step: .reminderTime,
            screen: .settings,
            plan: .annual,
            result: .completed,
            setting: .reminderTime,
            isPlus: true,
            hasBlockingSelection: false
        )

        let capture = try XCTUnwrap(client.captures.first)
        XCTAssertEqual(capture.event, "settings_change_saved")
        XCTAssertEqual(capture.properties, [
            "source": .string("settings"),
            "step": .string("reminder_time"),
            "screen": .string("settings"),
            "plan": .string("annual"),
            "result": .string("completed"),
            "setting": .string("reminder_time"),
            "is_plus": .bool(true),
            "has_blocking_selection": .bool(false)
        ])
    }

    func testOnboardingPermissionTelemetryUsesApprovedCoarsePropertiesOnly() {
        let client = RecordingAnalyticsClient()
        let manager = makeManager(client: client, token: "phc_test_token")

        manager.configure()
        manager.track(.onboardingStepViewed, source: .onboarding, step: .welcome, isPlus: false)
        manager.track(.onboardingStepCompleted, source: .onboarding, step: .reminderTime, isPlus: false)
        manager.track(.onboardingBackTapped, source: .onboarding, step: .method, isPlus: false)
        manager.track(.onboardingCompleted, source: .onboarding, isPlus: false)
        manager.track(.notificationPermissionRequested, source: .onboarding, step: .reminderTime, isPlus: false)
        manager.track(.screenTimePermissionRequested, source: .onboarding, step: .appBlocking, isPlus: true)
        manager.track(.screenTimePermissionCompleted, source: .onboarding, step: .appBlocking, result: .granted, isPlus: true)
        manager.track(.screenTimePermissionCompleted, source: .onboarding, step: .appBlocking, result: .denied, isPlus: true)

        XCTAssertEqual(client.captures.map(\.event), [
            "onboarding_step_viewed",
            "onboarding_step_completed",
            "onboarding_back_tapped",
            "onboarding_completed",
            "notification_permission_requested",
            "screen_time_permission_requested",
            "screen_time_permission_completed",
            "screen_time_permission_completed"
        ])
        XCTAssertEqual(client.captures.map(\.properties), [
            ["source": .string("onboarding"), "step": .string("welcome"), "is_plus": .bool(false)],
            ["source": .string("onboarding"), "step": .string("reminder_time"), "is_plus": .bool(false)],
            ["source": .string("onboarding"), "step": .string("method"), "is_plus": .bool(false)],
            ["source": .string("onboarding"), "is_plus": .bool(false)],
            ["source": .string("onboarding"), "step": .string("reminder_time"), "is_plus": .bool(false)],
            ["source": .string("onboarding"), "step": .string("app_blocking"), "is_plus": .bool(true)],
            ["source": .string("onboarding"), "step": .string("app_blocking"), "result": .string("granted"), "is_plus": .bool(true)],
            ["source": .string("onboarding"), "step": .string("app_blocking"), "result": .string("denied"), "is_plus": .bool(true)]
        ])
    }

    func testOptOutStopsFutureCaptureAndCanOptBackIn() {
        let client = RecordingAnalyticsClient()
        let manager = makeManager(client: client, token: "phc_test_token")

        manager.configure()
        manager.setAnalyticsEnabled(false)
        manager.track(.appBecameActive, source: .home)
        manager.setAnalyticsEnabled(true)
        manager.track(.appBecameActive, source: .home)

        XCTAssertEqual(client.optOutChanges, [true, false])
        XCTAssertEqual(client.captures.map(\.event), ["app_became_active"])
    }

    private func makeManager(
        client: RecordingAnalyticsClient,
        token: String,
        host: String = "https://us.i.posthog.com"
    ) -> AnalyticsManager {
        AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": token,
                "PostHogHost": host
            ]
        )
    }
}

private final class RecordingAnalyticsClient: ProductAnalyticsClient {
    private(set) var configurations: [ProductAnalyticsConfiguration] = []
    private(set) var optOutChanges: [Bool] = []
    private(set) var captures: [(event: String, properties: [String: AnalyticsPropertyValue])] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {
        configurations.append(configuration)
    }

    func setOptedOut(_ isOptedOut: Bool) {
        optOutChanges.append(isOptedOut)
    }

    func capture(event: String, properties: [String: AnalyticsPropertyValue]) {
        captures.append((event, properties))
    }
}
