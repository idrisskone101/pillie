import Foundation
import Testing

@testable import Pillie

struct NextDoseDayTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func day(_ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    @Test(arguments: [1, 2])
    func thursdayBreakOpensNextMonday(firstWeekday: Int) {
        let calendar = calendar(firstWeekday: firstWeekday)
        let resolved = NextDoseDay.resolve(
            from: day(9, 24, in: calendar),
            to: day(9, 28, in: calendar),
            calendar: calendar
        )
        #expect(resolved == .nextWeek)
    }

    @Test(arguments: [1, 2])
    func namedDaysInsideTheWeek(firstWeekday: Int) {
        let calendar = calendar(firstWeekday: firstWeekday)
        let thursday = day(9, 24, in: calendar)
        #expect(NextDoseDay.resolve(from: thursday, to: thursday, calendar: calendar) == .today)
        #expect(NextDoseDay.resolve(from: thursday, to: day(9, 25, in: calendar), calendar: calendar) == .tomorrow)
        #expect(NextDoseDay.resolve(from: day(9, 22, in: calendar), to: day(9, 25, in: calendar), calendar: calendar) == .thisWeek)
    }

    @Test func pastDayIsNeverTomorrow() {
        let calendar = calendar(firstWeekday: 2)
        #expect(NextDoseDay.resolve(from: day(9, 24, in: calendar), to: day(9, 23, in: calendar), calendar: calendar) == .onDate)
    }

    /// Pill 21/7 logs day 21, then skips seven break days: the next dose is
    /// eight days out. From the last day of a week that is the week after next.
    @Test func eightDaysFromTheEndOfAMondayWeekIsADate() {
        let calendar = calendar(firstWeekday: 2)
        let sunday = day(9, 27, in: calendar)
        #expect(NextDoseDay.resolve(from: sunday, to: day(10, 5, in: calendar), calendar: calendar) == .onDate)
        #expect(NextDoseDay.resolve(from: day(9, 26, in: calendar), to: day(10, 4, in: calendar), calendar: calendar) == .nextWeek)
    }

    @Test func eightDaysFromTheEndOfASundayWeekIsADate() {
        let calendar = calendar(firstWeekday: 1)
        let saturday = day(9, 26, in: calendar)
        #expect(NextDoseDay.resolve(from: saturday, to: day(10, 4, in: calendar), calendar: calendar) == .onDate)
        #expect(NextDoseDay.resolve(from: day(9, 27, in: calendar), to: day(10, 5, in: calendar), calendar: calendar) == .nextWeek)
    }
}

struct StatusCardTitleTests {
    private func local(_ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func pill(on date: Date) -> DoseScheduleAction {
        DoseScheduleAction(date: date, type: .pillActive, method: .pill, cycleDay: 1, cycleLength: 28)
    }

    private func resolve(
        alarmOn alarmDate: Date?,
        taken: Bool = false,
        breakDay: Bool = false
    ) -> StatusCardTitle {
        StatusCardTitle.resolve(
            alarmAction: alarmDate.map(pill(on:)),
            liveDay: local(9, 24),
            now: local(9, 24),
            isTodayTaken: taken,
            isTodayPassiveOrBreak: breakDay
        )
    }

    @Test func dueTodayShowsTheAction() {
        #expect(resolve(alarmOn: local(9, 24)) == .due(pill(on: local(9, 24))))
    }

    @Test func takenNamesTheNextDose() {
        #expect(resolve(alarmOn: local(9, 25), taken: true) == .next(on: local(9, 25), .tomorrow))
    }

    /// Wednesday is logged at 6 AM Thursday, before the 8 AM reminder: the live
    /// day is still Wednesday, but Thursday's dose is today on the calendar.
    @Test func loggedBeforeTheReminderReadsToday() throws {
        let calendar = Calendar.current
        let wednesday = local(9, 23)
        let thursdaySix = try #require(calendar.date(bySettingHour: 6, minute: 0, second: 0, of: local(9, 24)))
        let title = StatusCardTitle.resolve(
            alarmAction: pill(on: local(9, 24)),
            liveDay: wednesday,
            now: thursdaySix,
            isTodayTaken: true,
            isTodayPassiveOrBreak: false
        )
        #expect(title == .next(on: local(9, 24), .today))
        #expect(title.localized(reminderTime: "8:00 AM", locale: Locale(identifier: "en"))
            == "Your next one is today at 8:00 AM.")
    }

    @Test func breakDayNamesTheNextDose() {
        #expect(resolve(alarmOn: local(9, 28), breakDay: true) == .next(on: local(9, 28), .nextWeek))
    }

    @Test func breakDayWithTheAlarmTodayIsNothingDue() {
        #expect(resolve(alarmOn: local(9, 24), breakDay: true) == .nothingDue)
    }

    @Test func noAlarmIsNothingDue() {
        #expect(resolve(alarmOn: nil, taken: true) == .nothingDue)
        #expect(resolve(alarmOn: nil, breakDay: true) == .nothingDue)
    }

    @Test func englishLines() {
        let en = Locale(identifier: "en")
        #expect(StatusCardTitle.next(on: local(9, 25), .tomorrow).localized(reminderTime: "8:00 AM", locale: en)
            == "Your next one is tomorrow at 8:00 AM.")
        #expect(StatusCardTitle.next(on: local(9, 26), .thisWeek).localized(reminderTime: "8:00 AM", locale: en)
            == "Your next one is on Saturday at 8:00 AM.")
        #expect(StatusCardTitle.next(on: local(9, 28), .nextWeek).localized(reminderTime: "8:00 AM", locale: en)
            == "Your next due date is next Monday at 8:00 AM.")
        #expect(StatusCardTitle.next(on: local(10, 5), .onDate).localized(reminderTime: "8:00 AM", locale: en)
            == "Your next one is on October 5 at 8:00 AM.")
    }

    @Test func inflectedLanguagesKeepTheWeekdayBare() {
        #expect(StatusCardTitle.next(on: local(9, 23), .thisWeek).localized(reminderTime: "8:00", locale: Locale(identifier: "pl"))
            == "Następna: środa, godz. 8:00.")
        #expect(StatusCardTitle.next(on: local(9, 27), .nextWeek).localized(reminderTime: "8:00", locale: Locale(identifier: "it"))
            == "La prossima è domenica della settimana prossima alle 8:00.")
        #expect(StatusCardTitle.next(on: local(9, 23), .nextWeek).localized(reminderTime: "8:00", locale: Locale(identifier: "ru"))
            == "Следующий раз: среда на следующей неделе, в 8:00.")
    }
}
