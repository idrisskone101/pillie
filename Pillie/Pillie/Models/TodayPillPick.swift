//
//  TodayPillPick.swift
//  Pillie
//

import Foundation
import os

/// The pill a new user tapped during onboarding, and whether it is already taken.
/// Onboarding holds it as a draft until the reminder time is final, then commits it
/// with `TodayPillCommit`, because the live dose day depends on that time.
struct TodayPillPick: Codable, Equatable {
    enum Answer: String, Codable {
        case taken
        case notYet
    }

    let regimen: PillPack.PillRegimenPreset
    /// 0-based day index in the pack.
    let pillIndex: Int
    /// nil only on a pill-free day, where there is nothing to take.
    let answer: Answer?

    /// Refuses a pick the pack cannot hold: custom packs, an index past the end, or
    /// a missing answer on a day that has a pill.
    init?(regimen: PillPack.PillRegimenPreset, pillIndex: Int, answer: Answer?) {
        guard let packRegimen = regimen.regimen,
              (0..<packRegimen.totalDays).contains(pillIndex) else { return nil }
        let isPillFree = packRegimen.day(atIndex: pillIndex).kind == .noPill
        guard isPillFree ? answer == nil : answer != nil else { return nil }
        self.regimen = regimen
        self.pillIndex = pillIndex
        self.answer = answer
    }

    var day: PackDay {
        regimen.resolvedRegimen(custom: nil).day(atIndex: pillIndex)
    }

    /// The day pill N belongs to. A taken pill is the currently open dose window, so
    /// the next reminder opens pill N+1. An untaken pill, or a pill-free day, is the
    /// next dose owed: the window that opens at today's reminder, or the one already
    /// open when that reminder has passed.
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

    // MARK: Draft storage

    static let storageKey = "pillie_onboarding_today_pill_pick"
    private static let logger = Logger(subsystem: "com.idrisskone.pillie", category: "TodayPillPick")

    static func load(from defaults: UserDefaults = .standard) -> TodayPillPick? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            let stored = try JSONDecoder().decode(TodayPillPick.self, from: data)
            return TodayPillPick(regimen: stored.regimen, pillIndex: stored.pillIndex, answer: stored.answer)
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
