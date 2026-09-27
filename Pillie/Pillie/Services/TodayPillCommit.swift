//
//  TodayPillCommit.swift
//  Pillie
//

import Foundation

enum TodayPillCommit {
    static let reportedStorageKey = "pillie_onboarding_today_pill_reported"

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
            cycleDay: pick.dayIndex + 1,
            preserveHistory: false,
            anchorDay: anchorDay
        )
        if store.appActivatedDate == nil {
            store.appActivatedDate = store.today
        }

        guard pick.logsADose else { return }
        store.markTodayAsTaken()

        guard !defaults.bool(forKey: reportedStorageKey) else { return }
        defaults.set(true, forKey: reportedStorageKey)
        telemetry.todayActionCompleted(source: .onboarding)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        TodayPillPick.clear(from: defaults)
        defaults.removeObject(forKey: reportedStorageKey)
    }
}
