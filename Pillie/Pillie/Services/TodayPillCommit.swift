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
        commit(
            Start(
                method: .pill,
                regimen: pick.pack.preset,
                customRegimen: pick.pack.regimen,
                cycleDay: pick.dayIndex + 1,
                answer: pick.answer,
                logs: pick.logsADose
            ),
            store: store,
            now: now,
            defaults: defaults,
            telemetry: telemetry
        )
    }

    static func run(
        _ pick: RoutineDialPick,
        store: PillStore,
        now: Date = PillieClock.now,
        defaults: UserDefaults = .standard,
        telemetry: ProductAnalyticsTelemetry = .live
    ) {
        commit(
            Start(
                method: pick.method.contraceptiveMethod,
                regimen: .twentyOneSeven,
                customRegimen: nil,
                cycleDay: pick.cycleDay,
                answer: pick.answer,
                logs: pick.logsAnAction
            ),
            store: store,
            now: now,
            defaults: defaults,
            telemetry: telemetry
        )
    }

    static func clear(from defaults: UserDefaults = .standard) {
        TodayPillPick.clear(from: defaults)
        RoutineDialPick.clear(from: defaults)
        defaults.removeObject(forKey: reportedStorageKey)
    }

    private struct Start {
        let method: ContraceptiveMethod
        let regimen: PillPack.PillRegimenPreset
        let customRegimen: PackRegimen?
        let cycleDay: Int
        let answer: TodayPillPick.Answer?
        let logs: Bool
    }

    private static func commit(
        _ start: Start,
        store: PillStore,
        now: Date,
        defaults: UserDefaults,
        telemetry: ProductAnalyticsTelemetry
    ) {
        let anchorDay = TodayPillPick.Answer.anchorDay(
            for: start.answer,
            now: now,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute
        )
        store.startNewProtocol(
            method: start.method,
            regimen: start.regimen,
            customRegimen: start.customRegimen,
            cycleDay: start.cycleDay,
            preserveHistory: false,
            anchorDay: anchorDay
        )
        if store.appActivatedDate == nil {
            store.appActivatedDate = store.today
        }
        FirstReminderInstall.record(at: now, in: defaults)

        guard start.logs else { return }
        store.markTodayAsTaken()

        guard !defaults.bool(forKey: reportedStorageKey) else { return }
        defaults.set(true, forKey: reportedStorageKey)
        telemetry.todayActionCompleted(source: .onboarding)
    }
}
