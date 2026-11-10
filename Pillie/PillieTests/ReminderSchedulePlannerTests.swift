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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10)
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
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
        // After the 08:00 reminder, so the live dose day is today and its retry window
        // runs a full 24 hours (ADR 0009). Before 08:00 the live dose is yesterday's,
        // whose window closes at 08:00, and the retries never reach the cap.
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .custom,
            customRegimen: PackRegimen(activeDays: 365, breakDays: 0),
            startDate: now
        )
        XCTAssertEqual(epochDay(for: fixture.store.today), epochDay(for: now))

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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 0)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
    }

    func testCapsSameDayRetriesByRetryLimit() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 3)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 3)
    }

    func testPlusFollowUpsArePlannedForEveryUntakenDueDayInTheFollowUpWindow() throws {
        // Nothing rebuilds when the window rolls over at the next reminder, so the
        // plan made while today is still untaken must carry tomorrow's follow-ups.
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let tomorrowEpoch = epochDay(for: InMemoryStoreFactory.localDate("2026-05-27", hour: 12))

        let intents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            smartRemindersEnabled: true
        )
        let retries = intents.filter { $0.kind == .retry }

        XCTAssertEqual(
            retries.filter { $0.dueDayEpoch == tomorrowEpoch }.map(\.fireDate),
            [
                InMemoryStoreFactory.localDate("2026-05-27", hour: 8, minute: 10),
                InMemoryStoreFactory.localDate("2026-05-27", hour: 8, minute: 20),
                InMemoryStoreFactory.localDate("2026-05-27", hour: 8, minute: 30)
            ]
        )
        XCTAssertEqual(
            Set(retries.map(\.dueDayEpoch)),
            Set(intents.filter { $0.kind == .base }.prefix(ReminderSchedulePlanner.followUpDayCount).map(\.dueDayEpoch))
        )
    }

    func testUserWhoNeverOpensTheAppGetsADailyBaseReminderForAMonth() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .custom,
            customRegimen: PackRegimen(activeDays: 365, breakDays: 0),
            startDate: now
        )

        let bases = dueIntents(for: fixture.store, now: now, smartRemindersEnabled: false)
            .filter { $0.kind == .base }

        XCTAssertEqual(bases.count, ReminderSchedulePlanner.baseReminderCount)
        XCTAssertEqual(bases.first?.fireDate, InMemoryStoreFactory.localDate("2026-05-26", hour: 8))
        XCTAssertEqual(bases.last?.fireDate, InMemoryStoreFactory.localDate("2026-06-24", hour: 8))
    }

    func testMonthOfBaseRemindersCountsDoseDaysAndSkipsNoPillWeeks() throws {
        // Day 15 of a 21/7 no-pill pack: 7 dose days, a silent week, 21 dose days,
        // another silent week, then 2 dose days of the third pack. After 08:00, so
        // the live dose day is 26 May and not yesterday's.
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .custom,
            customRegimen: PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills),
            startDate: InMemoryStoreFactory.localDate("2026-05-12", hour: 0)
        )
        let breakDays = ["2026-06-02", "2026-06-08", "2026-06-30", "2026-07-06"]
            .map { epochDay(for: InMemoryStoreFactory.localDate($0, hour: 12)) }

        let due = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 3)
        let bases = due.filter { $0.kind == .base }

        XCTAssertEqual(bases.count, ReminderSchedulePlanner.baseReminderCount)
        XCTAssertEqual(bases.last?.fireDate, InMemoryStoreFactory.localDate("2026-07-08", hour: 8))
        XCTAssertFalse(due.contains { $0.action.type.isBreakType })
        XCTAssertFalse(due.contains { breakDays.contains($0.dueDayEpoch) })
    }

    func testPatchAndRingBreakWeeksStaySilent() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        for method in [ContraceptiveMethod.patch, .ring] {
            let fixture = try InMemoryStoreFactory.makeStore(
                now: now,
                method: method,
                startDate: InMemoryStoreFactory.localDate("2026-05-12", hour: 0)
            )

            let due = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 3)

            XCTAssertFalse(due.isEmpty, "\(method)")
            XCTAssertTrue(due.allSatisfy { $0.action.type.requiresUserAction }, "\(method)")
            XCTAssertFalse(due.contains { $0.action.type.isBreakType }, "\(method)")
        }
    }

    func testPlusFollowUpsCoverOnlyTheTwoNearestDueDays() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .custom,
            customRegimen: PackRegimen(activeDays: 365, breakDays: 0),
            startDate: now
        )

        let intents = plan(for: fixture.store, now: now, autoReminderRetryLimit: 5)
        let due = intents.compactMap { intent -> ReminderSchedulePlanner.DueReminderIntent? in
            if case .due(let due) = intent { return due }
            return nil
        }

        XCTAssertLessThan(intents.count, ReminderSchedulePlanner.maxPendingReminders)
        XCTAssertEqual(due.filter { $0.kind == .base }.count, ReminderSchedulePlanner.baseReminderCount)
        XCTAssertEqual(
            Set(due.filter { $0.kind == .retry }.map(\.dueDayEpoch)),
            [
                epochDay(for: InMemoryStoreFactory.localDate("2026-05-26", hour: 12)),
                epochDay(for: InMemoryStoreFactory.localDate("2026-05-27", hour: 12))
            ]
        )
        XCTAssertEqual(due.filter { $0.kind == .retry }.count, 10)
    }

    func testTreatsSnoozeAsSeparateFromAutomaticRetries() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        let supply = plan(for: pillFixture.store, now: now, smartRemindersEnabled: false)
            .compactMap { intent -> ReminderSchedulePlanner.SupplyReminderIntent? in
                if case .supply(let supply) = intent { return supply }
                return nil
            }

        XCTAssertEqual(supply.map(\.method), [.pill])
    }

    func testBuildsPillAndPatchSupplyRemindersButNotRing() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
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

    func testSupplyReminderFiresOnceOnItsThresholdDay() throws {
        // 21/7 from 1 May: 24 May leaves 5 pills, the refill threshold. Reminder 08:00.
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate("2026-05-24", hour: 7),
            startDate: Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate("2026-05-01", hour: 12))
        )
        fixture.store.refillReminderThresholdDays = 5

        func supplyFireDates(atHour hour: Int) -> [Date] {
            let now = InMemoryStoreFactory.localDate("2026-05-24", hour: hour)
            PillieClock.setFixedNowForTesting(now)
            return supplyIntents(for: fixture.store, now: now).map(\.fireDate)
        }

        XCTAssertEqual(supplyFireDates(atHour: 7), [InMemoryStoreFactory.localDate("2026-05-24", hour: 8)])
        // Every later rebuild that day (a foreground, a check-in) must not re-arm it.
        XCTAssertEqual(supplyFireDates(atHour: 10), [])
        XCTAssertEqual(supplyFireDates(atHour: 14), [])
    }

    // MARK: - Cycle Transition Notice (#123)

    func testCycleTransitionNoticeFiresOnBreakWeekStartForEachMethod() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let calendar = Calendar.current

        let fixtures: [(ContraceptiveMethod, InMemoryStoreFixture)] = [
            (.pill, try InMemoryStoreFactory.makeStore(now: now, method: .pill, regimen: .twentyOneOnly, startDate: now)),
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let calendar = Calendar.current
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, regimen: .twentyOneOnly, startDate: now)

        let notice = try XCTUnwrap(cycleTransitionIntents(for: fixture.store, now: now).first)
        let transitionDay = Date(timeIntervalSince1970: TimeInterval(notice.transitionDayEpoch))

        // The resume date is the active-phase / new-pack start: not a break day, and the
        // day before it still is. It is also the FIRST active day after the transition.
        XCTAssertEqual(isBreakDay(notice.resumeDate, pack: fixture.store.pack, calendar: calendar), false)
        let dayBeforeResume = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: notice.resumeDate))
        XCTAssertEqual(isBreakDay(dayBeforeResume, pack: fixture.store.pack, calendar: calendar), true)
        XCTAssertGreaterThan(notice.resumeDate, transitionDay)

        // For a 21-only pill cycle starting today (cycle day 1), the break starts on day 22
        // and the next pack starts on day 29 — i.e. cycleLength days after today.
        let expectedResume = calendar.date(
            byAdding: .day,
            value: fixture.store.pack.cycleLength,
            to: calendar.startOfDay(for: now)
        )
        XCTAssertEqual(notice.resumeDate, expectedResume)
    }

    func testCycleTransitionNoticeIsNotGatedByEntitlement() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, regimen: .twentyOneOnly, startDate: now)

        let freeNotices = plan(for: fixture.store, now: now, smartRemindersEnabled: false)
            .compactMap { intent -> ReminderSchedulePlanner.CycleTransitionIntent? in
                if case .cycleTransition(let notice) = intent { return notice }
                return nil
            }

        XCTAssertEqual(freeNotices.count, 1)
        XCTAssertEqual(freeNotices.first?.method, .pill)
    }

    func testCycleTransitionNoticeAbsentOnActivePhaseStart() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let calendar = Calendar.current
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, regimen: .twentyOneOnly, startDate: now)

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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, regimen: .twentyOneOnly, startDate: now)

        let notices = cycleTransitionIntents(for: fixture.store, now: now, cycleTransitionEnabled: false)
        XCTAssertTrue(notices.isEmpty)
    }

    func testCycleTransitionNoticeAbsentForContinuousRegimen() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .custom,
            customRegimen: PackRegimen(activeDays: 365, breakDays: 0),
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

    // MARK: - Served-base catch-up re-fire regression

    func testDoesNotRearmBaseAfterServedMomentPassed() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 15)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        ).filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testStabilizesPendingBaseFireDateFromServedMap() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 1)

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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 9
        fixture.store.reminderMinute = 30
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let tomorrowEpoch = epochDay(for: tomorrow)
        let staleServedAt = InMemoryStoreFactory.localDate("2026-05-27", hour: 8, minute: 0)

        let tomorrowBase = try XCTUnwrap(
            dueIntents(
                for: fixture.store,
                now: now,
                servedBaseFireDateByDueDayEpoch: [tomorrowEpoch: staleServedAt]
            ).first { $0.dueDayEpoch == tomorrowEpoch && $0.kind == .base }
        )

        XCTAssertEqual(
            tomorrowBase.fireDate,
            InMemoryStoreFactory.localDate("2026-05-27", hour: 9, minute: 30)
        )
    }

    func testTodayBeforeConfiguredTimeIgnoresServedEntry() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 22
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let staleServedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 45)

        let todayBase = try XCTUnwrap(
            dueIntents(
                for: fixture.store,
                now: now,
                servedBaseFireDateByDueDayEpoch: [todayEpoch: staleServedAt]
            ).first { $0.dueDayEpoch == todayEpoch && $0.kind == .base }
        )

        XCTAssertEqual(
            todayBase.fireDate,
            InMemoryStoreFactory.localDate("2026-05-26", hour: 22, minute: 0)
        )
    }

    func testReminderMovedBeforeNowCatchesUpInsteadOfWaitingForTheOldTime() throws {
        // At 10:00 the reminder moves from 22:00 to 08:00 while today's base is still
        // pending at 22:00. A time before now catches up within a minute (US-11).
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let pendingAtOldTime = InMemoryStoreFactory.localDate("2026-05-26", hour: 22, minute: 0)

        let todayBase = try XCTUnwrap(
            dueIntents(
                for: fixture.store,
                now: now,
                servedBaseFireDateByDueDayEpoch: [todayEpoch: pendingAtOldTime]
            ).first { $0.dueDayEpoch == todayEpoch && $0.kind == .base }
        )

        XCTAssertEqual(
            todayBase.fireDate,
            InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 1)
        )
    }

    func testRetriesAnchorWhenBaseSuppressedAfterServed() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 8, minute: 5)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 8, minute: 0)

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


    func testFreeUserNoBaseOrRetryAfterServed() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 15)

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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 15)
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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 15)

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
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 10, minute: 1)
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

    func testRetriesContinueAfterMidnightUntilNextReminder() throws {
        let reminderDay = InMemoryStoreFactory.localDate("2026-06-10", hour: 21)
        let afterMidnight = InMemoryStoreFactory.localDate("2026-06-11", hour: 1)
        let fixture = try InMemoryStoreFactory.makeStore(now: reminderDay, startDate: reminderDay)
        fixture.store.reminderHour = 21
        fixture.store.reminderMinute = 0

        PillieClock.setFixedNowForTesting(afterMidnight)
        fixture.store.refreshDayContextIfNeeded()

        let liveEpoch = epochDay(for: fixture.store.today)
        XCTAssertEqual(liveEpoch, epochDay(for: reminderDay))

        let liveIntents = dueIntents(
            for: fixture.store,
            now: afterMidnight,
            autoReminderIntervalMinutes: 60,
            autoReminderRetryLimit: 3
        )
        .filter { $0.dueDayEpoch == liveEpoch }

        XCTAssertEqual(liveIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(liveIntents.filter { $0.kind == .retry }.count, 3)
        XCTAssertTrue(liveIntents.allSatisfy { $0.fireDate > afterMidnight })
        let nextReminder = try XCTUnwrap(
            Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: afterMidnight)
        )
        XCTAssertTrue(liveIntents.allSatisfy { $0.fireDate < nextReminder })
    }

    // MARK: - Young streak reminder copy (ENG-168)

    func testStreakAtRiskOnlyOnNearestUntakenPillBase() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let intents = dueIntents(for: fixture.store, now: now, currentStreak: 1)
        let todayBase = try XCTUnwrap(
            intents.first { $0.dueDayEpoch == todayEpoch && $0.kind == .base }
        )

        XCTAssertEqual(todayBase.streakAtRisk, 1)
        XCTAssertTrue(
            intents.filter { !($0.dueDayEpoch == todayEpoch && $0.kind == .base) }
                .allSatisfy { $0.streakAtRisk == nil }
        )
    }

    func testStreakAtRiskMovesToTomorrowOnceTodayIsTaken() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let calendar = Calendar.current
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
        let tomorrowEpoch = epochDay(for: tomorrow)
        let dayAfter = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: tomorrow))
        let dayAfterEpoch = epochDay(for: dayAfter)

        let intents = dueIntents(
            for: fixture.store,
            now: now,
            statusOverrides: [todayEpoch: .taken],
            currentStreak: 1
        )

        let tomorrowBase = try XCTUnwrap(
            intents.first { $0.dueDayEpoch == tomorrowEpoch && $0.kind == .base }
        )
        let dayAfterBase = try XCTUnwrap(
            intents.first { $0.dueDayEpoch == dayAfterEpoch && $0.kind == .base }
        )

        XCTAssertEqual(tomorrowBase.streakAtRisk, 1)
        XCTAssertNil(dayAfterBase.streakAtRisk)
    }

    func testStreakAtRiskNilOutsideFirstWeekRange() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        for streak in [0, 7] {
            let intents = dueIntents(for: fixture.store, now: now, currentStreak: streak)
            XCTAssertTrue(
                intents.allSatisfy { $0.streakAtRisk == nil },
                "Expected no streakAtRisk for currentStreak \(streak)"
            )
        }
    }

    func testStreakAtRiskNilWhenTodayBaseAlreadyServed() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 17)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let servedAt = InMemoryStoreFactory.localDate("2026-05-26", hour: 21, minute: 15)
        let calendar = Calendar.current
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
        let tomorrowEpoch = epochDay(for: tomorrow)

        let intents = dueIntents(
            for: fixture.store,
            now: now,
            currentStreak: 2,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: servedAt]
        )

        XCTAssertEqual(intents.filter { $0.dueDayEpoch == todayEpoch && $0.kind == .base }.count, 0)
        let tomorrowBase = try XCTUnwrap(
            intents.first { $0.dueDayEpoch == tomorrowEpoch && $0.kind == .base }
        )
        XCTAssertNil(tomorrowBase.streakAtRisk)
    }

    func testStreakAtRiskNilForPatchAndRing() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)

        for method: ContraceptiveMethod in [.patch, .ring] {
            let fixture = try InMemoryStoreFactory.makeStore(
                now: now,
                method: method,
                startDate: now,
                ringInsertionDate: method == .ring ? now : nil
            )
            let intents = dueIntents(for: fixture.store, now: now, currentStreak: 1)
            XCTAssertFalse(intents.isEmpty, "Expected due intents for \(method)")
            XCTAssertTrue(
                intents.allSatisfy { $0.streakAtRisk == nil },
                "Expected no streakAtRisk for \(method)"
            )
        }
    }

    func testStreakAtRiskNilOnSugarPillReminder() throws {
        // 21/7 from 1 May: 21 May is hormone pill 21, 22 May the first sugar pill.
        // Sugar pills never touch the streak, so their reminder must not name it.
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate("2026-05-21", hour: 10),
            startDate: Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate("2026-05-01", hour: 12))
        )

        func nearestBase(on day: String) throws -> ReminderSchedulePlanner.DueReminderIntent {
            let now = InMemoryStoreFactory.localDate(day, hour: 10)
            PillieClock.setFixedNowForTesting(now)
            let dayEpoch = epochDay(for: now)
            return try XCTUnwrap(
                dueIntents(for: fixture.store, now: now, currentStreak: 3)
                    .first { $0.dueDayEpoch == dayEpoch && $0.kind == .base }
            )
        }

        let hormoneBase = try nearestBase(on: "2026-05-21")
        let sugarBase = try nearestBase(on: "2026-05-22")

        XCTAssertEqual(hormoneBase.action.type, .pillActive)
        XCTAssertEqual(sugarBase.action.type, .pillSugar)
        XCTAssertEqual([hormoneBase.streakAtRisk, sugarBase.streakAtRisk], [3, nil])
    }

    func testStreakAtRiskNilOnRetriesForPlusUser() throws {
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            smartRemindersEnabled: true,
            currentStreak: 1
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        let retries = todayIntents.filter { $0.kind == .retry }
        XCTAssertEqual(retries.count, 3)
        XCTAssertTrue(retries.allSatisfy { $0.streakAtRisk == nil })
        XCTAssertEqual(todayIntents.first { $0.kind == .base }?.streakAtRisk, 1)
    }

    func testRepeatsCountTheFollowUpsThatAlreadyFired() throws {
        // The 8:00 reminder and its 8:10, 8:20 and 8:30 follow-ups fired; the app opens at 8:45.
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 8, minute: 45)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let retries = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: InMemoryStoreFactory.localDate("2026-05-26", hour: 8)]
        )
        .filter { $0.dueDayEpoch == todayEpoch && $0.kind == .retry }

        XCTAssertEqual(retries.map(\.fireDate), [])
    }

    func testRepeatsKeepOnlyTheFollowUpsStillAhead() throws {
        // The 8:00 reminder and its 8:10 follow-up fired; the app opens at 8:15.
        let now = InMemoryStoreFactory.localDate("2026-05-26", hour: 8, minute: 15)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let retries = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            servedBaseFireDateByDueDayEpoch: [todayEpoch: InMemoryStoreFactory.localDate("2026-05-26", hour: 8)]
        )
        .filter { $0.dueDayEpoch == todayEpoch && $0.kind == .retry }

        XCTAssertEqual(retries.map(\.fireDate), [
            InMemoryStoreFactory.localDate("2026-05-26", hour: 8, minute: 20),
            InMemoryStoreFactory.localDate("2026-05-26", hour: 8, minute: 30)
        ])
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
        currentStreak: Int = 0,
        servedBaseFireDateByDueDayEpoch: [Int: Date] = [:]
    ) -> [ReminderSchedulePlanner.Intent] {
        let calendar = Calendar.current
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: store.today,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )
        var statusByEpochDay = store.statusesByEpochDay(for: candidateDueActions.map(\.date))
        statusOverrides.forEach { statusByEpochDay[$0.key] = $0.value }

        return planner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                scheduleDay: store.today,
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
                trialGrantDate: nil,
                hasEntitlement: false,
                currentStreak: currentStreak,
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
        currentStreak: Int = 0,
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
            currentStreak: currentStreak,
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
