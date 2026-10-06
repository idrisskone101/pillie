//
//  TrialExpiryWarningCopy.swift
//  Pillie
//
//  Authored copy for the Reverse Trial notices: the day-10/13 expiry warnings
//  and the day-15 expiry-day notice (#168 / ADR 0007). Informational, never a
//  medical claim. The warnings name when app blocking turns off, but only for
//  users who set blocking up; everyone else gets a reminders-only body. Only
//  legacy terms may say daily reminders stay free: hard-paywall users are told
//  their daily reminders stop when the trial ends (ENG-167). Day 10 is 5 days before the local-day rollover
//  after day 14, day 13 is tomorrow night, and day 15 fires the morning the
//  trial-end wall appears.
//

import Foundation

enum TrialExpiryWarningCopy {
    /// Part of each notice's request id. Bump it whenever these words change,
    /// or notices already pending on devices keep the old copy.
    static let revision = 2

    static func title(day: Int, locale: Locale = .current) -> String {
        PillieLocalization.string(titleKey(day: day), table: "Notifications", locale: locale)
    }

    static func body(
        day: Int,
        cohort: TrialEndPaywallCohort,
        terms: TrialEndAccessTerms,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.string(
            bodyKey(day: day, cohort: cohort, terms: terms),
            table: "Notifications",
            locale: locale
        )
    }

    static func titleKey(day: Int) -> String {
        "\(keyPrefix(day: day)).title"
    }

    static func bodyKey(day: Int, cohort: TrialEndPaywallCohort, terms: TrialEndAccessTerms) -> String {
        if terms == .hardPaywall {
            return "\(keyPrefix(day: day)).hard.body"
        }
        // The expiry-day notice reads the same for both cohorts.
        guard day < 15, cohort == .reminderOnly else { return "\(keyPrefix(day: day)).body" }
        return "\(keyPrefix(day: day)).reminders.body"
    }

    private static func keyPrefix(day: Int) -> String {
        switch day {
        case 15...: "notification.trial_expiry.day15"
        case 13...: "notification.trial_expiry.day13"
        default: "notification.trial_expiry.day10"
        }
    }
}
