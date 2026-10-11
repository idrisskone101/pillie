//
//  PaywallEntryPoint.swift
//  Pillie
//

import Foundation

enum PaywallEntryPoint: Equatable {
    case trialStatus
    case settingsSubscription
    case homeBlockingCard
    case protectionOffCard
    case plusUpsell
    case trialEndAutoPresent
    case onboardingEnd
}

extension AnalyticsPaywallSurface {
    var paywallEntry: PaywallEntryPoint {
        switch self {
        case .trialStatus: .trialStatus
        case .settingsSubscription: .settingsSubscription
        case .homeBlockingCard: .homeBlockingCard
        case .protectionOffCard: .protectionOffCard
        case .plusUpsell: .plusUpsell
        case .trialEnd: .trialEndAutoPresent
        case .onboardingEnd: .onboardingEnd
        // Onboarding verification restores only; it never opens a board, and the
        // gate it guards resolves into the trial-end wall.
        case .onboardingVerification: .trialEndAutoPresent
        }
    }
}
