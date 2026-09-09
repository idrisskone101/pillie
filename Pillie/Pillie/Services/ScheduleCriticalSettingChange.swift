//
//  ScheduleCriticalSettingChange.swift
//  Pillie
//

import Foundation

enum ScheduleCriticalSettingChange {
    struct Confirmation: Equatable {
        let title: String
        let body: String
        let confirmTitle: String
        let cancelTitle: String
    }

    static func confirmation(
        cycleDay: Int,
        locale: Locale = .current
    ) -> Confirmation {
        Confirmation(
            title: PillieLocalization.string(
                "settings.schedule_reset.title",
                locale: locale
            ),
            body: PillieLocalization.formatted(
                "settings.schedule_reset.body",
                locale: locale,
                arguments: Int64(cycleDay)
            ),
            confirmTitle: PillieLocalization.string(
                "settings.schedule_reset.confirm",
                locale: locale
            ),
            cancelTitle: PillieLocalization.string("global.action.cancel", locale: locale)
        )
    }

    /// Persists the Reminder Time chosen during onboarding without touching the
    /// notification pipeline. On a fresh install notification authorization has
    /// not been resolved yet, so scheduling here made every
    /// `UNUserNotificationCenter.add` fail with code 2003 (#196). Scheduling
    /// happens in `scheduleOnboardingReminders` once authorization is granted.
    static func saveOnboardingReminderTime(
        store: PillStore,
        hour: Int,
        minute: Int
    ) {
        store.reminderHour = hour
        store.reminderMinute = minute
    }

    /// Builds the onboarding reminder schedule. Only called after the user
    /// granted notification authorization (#196); a denial skips scheduling
    /// entirely so it can never produce a code-2003 error storm.
    static func scheduleOnboardingReminders(store: PillStore) {
        NotificationManager.shared.requestReschedule(from: store, reason: "onboarding-reminder-time-authorized")
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

    /// Saves the Custom Reminder Message copy (Pillie+) for the Due Action Reminder and
    /// the Auto-Reminder Retry, then reschedules so the new words take effect on the next
    /// build. Words never affect timing, snooze, retry cadence, or supply scheduling —
    /// only the title/body strings. The save event carries only four coarse customization
    /// booleans plus preset attribution, never the strings.
    static func saveSettingsCustomReminders(
        store: PillStore,
        title: String,
        body: String,
        retryTitle: String,
        retryBody: String,
        preset: CustomReminderPreset? = nil,
        editedAfterPreset: Bool = false
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
            retryBodyCustomized: CustomReminderCopy.isCustomized(retryBody),
            preset: preset,
            editedAfterPreset: editedAfterPreset
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
