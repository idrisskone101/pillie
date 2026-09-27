//
//  TodayPillCommit.swift
//  Pillie
//

import Foundation

/// Turns the onboarding pill pick into the pill pack once the reminder time is final.
/// Safe to repeat: the pack is rebuilt from the pick, the pill is logged at most once,
/// and `today_action_completed` fires once for its day.
enum TodayPillCommit {
    static let loggedDayStorageKey = "pillie_onboarding_today_pill_logged_day"

    static func run(
        _ pick: TodayPillPick,
        store: PillStore,
        now: Date = PillieClock.now,
        defaults: UserDefaults = .standard,
        telemetry: ProductAnalyticsTelemetry = .live
    ) {
        let anchorDay = pick.anchorDay(
            now: now,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute
        )
        store.startNewProtocol(
            method: .pill,
            regimen: pick.regimen,
            customRegimen: nil,
            cycleDay: pick.pillIndex + 1,
            preserveHistory: false,
            anchorDay: anchorDay
        )
        if store.appActivatedDate == nil {
            store.appActivatedDate = store.today
        }

        // A sugar pill is not a due action, so there is nothing to log.
        guard pick.answer == .taken, pick.day.kind == .active else { return }
        store.markTodayAsTaken()

        let loggedDay = defaults.object(forKey: loggedDayStorageKey) as? Date
        guard loggedDay != anchorDay else { return }
        defaults.set(anchorDay, forKey: loggedDayStorageKey)
        telemetry.todayActionCompleted(source: .onboarding)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        TodayPillPick.clear(from: defaults)
        defaults.removeObject(forKey: loggedDayStorageKey)
    }
}
