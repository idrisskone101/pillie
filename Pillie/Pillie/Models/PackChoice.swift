//
//  PackChoice.swift
//  Pillie
//

import Foundation

/// A pill pack the user picked: a preset, or a custom regimen that matches none.
/// `preset == .custom` exactly when `regimen` equals no preset's regimen.
struct PackChoice: Hashable, Sendable {
    let preset: PillPack.PillRegimenPreset
    let regimen: PackRegimen

    init(_ regimen: PackRegimen) {
        self.regimen = regimen
        preset = PillPack.PillRegimenPreset.allCases.first { $0.regimen == regimen } ?? .custom
    }

    init(preset: PillPack.PillRegimenPreset) {
        self.init(preset.resolvedRegimen(custom: nil))
    }

    var split: String { "\(regimen.activeDays) + \(regimen.breakDays)" }

    func displayName(locale: Locale = .current) -> String {
        preset == .custom ? split : preset.localizedRoutineDisplayName(locale: locale)
    }

    func scheduleSummary(locale: Locale = .current) -> String {
        guard preset == .custom else { return preset.localizedScheduleSummary(locale: locale) }
        guard regimen.breakDays > 0 else {
            return PillieLocalization.formatted(
                "onboarding.regimen.custom_summary_no_break",
                locale: locale,
                arguments: regimen.activeDays
            )
        }
        return PillieLocalization.formatted(
            "onboarding.regimen.custom_summary",
            locale: locale,
            arguments: regimen.activeDays, regimen.breakDays
        )
    }
}
