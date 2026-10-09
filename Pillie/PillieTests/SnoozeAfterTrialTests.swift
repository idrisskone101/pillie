//
//  SnoozeAfterTrialTests.swift
//  PillieTests
//

import XCTest
import UserNotifications

@testable import Pillie

/// Snooze is a Plus perk (ADR 0004). iOS reads a reminder's actions when it
/// shows it, so a reminder planned during the trial that fires after the trial
/// ends must not offer Snooze, even if Pillie never opens in between.
@MainActor
final class SnoozeAfterTrialTests: XCTestCase {
    // SwiftData models can deallocate inside the hosted XCTest invocation on the
    // Xcode 27 beta. Keep the stores for the process.
    private static var retainedFixtures: [InMemoryStoreFixture] = []

    override func setUp() {
        super.setUp()
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
    }

    override func tearDown() {
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testAReminderThatFiresAfterTheTrialEndsOffersNoSnooze() throws {
        // Granted Sep 1 at noon, the trial counts Sep 2 to 15 and ends at Sep 16
        // 00:00. Grandfathered terms keep the daily reminders after it.
        let manager = SubscriptionManager.shared
        manager.updateActiveDaySchedule(.everyCalendarDay, now: local(9, 1, 12))
        _ = manager.grantReverseTrial(now: local(9, 1, 12), termsCohort: .preCutover)
        let now = local(9, 15, 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: local(9, 1))
        Self.retainedFixtures.append(fixture)

        let center = InMemoryNotificationCenter()
        let summaries = KeptNotificationManager.make(center: center, hasPlusAccess: { true })
            .managedRequestSummariesForTesting(store: fixture.store, now: now)

        XCTAssertEqual(actions(firing: local(9, 15, 8), in: summaries, center), [markTaken, snooze])
        XCTAssertEqual(actions(firing: local(9, 16, 8), in: summaries, center), [markTaken])
    }

    private var markTaken: String { NotificationManager.shared.markTakenAction }
    private var snooze: String { NotificationManager.shared.snoozeAction }

    /// The actions iOS shows for the base reminder firing at `fireDate`.
    private func actions(
        firing fireDate: Date,
        in summaries: [NotificationManager.ReminderRequestDebugSummary],
        _ center: InMemoryNotificationCenter
    ) -> [String]? {
        guard let reminder = summaries.first(where: { $0.requestKind == "base" && $0.fireDate == fireDate }),
              let category = center.categories.first(where: { $0.identifier == reminder.categoryIdentifier })
        else { return nil }
        return category.actions.map(\.identifier)
    }

    private func local(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
}
