//
//  HonestPaywallDebugKeys.swift
//  Pillie
//

import Foundation

#if DEBUG
extension HonestPaywallScreen {
    /// `1` or a `PaywallSuccessReceipt.debugSample` kind: the paywall plays its
    /// success screen once the entrance settles.
    static let debugSuccessStateKey = "trialEndPaywallDebugSuccessState"
    /// The RevenueCat Test Store offering has no lifetime package; this price
    /// stands in for one so simulator QA can see the Lifetime tile.
    static let debugLifetimeDisplayKey = "honestPaywallDebugLifetimeDisplay"
    /// `cancel` or `restore`: the next trial-end paywall rises into the
    /// extend offer as if that had just happened (ENG-172).
    static let debugExtendTriggerKey = "honestPaywallDebugExtendTrigger"
}
#endif
