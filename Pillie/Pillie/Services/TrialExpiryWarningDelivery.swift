//
//  TrialExpiryWarningDelivery.swift
//  Pillie
//
//  The `trial_expiry_warning_sent` delivery decision (#168 / ADR 0007): maps a
//  notification's userInfo to the trial day to record, at most once per day
//  value — a warning presented in the foreground and later tapped reports one
//  event, not two. Pure value logic; the caller persists the sent-days list.
//

import Foundation

enum TrialExpiryWarningDelivery {
    /// UserDefaults key for the persisted list of day values already reported.
    static let sentDaysStorageKey = "trialExpiryWarningSentDays"

    /// userInfo keys/values, shared with `NotificationManager`'s request builder
    /// so the payload and this decision can never drift apart.
    static let requestKindKey = "requestKind"
    static let requestKindValue = "trialExpiryWarning"
    static let dayKey = "trialWarningDay"

    /// The `day` to record for this delivery, or `nil` when the notification is
    /// not a trial expiry warning or its day was already reported.
    static func day(fromUserInfo userInfo: [AnyHashable: Any], alreadySentDays: [Int]) -> Int? {
        guard userInfo[requestKindKey] as? String == requestKindValue,
              let day = userInfo[dayKey] as? Int,
              !alreadySentDays.contains(day)
        else { return nil }
        return day
    }
}
