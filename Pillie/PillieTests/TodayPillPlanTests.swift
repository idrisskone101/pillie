//
//  TodayPillPlanTests.swift
//  PillieTests
//
//  ENG-138: the step 8 plan card rows for the pill path.
//  Value types only, so the Xcode 27 beta @MainActor deinit crash cannot fire.
//

import XCTest

@testable import Pillie

@MainActor
final class TodayPillPlanTests: XCTestCase {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func pick(_ index: Int, _ answer: TodayPillPick.Answer?, _ regimen: PillPack.PillRegimenPreset = .twentyOneSeven) -> TodayPillPick {
        TodayPillPick(regimen: regimen, pillIndex: index, answer: answer)!
    }

    // MARK: Step 8 plan card

    func testNextReminderIsTheNextOccurrenceStrictlyAfterNow() {
        let before = TodayPillPlan.nextReminder(hour: 20, minute: 0, now: date(27, 12, 24), calendar: Self.calendar)
        XCTAssertEqual(before, .today(date(27, 20)))

        let after = TodayPillPlan.nextReminder(hour: 8, minute: 0, now: date(27, 12, 24), calendar: Self.calendar)
        XCTAssertEqual(after, .tomorrow(date(28, 8)))

        let exactlyNow = TodayPillPlan.nextReminder(hour: 12, minute: 24, now: date(27, 12, 24), calendar: Self.calendar)
        XCTAssertEqual(exactlyNow, .tomorrow(date(28, 12, 24)))
    }

    func testPlanRowsNameThePackTheTappedNumberAndTheNextReminder() {
        let locale = Locale(identifier: "en_US")
        var calendar = Self.calendar
        calendar.locale = locale

        let taken = TodayPillPlan(pick: pick(11, .taken), reminderHour: 20, reminderMinute: 0, now: date(27, 21, 5), calendar: calendar, locale: locale)
        XCTAssertEqual(taken.rows.map(\.value), ["Standard", "Pill 12 · taken", "Tomorrow, 8:00\u{202F}PM"])
        XCTAssertEqual(taken.rows.map(\.label), ["Pack", "Today", "Next reminder"])

        let notYet = TodayPillPlan(pick: pick(11, .notYet), reminderHour: 20, reminderMinute: 0, now: date(27, 12, 24), calendar: calendar, locale: locale)
        XCTAssertEqual(notYet.rows.map(\.value), ["Standard", "Pill 12 · not yet", "Today, 8:00\u{202F}PM"])

        let breakDay = TodayPillPlan(pick: pick(23, nil, .twentyOneOnly), reminderHour: 20, reminderMinute: 0, now: date(27, 12, 24), calendar: calendar, locale: locale)
        XCTAssertEqual(breakDay.rows[1].value, "Break day 3")
    }
}
