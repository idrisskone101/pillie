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
            configurationProvider: { nil }
        )

        manager.configure()
        manager.setAnalyticsEnabled(false)

        XCTAssertTrue(defaults.bool(forKey: AnalyticsManager.analyticsOptOutKey))
        XCTAssertFalse(manager.isAnalyticsEnabled)
        XCTAssertEqual(client.optOutCallCount, 0)
    }

    func testUsageAnalyticsToggleCallsConfiguredOptOutAndOptInPathsAcrossLaunches() {
        let client = AnalyticsClientSpy()
        let manager = AnalyticsManager(
            defaults: defaults,
            client: client,
            configurationProvider: {
                AnalyticsConfiguration(projectToken: "test-token", host: "https://example.com")
            }
        )

        manager.configure()
        manager.setAnalyticsEnabled(false)

        XCTAssertEqual(client.configureOptOutValues, [false])
        XCTAssertEqual(client.optOutCallCount, 1)
        XCTAssertEqual(client.optInCallCount, 0)
        XCTAssertTrue(defaults.bool(forKey: AnalyticsManager.analyticsOptOutKey))

        let relaunchClient = AnalyticsClientSpy()
        let relaunchManager = AnalyticsManager(
            defaults: defaults,
            client: relaunchClient,
            configurationProvider: {
                AnalyticsConfiguration(projectToken: "test-token", host: "https://example.com")
            }
        )

        relaunchManager.configure()
        relaunchManager.setAnalyticsEnabled(true)

        XCTAssertEqual(relaunchClient.configureOptOutValues, [true])
        XCTAssertEqual(relaunchClient.optInCallCount, 1)
        XCTAssertEqual(relaunchClient.optOutCallCount, 0)
        XCTAssertFalse(defaults.bool(forKey: AnalyticsManager.analyticsOptOutKey))
    }
}

private final class AnalyticsClientSpy: AnalyticsClient {
    private(set) var configureOptOutValues: [Bool] = []
    private(set) var optInCallCount = 0
    private(set) var optOutCallCount = 0

    func configure(projectToken: String, host: String, optOut: Bool) {
        configureOptOutValues.append(optOut)
    }

    func optIn() {
        optInCallCount += 1
    }

    func optOut() {
        optOutCallCount += 1
    }

    func capture(_ event: String, properties: [String: Any]) {}
}
