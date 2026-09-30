//
//  FirstReminderHandoff.swift
//  Pillie
//

import Foundation

/// Today's hand-off to the first Due Action Reminder of a fresh install. It
/// exists from onboarding until that reminder fires, and only while nothing is
/// logged; after either, Today reads as it always did.
struct FirstReminderHandoff: Equatable {
    /// Where the first reminder falls relative to `now`, in the words a person
    /// would use for it.
    enum When: Equatable {
        case thisMorning
        case today
        case tonight
        case tomorrowMorning
        case tomorrow
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
        if calendar.isDate(firstFire, inSameDayAs: now) {
            switch hour {
            case ..<12: return FirstReminderHandoff(when: .thisMorning)
            case 12..<17: return FirstReminderHandoff(when: .today)
            default: return FirstReminderHandoff(when: .tonight)
            }
        }
        return FirstReminderHandoff(when: hour < 12 ? .tomorrowMorning : .tomorrow)
    }

    /// The floating button's line. The status card already shows the time.
    func localizedLine(locale: Locale) -> String {
        PillieLocalization.string(when.stringKey, locale: locale)
    }

    /// The status card's subtitle, under the reminder time.
    func cardLine(locale: Locale) -> String {
        PillieLocalization.string("today.first_reminder.card", locale: locale)
    }
}

private extension FirstReminderHandoff.When {
    var stringKey: String {
        switch self {
        case .thisMorning: "today.first_reminder.this_morning"
        case .today: "today.first_reminder.today"
        case .tonight: "today.first_reminder.tonight"
        case .tomorrowMorning: "today.first_reminder.tomorrow_morning"
        case .tomorrow: "today.first_reminder.tomorrow"
        }
    }
}
