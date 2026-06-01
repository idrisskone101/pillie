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
