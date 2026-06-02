//
//  AnalyticsManagerPrivacyTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class AnalyticsManagerPrivacyTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "AnalyticsManagerPrivacyTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testDisablingUsageAnalyticsPersistsOptOutWhenAnalyticsIsUnconfigured() {
        let client = AnalyticsClientSpy()
        let manager = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": " "
            ]
        )

        manager.configure()
        manager.setAnalyticsEnabled(false)

        XCTAssertTrue(defaults.bool(forKey: AnalyticsManager.analyticsOptOutKey))
        XCTAssertFalse(manager.isAnalyticsEnabled)
        XCTAssertEqual(client.optOutChanges, [])
    }

    func testUsageAnalyticsToggleCallsConfiguredOptOutAndOptInPathsAcrossLaunches() {
        let client = AnalyticsClientSpy()
        let manager = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: analyticsInfoDictionary
        )

        manager.configure()
        manager.setAnalyticsEnabled(false)

        XCTAssertEqual(client.configureOptOutValues, [false])
        XCTAssertEqual(client.optOutChanges, [true])
        XCTAssertTrue(defaults.bool(forKey: AnalyticsManager.analyticsOptOutKey))

        let relaunchClient = AnalyticsClientSpy()
        let relaunchManager = AnalyticsManager(
            defaults: defaults,
            client: relaunchClient,
            infoDictionary: analyticsInfoDictionary
        )

        relaunchManager.configure()
        relaunchManager.setAnalyticsEnabled(true)

        XCTAssertEqual(relaunchClient.configureOptOutValues, [true])
        XCTAssertEqual(relaunchClient.optOutChanges, [false])
        XCTAssertFalse(defaults.bool(forKey: AnalyticsManager.analyticsOptOutKey))
    }

    private var analyticsInfoDictionary: [String: Any] {
        [
            "PostHogProjectToken": "test-token",
            "PostHogHost": "https://example.com"
        ]
    }
}

private final class AnalyticsClientSpy: ProductAnalyticsClient {
    private(set) var configureOptOutValues: [Bool] = []
    private(set) var optOutChanges: [Bool] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {
        configureOptOutValues.append(configuration.isOptedOut)
    }

    func setOptedOut(_ isOptedOut: Bool) {
        optOutChanges.append(isOptedOut)
    }

    func capture(event: String, properties: [String: AnalyticsPropertyValue]) {}

    func flush() {}
}
