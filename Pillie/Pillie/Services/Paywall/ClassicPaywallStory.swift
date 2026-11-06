//
//  ClassicPaywallStory.swift
//  Pillie
//
//  The paywall_design_v1 `classic` arm: the story main showed before PR #383.
//

import Foundation

enum ClassicPaywallStory: Equatable {
    case duringTrial(ClassicPaywallTrialActiveStory)
    case trialEnded(ClassicPaywallTrialEndedStory)
    case settingsFree(ClassicPaywallSettingsStory)
}

struct ClassicPaywallTrialActiveStory: Equatable {
    let title: String
    let subtitle: String
    let daysRemaining: Int
    let daysStampText: String
    let benefitChips: [ClassicPaywallBenefitChip]
}

enum ClassicPaywallTrialEndedBody: Equatable {
    case stats(dose: ClassicPaywallStatTile?, streak: ClassicPaywallStatTile?, lossLine: String)
    case comparison(free: ClassicPaywallComparisonCard, plus: ClassicPaywallComparisonCard)
    case chips([ClassicPaywallBenefitChip], aside: String)
}

struct ClassicPaywallTrialEndedStory: Equatable {
    let title: String
    let subtitle: String
    let body: ClassicPaywallTrialEndedBody
}

struct ClassicPaywallSettingsStory: Equatable {
    let title: String
    let subtitle: String
    let freeCard: ClassicPaywallComparisonCard
    let plusCard: ClassicPaywallComparisonCard
}

struct ClassicPaywallBenefitChip: Equatable {
    let label: String
    let tint: ClassicPaywallChipTint
}

enum ClassicPaywallChipTint: Equatable {
    case lavender
    case sage
    case coralSoft
}

struct ClassicPaywallStatTile: Equatable {
    let label: String
    let value: String
    let background: ClassicPaywallTileBackground
}

enum ClassicPaywallTileBackground: Equatable {
    case lavender
    case coralSoft
    case ink
}

struct ClassicPaywallComparisonCard: Equatable {
    let tierLabel: String
    let bullets: [String]
    let background: ClassicPaywallTileBackground
}
