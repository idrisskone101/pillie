//
//  OnboardingReminderCommit.swift
//  Pillie
//
//  Orders the Reminder Time commit during Protection Plan Onboarding (#196).
//  The legacy commit scheduled local notifications (via the reminder-time save)
//  before notification authorization was requested, so on a fresh install iOS
//  rejected every request with UNErrorCode 2003 ("Source is not authorized")
//  and analytics recorded an error storm. This type owns the safe ordering:
//  persist the chosen time first, then resolve authorization, and only touch
//  the notification pipeline after a grant. A denial is product state, not an
//  error — onboarding continues without scheduling.
//

import Foundation

struct OnboardingReminderCommit {
    let saveReminderTime: (_ hour: Int, _ minute: Int) -> Void
    let trackPermissionRequested: () -> Void
    let requestAuthorization: (_ completion: @escaping (_ granted: Bool) -> Void) -> Void
    let trackPermissionCompleted: (_ granted: Bool) -> Void
    let scheduleReminders: () -> Void

    func run(hour: Int, minute: Int, completion: @escaping () -> Void) {
        saveReminderTime(hour, minute)
        trackPermissionRequested()
        requestAuthorization { granted in
            trackPermissionCompleted(granted)
            if granted {
                scheduleReminders()
            }
            completion()
        }
    }

    /// Production wiring: persists through `ScheduleCriticalSettingChange`,
    /// resolves authorization through `NotificationManager` (which delivers the
    /// outcome on the main queue), and schedules only after a grant.
    static func live(store: PillStore, telemetry: OnboardingTelemetry) -> OnboardingReminderCommit {
        OnboardingReminderCommit(
            saveReminderTime: { hour, minute in
                ScheduleCriticalSettingChange.saveOnboardingReminderTime(store: store, hour: hour, minute: minute)
            },
            trackPermissionRequested: { telemetry.notificationPermissionRequested() },
            requestAuthorization: { completion in
                NotificationManager.shared.requestAuthorization(completion: completion)
            },
            trackPermissionCompleted: { granted in telemetry.notificationPermissionCompleted(granted: granted) },
            scheduleReminders: {
                ScheduleCriticalSettingChange.scheduleOnboardingReminders(store: store)
            }
        )
    }
}
