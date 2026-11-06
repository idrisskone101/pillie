//
//  HonestPaywallBoard.swift
//  Pillie
//

import Foundation

struct HonestPaywallBoard: Equatable {
    let moment: HonestPaywallMoment
    let layout: HonestPaywallLayout

    var chrome: HonestPaywallChrome { moment.chrome }
    var ctaVerb: PaywallCTAVerb { moment.ctaVerb }

    var isTrialEnd: Bool {
        switch moment {
        case .trialEnded: true
        case .duringTrial, .settingsFree: false
        }
    }
}

/// What the board renders, by paywall_design_v1 arm.
enum HonestPaywallLayout: Equatable {
    case s3(HonestPaywallStory)
    case classic(ClassicPaywallStory)
}

enum HonestPaywallMoment: Equatable {
    case duringTrial
    case trialEnded(TrialEndAccessTerms)
    case settingsFree

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
        case .trialEnded(.hardPaywall):
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
        case .settingsFree: .get
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
