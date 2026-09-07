//
//  DoseWindow.swift
//  Pillie
//

import Foundation

/// A due action stays completable until the next reminder, not calendar midnight.
enum DoseWindow {
    static func deadline(
        for day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date? {
        let start = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: nextDay)
    }

    static func isOpen(
        day: Date,
        now: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard let deadline = deadline(for: day, hour: hour, minute: minute, calendar: calendar) else {
            return calendar.startOfDay(for: day) >= calendar.startOfDay(for: now)
        }
        return now < deadline
    }

    /// Changes at local midnight and again at today's reminder time.
    static func contextToken(
        now: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: now)
        let epoch = Int(start.timeIntervalSince1970)
        let reminder = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
        let pastReminder = reminder.map { now >= $0 } ?? false
        return epoch &* 2 &+ (pastReminder ? 1 : 0)
    }

    static func activeDoseDate(
        now: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current,
        isYesterdayStillDue: (Date) -> Bool
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        guard
            let reminderToday = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today),
            now < reminderToday,
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            isYesterdayStillDue(yesterday)
        else {
            return today
        }
        return yesterday
    }
}
