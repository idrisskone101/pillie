//
//  PillRegimenMetadata.swift
//  Pillie
//

import Foundation

extension PillPack.PillRegimenPreset {
    func localizedScheduleSummary(locale: Locale = .current) -> String {
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

    func localizedRoutineDisplayName(locale: Locale = .current) -> String {
        let key: String?
        switch self {
        case .twentyOneSeven:
            key = "onboarding.regimen.name.standard"
        case .everyDay:
            key = "onboarding.regimen.name.continuous"
        case .custom:
            key = "onboarding.regimen.name.custom"
        default:
            key = nil
        }
        return key.map { PillieLocalization.string($0, locale: locale) } ?? ratioLabel
    }

    func localizedScheduleSubtitle(locale: Locale = .current) -> String {
        localizedScheduleSummary(locale: locale)
    }

    // Raw values are persisted identities, so "21-ONLY" must not reach the UI.
    private var ratioLabel: String {
        switch self {
        case .twentyOneOnly: return "21"
        default: return rawValue
        }
    }
}
