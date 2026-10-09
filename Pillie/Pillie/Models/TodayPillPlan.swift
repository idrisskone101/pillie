//
//  TodayPillPlan.swift
//  Pillie
//

import Foundation

struct TodayPillPlan: Equatable {
    enum NextReminder: Equatable {
        case today(Date)
        case tomorrow(Date)
        case later(Date)
    }

    let pick: TodayPillPick
    let reminderHour: Int
    let reminderMinute: Int
    var now: Date = PillieClock.now
    var calendar: Calendar = .current
    var locale: Locale = PillieLocalization.appLocale

    static func nextReminder(hour: Int, minute: Int, now: Date, calendar: Calendar = .current) -> NextReminder {
        let today = calendar.startOfDay(for: now)
        let todays = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? now
        if todays > now {
            return .today(todays)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return .tomorrow(calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? todays)
    }

    /// The first reminder the planner sends once this pick commits. A pill not taken
    /// yet past today's reminder time gets its catch-up a minute later. A pill-free
    /// day gets the break notice only on the first one, while its time is ahead;
    /// otherwise nothing comes until the new pack's first pill.
    var firstReminder: NextReminder {
        let today = calendar.startOfDay(for: now)
        let todays = calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: today) ?? now
        switch pick.answer {
        case .notYet where todays <= now:
            return .today(now.addingTimeInterval(60))
        case nil where !(pick.dayIndex == pick.pack.regimen.activeDays && todays > now):
            let daysToNewPack = pick.pack.regimen.totalDays - pick.dayIndex
            guard let newPackDay = calendar.date(byAdding: .day, value: daysToNewPack, to: today),
                  let reminder = calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: newPackDay)
            else { break }
            return daysToNewPack == 1 ? .tomorrow(reminder) : .later(reminder)
        default:
            break
        }
        return Self.nextReminder(hour: reminderHour, minute: reminderMinute, now: now, calendar: calendar)
    }

    var rows: [ProtectionPlanRoutineSummary.Row] {
        [
            ProtectionPlanRoutineSummary.Row(
                symbol: "pills.fill",
                label: PillieLocalization.string("today.pack.noun.pill", locale: locale),
                value: pick.pack.displayName(locale: locale)
            ),
            ProtectionPlanRoutineSummary.Row(
                symbol: "number",
                label: PillieLocalization.string("today.navigation.title", locale: locale),
                value: todayText
            ),
            ProtectionPlanRoutineSummary.Row(
                symbol: "bell.fill",
                label: PillieLocalization.string("onboarding.today_pill.plan.next_reminder", locale: locale),
                value: nextReminderText
            ),
        ]
    }

    private var todayText: String {
        let day = pick.day
        switch pick.answer {
        case .taken:
            return PillieLocalization.formatted("onboarding.today_pill.plan.pill_taken", locale: locale, arguments: day.number)
        case .notYet:
            return PillieLocalization.formatted("onboarding.today_pill.plan.pill_not_yet", locale: locale, arguments: day.number)
        case nil:
            let breakDay = day.number - pick.pack.regimen.activeDays
            return PillieLocalization.formatted("pack_card.tile.break_day", locale: locale, arguments: breakDay)
        }
    }

    private var nextReminderText: String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        switch firstReminder {
        case .today(let date):
            return PillieLocalization.formatted("onboarding.today_pill.plan.today_at", locale: locale, arguments: date.formatted(style))
        case .tomorrow(let date):
            return PillieLocalization.formatted("onboarding.today_pill.plan.tomorrow_at", locale: locale, arguments: date.formatted(style))
        case .later(let date):
            return date.formatted(
                Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                    .weekday(.abbreviated).month(.abbreviated).day().hour().minute()
            )
        }
    }
}
