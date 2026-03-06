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
}
