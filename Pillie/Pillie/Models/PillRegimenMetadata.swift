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
        case .twentySixTwo:
            key = "onboarding.regimen.26_2"
        case .twentyEightZero:
            key = "onboarding.regimen.28_0"
        case .eightyFourSeven:
            key = "onboarding.regimen.84_7"
        case .threeSixtyFiveZero:
            key = "onboarding.regimen.365_0"
        case .custom:
            key = "onboarding.regimen.custom"
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
