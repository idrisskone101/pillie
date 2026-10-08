//  Authored copy for the win-back pushes (ENG-173). Informational: never a
//  pregnancy scare, guilt, or fake urgency, and never a hint that reminders
//  stay free. Every key lives in `Notifications`; each line takes at most one
//  argument, the one its slot's `WinbackDetail` carries.

import Foundation

enum WinbackCopy {
    /// A reminder before 17:00 is a daytime one, so "tonight" would be false.
    static let eveningStartHour = 17

    static func title(for intent: WinbackIntent, locale: Locale = PillieLocalization.appLocale) -> String {
        let key = titleKey(slot: intent.slot, variant: intent.variant, reminderHour: reminderHour(intent.detail))
        return localized(key, detail: intent.detail, locale: locale)
    }

    static func body(for intent: WinbackIntent, locale: Locale = PillieLocalization.appLocale) -> String {
        localized(bodyKey(slot: intent.slot, variant: intent.variant), detail: intent.detail, locale: locale)
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
        case (.lastNote, .new):
            "\(prefix).slot4.new.body"
        default:
            "\(prefix).slot\(slot.rawValue).body"
        }
    }

    private static let prefix = "notification.winback"

    /// Only slot 2's title reads the hour, so slot 4 never needs one.
    private static func reminderHour(_ detail: WinbackDetail) -> Int {
        guard case .reminderTime(let hour, _) = detail else { return 0 }
        return hour
    }

    /// Lines without a placeholder ignore the argument, so every key of a
    /// slot formats with that slot's detail.
    private static func localized(_ key: String, detail: WinbackDetail, locale: Locale) -> String {
        let table = "Notifications"
        switch detail {
        case .reminderTime(let hour, let minute):
            return PillieLocalization.formatted(
                key,
                table: table,
                locale: locale,
                arguments: SettingsPresentation.time(hour: hour, minute: minute, locale: locale)
            )
        case .daysLogged(let days):
            return PillieLocalization.formatted(key, table: table, locale: locale, arguments: days)
        }
    }
}
