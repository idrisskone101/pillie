//
//  TodayPillCommit.swift
//  Pillie
//

import Foundation

enum TodayPillCommit {
    static let reportedStorageKey = "pillie_onboarding_today_pill_reported"
    static let answerReportedStorageKey = "pillie_onboarding_today_answer_reported"

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
        defaults.removeObject(forKey: answerReportedStorageKey)
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
        if let answer = start.answer, !defaults.bool(forKey: answerReportedStorageKey) {
            defaults.set(true, forKey: answerReportedStorageKey)
            let reminder = Calendar.current.date(
                bySettingHour: store.reminderHour,
                minute: store.reminderMinute,
                second: 0,
                of: start.pickedAt
            )
            telemetry.onboardingTodayAnswer(answer, reminderPassed: reminder.map { start.pickedAt >= $0 } ?? false)
        }

        // A pick from an earlier day names an earlier pill, and its answer is about that pill.
        let pickedDay = TodayPillPick.Answer.anchorDay(
            for: start.answer,
            now: start.pickedAt,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute
        )
        let liveDayAtPick = LiveDoseDay.on(start.pickedAt, reminderHour: store.reminderHour, reminderMinute: store.reminderMinute)
        let liveDayNow = LiveDoseDay.on(now, reminderHour: store.reminderHour, reminderMinute: store.reminderMinute)
        // Until a reminder passes, the pick still names the open dose, even past midnight.
        let anchorDay = liveDayAtPick == liveDayNow
            ? pickedDay
            : TodayPillPick.Answer.anchorDay(
                for: start.answer,
                now: now,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute
            )
        let daysSincePick = max(0, Calendar.current.dateComponents([.day], from: pickedDay, to: anchorDay).day ?? 0)
        let cycleDay = (start.cycleDay - 1 + daysSincePick) % start.cycleLength + 1

        store.startNewProtocol(
            method: start.method,
            regimen: start.regimen,
            customRegimen: start.customRegimen,
            cycleDay: cycleDay,
            preserveHistory: false,
            anchorDay: anchorDay
        )
        if store.appActivatedDate == nil {
            store.appActivatedDate = store.today
        }
        FirstReminderInstall.record(at: now, in: defaults)
        StreakChangeReport.record(store, reason: .packChange, defaults: defaults, telemetry: telemetry)

        guard start.logs, daysSincePick == 0 else { return }
        store.markTodayAsTaken()
        StreakChangeReport.record(store, reason: .logged, defaults: defaults, telemetry: telemetry)

        guard !defaults.bool(forKey: reportedStorageKey) else { return }
        defaults.set(true, forKey: reportedStorageKey)
        telemetry.todayActionCompleted(source: .onboarding)
    }
}
