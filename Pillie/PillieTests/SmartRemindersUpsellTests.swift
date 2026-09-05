//
//  SmartRemindersUpsellTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class SmartRemindersUpsellTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func testSmartRemindersUpsellIsEscalationFramedNotTheBaseReminder() {
        let content = PlusUpsellContent.smartReminders
        let title = commerce(content.localizedFeatureKey)
        let description = commerce(content.subtitleKey)

        XCTAssertEqual(title, "Smart reminders")
        XCTAssertTrue(
            description.contains("until you log"),
            "Upsell must frame Smart Reminders as repeating until the user logs."
        )
        XCTAssertTrue(
            description.contains("keeps pinging") || description.contains("how often"),
            "Upsell must frame Smart Reminders as extra pings after the first reminder."
        )
        XCTAssertNotEqual(
            content.subtitleKey,
            "paywall.subtitle",
            "Smart Reminders must not reuse the app-blocking paywall body."
        )
    }

    func testSmartRemindersUpsellAvoidsMedicalAndEfficacyClaims() {
        let description = commerce(PlusUpsellContent.smartReminders.subtitleKey).lowercased()

        let bannedPhrases = [
            "never miss",
            "miss a dose",
            "protect",
            "pregnan",
            "effective",
            "efficacy",
            "guarantee",
            "doctor",
            "medical"
        ]
        for phrase in bannedPhrases {
            XCTAssertFalse(
                description.contains(phrase),
                "Smart Reminders upsell copy must avoid medical/efficacy claim: \(phrase)"
            )
        }
    }

    func testAppBlockingUpsellUsesMethodAwareLockedBody() {
        let content = PlusUpsellContent.appBlocking()
        XCTAssertEqual(commerce(content.localizedFeatureKey), "App blocking")
        XCTAssertEqual(
            commerce(content.subtitleKey),
            "Your apps pause when the reminder is due, until you take your pill."
        )
    }

    func testCustomRemindersUpsellUsesADedicatedBody() {
        let content = PlusUpsellContent.customReminders
        XCTAssertEqual(commerce(content.localizedFeatureKey), "Reminder messages")
        XCTAssertEqual(
            commerce(content.subtitleKey),
            "Write the ping in your own words. Plus lets you change the daily one and the last one."
        )
        XCTAssertNotEqual(content.subtitleKey, content.localizedFeatureKey)
    }

    func testFeatureUpsellsRouteToStablePaywallSurfaces() {
        XCTAssertEqual(PlusUpsellContent.smartReminders.paywallSurface, .plusUpsell)
        XCTAssertEqual(PlusUpsellContent.appBlocking().paywallSurface, .plusUpsell)
        XCTAssertEqual(PlusUpsellContent.customReminders.paywallSurface, .plusUpsell)
    }

    func testPlusUpsellViewedUsesTheApprovedSurfaceContract() {
        XCTAssertEqual(AnalyticsEvent.plusUpsellViewed.rawValue, "plus_upsell_viewed")

        let properties = AnalyticsPayload(
            source: .upsell,
            isPlus: false,
            paywallSurface: .plusUpsell
        ).properties
        XCTAssertEqual(properties, [
            "source": .string("upsell"),
            "surface": .string("plus_upsell"),
            "is_plus": .bool(false)
        ])
    }

    func testPlusUpsellViewedEntryPointInvokesWithoutTrapping() {
        let telemetry = ProductAnalyticsTelemetry(analytics: NoOpTracker(), isPlus: { false })
        telemetry.plusUpsellViewed()
    }

    private func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: english)
    }
}

private struct NoOpTracker: AnalyticsTracking {
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
    ) {}
}
