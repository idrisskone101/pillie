//
//  ReminderSchedulePlannerTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class ReminderSchedulePlannerTests: XCTestCase {
    private let planner = ReminderSchedulePlanner()

    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testSchedulesCatchupWhenConfiguredTimeHasPassedForToday() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0

        let todayEpoch = epochDay(for: now)
        let todayBase = try XCTUnwrap(dueIntents(for: fixture.store, now: now).first {
            $0.dueDayEpoch == todayEpoch && $0.kind == .base
        })

        XCTAssertGreaterThan(todayBase.fireDate, now)
        XCTAssertLessThanOrEqual(todayBase.fireDate.timeIntervalSince(now), 60)
    }

    func testSkipsTakenDueActionsUsingStatusMap() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let intents = dueIntents(
            for: fixture.store,
            now: now,
            statusOverrides: [todayEpoch: .taken]
        )

        XCTAssertFalse(intents.contains { $0.dueDayEpoch == todayEpoch })
        XCTAssertTrue(intents.contains { $0.kind == .base })
    }

    func testCapsPlanAtPendingLimitAndReservesSupplySlot() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .threeSixtyFiveZero,
            startDate: now
        )

        let intents = plan(
            for: fixture.store,
            now: now,
            autoReminderIntervalMinutes: 5,
            autoReminderRetryLimit: 100
        )

        XCTAssertEqual(intents.count, ReminderSchedulePlanner.maxPendingReminders)
        XCTAssertEqual(intents.filter(\.isSupply).count, 1)
        XCTAssertEqual(intents.filter(\.isDue).count, ReminderSchedulePlanner.maxPendingReminders - 1)
    }

    func testKeepsPrimaryReminderWhenRetryLimitIsZero() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 0)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
    }

    func testCapsSameDayRetriesByRetryLimit() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 3)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 3)
    }

    func testTreatsSnoozeAsSeparateFromAutomaticRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 1,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            )
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testFreeUserGetsSingleDueReminderWithNoRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            smartRemindersEnabled: false
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
    }

    func testFreeUserSnoozeOverrideIsIgnored() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            ),
            smartRemindersEnabled: false
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 0)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
    }

    func testPlusUserRetainsRetriesAndSnooze() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            ),
            smartRemindersEnabled: true
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 3)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testFreeUserStillReceivesSupplyReminders() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        let supply = plan(for: pillFixture.store, now: now, smartRemindersEnabled: false)
            .compactMap { intent -> ReminderSchedulePlanner.SupplyReminderIntent? in
                if case .supply(let supply) = intent { return supply }
                return nil
            }

        XCTAssertEqual(supply.map(\.method), [.pill])
    }

    func testBuildsPillAndPatchSupplyRemindersButNotRing() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)
        let patchFixture = try InMemoryStoreFactory.makeStore(now: now, method: .patch, startDate: now)
        let ringFixture = try InMemoryStoreFactory.makeStore(
            now: now,
            method: .ring,
            startDate: now,
            ringInsertionDate: now
        )

        let pillSupply = supplyIntents(for: pillFixture.store, now: now)
        let patchSupply = supplyIntents(for: patchFixture.store, now: now)
        let ringSupply = supplyIntents(for: ringFixture.store, now: now)

        XCTAssertEqual(pillSupply.map(\.method), [.pill])
        XCTAssertEqual(patchSupply.map(\.method), [.patch])
        XCTAssertTrue(ringSupply.isEmpty)
    }

    // MARK: - Cycle Transition Notice (#123)

    func testCycleTransitionNoticeFiresOnBreakWeekStartForEachMethod() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let calendar = Calendar.current

        let fixtures: [(ContraceptiveMethod, InMemoryStoreFixture)] = [
            (.pill, try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)),
            (.patch, try InMemoryStoreFactory.makeStore(now: now, method: .patch, startDate: now)),
            (.ring, try InMemoryStoreFactory.makeStore(
                now: now,
                method: .ring,
                startDate: now,
                ringInsertionDate: now
            ))
        ]

        for (method, fixture) in fixtures {
            let notices = cycleTransitionIntents(for: fixture.store, now: now)
            XCTAssertEqual(notices.count, 1, "Expected exactly one notice for \(method)")
            let notice = try XCTUnwrap(notices.first)
            XCTAssertEqual(notice.method, method)

            // The transition day is the first day of the break/off week: it is a break day,
            // and the day before it is not.
            let transitionDay = Date(timeIntervalSince1970: TimeInterval(notice.transitionDayEpoch))
            XCTAssertEqual(isBreakDay(transitionDay, pack: fixture.store.pack, calendar: calendar), true)
            let dayBefore = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: transitionDay))
            XCTAssertEqual(isBreakDay(dayBefore, pack: fixture.store.pack, calendar: calendar), false)

            // It fires at the configured reminder time on that day.
            let expectedFire = calendar.date(
                bySettingHour: fixture.store.reminderHour,
                minute: fixture.store.reminderMinute,
                second: 0,
                of: transitionDay
            )
            XCTAssertEqual(notice.fireDate, expectedFire)
        }
    }

    func testCycleTransitionNoticeCarriesNextActivePhaseResumeDate() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let calendar = Calendar.current
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        let notice = try XCTUnwrap(cycleTransitionIntents(for: fixture.store, now: now).first)
        let transitionDay = Date(timeIntervalSince1970: TimeInterval(notice.transitionDayEpoch))

        // The resume date is the active-phase / new-pack start: not a break day, and the
        // day before it still is. It is also the FIRST active day after the transition.
        XCTAssertEqual(isBreakDay(notice.resumeDate, pack: fixture.store.pack, calendar: calendar), false)
        let dayBeforeResume = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: notice.resumeDate))
        XCTAssertEqual(isBreakDay(dayBeforeResume, pack: fixture.store.pack, calendar: calendar), true)
        XCTAssertGreaterThan(notice.resumeDate, transitionDay)

        // For a 21/7 pill cycle starting today (cycle day 1), the break starts on day 22
        // and the next pack starts on day 29 — i.e. cycleLength days after today.
        let expectedResume = calendar.date(
            byAdding: .day,
            value: fixture.store.pack.cycleLength,
            to: calendar.startOfDay(for: now)
        )
        XCTAssertEqual(notice.resumeDate, expectedResume)
    }

    func testCycleTransitionNoticeIsNotGatedByEntitlement() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        let freeNotices = plan(for: fixture.store, now: now, smartRemindersEnabled: false)
            .compactMap { intent -> ReminderSchedulePlanner.CycleTransitionIntent? in
                if case .cycleTransition(let notice) = intent { return notice }
                return nil
            }

        XCTAssertEqual(freeNotices.count, 1)
        XCTAssertEqual(freeNotices.first?.method, .pill)
    }

    func testCycleTransitionNoticeAbsentOnActivePhaseStart() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let calendar = Calendar.current
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        // The only planned notice lands on a break day, never on an active-phase start, so
        // it never doubles up with the day-1 Due Action Reminder.
        let notices = cycleTransitionIntents(for: fixture.store, now: now)
        for notice in notices {
            let transitionDay = Date(timeIntervalSince1970: TimeInterval(notice.transitionDayEpoch))
            XCTAssertEqual(isBreakDay(transitionDay, pack: fixture.store.pack, calendar: calendar), true)
        }

        // No managed reminder shares the transition slot's day with the resume (active) day.
        let resumeEpochs = Set(notices.map { Int(calendar.startOfDay(for: $0.resumeDate).timeIntervalSince1970) })
        let transitionEpochs = Set(notices.map(\.transitionDayEpoch))
        XCTAssertTrue(resumeEpochs.isDisjoint(with: transitionEpochs))
    }

    func testCycleTransitionNoticeAbsentWhenDisabled() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        let notices = cycleTransitionIntents(for: fixture.store, now: now, cycleTransitionEnabled: false)
        XCTAssertTrue(notices.isEmpty)
    }

    func testCycleTransitionNoticeAbsentForContinuousRegimen() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .threeSixtyFiveZero,
            startDate: now
        )

        XCTAssertTrue(cycleTransitionIntents(for: fixture.store, now: now).isEmpty)
    }

    private func cycleTransitionIntents(
        for store: PillStore,
        now: Date,
        cycleTransitionEnabled: Bool = true
    ) -> [ReminderSchedulePlanner.CycleTransitionIntent] {
        plan(for: store, now: now, cycleTransitionEnabled: cycleTransitionEnabled)
            .compactMap { intent in
                if case .cycleTransition(let notice) = intent { return notice }
                return nil
            }
    }

    private func isBreakDay(_ date: Date, pack: PillPack, calendar: Calendar) -> Bool {
        DoseScheduleEngine.dueAction(on: date, pack: pack, calendar: calendar)?.isBreak ?? false
    }

    // MARK: - Last Call Reminder

    func testSchedulesLastCallOnUntakenDay() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, lastCallEnabled: true)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .lastCall }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
    }

    func testDoesNotScheduleLastCallWhenDisabled() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let intents = dueIntents(for: fixture.store, now: now, lastCallEnabled: false)

        XCTAssertTrue(intents.filter { $0.kind == .lastCall }.isEmpty)
    }

    func testFiresLastCallEvenWhenRetryLimitIsZero() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 0,
            lastCallEnabled: true
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .lastCall }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
    }

    func testSuppressesLastCallUnderSixtyMinuteGap() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)

        // Last Call at 8:30 is only 30 minutes after the 8:00 reminder — suppressed.
        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            lastCallEnabled: true,
            lastCallHour: 8,
            lastCallMinute: 30
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertTrue(todayIntents.filter { $0.kind == .lastCall }.isEmpty)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
    }

    func testSchedulesLastCallAtExactlySixtyMinuteGap() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)

        // Exactly 60 minutes after the 8:00 reminder — allowed.
        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            lastCallEnabled: true,
            lastCallHour: 9,
            lastCallMinute: 0
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .lastCall }.count, 1)
    }

    func testSuppressesLastCallOnTakenDay() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let intents = dueIntents(
            for: fixture.store,
            now: now,
            statusOverrides: [todayEpoch: .taken],
            lastCallEnabled: true
        )

        XCTAssertFalse(intents.contains { $0.dueDayEpoch == todayEpoch && $0.kind == .lastCall })
        // The feature is still active for other untaken days.
        XCTAssertTrue(intents.contains { $0.kind == .lastCall })
    }

    func testFreeUserGetsNoLastCall() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let intents = dueIntents(
            for: fixture.store,
            now: now,
            lastCallEnabled: true,
            lastCallHour: 21,
            lastCallMinute: 0
        )

        // smartRemindersEnabled defaults to true in the helper; override to false here.
        let freeIntents = dueIntents(
            for: fixture.store,
            now: now,
            smartRemindersEnabled: false,
            lastCallEnabled: true
        )

        XCTAssertTrue(intents.contains { $0.kind == .lastCall })
        XCTAssertTrue(freeIntents.filter { $0.kind == .lastCall }.isEmpty)
    }

    func testDropsRetryWithinGuardWindowOfLastCall() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let guardWindow: TimeInterval = TimeInterval(ReminderSchedulePlanner.lastCallRetryGuardMinutes * 60)

        // 30-minute cadence from an 8:00 reminder puts a retry exactly on the 21:00 Last Call.
        let withLastCall = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderIntervalMinutes: 30,
            autoReminderRetryLimit: 100,
            lastCallEnabled: true,
            lastCallHour: 21,
            lastCallMinute: 0
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        let lastCall = try XCTUnwrap(withLastCall.first { $0.kind == .lastCall })
        XCTAssertFalse(withLastCall.contains {
            $0.kind == .retry && abs($0.fireDate.timeIntervalSince(lastCall.fireDate)) <= guardWindow
        })

        // Without the Last Call, a retry does land in that window — proving the dedupe acted.
        let withoutLastCall = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderIntervalMinutes: 30,
            autoReminderRetryLimit: 100,
            lastCallEnabled: false
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertTrue(withoutLastCall.contains {
            $0.kind == .retry && abs($0.fireDate.timeIntervalSince(lastCall.fireDate)) <= guardWindow
        })
    }

    func testPreSchedulesAtMostOneLastCallPerDayAcrossHorizon() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let lastCalls = dueIntents(for: fixture.store, now: now, lastCallEnabled: true)
            .filter { $0.kind == .lastCall }
        let distinctDays = Set(lastCalls.map(\.dueDayEpoch))

        XCTAssertGreaterThanOrEqual(distinctDays.count, 2)
        XCTAssertEqual(lastCalls.count, distinctDays.count) // at most one per day
    }

    // MARK: - Served-base catch-up re-fire regression

    func testDoesNotRearmBaseAfterServedMomentPassed() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 15)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        ).filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testStabilizesPendingBaseFireDateFromServedMap() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 1)

        let todayBase = try XCTUnwrap(
            dueIntents(
                for: fixture.store,
                now: now,
                servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
            ).first { $0.dueDayEpoch == todayEpoch && $0.kind == .base }
        )

        XCTAssertEqual(todayBase.fireDate, servedAt)
    }

    func testFutureDayReplansAtConfiguredTimeDespiteServedEntry() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 9
        fixture.store.reminderMinute = 30
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let tomorrowEpoch = epochDay(for: tomorrow)
        let staleServedAt = InMemoryStoreFactory.fixedDate("2026-05-27", hour: 8, minute: 0)

        let tomorrowBase = try XCTUnwrap(
            dueIntents(
                for: fixture.store,
                now: now,
                servedBaseFireDateByDueDayEpoch: [tomorrowEpoch: staleServedAt]
            ).first { $0.dueDayEpoch == tomorrowEpoch && $0.kind == .base }
        )

        XCTAssertEqual(
            tomorrowBase.fireDate,
            InMemoryStoreFactory.fixedDate("2026-05-27", hour: 9, minute: 30)
        )
    }

    func testTodayBeforeConfiguredTimeIgnoresServedEntry() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 22
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let staleServedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 45)

        let todayBase = try XCTUnwrap(
            dueIntents(
                for: fixture.store,
                now: now,
                servedBaseFireDateByDueDayEpoch: [todayEpoch: staleServedAt]
            ).first { $0.dueDayEpoch == todayEpoch && $0.kind == .base }
        )

        XCTAssertEqual(
            todayBase.fireDate,
            InMemoryStoreFactory.fixedDate("2026-05-26", hour: 22, minute: 0)
        )
    }

    func testRetriesAnchorWhenBaseSuppressedAfterServed() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 8, minute: 5)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 8, minute: 0)

        let retries = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderIntervalMinutes: 30,
            autoReminderRetryLimit: 3,
            smartRemindersEnabled: true,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        )
        .filter { $0.dueDayEpoch == todayEpoch && $0.kind == .retry }

        XCTAssertEqual(retries.count, 3)
        XCTAssertTrue(retries.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(retries.first?.fireDate, servedAt.addingTimeInterval(30 * 60))
    }

    func testLastCallPlansWhenBaseSuppressedAfterServed() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 5)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 8, minute: 0)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            lastCallEnabled: true,
            lastCallHour: 21,
            lastCallMinute: 0,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
        XCTAssertEqual(todayIntents.filter { $0.kind == .lastCall }.count, 1)
    }

    func testFreeUserNoBaseOrRetryAfterServed() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 15)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            smartRemindersEnabled: false,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertTrue(todayIntents.isEmpty)
    }

    func testSnoozeBypassesServedBaseRecord() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 15)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            ),
            smartRemindersEnabled: true,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testServedCommitmentDoesNotBlockTomorrow() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 21, minute: 15)

        let intents = dueIntents(
            for: fixture.store,
            now: now,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        )

        XCTAssertEqual(intents.filter { $0.dueDayEpoch == todayEpoch && $0.kind == .base }.count, 0)

        let calendar = Calendar.current
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
        let tomorrowEpoch = epochDay(for: tomorrow)
        XCTAssertEqual(intents.filter { $0.dueDayEpoch == tomorrowEpoch && $0.kind == .base }.count, 1)
    }

    func testBackToBackPlanConvergesWithStableServedBase() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10, minute: 1)
        let servedMap = [todayEpoch: servedAt]

        let first = dueIntents(
            for: fixture.store,
            now: now,
            servedBaseFireDateByDueDayEpoch: servedMap
        )
        let second = dueIntents(
            for: fixture.store,
            now: now,
            servedBaseFireDateByDueDayEpoch: servedMap
        )

        let firstBase = first.filter { $0.dueDayEpoch == todayEpoch && $0.kind == .base }
        let secondBase = second.filter { $0.dueDayEpoch == todayEpoch && $0.kind == .base }

        XCTAssertEqual(firstBase.count, 1)
        XCTAssertEqual(firstBase.map(\.fireDate), secondBase.map(\.fireDate))
        XCTAssertEqual(firstBase.first?.fireDate, servedAt)
    }

    func testSchedulesLastCallForAllMethods() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)

        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)
        let patchFixture = try InMemoryStoreFactory.makeStore(now: now, method: .patch, startDate: now)
        let ringFixture = try InMemoryStoreFactory.makeStore(
            now: now,
            method: .ring,
            startDate: now,
            ringInsertionDate: now
        )

        for store in [pillFixture.store, patchFixture.store, ringFixture.store] {
            let lastCalls = dueIntents(for: store, now: now, lastCallEnabled: true)
                .filter { $0.kind == .lastCall }
            XCTAssertFalse(lastCalls.isEmpty, "Expected a Last Call for method \(store.pack.method)")
        }
    }

    private func plan(
        for store: PillStore,
        now: Date,
        autoReminderIntervalMinutes: Int? = nil,
        autoReminderRetryLimit: Int? = nil,
        statusOverrides: [Int: PillDay.Status] = [:],
        snoozeOverride: ReminderSchedulePlanner.SnoozeOverride? = nil,
        smartRemindersEnabled: Bool = true,
        cycleTransitionEnabled: Bool = true,
        lastCallEnabled: Bool = false,
        lastCallHour: Int = 21,
        lastCallMinute: Int = 0,
        servedBaseFireDateByDueDayEpoch: [Int: Date] = [:]
    ) -> [ReminderSchedulePlanner.Intent] {
        let calendar = Calendar.current
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )
        var statusByEpochDay = store.statusesByEpochDay(for: candidateDueActions.map(\.date))
        statusOverrides.forEach { statusByEpochDay[$0.key] = $0.value }

        return planner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                pack: store.pack,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                autoReminderIntervalMinutes: autoReminderIntervalMinutes ?? store.autoReminderIntervalMinutes,
                autoReminderRetryLimit: autoReminderRetryLimit ?? store.autoReminderRetryLimit,
                refillReminderThresholdDays: store.refillReminderThresholdDays,
                patchRestockReminderThresholdPatches: store.patchRestockReminderThresholdPatches,
                candidateDueActions: candidateDueActions,
                statusByEpochDay: statusByEpochDay,
                snoozeOverride: snoozeOverride,
                smartRemindersEnabled: smartRemindersEnabled,
                cycleTransitionEnabled: cycleTransitionEnabled,
                lastCallEnabled: lastCallEnabled,
                lastCallHour: lastCallHour,
                lastCallMinute: lastCallMinute,
                trialGrantDate: nil,
                hasEntitlement: false,
                servedBaseFireDateByDueDayEpoch: servedBaseFireDateByDueDayEpoch,
                calendar: calendar
            )
        )
    }

    private func dueIntents(
        for store: PillStore,
        now: Date,
        autoReminderIntervalMinutes: Int? = nil,
        autoReminderRetryLimit: Int? = nil,
        statusOverrides: [Int: PillDay.Status] = [:],
        snoozeOverride: ReminderSchedulePlanner.SnoozeOverride? = nil,
        smartRemindersEnabled: Bool = true,
        lastCallEnabled: Bool = false,
        lastCallHour: Int = 21,
        lastCallMinute: Int = 0,
        servedBaseFireDateByDueDayEpoch: [Int: Date] = [:]
    ) -> [ReminderSchedulePlanner.DueReminderIntent] {
        plan(
            for: store,
            now: now,
            autoReminderIntervalMinutes: autoReminderIntervalMinutes,
            autoReminderRetryLimit: autoReminderRetryLimit,
            statusOverrides: statusOverrides,
            snoozeOverride: snoozeOverride,
            smartRemindersEnabled: smartRemindersEnabled,
            lastCallEnabled: lastCallEnabled,
            lastCallHour: lastCallHour,
            lastCallMinute: lastCallMinute,
            servedBaseFireDateByDueDayEpoch: servedBaseFireDateByDueDayEpoch
        )
        .compactMap { intent in
            if case .due(let due) = intent { return due }
            return nil
        }
    }

    private func supplyIntents(
        for store: PillStore,
        now: Date
    ) -> [ReminderSchedulePlanner.SupplyReminderIntent] {
        plan(for: store, now: now).compactMap { intent in
            if case .supply(let supply) = intent { return supply }
            return nil
        }
    }

    private func epochDay(for date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
    }
}

private extension ReminderSchedulePlanner.Intent {
    var isDue: Bool {
        if case .due = self { return true }
        return false
    }

    var isSupply: Bool {
        if case .supply = self { return true }
        return false
    }
}
