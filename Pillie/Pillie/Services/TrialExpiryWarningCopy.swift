//
//  TrialExpiryWarningCopy.swift
//  Pillie
//
//  Authored copy for the Reverse Trial day-10/13 expiry warnings (#168 /
//  ADR 0007). Informational, never a medical claim: it names when app blocking
//  turns off, consistent with expiry at the local-day rollover after day 14 —
//  from day 10 that rollover is 5 days away; from day 13 it is tomorrow night.
//

import Foundation

enum TrialExpiryWarningCopy {
    static func title(day: Int, locale: Locale = .current) -> String {
        let key = day >= 13
            ? "notification.trial_expiry.day13.title"
            : "notification.trial_expiry.day10.title"
        return PillieLocalization.string(key, table: "Notifications", locale: locale)
    }

    static func body(day: Int, locale: Locale = .current) -> String {
        let key = day >= 13
            ? "notification.trial_expiry.day13.body"
            : "notification.trial_expiry.day10.body"
        return PillieLocalization.string(key, table: "Notifications", locale: locale)
    }
}
