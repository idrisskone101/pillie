//
//  TrialEndSuccessOutcome.swift
//  Pillie
//

import Foundation

enum TrialEndSuccessOutcome: Equatable {
    case purchased(PilliePlusPlan)
    case restored

    var showsCancellationNote: Bool {
        switch self {
        case .purchased(let plan): plan.showsCancellationDisclosure
        case .restored: false
        }
    }

    func label(
        annual: String,
        monthly: String,
        lifetime: String,
        restored: String
    ) -> String {
        switch self {
        case .purchased(.annual): return annual
        case .purchased(.monthly): return monthly
        case .purchased(.lifetime): return lifetime
        case .restored: return restored
        }
    }
}

#if DEBUG
extension HonestPaywallScreen {
    static let debugSuccessStateKey = "trialEndPaywallDebugSuccessState"
    /// The RevenueCat Test Store offering has no lifetime package; this price
    /// stands in for one so simulator QA can see the Lifetime tile.
    static let debugLifetimeDisplayKey = "honestPaywallDebugLifetimeDisplay"
    /// `cancel` or `restore`: the next trial-end paywall rises into the
    /// extend offer as if that had just happened (ENG-172).
    static let debugExtendTriggerKey = "honestPaywallDebugExtendTrigger"
}
#endif
