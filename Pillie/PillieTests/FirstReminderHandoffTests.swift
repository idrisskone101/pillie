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
        hasLoggedAnything: Bool = false,
        isDoseDue: Bool = false
    ) -> FirstReminderHandoff? {
        FirstReminderHandoff.resolve(
            installedAt: installedAt,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            now: now ?? installedAt ?? date(1, 0),
            hasLoggedAnything: hasLoggedAnything,
            isDoseDue: isDoseDue,
            calendar: calendar
        )
    }

    @Test func morningInstallWithEveningReminderIsTonight() {
        #expect(resolve(installedAt: date(24, 9), reminderHour: 20)?.when == .tonight)
    }

    @Test func morningInstallWithAfternoonReminderIsThisAfternoon() {
        #expect(resolve(installedAt: date(24, 10), reminderHour: 15)?.when == .thisAfternoon)
    }

    @Test func earlyMorningInstallBeforeAMorningReminderIsThisMorning() {
        #expect(resolve(installedAt: date(24, 2), reminderHour: 8)?.when == .thisMorning)
    }

    @Test func nightInstallWithMorningReminderIsTomorrowMorning() {
        #expect(resolve(installedAt: date(24, 22), reminderHour: 8)?.when == .tomorrowMorning)
    }

    @Test func nightInstallWithAfternoonReminderIsTomorrowAfternoon() {
        #expect(resolve(installedAt: date(24, 22), reminderHour: 14)?.when == .tomorrowAfternoon)
    }

    @Test func installAfterTheEveningReminderIsTomorrowNight() {
        #expect(resolve(installedAt: date(24, 21), reminderHour: 20)?.when == .tomorrowNight)
    }

    @Test func installAtTheReminderMinuteWaitsForTomorrow() {
        #expect(resolve(installedAt: date(24, 20), reminderHour: 20)?.when == .tomorrowNight)
    }

    @Test func minutesCountTowardTheFirstFire() {
        #expect(resolve(installedAt: date(24, 20, 10), reminderHour: 20, reminderMinute: 5)?.when == .tomorrowNight)
        #expect(resolve(installedAt: date(24, 20, 10), reminderHour: 20, reminderMinute: 30)?.when == .tonight)
    }

    @Test func aNightInstallReadPastMidnightNoLongerSaysTomorrow() {
        let installedAt = date(24, 21)
        #expect(resolve(installedAt: installedAt, reminderHour: 20, now: date(25, 1))?.when == .tonight)
    }

    @Test func loggingAnythingEndsTheHandoff() {
        #expect(resolve(installedAt: date(24, 12), reminderHour: 20, hasLoggedAnything: true) == nil)
    }

    @Test func aNotYetPillPastItsReminderIsDueNotTomorrow() {
        #expect(resolve(installedAt: date(24, 21), reminderHour: 8, isDoseDue: true) == nil)
        #expect(resolve(installedAt: date(24, 21), reminderHour: 20, isDoseDue: true) == nil)
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
        let line = { (when: FirstReminderHandoff.When) in FirstReminderHandoff(when: when).localizedLine(locale: en) }
        #expect(line(.thisMorning) == "Your first reminder is this morning")
        #expect(line(.thisAfternoon) == "Your first reminder is this afternoon")
        #expect(line(.tonight) == "Your first reminder is tonight")
        #expect(line(.tomorrowMorning) == "Your first reminder is tomorrow morning")
        #expect(line(.tomorrowAfternoon) == "Your first reminder is tomorrow afternoon")
        #expect(line(.tomorrowNight) == "Your first reminder is tomorrow night")
    }

    @Test func cardLineIsTheSameForEveryMoment() {
        let en = Locale(identifier: "en")
        let moments: [FirstReminderHandoff.When] = [
            .thisMorning, .thisAfternoon, .tonight, .tomorrowMorning, .tomorrowAfternoon, .tomorrowNight,
        ]
        for when in moments {
            #expect(FirstReminderHandoff(when: when).cardLine(locale: en) == "First reminder")
        }
    }
}
