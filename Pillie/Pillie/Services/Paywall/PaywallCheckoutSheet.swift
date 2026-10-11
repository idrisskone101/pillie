//
//  PaywallCheckoutSheet.swift
//  Pillie
//

import Foundation

struct PaywallCheckoutSheet: Equatable {
    let selectedIntent: PaywallPurchaseIntent
    let cards: [PaywallPlanCard]
    let primaryCTA: String
    let isPurchaseEnabled: Bool
    let reassurance: String
    var primaryAction: PaywallPrimaryAction = .purchase
}

enum PaywallPrimaryAction: Equatable {
    case purchase
    /// The plans failed to load; the button reloads them.
    case retry
}

struct PaywallPlanCard: Equatable {
    let intent: PaywallPurchaseIntent
    let title: String
    let price: String
    let caption: String
    let savingsBadge: String?
    let isSelected: Bool
    let accessibilityLabel: String
}
