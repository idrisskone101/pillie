//
//  CycleTransitionNoticeTests.swift
//  PillieTests
//
//  Pure value-type coverage for the free Cycle Transition Notice (#123). These exercise
//  `ReminderSchedulePlanner` and `CycleTransitionCopy` directly with a bare `PillPack`,
//  with no `@MainActor` `PillStore` / SwiftData `ModelContainer`, so they run on the
//  Xcode 27 beta despite the hosted-XCTest `@MainActor` deinit instability. The
//  store-backed equivalents live in `ReminderSchedulePlannerTests`.
//

import XCTest
@testable import Pillie

final class CycleTransitionNoticeTests: XCTestCase {
    private let planner = ReminderSchedulePlanner()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
    }

    private func pack(
        method: ContraceptiveMethod,
        regimen: PillPack.PillRegimenPreset = .twentyOneSeven,
        startDate: Date,
        ringInsertionDate: Date? = nil
    ) -> PillPack {
        let pack = PillPack(
            method: method,
            pillRegimen: method == .pill ? regimen : .twentyOneSeven,
            startDate: startDate,
            packNumber: 1
        )
        pack.ringInsertionDate = ringInsertionDate
        return pack
    }

    private func plan(
        pack: PillPack,
        now: Date,
        reminderHour: Int = 8,
        smartRemindersEnabled: Bool = true,
        cycleTransitionEnabled: Bool = true
    ) -> [ReminderSchedulePlanner.Intent] {
        planner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                pack: pack,
                reminderHour: reminderHour,
                reminderMinute: 0,
                autoReminderIntervalMinutes: 10,
                autoReminderRetryLimit: 3,
                refillReminderThresholdDays: 5,
                patchRestockReminderThresholdPatches: 1,
                candidateDueActions: [],
                statusByEpochDay: [:],
                snoozeOverride: nil,
                smartRemindersEnabled: smartRemindersEnabled,
                cycleTransitionEnabled: cycleTransitionEnabled,
                lastCallEnabled: false,
                lastCallHour: 21,
                lastCallMinute: 0,
                trialGrantDate: nil,
                hasEntitlement: false,
                servedBaseFireDateByDueDayEpoch: [:],
                calendar: calendar
            )
        )
    }

    private func notices(
        pack: PillPack,
        now: Date,
        smartRemindersEnabled: Bool = true,
        cycleTransitionEnabled: Bool = true
    ) -> [ReminderSchedulePlanner.CycleTransitionIntent] {
        plan(
            pack: pack,
            now: now,
            smartRemindersEnabled: smartRemindersEnabled,
            cycleTransitionEnabled: cycleTransitionEnabled
        )
        .compactMap { intent in
            if case .cycleTransition(let notice) = intent { return notice }
            return nil
        }
    }

    // MARK: - Fires on break-week start, per method

    func testPillNoticeFiresOnFirstPlaceboDay() throws {
        let start = day(2026, 5, 26) // cycle day 1, active
        let pack = pack(method: .pill, startDate: start)

        let notice = try XCTUnwrap(notices(pack: pack, now: start).first)
        XCTAssertEqual(notice.method, .pill)
        // 21/7: active days are 1...21, the placebo week starts on day 22 (start + 21).
        XCTAssertEqual(notice.transitionDayEpoch, Int(day(2026, 6, 16).timeIntervalSince1970))
        XCTAssertEqual(notice.fireDate, calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day(2026, 6, 16)))
    }

    func testPatchNoticeFiresOnFirstPatchFreeDay() throws {
        let start = day(2026, 5, 26)
        let pack = pack(method: .patch, startDate: start)

        let notice = try XCTUnwrap(notices(pack: pack, now: start).first)
        XCTAssertEqual(notice.method, .patch)
        // Patch: day 22 is the removal (its own Due Action Reminder); the silent off week
        // begins day 23 (start + 22).
        XCTAssertEqual(notice.transitionDayEpoch, Int(day(2026, 6, 17).timeIntervalSince1970))
    }

    func testRingNoticeFiresOnFirstRingFreeDay() throws {
        let start = day(2026, 5, 26)
        let pack = pack(method: .ring, startDate: start, ringInsertionDate: start)

        let notice = try XCTUnwrap(notices(pack: pack, now: start).first)
        XCTAssertEqual(notice.method, .ring)
        // Ring: day 22 is removal; the silent off week begins day 23 (start + 22).
        XCTAssertEqual(notice.transitionDayEpoch, Int(day(2026, 6, 17).timeIntervalSince1970))
    }

    // MARK: - Resume date

    func testNoticeCarriesNextActivePhaseResumeDate() throws {
        let start = day(2026, 5, 26)
        let pack = pack(method: .pill, startDate: start)

        let notice = try XCTUnwrap(notices(pack: pack, now: start).first)
        // The next pack starts on cycle day 1 of the following cycle (start + 28).
        XCTAssertEqual(notice.resumeDate, day(2026, 6, 23))

        // The resume day is active and the day before it is still a break day.
        XCTAssertEqual(DoseScheduleEngine.dueAction(on: notice.resumeDate, pack: pack, calendar: calendar)?.isBreak, false)
        let dayBefore = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: notice.resumeDate))
        XCTAssertEqual(DoseScheduleEngine.dueAction(on: dayBefore, pack: pack, calendar: calendar)?.isBreak, true)
    }

    // MARK: - Not gated by entitlement

    func testNoticeIsNotGatedBySmartReminders() throws {
        let start = day(2026, 5, 26)
        let pack = pack(method: .pill, startDate: start)

        let free = notices(pack: pack, now: start, smartRemindersEnabled: false)
        XCTAssertEqual(free.count, 1)
        XCTAssertEqual(free.first?.method, .pill)
    }

    func testNoticeDoesNotCatchUpOrRepeatAfterItsScheduledTime() {
        let start = day(2026, 5, 26)
        let pack = pack(method: .pill, startDate: start)
        let transitionDay = day(2026, 6, 16)
        let afterScheduledFire = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: transitionDay
        )!

        XCTAssertTrue(notices(pack: pack, now: afterScheduledFire).isEmpty)
    }

    // MARK: - Absent on the active-phase start / when disabled / continuous regimens

    func testNoticeNeverLandsOnActivePhaseStart() throws {
        let start = day(2026, 5, 26)
        let pack = pack(method: .pill, startDate: start)

        // Whatever the schedule, the transition day is always a break day — never the
        // active/new-pack start that already owns the day-1 Due Action Reminder.
        for offset in 0..<28 {
            let now = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start))
            for notice in notices(pack: pack, now: now) {
                let transitionDay = Date(timeIntervalSince1970: TimeInterval(notice.transitionDayEpoch))
                XCTAssertEqual(
                    DoseScheduleEngine.dueAction(on: transitionDay, pack: pack, calendar: calendar)?.isBreak,
                    true,
                    "Notice landed on a non-break day for offset \(offset)"
                )
            }
        }
    }

    func testNoNoticeWhenDisabled() {
        let start = day(2026, 5, 26)
        let pack = pack(method: .pill, startDate: start)
        XCTAssertTrue(notices(pack: pack, now: start, cycleTransitionEnabled: false).isEmpty)
    }

    func testNoNoticeForContinuousRegimenWithoutBreakWeek() {
        let start = day(2026, 5, 26)
        let pack = pack(method: .pill, regimen: .threeSixtyFiveZero, startDate: start)
        XCTAssertTrue(notices(pack: pack, now: start).isEmpty)
    }

    // MARK: - Copy is method-aware and names the resume date

    func testCopyIsMethodAwareAndNamesResumeDate() {
        let resume = day(2026, 6, 23)

        let titles = [
            CycleTransitionCopy.title(for: .pill),
            CycleTransitionCopy.title(for: .patch),
            CycleTransitionCopy.title(for: .ring)
        ]
        XCTAssertEqual(Set(titles).count, 3, "Titles should be method-aware")

        for method in ContraceptiveMethod.allCases {
            let body = CycleTransitionCopy.body(for: method, resumeDate: resume, calendar: calendar)
            XCTAssertFalse(body.isEmpty)
            XCTAssertTrue(body.contains("expected"), "Body should reassure the pause is expected")
            // No medical claims: never speaks to protection / safety / efficacy.
            let lowered = body.lowercased()
            for banned in ["protect", "safe", "effective", "efficacy"] {
                XCTAssertFalse(lowered.contains(banned), "Body must avoid medical claim: \(banned)")
            }
        }
    }
}
