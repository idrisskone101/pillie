//
//  HonestPaywallScene.swift
//  Pillie
//

import Foundation

struct HonestPaywallScene: Equatable {
    let board: HonestPaywallBoard
    let checkout: PaywallCheckoutSheet
}

enum HonestPaywallSceneBuilder {
    static func build(
        board: HonestPaywallBoard,
        offerings: PaywallOfferingsSnapshot?,
        selection: PaywallPurchaseIntent,
        locale: Locale,
        annualFreeWeek: Bool = false,
        loadFailed: Bool = false
    ) -> HonestPaywallScene {
        HonestPaywallScene(
            board: board,
            checkout: PaywallCheckoutBuilder.build(
                moment: board.moment,
                offerings: offerings,
                selection: selection,
                locale: locale,
                annualFreeWeek: annualFreeWeek,
                loadFailed: loadFailed
            )
        )
    }
}
