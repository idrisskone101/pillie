//
//  ClassicPaywallCheckout.swift
//  Pillie
//

import Foundation

/// The classic arm's stacked plan tiles, CTA and footer.
struct ClassicPaywallCheckout: Equatable {
    let selectedIntent: PaywallPurchaseIntent
    let tiles: [ClassicPaywallStackTile]
    let primaryCTA: String
    let isPurchaseEnabled: Bool
    let footer: ClassicPaywallFooter
}

struct ClassicPaywallStackTile: Equatable {
    let intent: PaywallPurchaseIntent
    let title: String
    let primaryLine: String
    let trailingPrice: String?
    let savingsBadge: ClassicPaywallSavingsBadge?
    let isSelected: Bool
    let accessibilityLabel: String
}

struct ClassicPaywallSavingsBadge: Equatable {
    let percent: Int
    let label: String
}

struct ClassicPaywallFooter: Equatable {
    let reassurance: String
    let restoreActionLabel: String
}
