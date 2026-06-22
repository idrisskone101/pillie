//
//  SmartRemindersMigrationNoticeTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class SmartRemindersMigrationNoticeTests: XCTestCase {

    // MARK: - Eligibility (pure decision)

    func testPreExistingFreeUserIsEligible() {
        // Onboarding completed before the change, not Plus, never evaluated.
        XCTAssertTrue(
            SmartRemindersMigrationNotice.isEligible(
                alreadyEvaluated: false,
                onboardingComplete: true,
                isPlus: false
            )
        )
    }

    func testPlusUserIsNeverEligible() {
        XCTAssertFalse(
            SmartRemindersMigrationNotice.isEligible(
                alreadyEvaluated: false,
                onboardingComplete: true,
                isPlus: true
            )
        )
    }

    func testMidOnboardingOrBrandNewUserIsNotEligible() {
        // Onboarding not complete at first launch → a new / mid-onboarding user, for whom
        // Smart Reminders was always Plus. Never eligible.
        XCTAssertFalse(
            SmartRemindersMigrationNotice.isEligible(
                alreadyEvaluated: false,
                onboardingComplete: false,
                isPlus: false
            )
        )
    }

    func testAlreadyEvaluatedUserIsNotEligibleAgain() {
        // The one-time marker has already been set on a prior launch.
        XCTAssertFalse(
            SmartRemindersMigrationNotice.isEligible(
                alreadyEvaluated: true,
                onboardingComplete: true,
                isPlus: false
            )
        )
    }

    // MARK: - One-time evaluation (marker persistence)

    private func freshDefaults() -> UserDefaults {
        let suite = "SmartRemindersMigrationNoticeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testFirstEvaluationShowsTheNoticeForAPreExistingFreeUserThenNeverAgain() {
        let defaults = freshDefaults()

        // First launch after the update: eligible, and the marker is recorded.
        XCTAssertTrue(
            SmartRemindersMigrationNotice.evaluate(
                defaults: defaults,
                onboardingComplete: true,
                isPlus: false
            )
        )
        XCTAssertTrue(defaults.bool(forKey: SmartRemindersMigrationNotice.markerKey))

        // Subsequent launches never re-show it, even though the user is still free.
        XCTAssertFalse(
            SmartRemindersMigrationNotice.evaluate(
                defaults: defaults,
                onboardingComplete: true,
                isPlus: false
            )
        )
    }

    func testEvaluationSetsTheMarkerEvenWhenNotEligibleSoItNeverShowsLater() {
        // A Plus user (or a brand-new user mid-onboarding) is resolved on first launch and
        // the marker is set, so churning to free later never resurfaces the notice.
        let defaults = freshDefaults()

        XCTAssertFalse(
            SmartRemindersMigrationNotice.evaluate(
                defaults: defaults,
                onboardingComplete: true,
                isPlus: true
            )
        )
        XCTAssertTrue(defaults.bool(forKey: SmartRemindersMigrationNotice.markerKey))

        // Even if the same user is later free, the resolved marker suppresses the notice.
        XCTAssertFalse(
            SmartRemindersMigrationNotice.evaluate(
                defaults: defaults,
                onboardingComplete: true,
                isPlus: false
            )
        )
    }

    // MARK: - Copy

    func testNoticeLeadsWithDailyReminderReassuranceAndReusesTheSmartRemindersUpsell() {
        let content = SmartRemindersMigrationNotice.content

        // Reassurance-first: the primary daily reminder stays free and active (ADR 0004).
        XCTAssertEqual(content.reassuranceTitle, "Your daily reminder is still active")

        // Reuses the Smart Reminders upsell component from #102 for the upgrade framing.
        XCTAssertEqual(content.upsell, PlusUpsellContent.smartReminders)
    }

    func testNoticeCopyAvoidsMedicalAndEfficacyClaims() {
        // ADR 0002 / 0004 / CONTEXT.md: no medical, efficacy, or "never miss" claims.
        let copy = (SmartRemindersMigrationNotice.content.reassuranceTitle
            + " " + SmartRemindersMigrationNotice.content.reassuranceBody).lowercased()

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
                copy.contains(phrase),
                "Migration notice copy must avoid medical/efficacy claim: \(phrase)"
            )
        }
    }

    // MARK: - Telemetry

    func testMigrationNoticeTelemetryUsesADedicatedMigrationSource() {
        XCTAssertEqual(AnalyticsSource.migration.rawValue, "migration")

        // Notice viewed / upgrade-tapped reuse the established Plus upsell events, scoped
        // to the migration source and carrying only coarse, PII-free context.
        XCTAssertEqual(AnalyticsEvent.plusUpsellViewed.rawValue, "plus_upsell_viewed")
        XCTAssertEqual(AnalyticsEvent.plusUpsellUpgradeTapped.rawValue, "plus_upsell_upgrade_tapped")

        let viewed = AnalyticsPayload(source: .migration, isPlus: false).properties
        XCTAssertEqual(viewed, [
            "source": .string("migration"),
            "is_plus": .bool(false)
        ])
    }

    func testMigrationNoticeTelemetryEntryPointsInvokeWithoutTrapping() {
        let telemetry = ProductAnalyticsTelemetry(analytics: NoOpMigrationTracker(), isPlus: { false })
        telemetry.smartRemindersMigrationNoticeViewed()
        telemetry.smartRemindersMigrationNoticeUpgradeTapped()
        telemetry.smartRemindersMigrationNoticeDismissed()
    }
}

private struct NoOpMigrationTracker: AnalyticsTracking {
    func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource?,
        step: AnalyticsStep?,
        screen: AnalyticsScreen?,
        plan: AnalyticsPlan?,
        result: AnalyticsResult?,
        setting: AnalyticsSetting?,
        acquisitionSource: AcquisitionSource?,
        isPlus: Bool?,
        hasBlockingSelection: Bool?,
        titleCustomized: Bool?,
        bodyCustomized: Bool?,
        retryTitleCustomized: Bool?,
        retryBodyCustomized: Bool?
    ) {}
}
