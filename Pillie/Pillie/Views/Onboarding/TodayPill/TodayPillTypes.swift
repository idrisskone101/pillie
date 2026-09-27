//
//  TodayPillTypes.swift
//  Pillie
//

import Foundation

struct TodayPillSelection: Equatable {
    private(set) var regimen: PillPack.PillRegimenPreset
    private(set) var dayIndex: Int?
    private(set) var answer: TodayPillPick.Answer?

    init(regimen: PillPack.PillRegimenPreset) {
        self.regimen = regimen
    }

    init(restoring pick: TodayPillPick) {
        regimen = pick.regimen
        dayIndex = pick.dayIndex
        answer = pick.answer
    }

    var packRegimen: PackRegimen {
        regimen.resolvedRegimen(custom: nil)
    }

    var asksQuestion: Bool {
        guard let dayIndex else { return false }
        return packRegimen.day(atIndex: dayIndex).kind != .noPill
    }

    var pick: TodayPillPick? {
        guard let dayIndex else { return nil }
        return TodayPillPick(regimen: regimen, dayIndex: dayIndex, answer: answer)
    }

    mutating func tap(_ index: Int) {
        guard index != dayIndex else { return }
        dayIndex = index
        answer = nil
    }

    mutating func record(_ answer: TodayPillPick.Answer) {
        guard asksQuestion else { return }
        self.answer = answer
    }

    mutating func changeRegimen(_ regimen: PillPack.PillRegimenPreset) {
        self.regimen = regimen
        if let dayIndex, dayIndex >= packRegimen.totalDays {
            self.dayIndex = nil
        }
        if !asksQuestion {
            answer = nil
        }
    }
}

/// Splits a "%@"-templated localized string around its single placeholder, so
/// TodayPillQuestionLine can render the pill number as a chip instead of plain
/// text while keeping the template's own punctuation and spacing.
enum TodayPillQuestionTemplate {
    static func split(_ template: String) -> (prefix: String, prefixSpaced: Bool, suffix: String, suffixSpaced: Bool) {
        let pieces = template.components(separatedBy: "%@")
        guard pieces.count == 2 else { return (template, true, "", false) }
        return (
            pieces[0].trimmingCharacters(in: .whitespaces),
            pieces[0].last?.isWhitespace ?? false,
            pieces[1].trimmingCharacters(in: .whitespaces),
            pieces[1].first?.isWhitespace ?? false
        )
    }
}
