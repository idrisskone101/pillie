//
//  ScheduleCriticalSettingChange.swift
//  Pillie
//

import Foundation

enum ScheduleCriticalSettingChange {
    static func saveOnboardingReminderTime(
        store: PillStore,
        hour: Int,
        minute: Int
    ) {
        saveReminderTime(store: store, hour: hour, minute: minute, reason: "onboarding-reminder-time")
    }

    static func saveSettingsReminderTime(
        store: PillStore,
        hour: Int,
        minute: Int
    ) {
        saveReminderTime(store: store, hour: hour, minute: minute, reason: "settings-reminder-time")
        ProductAnalyticsTelemetry.live.reminderTimeSaved()
    }

    static func saveSettingsAutoReminderInterval(
        store: PillStore,
        intervalMinutes: Int
    ) {
        store.autoReminderIntervalMinutes = intervalMinutes
        NotificationManager.shared.requestReschedule(from: store, reason: "settings-auto-interval")
        ProductAnalyticsTelemetry.live.autoReminderIntervalSaved()
    }

    static func saveSettingsAutoReminderRetryLimit(
        store: PillStore,
        retryLimit: Int
    ) {
        store.autoReminderRetryLimit = retryLimit
        NotificationManager.shared.requestReschedule(from: store, reason: "settings-auto-retry-limit")
        ProductAnalyticsTelemetry.live.autoReminderRetryLimitSaved()
    }

    static func saveSettingsSupplyReminderThreshold(
        store: PillStore,
        threshold: Int
    ) {
        if store.pack.method == .patch {
            store.patchRestockReminderThresholdPatches = threshold
        } else {
            store.refillReminderThresholdDays = threshold
        }
        NotificationManager.shared.requestReschedule(from: store, reason: "settings-supply-threshold")
        ProductAnalyticsTelemetry.live.supplyReminderSaved()
    }

    /// Saves the Custom Reminder Message copy (Pillie+) for both the Due Action Reminder
    /// and the Auto-Reminder Retry, then reschedules so the new words take effect on the
    /// next build. Words never affect timing, snooze, retry cadence, or supply scheduling
    /// — only the title/body strings. The save event carries only four coarse booleans
    /// (whether each field is customized), never the strings.
    static func saveSettingsCustomReminders(
        store: PillStore,
        title: String,
        body: String,
        retryTitle: String,
        retryBody: String
    ) {
        store.customDueReminderTitle = title
        store.customDueReminderBody = body
        store.customRetryReminderTitle = retryTitle
        store.customRetryReminderBody = retryBody
        NotificationManager.shared.requestReschedule(from: store, reason: "settings-custom-reminders")
        ProductAnalyticsTelemetry.live.customRemindersSaved(
            titleCustomized: CustomReminderCopy.isCustomized(title),
            bodyCustomized: CustomReminderCopy.isCustomized(body),
            retryTitleCustomized: CustomReminderCopy.isCustomized(retryTitle),
            retryBodyCustomized: CustomReminderCopy.isCustomized(retryBody)
        )
    }

    /// Saves the free Cycle Transition Notice toggle (#123) and reschedules so the notice
    /// is added or removed on the next build. Free for all users — not gated by Pillie+.
    static func saveCycleTransitionNoticeEnabled(
        store: PillStore,
        enabled: Bool
    ) {
        store.cycleTransitionNoticeEnabled = enabled
        NotificationManager.shared.requestReschedule(from: store, reason: "settings-cycle-transition-notice")
    }

    private static func saveReminderTime(
        store: PillStore,
        hour: Int,
        minute: Int,
        reason: String
    ) {
        store.reminderHour = hour
        store.reminderMinute = minute
        NotificationManager.shared.requestReschedule(from: store, reason: reason)
    }
}
