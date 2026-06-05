//
//  NotificationEdgeCaseTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class NotificationEdgeCaseTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testReminderBeforeNowSchedulesCatchupInsteadOfDroppingToday() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10)
        let fixture = try InMemoryStoreFactory.makeStore(now: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let todayBase = try XCTUnwrap(summaries.first {
            $0.dueDayEpoch == todayEpoch && $0.requestKind == "base"
        })
        let fireDate = try XCTUnwrap(todayBase.fireDate)

        XCTAssertGreaterThan(fireDate, now)
        XCTAssertLessThanOrEqual(fireDate.timeIntervalSince(now), 60)
    }

    func testMidnightAndNoonReminderTimesAreRepresentable() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10)
        let fixture = try InMemoryStoreFactory.makeStore(now: now)
        let store = fixture.store

        store.reminderHour = 0
        store.reminderMinute = 0
        XCTAssertEqual(store.nextReminderTime, "12:00 AM")

        store.reminderHour = 12
        XCTAssertEqual(store.nextReminderTime, "12:00 PM")
    }

    func testReminderRequestsStayUnderIOSPendingLimit() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .threeSixtyFiveZero,
            startDate: now
        )
        fixture.store.autoReminderIntervalMinutes = 5
        fixture.store.refillReminderThresholdDays = 3

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )

        XCTAssertLessThanOrEqual(summaries.count, 64)
        XCTAssertTrue(summaries.contains { $0.identifier.hasPrefix("pillie_reminder_") })
        XCTAssertTrue(summaries.contains { $0.identifier.hasPrefix("pillie_refill_reminder_") })
    }

    func testDSTTransitionDayStillBuildsDueReminder() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-03-08", hour: 3, minute: 30)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 2
        fixture.store.reminderMinute = 30

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)

        XCTAssertTrue(summaries.contains {
            $0.dueDayEpoch == todayEpoch && $0.actionTypeRaw == PillDay.ActionType.pillActive.rawValue
        })
    }

    func testAutoReminderRetryLimitDefaultsPersistsAndNormalizes() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now)

        XCTAssertEqual(PillStore.autoReminderRetryLimitOptions, [0, 1, 2, 3, 5])
        XCTAssertEqual(fixture.store.autoReminderRetryLimit, 3)

        fixture.store.autoReminderRetryLimit = 5
        let reloadedStore = PillStore(modelContext: fixture.context)
        XCTAssertEqual(reloadedStore.autoReminderRetryLimit, 5)

        fixture.store.autoReminderRetryLimit = 4
        XCTAssertEqual(fixture.store.autoReminderRetryLimit, 3)
    }

    func testZeroAutoReminderRetryLimitKeepsPrimaryReminderWithoutRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 0

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let todayDueReminders = summaries.filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "base" }.count, 1)
        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "retry" }.count, 0)
    }

    func testAutoReminderRetryLimitCapsSameDayRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let retryLimits = [1, 3, 5]

        for retryLimit in retryLimits {
            let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
            fixture.store.autoReminderRetryLimit = retryLimit

            let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
                store: fixture.store,
                now: now
            )
            let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
            let todayDueReminders = summaries.filter { $0.dueDayEpoch == todayEpoch }

            XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "base" }.count, 1)
            XCTAssertEqual(
                todayDueReminders.filter { $0.requestKind == "retry" }.count,
                retryLimit,
                "Expected \(retryLimit) automatic retries for limit \(retryLimit)."
            )
        }
    }

    func testSnoozeRequestIsSeparateFromAutomaticRetryLimit() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 1
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now,
            snoozeFirstFireDate: snoozeFireDate
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let todayDueReminders = summaries.filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "snooze" }.count, 1)
        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "retry" }.count, 1)
        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "base" }.count, 0)
    }

    func testPrimaryDueReminderCopyIsWarmAndDiscreetForEachDueAction() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let cases: [(method: ContraceptiveMethod, startOffsetDays: Int, expectedAction: PillDay.ActionType, expectedTitle: String, expectedBody: String)] = [
            (.pill, 0, .pillActive, "Pillie check-in", "A quick moment to take your pill and log it."),
            (.patch, 0, .patchChange, "Patch check-in", "Time to switch your patch when you're ready."),
            (.patch, -21, .patchRemove, "Patch check-in", "Time to remove your patch when you're ready."),
            (.ring, 0, .ringInsert, "Ring check-in", "Time to insert your ring when you're ready."),
            (.ring, -21, .ringRemove, "Ring check-in", "Time to remove your ring when you're ready."),
            (.ring, -28, .ringReinsert, "Ring check-in", "Time to reinsert your ring when you're ready.")
        ]

        for testCase in cases {
            let startDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: testCase.startOffsetDays, to: now))
            let fixture = try InMemoryStoreFactory.makeStore(
                now: now,
                method: testCase.method,
                startDate: startDate,
                ringInsertionDate: testCase.method == .ring ? startDate : nil
            )
            fixture.store.autoReminderRetryLimit = 0

            let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
                store: fixture.store,
                now: now
            )
            let primary = try XCTUnwrap(summaries.first { $0.requestKind == "base" })

            XCTAssertEqual(primary.actionTypeRaw, testCase.expectedAction.rawValue)
            XCTAssertEqual(primary.title, testCase.expectedTitle)
            XCTAssertEqual(primary.body, testCase.expectedBody)
            XCTAssertNotNil(primary.dueDayEpoch)
            XCTAssertFalse(primary.body.localizedCaseInsensitiveContains("cycle day"))
        }
    }

    func testAutoReminderRetryUsesDistinctSofterCopyAndKeepsActionPayload() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 1

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let primary = try XCTUnwrap(summaries.first { $0.requestKind == "base" })
        let retry = try XCTUnwrap(summaries.first { $0.requestKind == "retry" })

        XCTAssertEqual(retry.title, "Still here when you're ready")
        XCTAssertEqual(retry.body, "Take a tiny moment for your Pillie check-in.")
        XCTAssertNotEqual(retry.title, primary.title)
        XCTAssertNotEqual(retry.body, primary.body)
        XCTAssertEqual(retry.categoryIdentifier, primary.categoryIdentifier)
        XCTAssertEqual(retry.dueDayEpoch, primary.dueDayEpoch)
        XCTAssertEqual(retry.actionTypeRaw, PillDay.ActionType.pillActive.rawValue)
        XCTAssertFalse(retry.body.localizedCaseInsensitiveContains("cycle day"))
    }

    func testSupplyReminderCopyIsWarmDiscreetAndDoesNotScheduleForRing() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)
        let pillRefill = try XCTUnwrap(
            NotificationManager.shared.managedRequestSummariesForTesting(store: pillFixture.store, now: now)
                .first { $0.identifier.hasPrefix("pillie_refill_reminder_") }
        )

        let patchFixture = try InMemoryStoreFactory.makeStore(now: now, method: .patch, startDate: now)
        let patchRestock = try XCTUnwrap(
            NotificationManager.shared.managedRequestSummariesForTesting(store: patchFixture.store, now: now)
                .first { $0.identifier.hasPrefix("pillie_refill_reminder_") }
        )

        let ringFixture = try InMemoryStoreFactory.makeStore(now: now, method: .ring, startDate: now, ringInsertionDate: now)
        let ringSummaries = NotificationManager.shared.managedRequestSummariesForTesting(store: ringFixture.store, now: now)

        XCTAssertEqual(pillRefill.title, "Refill check-in")
        XCTAssertEqual(pillRefill.body, "Looks like you're getting low. A refill soon could save future stress.")
        XCTAssertEqual(patchRestock.title, "Patch restock check-in")
        XCTAssertEqual(patchRestock.body, "Looks like you're getting low. A restock soon could save future stress.")
        XCTAssertFalse(ringSummaries.contains { $0.identifier.hasPrefix("pillie_refill_reminder_") })
        XCTAssertFalse(pillRefill.body.localizedCaseInsensitiveContains("cycle day"))
        XCTAssertFalse(patchRestock.body.localizedCaseInsensitiveContains("cycle day"))
    }
}
