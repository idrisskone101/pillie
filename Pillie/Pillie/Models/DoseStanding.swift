//
//  DoseStanding.swift
//  Pillie
//

import Foundation

enum DoseStanding: Hashable, Sendable {
    case upcoming
    case late(until: Date)
    case missed
    case taken

    static func resolve(
        action: PillDay.ActionType?,
        status: PillDay.Status,
        day: Date,
        packStartedAt: Date? = nil,
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar = .current
    ) -> DoseStanding? {
        resolve(
            action: action,
            status: status,
            day: day,
            packStartedAt: packStartedAt,
            now: now,
            reminder: DoseWindow.reminder(for: day, hour: reminderHour, minute: reminderMinute, calendar: calendar),
            deadline: DoseWindow.deadline(for: day, hour: reminderHour, minute: reminderMinute, calendar: calendar),
            calendar: calendar
        )
    }

    /// `reminder` opens `day`'s window and `deadline` closes it.
    static func resolve(
        action: PillDay.ActionType?,
        status: PillDay.Status,
        day: Date,
        packStartedAt: Date? = nil,
        now: Date,
        reminder: Date?,
        deadline: Date?,
        calendar: Calendar = .current
    ) -> DoseStanding? {
        guard action?.enforcesAdherence == true else { return nil }
        switch status {
        case .taken:
            return .taken
        case .missed:
            return .missed
        case .breakDay, .noData:
            return nil
        case .upcoming:
            guard let reminder, let deadline else { return nil }
            if startedAfterReminder(packStartedAt: packStartedAt, day: day, reminder: reminder, calendar: calendar) {
                return .upcoming
            }
            return now < reminder ? .upcoming : .late(until: deadline)
        }
    }

    /// A pack started after its first day's reminder never missed that reminder.
    static func startedAfterReminder(
        packStartedAt: Date?,
        day: Date,
        reminder: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let packStartedAt else { return false }
        return packStartedAt >= reminder && calendar.isDate(packStartedAt, inSameDayAs: day)
    }
}
