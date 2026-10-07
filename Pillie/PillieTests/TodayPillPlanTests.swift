//
//  TodayPillPlanTests.swift
//  PillieTests
//

// Value types only, so the Xcode 27 beta @MainActor deinit crash cannot fire.

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
        TodayPillPick(pack: PackChoice(preset: regimen), dayIndex: index, answer: answer)!
    }

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

        let customPick = TodayPillPick(pack: PackChoice(PackRegimen(activeDays: 88, breakDays: 3, breakKind: .noPills)), dayIndex: 89, answer: nil)!
        let custom = TodayPillPlan(pick: customPick, reminderHour: 20, reminderMinute: 0, now: date(27, 12, 24), calendar: calendar, locale: locale)
        XCTAssertEqual(custom.rows.map(\.value), ["88 + 3", "Break day 2", "Tue, Sep 29 at 8:00\u{202F}PM"])
    }

    private func nextReminderRow(_ pick: TodayPillPick, hour: Int, now: Date) -> String {
        let locale = Locale(identifier: "en_US")
        var calendar = Self.calendar
        calendar.locale = locale
        return TodayPillPlan(pick: pick, reminderHour: hour, reminderMinute: 0, now: now, calendar: calendar, locale: locale).rows[2].value
    }

    /// Past today's reminder time, a pill not taken yet gets its catch-up reminder a minute after setup.
    func testANotYetPillPastTheReminderTimeIsRemindedRightAway() {
        XCTAssertEqual(nextReminderRow(pick(11, .notYet), hour: 8, now: date(27, 12, 24)), "Today, 12:25\u{202F}PM")
    }

    /// A pill-free day after the first one gets no reminder; the next is the new pack's first pill.
    func testAPillFreeDayIsRemindedOnTheNewPacksFirstPill() {
        XCTAssertEqual(nextReminderRow(pick(23, nil, .twentyOneOnly), hour: 20, now: date(27, 12, 24)), "Fri, Oct 2 at 8:00\u{202F}PM")
    }

    /// The first pill-free day still gets its break notice at the reminder time.
    func testTheFirstPillFreeDayKeepsTonightsNotice() {
        XCTAssertEqual(nextReminderRow(pick(21, nil, .twentyOneOnly), hour: 20, now: date(27, 12, 24)), "Today, 8:00\u{202F}PM")
    }
}
