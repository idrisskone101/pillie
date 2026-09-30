//
//  TodayPillCommit.swift
//  Pillie
//

import Foundation

enum TodayPillCommit {
    static let reportedStorageKey = "pillie_onboarding_today_pill_reported"

    static func run(
        _ draft: OnboardingDraft<TodayPillPick>,
        store: PillStore,
        now: Date = PillieClock.now,
        defaults: UserDefaults = .standard,
        telemetry: ProductAnalyticsTelemetry = .live
    ) {
        let pick = draft.pick
        commit(
            Start(
                method: .pill,
                regimen: pick.pack.preset,
                customRegimen: pick.pack.regimen,
                cycleDay: pick.dayIndex + 1,
                cycleLength: pick.pack.regimen.totalDays,
                answer: pick.answer,
                logs: pick.logsADose,
                pickedAt: draft.pickedAt
            ),
            store: store,
            now: now,
            defaults: defaults,
            telemetry: telemetry
        )
    }

    static func run(
        _ draft: OnboardingDraft<RoutineDialPick>,
        store: PillStore,
        now: Date = PillieClock.now,
        defaults: UserDefaults = .standard,
        telemetry: ProductAnalyticsTelemetry = .live
    ) {
        let pick = draft.pick
        commit(
            Start(
                method: pick.method.contraceptiveMethod,
                regimen: .twentyOneSeven,
                customRegimen: nil,
                cycleDay: pick.cycleDay,
                cycleLength: RoutineDialDay.cycleLength,
                answer: pick.answer,
                logs: pick.logsAnAction,
                pickedAt: draft.pickedAt
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
        let cycleLength: Int
        let answer: TodayPillPick.Answer?
        let logs: Bool
        let pickedAt: Date
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

        guard start.logs else { return }
        store.markTodayAsTaken()

        guard !defaults.bool(forKey: reportedStorageKey) else { return }
        defaults.set(true, forKey: reportedStorageKey)
        telemetry.todayActionCompleted(source: .onboarding)
    }
}
