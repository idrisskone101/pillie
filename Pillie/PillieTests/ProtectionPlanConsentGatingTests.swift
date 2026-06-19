//
//  ProtectionPlanConsentGatingTests.swift
//  PillieTests
//
//  Verifies the Protection Plan Onboarding privacy contract: Product Analytics
//  Telemetry stays consent-gated, and events emitted before the user grants
//  consent on the Analytics Consent screen are dropped rather than buffered.
//

import XCTest

@testable import Pillie

final class ProtectionPlanConsentGatingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProtectionPlanConsentGatingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private var validInfoDictionary: [String: Any] {
        [
            "PostHogProjectToken": "test-token",
            "PostHogHost": "https://example.com"
        ]
    }

    func testProductAnalyticsEventsAreDroppedUntilConsentIsGranted() {
        let client = RecordingAnalyticsClient()
        let manager = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: validInfoDictionary
        )
        manager.configure()

        // Funnel events fired on Welcome and the Analytics Consent screen itself,
        // i.e. before the user has granted consent.
        manager.track(.onboardingStepViewed, step: .welcome)
        manager.track(.onboardingStepViewed, step: .analyticsConsent)

        XCTAssertEqual(
            client.capturedEvents, [],
            "Pre-consent events must be dropped, never captured or buffered."
        )

        // User taps "Allow Analytics".
        manager.setAnalyticsEnabled(true)
        manager.track(.onboardingStepViewed, step: .painPoints)

        // Only the post-consent event flows; the earlier ones are not replayed.
        XCTAssertEqual(client.capturedEvents, [AnalyticsEvent.onboardingStepViewed.rawValue])
    }

    func testDecliningConsentKeepsProductAnalyticsDropped() {
        let client = RecordingAnalyticsClient()
        let manager = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: validInfoDictionary
        )
        manager.configure()

        // User taps "Not Now".
        manager.setAnalyticsEnabled(false)
        manager.track(.onboardingStepViewed, step: .painPoints)

        XCTAssertEqual(
            client.capturedEvents, [],
            "Declining consent must keep telemetry fully gated."
        )
        XCTAssertFalse(manager.isAnalyticsEnabled)
    }
}

/// Records every captured event so tests can assert exactly what was (and was not)
/// sent through to the underlying analytics client.
private final class RecordingAnalyticsClient: ProductAnalyticsClient {
    private(set) var capturedEvents: [String] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {}

    func setOptedOut(_ isOptedOut: Bool) {}

    func capture(event: String, properties: [String: AnalyticsPropertyValue]) {
        capturedEvents.append(event)
    }

    func flush() {}
}
