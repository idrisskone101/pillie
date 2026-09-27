//
//  TodayPillPick.swift
//  Pillie
//

import Foundation
import os

struct TodayPillPick: Codable, Equatable {
    enum Answer: String, Codable {
        case taken
        case notYet
    }

    let regimen: PillPack.PillRegimenPreset
    let dayIndex: Int
    let answer: Answer?

    init?(regimen: PillPack.PillRegimenPreset, dayIndex: Int, answer: Answer?) {
        guard let packRegimen = regimen.regimen,
              (0..<packRegimen.totalDays).contains(dayIndex) else { return nil }
        let isPillFree = packRegimen.day(atIndex: dayIndex).kind == .noPill
        guard isPillFree ? answer == nil : answer != nil else { return nil }
        self.regimen = regimen
        self.dayIndex = dayIndex
        self.answer = answer
    }

    var day: PackDay {
        regimen.resolvedRegimen(custom: nil).day(atIndex: dayIndex)
    }

    /// Whether committing this pick logs a taken dose: a "taken" answer on an
    /// active pill day. A pill-free day and a "not yet" answer never log one.
    var logsADose: Bool {
        answer == .taken && day.kind == .active
    }

    func anchorDay(
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        switch answer {
        case .taken:
            return LiveDoseDay.on(now, reminderHour: reminderHour, reminderMinute: reminderMinute, calendar: calendar)
        case .notYet, nil:
            return calendar.startOfDay(for: now)
        }
    }

    static let storageKey = "pillie_onboarding_today_pill_pick"
    private static let logger = Logger(subsystem: "com.idrisskone.pillie", category: "TodayPillPick")

    static func load(from defaults: UserDefaults = .standard) -> TodayPillPick? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            let stored = try JSONDecoder().decode(TodayPillPick.self, from: data)
            return TodayPillPick(regimen: stored.regimen, dayIndex: stored.dayIndex, answer: stored.answer)
        } catch {
            Self.logger.error("today_pill_pick.load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        do {
            defaults.set(try JSONEncoder().encode(self), forKey: Self.storageKey)
        } catch {
            Self.logger.error("today_pill_pick.save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
