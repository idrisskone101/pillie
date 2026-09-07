//
//  AppGroupConstants.swift
//  Shared constants — keep in sync with Pillie/Shared/AppGroupConstants.swift
//

import Foundation

enum AppGroupConstants {
    static let appGroupID = "group.com.idrisskone.pillie"
    static let sharedDefaults = UserDefaults(suiteName: appGroupID)
}

enum AppGroupKeys {
    static let isTodayTaken = "pillie_is_today_taken"
    static let todayTakenEpochDay = "pillie_today_taken_epoch_day"
    static let familyActivitySelectionData = "pillie_family_activity_selection_data"
    static let blockingRequested = "pillie_blocking_requested"
    static let blockingReason = "pillie_blocking_reason"
    static let blockingEnabled = "pillie_blocking_enabled"
    static let interventionUnflushedCount = "pillie_intervention_unflushed_count"
    static let interventionLifetimeTotal = "pillie_intervention_lifetime_total"
    static let plusAccessValidUntil = "pillie_plus_access_valid_until"
    static let blockingSnoozeUntil = "pillie_blocking_snooze_until"
    static let blockingSnoozeLedger = "pillie_blocking_snooze_ledger"
}
