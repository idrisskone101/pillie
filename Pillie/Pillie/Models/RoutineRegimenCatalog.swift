//
//  RoutineRegimenCatalog.swift
//  Pillie
//
//  Common-first grouping of the pill regimens for Routine Basics Details (#77). The
//  legacy form listed all seven presets as equal cards, which read as a busy wall of
//  choices. Here the three regimens most users pick are surfaced up front and the
//  rest sit behind a "More options" disclosure — but `common + more` always covers
//  every `PillPack.PillRegimenPreset`, so the full production model is preserved and
//  no existing pack type becomes unreachable.
//

import Foundation

enum RoutineRegimenCatalog {
    /// The regimens shown up front, in display order.
    static let common: [PillPack.PillRegimenPreset] = [
        .twentyOneSeven,
        .twentyFourFour,
        .threeSixtyFiveZero,
    ]

    /// The remaining regimens, revealed via the "More options" disclosure. Together
    /// with `common`, this is exactly the full set of presets.
    static let more: [PillPack.PillRegimenPreset] = [
        .twentySixTwo,
        .twentyEightZero,
        .eightyFourSeven,
        .custom,
    ]
}

extension PillPack.PillRegimenPreset {
    /// Friendly label for the Routine Details rows. The two most common shapes read
    /// more clearly as words; everything else keeps its familiar ratio label.
    var routineDisplayName: String {
        switch self {
        case .twentyOneSeven: return "Standard"
        case .threeSixtyFiveZero: return "Continuous"
        case .custom: return "Custom"
        default: return rawValue
        }
    }
}
