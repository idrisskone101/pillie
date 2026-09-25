//
//  StatusCardTitle.swift
//  Pillie
//

import Foundation

/// The line under the reminder time on Home's status card.
enum StatusCardTitle: Equatable {
    case nothingDue
    case due(DoseScheduleAction)
    case completed
    case next(on: Date, NextDoseDay)

    /// `alarmAction` is the next untaken due action from the live day.
    static func resolve(
        alarmAction: DoseScheduleAction?,
        today: Date,
        isTodayTaken: Bool,
        isTodayPassiveOrBreak: Bool,
        calendar: Calendar = .current
    ) -> StatusCardTitle {
        guard let alarmAction else { return .nothingDue }
        let day = NextDoseDay.resolve(today: today, next: alarmAction.date, calendar: calendar)
        if day == .today {
            if isTodayTaken { return .completed }
            return isTodayPassiveOrBreak ? .nothingDue : .due(alarmAction)
        }
        guard isTodayTaken || isTodayPassiveOrBreak else { return .due(alarmAction) }
        return .next(on: alarmAction.date, day)
    }

    func localized(reminderTime: String, locale: Locale) -> String {
        switch self {
        case .nothingDue:
            PillieLocalization.string("today.empty.title", locale: locale)
        case .due(let action):
            DueActionCopy.localizedLabel(for: action, locale: locale)
        case .completed:
            PillieLocalization.string("global.status.completed", locale: locale)
        case .next(let date, let day):
            day.localizedLine(for: date, reminderTime: reminderTime, locale: locale)
        }
    }
}

/// Where the next dose falls relative to the live day, in calendar weeks.
enum NextDoseDay: Equatable {
    case today
    case tomorrow
    case thisWeek
    /// The calendar week right after this one, never further.
    case nextWeek
    /// Anything the named-day phrases cannot say truthfully.
    case onDate

    static func resolve(today: Date, next: Date, calendar: Calendar = .current) -> NextDoseDay {
        let start = calendar.startOfDay(for: today)
        let target = calendar.startOfDay(for: next)
        guard let days = calendar.dateComponents([.day], from: start, to: target).day else {
            return .onDate
        }
        switch days {
        case 0: return .today
        case 1: return .tomorrow
        case ..<0: return .onDate
        default: break
        }
        guard
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start,
            let targetWeek = calendar.dateInterval(of: .weekOfYear, for: target)?.start
        else {
            return .onDate
        }
        if targetWeek == thisWeek {
            return .thisWeek
        }
        if calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeek) == targetWeek {
            return .nextWeek
        }
        return .onDate
    }

    /// Weekday names arrive in their dictionary form, so every catalog frame
    /// must read correctly with a bare weekday of any gender.
    func localizedLine(for date: Date, reminderTime: String, locale: Locale) -> String {
        let weekday = date.formatted(Date.FormatStyle().weekday(.wide).locale(locale))
        switch self {
        case .tomorrow:
            return PillieLocalization.formatted(
                "today.next_action.tomorrow",
                locale: locale,
                arguments: reminderTime
            )
        case .thisWeek:
            return PillieLocalization.formatted(
                "today.next_action.weekday",
                locale: locale,
                arguments: weekday, reminderTime
            )
        case .nextWeek:
            return PillieLocalization.formatted(
                "today.next_action.next_week",
                locale: locale,
                arguments: weekday, reminderTime
            )
        case .today, .onDate:
            let day = date.formatted(Date.FormatStyle().month(.wide).day().locale(locale))
            return PillieLocalization.formatted(
                "today.next_action.date",
                locale: locale,
                arguments: day, reminderTime
            )
        }
    }
}
