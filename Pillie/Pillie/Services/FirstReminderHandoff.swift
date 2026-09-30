//
//  FirstReminderHandoff.swift
//  Pillie
//

import Foundation

/// Today's hand-off to the first Due Action Reminder of a fresh install. It
/// exists from onboarding until that reminder fires, and only while nothing is
/// logged; after either, Today reads as it always did.
struct FirstReminderHandoff: Equatable {
    /// Where the first reminder falls relative to `now`: today or tomorrow,
    /// and which part of that day. The raw value is the string key suffix.
    enum When: String, Equatable {
        case thisMorning = "this_morning"
        case thisAfternoon = "this_afternoon"
        case tonight
        case tomorrowMorning = "tomorrow_morning"
        case tomorrowAfternoon = "tomorrow_afternoon"
        case tomorrowNight = "tomorrow_night"
    }

    let when: When

    /// Nil for installs that predate the record (`installedAt == nil`), once
    /// anything is logged, and once the first reminder time has passed. The
    /// first reminder is the first occurrence of the reminder time strictly
    /// after `installedAt`.
    static func resolve(
        installedAt: Date?,
        reminderHour: Int,
        reminderMinute: Int,
        now: Date,
        hasLoggedAnything: Bool,
        calendar: Calendar = .current
    ) -> FirstReminderHandoff? {
        guard
            let installedAt,
            !hasLoggedAnything,
            let firstFire = calendar.nextDate(
                after: installedAt,
                matching: DateComponents(hour: reminderHour, minute: reminderMinute),
                matchingPolicy: .nextTime
            ),
            now < firstFire
        else { return nil }

        let hour = calendar.component(.hour, from: firstFire)
        // Relative to `now`, not the install: an evening install viewed after
        // midnight must not still say "tomorrow" for a reminder later that day.
        let when: When = switch (calendar.isDate(firstFire, inSameDayAs: now), hour) {
        case (true, ..<12): .thisMorning
        case (true, 12..<17): .thisAfternoon
        case (true, _): .tonight
        case (false, ..<12): .tomorrowMorning
        case (false, 12..<17): .tomorrowAfternoon
        case (false, _): .tomorrowNight
        }
        return FirstReminderHandoff(when: when)
    }

    /// The floating button's line. The status card already shows the time.
    func localizedLine(locale: Locale) -> String {
        PillieLocalization.string("today.first_reminder.\(when.rawValue)", locale: locale)
    }

    /// The status card's subtitle, under the reminder time.
    func cardLine(locale: Locale) -> String {
        PillieLocalization.string("today.first_reminder.card", locale: locale)
    }
}
