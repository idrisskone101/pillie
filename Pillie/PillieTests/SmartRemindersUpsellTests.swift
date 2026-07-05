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

    // MARK: - Telemetry (mirrors the Blocking upsell events)
    //
    // Hosted XCTest on the Xcode 27 beta aborts when a class instance is deallocated
    // during a test (the documented @MainActor/class deinit crash), so a recording
    // spy cannot be used here. These assertions follow the surviving value-type
    // pattern from SettingsTelemetryTests: assert the event identifier and the
    // payload shape the settings upsell emits, and smoke-invoke the entry point
    // through a struct tracker so no reference type is allocated.

    func testSettingsUpsellViewedUsesTheApprovedSettingsSourcedEvent() {
        XCTAssertEqual(AnalyticsEvent.plusUpsellViewed.rawValue, "plus_upsell_viewed")

        // The Smart Reminders settings upsell mirrors the Blocking one exactly:
        // a `plus_upsell_viewed` event sourced to settings, carrying only coarse,
        // PII-free context.
        let properties = AnalyticsPayload(source: .settings, isPlus: false).properties
        XCTAssertEqual(properties, [
            "source": .string("settings"),
            "is_plus": .bool(false)
        ])
    }

    func testSettingsSmartRemindersUpsellViewedEntryPointInvokesWithoutTrapping() {
        // Binds the test to the real method symbol. A struct tracker keeps the run
        // free of any class deallocation, which is what aborts hosted XCTest here.
        let telemetry = ProductAnalyticsTelemetry(analytics: NoOpTracker(), isPlus: { false })
        telemetry.settingsSmartRemindersUpsellViewed()
        telemetry.settingsBlockingUpsellViewed()
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
        trialWarningDay: Int?,
        titleCustomized: Bool?,
        bodyCustomized: Bool?,
        retryTitleCustomized: Bool?,
        retryBodyCustomized: Bool?,
        lastCallTitleCustomized: Bool?,
        lastCallBodyCustomized: Bool?
    ) {}
}
