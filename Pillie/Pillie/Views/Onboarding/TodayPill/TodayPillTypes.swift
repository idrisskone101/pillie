//
//  TodayPillTypes.swift
//  Pillie
//

import Foundation

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

    var asksQuestion: Bool {
        guard let pillIndex else { return false }
        return packRegimen.day(atIndex: pillIndex).kind != .noPill
    }

    var pick: TodayPillPick? {
        guard let pillIndex else { return nil }
        return TodayPillPick(regimen: regimen, pillIndex: pillIndex, answer: answer)
    }

    mutating func tap(_ index: Int) {
        guard index != pillIndex else { return }
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
