//
//  PaywallPurchaseIntent.swift
//  Pillie
//

import Foundation

enum PaywallPurchaseIntent: Equatable {
    case subscribe(PaywallRecurrence)
    case lifetime

    var pilliePlusPlan: PilliePlusPlan {
        switch self {
        case .subscribe(.year): .annual
        case .subscribe(.month): .monthly
        case .lifetime: .lifetime
        }
    }
}
