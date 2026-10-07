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
