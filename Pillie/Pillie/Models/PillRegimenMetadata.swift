//
//  PillRegimenMetadata.swift
//  Pillie
//

import Foundation

extension PillPack.PillRegimenPreset {
    func localizedScheduleSummary(locale: Locale = PillieLocalization.appLocale) -> String {
        let key: String
        switch self {
        case .twentyOneSeven:
            key = "onboarding.regimen.21_7"
        case .twentyOneOnly:
            key = "onboarding.regimen.21_only"
        case .twentyFourFour:
            key = "onboarding.regimen.24_4"
        case .twentySixTwo:
            key = "onboarding.regimen.26_2"
        case .everyDay:
            key = "onboarding.regimen.28_0"
        case .twentyOneFour:
            key = "onboarding.regimen.21_4"
        case .custom:
            key = "onboarding.regimen.custom"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    func localizedRoutineDisplayName(locale: Locale = PillieLocalization.appLocale) -> String {
        let key: String
        switch self {
        case .twentyOneSeven:
            key = "onboarding.regimen.name.standard"
        case .twentyOneOnly:
            key = "onboarding.regimen.name.21_only"
        case .everyDay:
            key = "onboarding.regimen.name.every_day"
        case .custom:
            key = "onboarding.regimen.name.custom"
        case .twentyFourFour, .twentySixTwo, .twentyOneFour:
            return rawValue
        }
        return PillieLocalization.string(key, locale: locale)
    }

    func localizedScheduleSubtitle(locale: Locale = PillieLocalization.appLocale) -> String {
        localizedScheduleSummary(locale: locale)
    }
}
