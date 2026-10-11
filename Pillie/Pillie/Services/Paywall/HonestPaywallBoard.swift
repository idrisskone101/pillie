//
//  HonestPaywallBoard.swift
//  Pillie
//

import Foundation

struct HonestPaywallBoard: Equatable {
    let moment: HonestPaywallMoment
    let story: HonestPaywallStory

    var chrome: HonestPaywallChrome { moment.chrome }
    var ctaVerb: PaywallCTAVerb { moment.ctaVerb }

    var isTrialEnd: Bool {
        switch moment {
        case .trialEnded: true
        case .duringTrial, .settingsFree, .onboarding: false
        }
    }
}

enum HonestPaywallMoment: Equatable {
    case duringTrial
    case trialEnded(TrialEndAccessTerms)
    case settingsFree
    /// The `hard_trial` arm's onboarding paywall (ENG-206): nothing past it without Plus.
    case onboarding

    var chrome: HonestPaywallChrome {
        switch self {
        case .duringTrial, .settingsFree:
            HonestPaywallChrome(
                showsClose: true,
                allowsInteractiveDismiss: true,
                showsContinueFree: false
            )
        case .trialEnded(.legacy):
            HonestPaywallChrome(
                showsClose: true,
                allowsInteractiveDismiss: true,
                showsContinueFree: true
            )
        case .trialEnded(.hardPaywall), .onboarding:
            HonestPaywallChrome(
                showsClose: false,
                allowsInteractiveDismiss: false,
                showsContinueFree: false
            )
        }
    }

    var ctaVerb: PaywallCTAVerb {
        switch self {
        case .duringTrial, .trialEnded: .keep
        case .settingsFree, .onboarding: .get
        }
    }
}

struct HonestPaywallChrome: Equatable {
    let showsClose: Bool
    let allowsInteractiveDismiss: Bool
    let showsContinueFree: Bool
}

enum PaywallCTAVerb: Equatable {
    case keep
    case get
}

struct HonestPaywallStory: Equatable {
    let title: String
    let subtitle: String
    let review: PaywallReview
}

struct PaywallReview: Equatable {
    let quote: String
    let source: String
}
