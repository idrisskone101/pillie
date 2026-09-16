#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct ReminderWallClockTests {
    @Test(arguments: [
        (zone: "America/New_York", hour: 6, minute: 0),
        (zone: "America/New_York", hour: 18, minute: 30),
        (zone: "America/Chicago", hour: 6, minute: 0),
        (zone: "America/Los_Angeles", hour: 6, minute: 0),
        (zone: "Europe/Paris", hour: 6, minute: 0),
        (zone: "Europe/Paris", hour: 20, minute: 5),
        (zone: "Australia/Sydney", hour: 6, minute: 0),
        (zone: "America/Lima", hour: 6, minute: 0),
    ])
    func pickerRoundTripsStoredHourInSeptember(
        zone: String,
        hour: Int,
        minute: Int
    ) throws {
        let calendar = try calendar(in: zone)
        let now = try septemberAfternoon(calendar: calendar)
        let seeded = ReminderTimeConverter.dateForPicker(
            hour: hour,
            minute: minute,
            now: now,
            calendar: calendar
        )
        let extracted = ReminderTimeConverter.hourAndMinute(from: seeded, calendar: calendar)
        #expect(extracted.hour == hour)
        #expect(extracted.minute == minute)
    }

    @Test func deviceActivityBoundsKeepLocalHourAndTimeZone() throws {
        let calendar = try calendar(in: "America/New_York")
        let bounds = DoseWindow.deviceActivityBounds(
            hour: 6,
            minute: 0,
            calendar: calendar
        )

        #expect(bounds.start.hour == 6)
        #expect(bounds.start.minute == 0)
        #expect(bounds.start.timeZone == calendar.timeZone)
        #expect(bounds.start.calendar == calendar)
        #expect(bounds.end.hour == 5)
        #expect(bounds.end.minute == 59)
        #expect(bounds.end.timeZone == calendar.timeZone)
        #expect(bounds.end.calendar == calendar)
    }

    @Test func settingsTimeKeepsTheStoredHourInUSEnglish() {
        #expect(SettingsPresentation.time(hour: 6, minute: 0, locale: Locale(identifier: "en_US")) == "6:00 AM")
        #expect(SettingsPresentation.time(hour: 18, minute: 0, locale: Locale(identifier: "en_US")) == "6:00 PM")
    }

    @Test func fourPMIsStillYesterdayWhenReminderIsSixPM() throws {
        let calendar = try calendar(in: "America/New_York")
        let fourPM = try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 16,
            hour: 16
        )))
        let liveDay = BlockingInterventionPolicy.liveDay(
            now: fourPM,
            reminderHour: 18,
            reminderMinute: 0,
            calendar: calendar
        )
        #expect(calendar.component(.day, from: liveDay) == 15)
    }

    private func calendar(in identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    private func septemberAfternoon(calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 16,
            hour: 15
        )))
    }
}
#endif
