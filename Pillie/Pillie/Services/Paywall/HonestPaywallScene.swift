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
        locale: Locale
    ) -> HonestPaywallScene {
        HonestPaywallScene(
            board: board,
            checkout: PaywallCheckoutBuilder.build(
                moment: board.moment,
                offerings: offerings,
                selection: selection,
                locale: locale
            )
        )
    }
}
