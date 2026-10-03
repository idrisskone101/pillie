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
                verb: board.ctaVerb,
                offerings: offerings,
                selection: selection,
                locale: locale
            )
        )
    }

    static func placeholder(
        board: HonestPaywallBoard,
        locale: Locale
    ) -> HonestPaywallScene {
        build(
            board: board,
            offerings: nil,
            selection: .subscribe(.year),
            locale: locale
        )
    }
}
