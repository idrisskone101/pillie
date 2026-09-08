//
//  HonestPaywallView.swift
//  Pillie
//

import SwiftUI

struct HonestPaywallView: View {
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

                        PaywallCheckoutChrome(
                            checkout: scene.checkout,
                            isPurchasing: isPurchasing,
                            section: .stack,
                            onRecurrenceChange: onRecurrenceChange,
                            onPurchase: onPurchase,
                            onRestore: onRestore,
                            onLifetime: { onPurchase(.lifetime) }
                        )
                    }
                    .padding(.horizontal, HonestPaywallLayout.horizontalInset)

                    Spacer(minLength: 16)

                    PaywallCheckoutChrome(
                        checkout: scene.checkout,
                        isPurchasing: isPurchasing,
                        section: .footer,
                        onRecurrenceChange: onRecurrenceChange,
                        onPurchase: onPurchase,
                        onRestore: onRestore,
                        onLifetime: { onPurchase(.lifetime) }
                    )
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        // Paper's footer sits 28pt from the physical bottom, including the home-indicator band.
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let onContinueFree, scene.board.chrome.showsContinueFree {
                Button(action: onContinueFree) {
                    Text(PillieLocalization.string("trial.end.continue_free", table: "Commerce"))
                        .font(.pillie(14, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            }
        }
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
            .accessibilityLabel(PillieLocalization.string("global.action.close"))
        }
        .frame(height: 32)
        .padding(.horizontal, HonestPaywallLayout.horizontalInset)
    }
}
