//
//  OnboardingCheckIn.swift
//  Pillie
//

import Foundation

/// The dose or task an onboarding pick logged. It answers a setup question rather than
/// being a check-in made in the app, so the Review Prompt never counts it on its own
/// (ADR 0005). Onboarding completion clears the pick's other keys but keeps this one.
enum OnboardingCheckIn {
    static let dayKey = "pillie_onboarding_check_in_day"
    static let timeZoneKey = "pillie_onboarding_check_in_time_zone"

    static func record(day: Date, in defaults: UserDefaults = .standard) {
        defaults.set(day, forKey: dayKey)
        defaults.set(Calendar.current.timeZone.identifier, forKey: timeZoneKey)
    }

    /// The day it was logged on, the same date after a time zone change.
    static func day(in defaults: UserDefaults = .standard) -> Date? {
        guard let stored = defaults.object(forKey: dayKey) as? Date else { return nil }
        return StoredDay.day(of: stored, writtenIn: defaults.string(forKey: timeZoneKey))
    }
}

extension PillStore {
    /// The Review Prompt decision Home shows: a streak made only of the onboarding
    /// check-in waits for a check-in made in the app.
    func homeReviewPromptDecision(
        higherPriorityCardShowing: Bool,
        defaults: UserDefaults = .standard
    ) -> ReviewPromptEligibility.Decision {
        let decision = reviewPromptDecision(higherPriorityCardShowing: higherPriorityCardShowing)
        guard decision == .show,
              currentStreak == 1,
              let checkInDay = OnboardingCheckIn.day(in: defaults),
              statusForDate(checkInDay) == .taken,
              doseRecord(from: checkInDay, to: today).taken == 1
        else { return decision }
        return .suppressed(.ineligibleStreak)
    }
}
