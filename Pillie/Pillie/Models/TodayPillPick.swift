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

        static func anchorDay(
            for answer: Answer?,
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
    }

    let pack: PackChoice
    let dayIndex: Int
    let answer: Answer?

    init?(pack: PackChoice, dayIndex: Int, answer: Answer?) {
        guard (0..<pack.regimen.totalDays).contains(dayIndex) else { return nil }
        let isPillFree = pack.regimen.day(atIndex: dayIndex).kind == .noPill
        guard isPillFree ? answer == nil : answer != nil else { return nil }
        self.pack = pack
        self.dayIndex = dayIndex
        self.answer = answer
    }

    var day: PackDay {
        pack.regimen.day(atIndex: dayIndex)
    }

    /// Whether committing this pick logs a taken dose: a "taken" answer on a
    /// hormone or sugar pill day. A pill-free day and a "not yet" answer never log one.
    var logsADose: Bool {
        answer == .taken && day.kind != .noPill
    }

    func anchorDay(
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        Answer.anchorDay(for: answer, now: now, reminderHour: reminderHour, reminderMinute: reminderMinute, calendar: calendar)
    }

    static let storageKey = "pillie_onboarding_today_pill_pick"
    private static let logger = Logger(subsystem: "com.idrisskone.pillie", category: "TodayPillPick")

    static func load(from defaults: UserDefaults = .standard) -> TodayPillPick? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode(TodayPillPick.self, from: data)
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

    // "regimen" keeps the preset raw value the ENG-138/144 drafts were saved with;
    // "custom" is written only for a custom pack.
    private enum CodingKeys: String, CodingKey {
        case regimen
        case custom
        case dayIndex
        case answer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preset = try container.decode(PillPack.PillRegimenPreset.self, forKey: .regimen)
        let pack = preset == .custom
            ? PackChoice(try container.decode(PackRegimen.self, forKey: .custom))
            : PackChoice(preset: preset)
        guard let pick = TodayPillPick(
            pack: pack,
            dayIndex: try container.decode(Int.self, forKey: .dayIndex),
            answer: try container.decodeIfPresent(Answer.self, forKey: .answer)
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "pick does not fit its pack")
            )
        }
        self = pick
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pack.preset, forKey: .regimen)
        if pack.preset == .custom {
            try container.encode(pack.regimen, forKey: .custom)
        }
        try container.encode(dayIndex, forKey: .dayIndex)
        try container.encodeIfPresent(answer, forKey: .answer)
    }
}
