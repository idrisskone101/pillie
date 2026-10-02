//
//  PaywallCheckoutSheet.swift
//  Pillie
//

import Foundation

struct PaywallCheckoutSheet: Equatable {
    let selectedIntent: PaywallPurchaseIntent
    let tiles: [PaywallStackTile]
    let primaryCTA: String
    let isPurchaseEnabled: Bool
    let footer: PaywallFooter
}

struct PaywallStackTile: Equatable {
    let intent: PaywallPurchaseIntent
    let title: String
    let primaryLine: String
    let trailingPrice: String?
    let savingsBadge: PaywallSavingsBadge?
    let isSelected: Bool
    let accessibilityLabel: String
}

struct PaywallSavingsBadge: Equatable {
    let percent: Int
    let label: String
}

struct PaywallFooter: Equatable {
    let reassurance: String
    let restoreActionLabel: String
}
