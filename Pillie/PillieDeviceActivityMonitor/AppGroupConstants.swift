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
    static let familyActivitySelectionData = "pillie_family_activity_selection_data"
    static let blockingRequested = "pillie_blocking_requested"
    static let blockingReason = "pillie_blocking_reason"
    static let blockingEnabled = "pillie_blocking_enabled"
}
