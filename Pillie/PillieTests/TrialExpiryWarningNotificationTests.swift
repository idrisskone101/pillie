//
//  TrialExpiryWarningNotificationTests.swift
//  PillieTests
//
//  The Reverse Trial day-10/13 expiry warnings through the real notification
//  build path (#168): managed identifiers (so a purchase-triggered reschedule
//  cancels them as stale), authored copy, and the day payload the
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
        hasEntitlement: Bool
    ) throws -> InMemoryStoreFixture {
        let trialStore = InMemoryTrialGrantStore()
        if let grantDate {
            trialStore.saveGrantDate(grantDate)
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
        now: Date
    ) -> [NotificationManager.ReminderRequestDebugSummary] {
        NotificationManager.shared.managedRequestSummariesForTesting(store: store, now: now)
            .filter { $0.requestKind == "trialExpiryWarning" }
            .sorted { (a: NotificationManager.ReminderRequestDebugSummary, b) in
                (a.trialWarningDay ?? 0) < (b.trialWarningDay ?? 0)
            }
    }

    @MainActor
    func testBuildsManagedWarningRequestsWithDayPayload() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try makeTrialFixture(now: now, grantDate: now, hasEntitlement: false)

        let warnings = trialWarningSummaries(store: fixture.store, now: now)

        XCTAssertEqual(warnings.map(\.trialWarningDay), [10, 13])
        for warning in warnings {
            let day = try XCTUnwrap(warning.trialWarningDay)
            XCTAssertTrue(warning.identifier.hasPrefix("pillie_trial_warning_"))
            XCTAssertEqual(warning.title, TrialExpiryWarningCopy.title(day: day))
            XCTAssertEqual(warning.body, TrialExpiryWarningCopy.body(day: day))
            // Informational: no reminder category, no Mark as Taken / Snooze.
            XCTAssertEqual(warning.categoryIdentifier, "")
        }
    }

    @MainActor
    func testEntitledUserBuildsNoWarningRequests() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try makeTrialFixture(now: now, grantDate: now, hasEntitlement: true)

        XCTAssertTrue(trialWarningSummaries(store: fixture.store, now: now).isEmpty)
    }
}
