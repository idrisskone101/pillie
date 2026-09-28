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
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
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
            guard
                let reminder = DoseWindow.reminder(
                    for: day, hour: reminderHour, minute: reminderMinute, calendar: calendar
                ),
                let deadline = DoseWindow.deadline(
                    for: day, hour: reminderHour, minute: reminderMinute, calendar: calendar
                )
            else { return nil }
            return now < reminder ? .upcoming : .late(until: deadline)
        }
    }
}
