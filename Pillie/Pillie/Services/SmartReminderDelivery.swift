//
//  SmartReminderDelivery.swift
//  Pillie
//

import Foundation

/// Coarse, content-free decisions for Smart Reminder runtime telemetry.
/// Notification copy, medication data, and app selections never enter this type.
struct SmartReminderDelivery {
    static let firedRequestIdentifiersStorageKey = "smart_reminder_fired_request_identifiers"
    static let requestKindKey = "requestKind"
    static let retryRequestKind = ReminderSchedulePlanner.DueReminderKind.retry.rawValue

    static func shouldRecordFire(
        requestIdentifier: String,
        requestKind: String?,
        alreadyRecordedRequestIdentifiers: [String]
    ) -> Bool {
        requestKind == retryRequestKind
            && !alreadyRecordedRequestIdentifiers.contains(requestIdentifier)
    }

    static func outcome(
        requestKind: String?,
        actionIdentifier: String,
        markTakenActionIdentifier: String,
        snoozeActionIdentifier: String,
        defaultActionIdentifier: String
    ) -> AnalyticsSmartReminderOutcome? {
        guard requestKind == retryRequestKind else { return nil }
        switch actionIdentifier {
        case markTakenActionIdentifier: return .completed
        case snoozeActionIdentifier: return .snoozed
        case defaultActionIdentifier: return .opened
        default: return nil
        }
    }
}
