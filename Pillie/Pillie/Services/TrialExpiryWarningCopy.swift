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
    static func title(day: Int) -> String {
        day >= 13
            ? "Your Plus trial is almost over"
            : "Your Plus trial ends soon"
    }

    static func body(day: Int) -> String {
        day >= 13
            ? "App blocking turns off tomorrow night. Reminders stay free, forever."
            : "App blocking turns off in 5 days. Reminders stay free, forever."
    }
}
