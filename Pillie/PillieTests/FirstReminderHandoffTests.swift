import Foundation
import Testing

@testable import Pillie

struct FirstReminderHandoffTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func resolve(
        installedAt: Date?,
        reminderHour: Int,
        reminderMinute: Int = 0,
        now: Date? = nil,
        hasLoggedAnything: Bool = false
    ) -> FirstReminderHandoff? {
        FirstReminderHandoff.resolve(
            installedAt: installedAt,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            now: now ?? installedAt ?? date(1, 0),
            hasLoggedAnything: hasLoggedAnything,
            calendar: calendar
        )
    }

    @Test func middayInstallWithEveningReminderIsTonight() {
        #expect(resolve(installedAt: date(24, 12, 30), reminderHour: 20)?.when == .tonight)
    }

    @Test func afternoonReminderTheSameDayIsToday() {
        #expect(resolve(installedAt: date(24, 9), reminderHour: 15)?.when == .today)
    }

    @Test func earlyMorningInstallBeforeAMorningReminderIsThisMorning() {
        #expect(resolve(installedAt: date(24, 2), reminderHour: 8)?.when == .thisMorning)
    }

    @Test func nightInstallWithMorningReminderIsTomorrowMorning() {
        #expect(resolve(installedAt: date(24, 22), reminderHour: 8)?.when == .tomorrowMorning)
    }

    @Test func installAfterTheEveningReminderIsTomorrowAt() {
        #expect(resolve(installedAt: date(24, 21), reminderHour: 20)?.when == .tomorrow)
    }

    @Test func installAtTheReminderMinuteWaitsForTomorrow() {
        #expect(resolve(installedAt: date(24, 20), reminderHour: 20)?.when == .tomorrow)
    }

    @Test func minutesCountTowardTheFirstFire() {
        #expect(resolve(installedAt: date(24, 20, 10), reminderHour: 20, reminderMinute: 5)?.when == .tomorrow)
        #expect(resolve(installedAt: date(24, 20, 10), reminderHour: 20, reminderMinute: 30)?.when == .tonight)
    }

    @Test func aNightInstallReadPastMidnightNoLongerSaysTomorrow() {
        let installedAt = date(24, 21)
        #expect(resolve(installedAt: installedAt, reminderHour: 20, now: date(25, 1))?.when == .tonight)
    }

    @Test func loggingAnythingEndsTheHandoff() {
        #expect(resolve(installedAt: date(24, 12), reminderHour: 20, hasLoggedAnything: true) == nil)
    }

    @Test func atAndAfterTheFirstFireTheHandoffIsGone() {
        let installedAt = date(24, 12)
        #expect(resolve(installedAt: installedAt, reminderHour: 20, now: date(24, 19, 59))?.when == .tonight)
        #expect(resolve(installedAt: installedAt, reminderHour: 20, now: date(24, 20)) == nil)
        #expect(resolve(installedAt: installedAt, reminderHour: 20, now: date(25, 9)) == nil)
    }

    @Test func installsWithoutARecordKeepTodaysBehavior() {
        #expect(resolve(installedAt: nil, reminderHour: 20, now: date(24, 12)) == nil)
    }

    @Test func englishLines() {
        let en = Locale(identifier: "en")
        #expect(FirstReminderHandoff(when: .tonight).localizedLine(reminderTime: "8:00 PM", locale: en)
            == "Your first reminder is tonight at 8:00 PM.")
        #expect(FirstReminderHandoff(when: .thisMorning).localizedLine(reminderTime: "8:00 AM", locale: en)
            == "Your first reminder is this morning at 8:00 AM.")
        #expect(FirstReminderHandoff(when: .today).localizedLine(reminderTime: "3:00 PM", locale: en)
            == "Your first reminder is today at 3:00 PM.")
        #expect(FirstReminderHandoff(when: .tomorrowMorning).localizedLine(reminderTime: "8:00 AM", locale: en)
            == "Your first reminder is tomorrow morning at 8:00 AM.")
        #expect(FirstReminderHandoff(when: .tomorrow).localizedLine(reminderTime: "8:00 PM", locale: en)
            == "Your first reminder is tomorrow at 8:00 PM.")
    }
}
