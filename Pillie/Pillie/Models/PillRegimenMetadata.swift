//
//  PillRegimenMetadata.swift
//  Pillie
//

import Foundation

extension PillPack.PillRegimenPreset {
    var scheduleSubtitle: String {
        switch self {
        case .twentyOneSeven: return "21 active, 7 break"
        case .twentyFourFour: return "24 active, 4 break"
        case .twentySixTwo: return "26 active, 2 break"
        case .twentyEightZero: return "28 active, continuous"
        case .eightyFourSeven: return "84 active, 7 break"
        case .threeSixtyFiveZero: return "365 active, continuous"
        case .custom: return "Custom active + break days"
        }
    }

    func localizedScheduleSummary(locale: Locale = .current) -> String {
        let key: String
        switch self {
        case .twentyOneSeven:
            key = "onboarding.regimen.21_7"
        case .twentyFourFour:
            key = "onboarding.regimen.24_4"
        case .twentyEightZero, .threeSixtyFiveZero:
            key = "onboarding.regimen.28_0"
        case .custom:
            key = "onboarding.regimen.custom"
        case .twentySixTwo:
            return locale.language.languageCode?.identifier == "it"
                ? "26 giorni attivi, 2 giorni di pausa"
                : "26 active days, 2 break days"
        case .eightyFourSeven:
            return locale.language.languageCode?.identifier == "it"
                ? "84 giorni attivi, 7 giorni di pausa"
                : "84 active days, 7 break days"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    func localizedRoutineDisplayName(locale: Locale = .current) -> String {
        let key: String?
        switch self {
        case .twentyOneSeven:
            key = "onboarding.regimen.name.standard"
        case .threeSixtyFiveZero:
            key = "onboarding.regimen.name.continuous"
        case .custom:
            key = "onboarding.regimen.name.custom"
        default:
            key = nil
        }
        return key.map { PillieLocalization.string($0, locale: locale) } ?? rawValue
    }

    func localizedScheduleSubtitle(locale: Locale = .current) -> String {
        localizedScheduleSummary(locale: locale)
    }
}
