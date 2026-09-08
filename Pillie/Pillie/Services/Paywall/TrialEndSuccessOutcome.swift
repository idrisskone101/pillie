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
}
#endif
