//
//  FirstReminderInstall.swift
//  Pillie
//

import Foundation

/// When this install finished onboarding. Written once and never backfilled:
/// installs without it never see the first-reminder hand-off. Onboarding
/// completion clears its other keys but must not clear this one, since Today
/// reads it afterwards.
enum FirstReminderInstall {
    static let storageKey = "pillie_first_reminder_installed_at"

    static func date(in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: storageKey) as? Date
    }

    static func record(at now: Date, in defaults: UserDefaults = .standard) {
        guard date(in: defaults) == nil else { return }
        defaults.set(now, forKey: storageKey)
    }
}
