//
//  LastCallReminderPlannerTests.swift
//  PillieTests
//
//  Value-type coverage for the Last Call Reminder planning in
//  `ReminderSchedulePlanner.planReminders(_:)`. This class is intentionally NOT
//  `@MainActor` and never instantiates `PillStore`, so it sidesteps the Xcode 27 beta
//  hosted-XCTest crash that aborts while deallocating any `@MainActor` test class. It
//  mirrors the Last Call acceptance criteria proven in `ReminderSchedulePlannerTests`
//  using a pure `PillPack` + `DoseScheduleEngine` fixture.
//

import XCTest
@testable import Pillie

final class LastCallReminderPlannerTests: XCTestCase {
    private let planner = ReminderSchedulePlanner()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private func date(_ isoDate: String, hour: Int, minute: Int = 0) -> Date {
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3, "Use YYYY-MM-DD dates in tests.")
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: hour,
            minute: minute
        ))!
    }

    private func epochDay(for date: Date) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    private func makeInput(
        now: Date,
        method: ContraceptiveMethod = .pill,
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        intervalMinutes: Int = 10,
        retryLimit: Int = 3,
        smartRemindersEnabled: Bool = true,
        lastCallEnabled: Bool = false,
        lastCallHour: Int = 21,
        lastCallMinute: Int = 0,
        takenEpochs: Set<Int> = []
    ) -> ReminderSchedulePlanner.Input {
        let startDate = calendar.startOfDay(for: now)
        let pack = PillPack(
            method: method,
            pillRegimen: .twentyOneSeven,
            startDate: startDate,
            packNumber: 1,
            isCurrent: true
        )
        if method == .ring {
            pack.ringInsertionDate = startDate
        }

        let candidates = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: pack,
            calendar: calendar
        )

        var statusByEpochDay: [Int: PillDay.Status] = [:]
        for epoch in takenEpochs {
            statusByEpochDay[epoch] = .taken
        }

        return ReminderSchedulePlanner.Input(
            now: now,
            pack: pack,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            autoReminderIntervalMinutes: intervalMinutes,
            autoReminderRetryLimit: retryLimit,
            refillReminderThresholdDays: 5,
            patchRestockReminderThresholdPatches: 1,
            candidateDueActions: candidates,
            statusByEpochDay: statusByEpochDay,
            snoozeOverride: nil,
            smartRemindersEnabled: smartRemindersEnabled,
            cycleTransitionEnabled: false,
            lastCallEnabled: lastCallEnabled,
            lastCallHour: lastCallHour,
            lastCallMinute: lastCallMinute,
            calendar: calendar
        )
    }

    private func dueIntents(_ input: ReminderSchedulePlanner.Input) -> [ReminderSchedulePlanner.DueReminderIntent] {
        planner.planReminders(input).compactMap { intent in
            if case .due(let due) = intent { return due }
            return nil
        }
    }

    func testFiresLastCallOnUntakenDay() {
        let now = date("2026-05-26", hour: 7)
        let todayEpoch = epochDay(for: now)

        let today = dueIntents(makeInput(now: now, lastCallEnabled: true))
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(today.filter { $0.kind == .lastCall }.count, 1)
        XCTAssertEqual(today.filter { $0.kind == .base }.count, 1)
    }

    func testNoLastCallWhenDisabled() {
        let now = date("2026-05-26", hour: 7)
        let intents = dueIntents(makeInput(now: now, lastCallEnabled: false))
        XCTAssertTrue(intents.filter { $0.kind == .lastCall }.isEmpty)
    }

    func testFiresLastCallWhenRetryLimitIsZero() {
        let now = date("2026-05-26", hour: 7)
        let todayEpoch = epochDay(for: now)

        let today = dueIntents(makeInput(now: now, retryLimit: 0, lastCallEnabled: true))
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(today.filter { $0.kind == .lastCall }.count, 1)
        XCTAssertEqual(today.filter { $0.kind == .retry }.count, 0)
    }

    func testSuppressedUnderSixtyMinuteGap() {
        let now = date("2026-05-26", hour: 7)
        let todayEpoch = epochDay(for: now)

        // 8:30 Last Call is only 30 minutes after the 8:00 reminder — suppressed.
        let today = dueIntents(makeInput(
            now: now,
            reminderHour: 8,
            lastCallEnabled: true,
            lastCallHour: 8,
            lastCallMinute: 30
        ))
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertTrue(today.filter { $0.kind == .lastCall }.isEmpty)
        XCTAssertEqual(today.filter { $0.kind == .base }.count, 1)
    }

    func testAllowedAtExactlySixtyMinuteGap() {
        let now = date("2026-05-26", hour: 7)
        let todayEpoch = epochDay(for: now)

        let today = dueIntents(makeInput(
            now: now,
            reminderHour: 8,
            lastCallEnabled: true,
            lastCallHour: 9,
            lastCallMinute: 0
        ))
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(today.filter { $0.kind == .lastCall }.count, 1)
    }

    func testSuppressedOnTakenDay() {
        let now = date("2026-05-26", hour: 7)
        let todayEpoch = epochDay(for: now)

        let intents = dueIntents(makeInput(
            now: now,
            lastCallEnabled: true,
            takenEpochs: [todayEpoch]
        ))

        XCTAssertFalse(intents.contains { $0.dueDayEpoch == todayEpoch && $0.kind == .lastCall })
        XCTAssertTrue(intents.contains { $0.kind == .lastCall }) // still on for other days
    }

    func testGatedOffForFreeUser() {
        let now = date("2026-05-26", hour: 7)

        let plus = dueIntents(makeInput(now: now, smartRemindersEnabled: true, lastCallEnabled: true))
        let free = dueIntents(makeInput(now: now, smartRemindersEnabled: false, lastCallEnabled: true))

        XCTAssertTrue(plus.contains { $0.kind == .lastCall })
        XCTAssertTrue(free.filter { $0.kind == .lastCall }.isEmpty)
    }

    func testDropsRetryWithinGuardWindowOfLastCall() {
        let now = date("2026-05-26", hour: 7)
        let todayEpoch = epochDay(for: now)
        let guardWindow = TimeInterval(ReminderSchedulePlanner.lastCallRetryGuardMinutes * 60)

        // 30-minute cadence from 8:00 lands a retry exactly on the 21:00 Last Call.
        let withLastCall = dueIntents(makeInput(
            now: now,
            reminderHour: 8,
            intervalMinutes: 30,
            retryLimit: 100,
            lastCallEnabled: true,
            lastCallHour: 21
        ))
        .filter { $0.dueDayEpoch == todayEpoch }

        let lastCall = withLastCall.first { $0.kind == .lastCall }
        XCTAssertNotNil(lastCall)
        let lastCallDate = lastCall!.fireDate
        XCTAssertFalse(withLastCall.contains {
            $0.kind == .retry && abs($0.fireDate.timeIntervalSince(lastCallDate)) <= guardWindow
        })

        // Without the Last Call, a retry does land in that window — proving the dedupe acted.
        let withoutLastCall = dueIntents(makeInput(
            now: now,
            reminderHour: 8,
            intervalMinutes: 30,
            retryLimit: 100,
            lastCallEnabled: false
        ))
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertTrue(withoutLastCall.contains {
            $0.kind == .retry && abs($0.fireDate.timeIntervalSince(lastCallDate)) <= guardWindow
        })
    }

    func testPreSchedulesAtMostOnePerDayAcrossHorizon() {
        let now = date("2026-05-26", hour: 7)

        let lastCalls = dueIntents(makeInput(now: now, lastCallEnabled: true))
            .filter { $0.kind == .lastCall }
        let distinctDays = Set(lastCalls.map(\.dueDayEpoch))

        XCTAssertGreaterThanOrEqual(distinctDays.count, 2)
        XCTAssertEqual(lastCalls.count, distinctDays.count)
        XCTAssertLessThanOrEqual(lastCalls.count, ReminderSchedulePlanner.maxPendingReminders)
    }

    func testFiresForAllMethods() {
        let now = date("2026-05-26", hour: 7)

        for method in [ContraceptiveMethod.pill, .patch, .ring] {
            let lastCalls = dueIntents(makeInput(now: now, method: method, lastCallEnabled: true))
                .filter { $0.kind == .lastCall }
            XCTAssertFalse(lastCalls.isEmpty, "Expected a Last Call for method \(method)")
        }
    }
}
