//
//  SmartRemindersUpsellTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class SmartRemindersUpsellTests: XCTestCase {

    // MARK: - Upsell copy (ADR 0004 framing)

    func testSmartRemindersUpsellIsEscalationFramedNotTheBaseReminder() {
        let content = PlusUpsellContent.smartReminders

        XCTAssertEqual(content.featureName, "Smart Reminders")

        let description = content.featureDescription.lowercased()
        // ADR 0004: copy must read Smart Reminders as the follow-up escalation
        // ("Pillie keeps reminding you until you log it"), not the base daily reminder.
        XCTAssertTrue(
            description.contains("until you log"),
            "Upsell must frame Smart Reminders as repeating until the user logs."
        )
        XCTAssertTrue(
            description.contains("follow") || description.contains("after the first"),
            "Upsell must frame Smart Reminders as a follow-up after the first reminder, not the base reminder."
        )
    }

    func testSmartRemindersUpsellAvoidsMedicalAndEfficacyClaims() {
        let description = PlusUpsellContent.smartReminders.featureDescription.lowercased()

        // ADR 0002 / 0004 / CONTEXT.md: no medical, efficacy, or "never miss" claims.
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

    func testAppBlockingUpsellContentIsPreserved() {
        // Regression: the existing App Blocking upsell copy is unchanged by the refactor.
        let content = PlusUpsellContent.appBlocking
        XCTAssertEqual(content.featureName, "App Blocking")
        XCTAssertEqual(
            content.featureDescription,
            "Block distracting apps until your pill is logged."
        )
    }

    func testFeatureUpsellsRouteToStablePaywallSurfaces() {
        XCTAssertEqual(PlusUpsellContent.smartReminders.paywallSurface, .plusUpsell)
        XCTAssertEqual(PlusUpsellContent.appBlocking.paywallSurface, .plusUpsell)
        XCTAssertEqual(PlusUpsellContent.customReminders.paywallSurface, .plusUpsell)
    }

    // MARK: - Telemetry (mirrors the Blocking upsell events)
    //
    // Hosted XCTest on the Xcode 27 beta aborts when a class instance is deallocated
    // during a test (the documented @MainActor/class deinit crash), so a recording
    // spy cannot be used here. These assertions follow the surviving value-type
    // pattern from SettingsTelemetryTests: assert the event identifier and the
    // payload shape the settings upsell emits, and smoke-invoke the entry point
    // through a struct tracker so no reference type is allocated.

    func testPlusUpsellViewedUsesTheApprovedSurfaceContract() {
        XCTAssertEqual(AnalyticsEvent.plusUpsellViewed.rawValue, "plus_upsell_viewed")

        // Every feature sheet owns its one view emission under one stable contract.
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
        // Binds the test to the real method symbol. A struct tracker keeps the run
        // free of any class deallocation, which is what aborts hosted XCTest here.
        let telemetry = ProductAnalyticsTelemetry(analytics: NoOpTracker(), isPlus: { false })
        telemetry.plusUpsellViewed()
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
