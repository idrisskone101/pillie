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
}
