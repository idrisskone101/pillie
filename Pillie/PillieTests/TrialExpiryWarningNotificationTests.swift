//
//  TrialExpiryWarningNotificationTests.swift
//  PillieTests
//
//  The Reverse Trial day-10/13 expiry warnings and day-15 expiry-day notice
//  through the real notification build path (#168): managed identifiers (so a
//  purchase-triggered reschedule cancels them as stale, and a blocker setup
//  change replaces them), authored copy, and the day payload the
//  `trial_expiry_warning_sent` event reads at delivery.
//
//  The class is intentionally NOT `@MainActor` (only the test methods are): a
//  `@MainActor` XCTestCase subclass aborts on deinit under the Xcode 27 beta
//  hosted runner.
//

import XCTest
@testable import Pillie

final class TrialExpiryWarningNotificationTests: XCTestCase {

    @MainActor
    private func makeTrialFixture(
        now: Date,
        grantDate: Date?,
        hasEntitlement: Bool,
        termsCohort: TrialTermsCohort? = nil
    ) throws -> InMemoryStoreFixture {
        let trialStore = InMemoryTrialGrantStore()
        if let grantDate {
            trialStore.saveGrantDate(grantDate)
        }
        if let termsCohort {
            trialStore.saveTermsCohort(termsCohort)
        }
        SubscriptionManager.shared.setTrialGrantStoreForTesting(trialStore)
        SubscriptionManager.shared.setPlusForTesting(hasEntitlement)

        addTeardownBlock { @MainActor in
            SubscriptionManager.shared.setPlusForTesting(false)
            SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
            InMemoryStoreFactory.resetClockAndDefaults()
        }

        return try InMemoryStoreFactory.makeStore(now: now, startDate: now)
    }

    @MainActor
    private func trialWarningSummaries(
        store: PillStore,
        now: Date,
        cohort: TrialEndPaywallCohort = .reminderOnly
    ) -> [NotificationManager.ReminderRequestDebugSummary] {
        let manager = KeptNotificationManager.make(hasBlockerSetup: { cohort == .blockerConfigured })
        return manager.managedRequestSummariesForTesting(store: store, now: now)
            .filter { $0.requestKind == "trialExpiryWarning" }
            .sorted { (a: NotificationManager.ReminderRequestDebugSummary, b) in
                (a.trialWarningDay ?? 0) < (b.trialWarningDay ?? 0)
            }
    }

    @MainActor
    func testBuildsManagedWarningRequestsWithDayPayload() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try makeTrialFixture(now: now, grantDate: now, hasEntitlement: false)

        let warnings = trialWarningSummaries(store: fixture.store, now: now, cohort: .blockerConfigured)

        XCTAssertEqual(warnings.map(\.trialWarningDay), [10, 13, 15])
        for warning in warnings {
            let day = try XCTUnwrap(warning.trialWarningDay)
            XCTAssertTrue(warning.identifier.hasPrefix("pillie_trial_warning_day_\(day)_blocker_configured_"))
            XCTAssertEqual(warning.title, TrialExpiryWarningCopy.title(day: day))
            XCTAssertEqual(warning.body, TrialExpiryWarningCopy.body(day: day, cohort: .blockerConfigured, terms: .legacy))
            // Informational: no reminder category, no Mark as Taken / Snooze.
            XCTAssertEqual(warning.categoryIdentifier, "")
        }
    }

    @MainActor
    func testCohortChangeReplacesRequestIdentifiersAndKeepsPayload() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try makeTrialFixture(now: now, grantDate: now, hasEntitlement: false)

        let blocker = trialWarningSummaries(store: fixture.store, now: now, cohort: .blockerConfigured)
        let remindersOnly = trialWarningSummaries(store: fixture.store, now: now, cohort: .reminderOnly)

        XCTAssertEqual(blocker.count, 3)
        XCTAssertEqual(remindersOnly.count, 3)
        XCTAssertTrue(Set(blocker.map(\.identifier)).isDisjoint(with: remindersOnly.map(\.identifier)))
        XCTAssertEqual(blocker.map(\.trialWarningDay), remindersOnly.map(\.trialWarningDay))
        XCTAssertTrue(remindersOnly.allSatisfy { $0.identifier.contains("_reminder_only_") })
    }

    @MainActor
    func testPostCutoverInstallNeverHearsRemindersStayFree() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-10-05", hour: 9)
        let fixture = try makeTrialFixture(
            now: now,
            grantDate: now,
            hasEntitlement: false,
            termsCohort: .postCutover
        )
        SubscriptionManager.shared.debugSetHardPaywallEnabled(true)
        addTeardownBlock { @MainActor in
            SubscriptionManager.shared.debugSetHardPaywallEnabled(nil)
        }

        let warnings = trialWarningSummaries(store: fixture.store, now: now, cohort: .blockerConfigured)

        XCTAssertEqual(warnings.map(\.trialWarningDay), [10, 13, 15])
        XCTAssertEqual(warnings.map(\.body), [
            "Choose a plan in the next 5 days to keep using Pillie.",
            "Choose a plan by tomorrow night to keep using Pillie.",
            "Choose monthly, annual, or lifetime to keep using Pillie.",
        ])
        XCTAssertTrue(warnings.allSatisfy { $0.identifier.contains("_blocker_configured_hard_") })
    }

    @MainActor
    func testEntitledUserBuildsNoWarningRequests() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try makeTrialFixture(now: now, grantDate: now, hasEntitlement: true)

        XCTAssertTrue(trialWarningSummaries(store: fixture.store, now: now).isEmpty)
    }
}
