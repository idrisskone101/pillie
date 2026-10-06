//
//  TodayPillPlan.swift
//  Pillie
//

import Foundation

struct TodayPillPlan: Equatable {
    enum NextReminder: Equatable {
        case today(Date)
        case tomorrow(Date)
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
        switch Self.nextReminder(hour: reminderHour, minute: reminderMinute, now: now, calendar: calendar) {
        case .today(let date):
            return PillieLocalization.formatted("onboarding.today_pill.plan.today_at", locale: locale, arguments: date.formatted(style))
        case .tomorrow(let date):
            return PillieLocalization.formatted("onboarding.today_pill.plan.tomorrow_at", locale: locale, arguments: date.formatted(style))
        }
    }
}
