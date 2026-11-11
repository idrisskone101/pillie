//
//  HonestPaywallScene.swift
//  Pillie
//

import Foundation

/// The S3 layout's content: the board's story with its plan cards.
struct HonestPaywallScene: Equatable {
    let chrome: HonestPaywallChrome
    let story: HonestPaywallStory
    let checkout: PaywallCheckoutSheet
}

enum HonestPaywallSceneBuilder {
    static func build(
        board: HonestPaywallBoard,
        story: HonestPaywallStory,
        offerings: PaywallOfferingsSnapshot?,
        selection: PaywallPurchaseIntent,
        locale: Locale
    ) -> HonestPaywallScene {
        HonestPaywallScene(
            chrome: board.chrome,
            story: story,
            checkout: PaywallCheckoutBuilder.build(
                moment: board.moment,
                offerings: offerings,
                selection: selection,
                locale: locale
            )
        )
    }
}
