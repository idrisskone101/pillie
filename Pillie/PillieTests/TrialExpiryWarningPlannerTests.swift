//
//  TrialExpiryWarningPlannerTests.swift
//  PillieTests
//
//  The Reverse Trial's day-10/13 expiry warning notifications (issue #168 /
//  ADR 0007): planned as intents in the reminder schedule planner so they are
//  capped, cancelled, and tested like every other reminder intent.
//

import XCTest
@testable import Pillie

@MainActor
final class TrialExpiryWarningPlannerTests: XCTestCase {
    private let planner = ReminderSchedulePlanner()

    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testSchedulesDay10AndDay13WarningsAtGrant() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let warnings = warningIntents(for: fixture.store, now: now, trialGrantDate: now)

        XCTAssertEqual(warnings.map(\.day), [10, 13])

        let calendar = Calendar.current
        for warning in warnings {
            let expected = try XCTUnwrap(
                calendar.date(byAdding: .day, value: warning.day, to: calendar.startOfDay(for: now))
            )
            XCTAssertEqual(calendar.startOfDay(for: warning.fireDate), expected)
            let components = calendar.dateComponents([.hour, .minute], from: warning.fireDate)
            XCTAssertEqual(components.hour, ReminderSchedulePlanner.trialWarningHour)
            XCTAssertEqual(components.minute, 0)
        }
    }

    func testEntitledUserGetsNoWarnings() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let warnings = warningIntents(
            for: fixture.store,
            now: now,
            trialGrantDate: now,
            hasEntitlement: true
        )

        XCTAssertTrue(warnings.isEmpty)
    }

    func testPastWarningDatesAreDropped() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let grantDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -11, to: now))

        let warnings = warningIntents(for: fixture.store, now: now, trialGrantDate: grantDate)

        XCTAssertEqual(warnings.map(\.day), [13])
        XCTAssertGreaterThan(try XCTUnwrap(warnings.first).fireDate, now)
    }

    func testExpiredTrialGetsNoWarnings() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let grantDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -20, to: now))

        let warnings = warningIntents(for: fixture.store, now: now, trialGrantDate: grantDate)

        XCTAssertTrue(warnings.isEmpty)
    }

    func testWarningCopyAgreesWithExpiryClock() throws {
        // From the day-10 warning, expiry (local midnight after day 14) is 5
        // local-day rollovers away; from day 13 it lands tomorrow night.
        let calendar = Calendar.current
        let grantDate = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let clock = ReverseTrialClock(grantDate: grantDate)

        let day10Moment = try XCTUnwrap(calendar.date(byAdding: .day, value: 10, to: grantDate))
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: day10Moment), 5)
        XCTAssertTrue(TrialExpiryWarningCopy.body(day: 10).contains("in 5 days"))

        let day13Moment = try XCTUnwrap(calendar.date(byAdding: .day, value: 13, to: grantDate))
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: day13Moment), 2)
        XCTAssertTrue(TrialExpiryWarningCopy.body(day: 13).contains("tomorrow night"))

        // Informational, blocking-scoped copy: names app blocking, never the
        // contraceptive method or any protection/effectiveness claim.
        for day in ReminderSchedulePlanner.trialWarningDays {
            let copy = TrialExpiryWarningCopy.title(day: day) + " " + TrialExpiryWarningCopy.body(day: day)
            XCTAssertTrue(copy.contains("App blocking"))
            for banned in ["protect", "effective", "pregnan", "pill", "patch", "ring"] {
                XCTAssertFalse(copy.lowercased().contains(banned), "copy contains banned term: \(banned)")
            }
        }
    }

    func testWarningsReserveSlotsUnderPendingCap() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .threeSixtyFiveZero,
            startDate: now
        )

        let intents = plan(
            for: fixture.store,
            now: now,
            trialGrantDate: now,
            autoReminderIntervalMinutes: 5,
            autoReminderRetryLimit: 100
        )

        XCTAssertEqual(intents.count, ReminderSchedulePlanner.maxPendingReminders)
        XCTAssertEqual(intents.filter(\.isTrialWarning).count, 2)
        XCTAssertEqual(intents.filter(\.isSupply).count, 1)
        XCTAssertEqual(intents.filter(\.isDue).count, ReminderSchedulePlanner.maxPendingReminders - 3)
    }

    func testDueAndSupplyPlansAreUntouchedByTrialWarnings() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let withoutTrial = plan(for: fixture.store, now: now, trialGrantDate: nil)
        let withTrial = plan(for: fixture.store, now: now, trialGrantDate: now)

        XCTAssertEqual(
            withTrial.filter { !$0.isTrialWarning },
            withoutTrial
        )
        XCTAssertEqual(withTrial.filter(\.isTrialWarning).count, 2)
    }

    // MARK: - Helpers

    private func plan(
        for store: PillStore,
        now: Date,
        trialGrantDate: Date?,
        hasEntitlement: Bool = false,
        autoReminderIntervalMinutes: Int? = nil,
        autoReminderRetryLimit: Int? = nil
    ) -> [ReminderSchedulePlanner.Intent] {
        let calendar = Calendar.current
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )

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
                statusByEpochDay: store.statusesByEpochDay(for: candidateDueActions.map(\.date)),
                snoozeOverride: nil,
                smartRemindersEnabled: true,
                cycleTransitionEnabled: true,
                trialGrantDate: trialGrantDate,
                hasEntitlement: hasEntitlement,
                servedBaseFireDateByDueDayEpoch: [:],
                calendar: calendar
            )
        )
    }

    private func warningIntents(
        for store: PillStore,
        now: Date,
        trialGrantDate: Date?,
        hasEntitlement: Bool = false
    ) -> [ReminderSchedulePlanner.TrialExpiryWarningIntent] {
        plan(for: store, now: now, trialGrantDate: trialGrantDate, hasEntitlement: hasEntitlement)
            .compactMap { intent in
                if case .trialExpiryWarning(let warning) = intent { return warning }
                return nil
            }
            .sorted { $0.day < $1.day }
    }
}

private extension ReminderSchedulePlanner.Intent {
    var isTrialWarning: Bool {
        if case .trialExpiryWarning = self { return true }
        return false
    }

    var isDue: Bool {
        if case .due = self { return true }
        return false
    }

    var isSupply: Bool {
        if case .supply = self { return true }
        return false
    }
}
