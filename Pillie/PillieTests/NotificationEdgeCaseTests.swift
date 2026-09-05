//
//  NotificationEdgeCaseTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class NotificationEdgeCaseTests: XCTestCase {
    override func tearDown() {
        SubscriptionManager.shared.setPlusForTesting(false)
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testFreeUserReceivesSingleDueReminderWithoutRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 3
        SubscriptionManager.shared.setPlusForTesting(false)

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let todayDueReminders = summaries.filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "base" }.count, 1)
        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "retry" }.count, 0)
    }

    func testPlusUserReceivesRetriesPerStoredLimit() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 3
        SubscriptionManager.shared.setPlusForTesting(true)

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let todayDueReminders = summaries.filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "base" }.count, 1)
        XCTAssertEqual(todayDueReminders.filter { $0.requestKind == "retry" }.count, 3)
    }

    func testReminderCategoryDropsSnoozeActionForFreeUsers() {
        let freeActions = NotificationManager.shared.reminderCategoryActionIdentifiersForTesting(isPlus: false)
        let plusActions = NotificationManager.shared.reminderCategoryActionIdentifiersForTesting(isPlus: true)

        XCTAssertEqual(freeActions, [NotificationManager.shared.markTakenAction])
        XCTAssertEqual(
            plusActions,
            [NotificationManager.shared.markTakenAction, NotificationManager.shared.snoozeAction]
        )
    }

    func testFreeUserStoredRetryLimitIsPreservedAndReturnsOnUpgrade() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 5
        SubscriptionManager.shared.setPlusForTesting(false)

        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let freeReminders = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(freeReminders.filter { $0.requestKind == "retry" }.count, 0)
        // Gating must not mutate the stored preference.
        XCTAssertEqual(fixture.store.autoReminderRetryLimit, 5)

        SubscriptionManager.shared.setPlusForTesting(true)
        let plusReminders = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(plusReminders.filter { $0.requestKind == "retry" }.count, 5)
    }

    func testFreeUserSupplyReminderIsUnaffected() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)
        SubscriptionManager.shared.setPlusForTesting(false)

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )

        XCTAssertTrue(summaries.contains { $0.identifier.hasPrefix("pillie_refill_reminder_") })
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

        // Auto-Reminder Retry is a Smart Reminders (Plus) perk now (ADR 0004).
        SubscriptionManager.shared.setPlusForTesting(true)

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
        // Snooze is a Smart Reminders (Plus) perk now (ADR 0004).
        SubscriptionManager.shared.setPlusForTesting(true)
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
            (.pill, 0, .pillActive, "Pillie time!", "Hey, quick check-in. Log your pill when you're done"),
            (.patch, 0, .patchChange, "Pillie time!", "Hey, quick check-in. Apply your patch when you're done"),
            (.patch, -7, .patchChange, "Pillie time!", "Hey, quick check-in. Change your patch when you're done"),
            (.patch, -21, .patchRemove, "Pillie time!", "Hey, quick check-in. Remove your patch when you're done"),
            (.ring, 0, .ringInsert, "Pillie time!", "Hey, quick check-in. Insert your ring when you're done"),
            (.ring, -21, .ringRemove, "Pillie time!", "Hey, quick check-in. Remove your ring when you're done"),
            (.ring, -28, .ringReinsert, "Pillie time!", "Hey, quick check-in. Change your ring when you're done")
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
        // Auto-Reminder Retry is a Smart Reminders (Plus) perk now (ADR 0004).
        SubscriptionManager.shared.setPlusForTesting(true)

        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now
        )
        let primary = try XCTUnwrap(summaries.first { $0.requestKind == "base" })
        let retry = try XCTUnwrap(summaries.first { $0.requestKind == "retry" })

        XCTAssertEqual(retry.title, "Reminder follow-up")
        XCTAssertEqual(retry.body, "Hey, quick check-in is still open. Check in when you're ready")
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

        XCTAssertEqual(pillRefill.title, "Pill supply reminder")
        XCTAssertEqual(pillRefill.body, "Your current supply may be running low. Check it when convenient.")
        XCTAssertEqual(patchRestock.title, "Patch supply reminder")
        XCTAssertEqual(patchRestock.body, "Your current patch supply may be running low. Check it when convenient.")
        XCTAssertFalse(ringSummaries.contains { $0.identifier.hasPrefix("pillie_refill_reminder_") })
        XCTAssertFalse(pillRefill.body.localizedCaseInsensitiveContains("cycle day"))
        XCTAssertFalse(patchRestock.body.localizedCaseInsensitiveContains("cycle day"))
    }
}
