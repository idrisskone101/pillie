//
//  HonestPaywallView.swift
//  Pillie
//

import SwiftUI

struct HonestPaywallView: View {
    @Environment(\.locale) private var locale

    let scene: HonestPaywallScene
    let isPurchasing: Bool
    let onRecurrenceChange: (PaywallRecurrence) -> Void
    let onPurchase: (PaywallPurchaseIntent) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onContinueFree: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if scene.board.chrome.showsClose {
                        closeRow
                    }

                    VStack(spacing: 0) {
                        PaywallMomentHeader(board: scene.board)

                        checkoutChrome(section: .stack)
                    }
                    .padding(.horizontal, HonestPaywallLayout.horizontalInset)

                    Spacer(minLength: 16)

                    checkoutChrome(section: .footer)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        // Paper's footer sits 28pt from the physical bottom, including the home-indicator band.
        .ignoresSafeArea(edges: .bottom)
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(PillieTheme.sage, in: Circle())
            }
            .accessibilityLabel(PillieLocalization.string(
                "global.action.close",
                locale: locale
            ))
        }
        .frame(height: 32)
        .padding(.horizontal, HonestPaywallLayout.horizontalInset)
    }

    private func checkoutChrome(section: PaywallCheckoutSection) -> PaywallCheckoutChrome {
        PaywallCheckoutChrome(
            checkout: scene.checkout,
            isPurchasing: isPurchasing,
            section: section,
            continueFree: continueFree,
            onRecurrenceChange: onRecurrenceChange,
            onPurchase: onPurchase,
            onRestore: onRestore,
            onLifetime: { onPurchase(.lifetime) }
        )
    }

    private var continueFree: PaywallContinueFreeAction? {
        guard let onContinueFree, scene.board.chrome.showsContinueFree else { return nil }
        return PaywallContinueFreeAction(
            title: PillieLocalization.string(
                "trial.end.continue_free",
                table: "Commerce",
                locale: locale
            ),
            action: onContinueFree
        )
    }
}
