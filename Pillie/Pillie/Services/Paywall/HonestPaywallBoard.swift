//
//  HonestPaywallBoard.swift
//  Pillie
//

import Foundation

struct HonestPaywallChrome: Equatable {
    let showsClose: Bool
    let allowsInteractiveDismiss: Bool
    let showsContinueFree: Bool
}

enum PaywallCTAVerb: Equatable {
    case keep
    case get
}

enum HonestPaywallBoard: Equatable {
    case duringTrial(HonestPaywallTrialActiveStory)
    case trialEnded(HonestPaywallTrialEndedStory)
    case settingsFree(HonestPaywallSettingsStory)

    var chrome: HonestPaywallChrome {
        switch self {
        case .duringTrial, .settingsFree:
            HonestPaywallChrome(
                showsClose: true,
                allowsInteractiveDismiss: true,
                showsContinueFree: false
            )
        case .trialEnded(let story):
            story.chrome
        }
    }

    var ctaVerb: PaywallCTAVerb {
        switch self {
        case .duringTrial, .trialEnded: .keep
        case .settingsFree: .get
        }
    }
}

struct HonestPaywallTrialActiveStory: Equatable {
    let title: String
    let subtitle: String
    let daysRemaining: Int
    let daysStampText: String
    let benefitChips: [PaywallBenefitChip]
}

struct HonestPaywallTrialEndedStory: Equatable {
    let title: String
    let subtitle: String
    let doseTile: PaywallStatTile
    let streakTile: PaywallStatTile
    let handwrittenLossLine: String
    let chrome: HonestPaywallChrome
}

struct HonestPaywallSettingsStory: Equatable {
    let title: String
    let subtitle: String
    let freeCard: PaywallComparisonCard
    let plusCard: PaywallComparisonCard
}

struct PaywallBenefitChip: Equatable {
    let label: String
    let tint: PaywallChipTint
}

enum PaywallChipTint: Equatable {
    case lavender
    case sage
    case coralSoft
}

struct PaywallStatTile: Equatable {
    let label: String
    let value: String
    let background: PaywallTileBackground
}

enum PaywallTileBackground: Equatable {
    case lavender
    case coralSoft
    case ink
}

struct PaywallComparisonCard: Equatable {
    let tierLabel: String
    let bullets: [String]
    let background: PaywallTileBackground
}
