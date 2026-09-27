//
//  TodayPillTypes.swift
//  Pillie
//

import Foundation

/// What step 7 holds while the person taps: a pack, maybe a tapped pill, maybe an answer.
struct TodayPillSelection: Equatable {
    private(set) var regimen: PillPack.PillRegimenPreset
    private(set) var pillIndex: Int?
    private(set) var answer: TodayPillPick.Answer?

    init(regimen: PillPack.PillRegimenPreset) {
        self.regimen = regimen
    }

    init(restoring pick: TodayPillPick) {
        regimen = pick.regimen
        pillIndex = pick.pillIndex
        answer = pick.answer
    }

    var packRegimen: PackRegimen {
        regimen.resolvedRegimen(custom: nil)
    }

    /// A pill-free day has nothing to take, so it skips the question.
    var asksQuestion: Bool {
        guard let pillIndex else { return false }
        return packRegimen.day(atIndex: pillIndex).kind != .noPill
    }

    /// Ready to continue: nil until a pill is tapped and, when it has a pill, answered.
    var pick: TodayPillPick? {
        guard let pillIndex else { return nil }
        return TodayPillPick(regimen: regimen, pillIndex: pillIndex, answer: answer)
    }

    mutating func tap(_ index: Int) {
        pillIndex = index
        answer = nil
    }

    mutating func record(_ answer: TodayPillPick.Answer) {
        guard asksQuestion else { return }
        self.answer = answer
    }

    mutating func changeRegimen(_ regimen: PillPack.PillRegimenPreset) {
        self.regimen = regimen
        if let pillIndex, pillIndex >= packRegimen.totalDays {
            self.pillIndex = nil
        }
        if !asksQuestion {
            answer = nil
        }
    }
}
