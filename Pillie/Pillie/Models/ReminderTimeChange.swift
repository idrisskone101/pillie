//
//  ReminderTimeChange.swift
//  Pillie
//

import Foundation

/// A reminder time saved in Settings applies from the next dose day. Days already
/// lived keep the time they were lived under, so a late dose never turns missed
/// and a missed one never reopens because the reminder moved.
struct ReminderTimeChange: Codable, Equatable {
    struct Time: Codable, Equatable, Comparable {
        let hour: Int
        let minute: Int

        static func < (lhs: Time, rhs: Time) -> Bool {
            (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
        }
    }

    /// The first day on the new time; earlier days keep `previous`.
    let firstNewDay: Date
    let previous: Time
    /// The time `firstNewDay` opens at. When the live dose was late at the change,
    /// it is the later of the two times, so that dose's window cannot close early.
    let transition: Time

    /// The same change with `firstNewDay` kept on its date after a time zone change.
    func moved(writtenIn identifier: String?) -> ReminderTimeChange {
        ReminderTimeChange(
            firstNewDay: StoredDay.day(of: firstNewDay, writtenIn: identifier),
            previous: previous,
            transition: transition
        )
    }

    /// The change for moving from `previous` to `new` at `now`.
    static func moving(
        from previous: Time,
        to new: Time,
        at now: Date,
        pending: ReminderTimeChange?,
        liveDoseIsLate: (Date, ReminderClock) -> Bool,
        calendar: Calendar = .current
    ) -> ReminderTimeChange? {
        let before = ReminderClock(current: previous, change: pending, calendar: calendar)
        let liveDay = before.liveDay(at: now)
        guard let firstNewDay = calendar.date(byAdding: .day, value: 1, to: liveDay) else { return nil }
        let livedTime = before.time(on: liveDay)
        return ReminderTimeChange(
            firstNewDay: firstNewDay,
            previous: livedTime,
            transition: liveDoseIsLate(liveDay, before) ? max(livedTime, new) : new
        )
    }
}

/// The reminder moment of each dose day, honoring a reminder-time change.
struct ReminderClock {
    let current: ReminderTimeChange.Time
    let change: ReminderTimeChange?
    var calendar: Calendar = .current

    func time(on day: Date) -> ReminderTimeChange.Time {
        guard let change else { return current }
        let day = calendar.startOfDay(for: day)
        if day < change.firstNewDay { return change.previous }
        if day == change.firstNewDay { return change.transition }
        return current
    }

    func reminder(on day: Date) -> Date? {
        let time = time(on: day)
        return DoseWindow.reminder(for: day, hour: time.hour, minute: time.minute, calendar: calendar)
    }

    /// When `day`'s window closes: the next day's reminder.
    func deadline(for day: Date) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)).flatMap(reminder(on:))
    }

    func isOpen(day: Date, now: Date) -> Bool {
        guard let deadline = deadline(for: day) else {
            return calendar.startOfDay(for: day) >= calendar.startOfDay(for: now)
        }
        return now < deadline
    }

    /// The dose day open at `now`: from one reminder to the next.
    func liveDay(at now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        guard let reminder = reminder(on: today), now < reminder,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return today
        }
        return yesterday
    }
}
