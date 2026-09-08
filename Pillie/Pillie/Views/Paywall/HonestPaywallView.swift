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
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    PaywallMomentHeader(board: scene.board)
                    PaywallCheckoutChrome(
                        checkout: scene.checkout,
                        isPurchasing: isPurchasing,
                        onRecurrenceChange: onRecurrenceChange,
                        onPurchase: onPurchase,
                        onRestore: onRestore,
                        onLifetime: { onPurchase(.lifetime) }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, scene.board.chrome.showsClose ? 8 : 24)
                .padding(.bottom, 32)
            }

            if scene.board.chrome.showsClose {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(PillieTheme.sage, in: Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
                .accessibilityLabel(PillieLocalization.string("global.action.close"))
            }
        }
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
}
