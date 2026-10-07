//
//  WinbackCopy.swift
//  Pillie
//
//  Authored copy for the win-back pushes (ENG-173). Informational: never a
//  pregnancy scare, guilt, or fake urgency, and never a hint that reminders
//  stay free. Every key lives in `Notifications`; each line takes at most one
//  argument, the one its slot's `WinbackDetail` carries.
//

import Foundation

enum WinbackCopy {
    /// A reminder before 17:00 is a daytime one, so "tonight" would be false.
    static let eveningStartHour = 17

    static func title(
        for intent: WinbackIntent,
        locale: Locale = PillieLocalization.appLocale,
        calendar: Calendar = .current
    ) -> String {
        let key = titleKey(slot: intent.slot, variant: intent.variant, reminderHour: reminderHour(intent.detail))
        return localized(key, intent: intent, locale: locale, calendar: calendar)
    }

    static func body(
        for intent: WinbackIntent,
        locale: Locale = PillieLocalization.appLocale,
        calendar: Calendar = .current
    ) -> String {
        localized(bodyKey(slot: intent.slot, variant: intent.variant), intent: intent, locale: locale, calendar: calendar)
    }

    static func titleKey(slot: WinbackSlot, variant: WinbackVariant, reminderHour: Int) -> String {
        let daytime = reminderHour < eveningStartHour
        switch (slot, variant) {
        case (.dayAfter, .notAReminder):
            return "\(prefix).slot2.challenger.title"
        case (.dayAfter, .blocker):
            return daytime ? "\(prefix).slot2.blocker.day.title" : "\(prefix).slot2.blocker.title"
        case (.dayAfter, _):
            return daytime ? "\(prefix).slot2.day.title" : "\(prefix).slot2.title"
        case (.extendOffer, .restore):
            return "\(prefix).slot3.restore.title"
        default:
            return "\(prefix).slot\(slot.rawValue).title"
        }
    }

    static func bodyKey(slot: WinbackSlot, variant: WinbackVariant) -> String {
        switch (slot, variant) {
        case (.dayAfter, .notAReminder):
            "\(prefix).slot2.challenger.body"
        case (_, .blocker):
            "\(prefix).slot\(slot.rawValue).blocker.body"
        case (.extendOffer, .restore):
            "\(prefix).slot3.restore.body"
        case (.lastNote, .new):
            "\(prefix).slot4.new.body"
        default:
            "\(prefix).slot\(slot.rawValue).body"
        }
    }

    private static let prefix = "notification.winback"

    /// Only slot 2's title reads the hour, so slots 3 and 4 never need one.
    private static func reminderHour(_ detail: WinbackDetail) -> Int {
        guard case .reminderTime(let hour, _) = detail else { return 0 }
        return hour
    }

    /// Lines without a placeholder ignore the argument, so every key of a
    /// slot formats with that slot's detail.
    private static func localized(_ key: String, intent: WinbackIntent, locale: Locale, calendar: Calendar) -> String {
        let table = "Notifications"
        switch intent.detail {
        case .reminderTime(let hour, let minute):
            return PillieLocalization.formatted(
                key,
                table: table,
                locale: locale,
                arguments: reminderTime(hour: hour, minute: minute, on: intent.fireDate, locale: locale, calendar: calendar)
            )
        case .extendPrice(let price):
            return PillieLocalization.formatted(key, table: table, locale: locale, arguments: price)
        case .daysLogged(let days):
            return PillieLocalization.formatted(key, table: table, locale: locale, arguments: days)
        }
    }

    private static func reminderTime(hour: Int, minute: Int, on day: Date, locale: Locale, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return formatter.string(from: time)
    }
}
