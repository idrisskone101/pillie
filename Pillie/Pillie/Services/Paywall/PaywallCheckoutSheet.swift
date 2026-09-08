//
//  PaywallCheckoutSheet.swift
//  Pillie
//

import Foundation

struct PaywallCheckoutSheet: Equatable {
    let selectedRecurrence: PaywallRecurrence
    let yearTile: PaywallStackTile
    let monthTile: PaywallStackTile
    let lifetimeLink: PaywallLifetimeLink?
    let primaryCTA: String
    let isPurchaseEnabled: Bool
    let footer: PaywallFooter
}

struct PaywallStackTile: Equatable {
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

struct PaywallLifetimeLink: Equatable {
    let text: String
    let accessibilityLabel: String
}

struct PaywallFooter: Equatable {
    let reassurance: String
    let restoreActionLabel: String
}
