//
//  ClassicPaywallView.swift
//  Pillie
//
//  The paywall_design_v1 `classic` arm, ported from HonestPaywallView at
//  2c8062a. HonestPaywallScreen owns everything but the layout.
//

import SwiftUI

struct ClassicPaywallView: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let moment: HonestPaywallMoment
    let story: ClassicPaywallStory
    let checkout: ClassicPaywallCheckout
    let isPurchasing: Bool
    let onSelect: (PaywallPurchaseIntent) -> Void
    let onPurchase: (PaywallPurchaseIntent) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onContinueFree: (() -> Void)?
    /// The extend offer or the purchase success sheet has taken the plans' place.
    var isAway = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if moment.chrome.showsClose {
                        closeRow
                    }

                    VStack(spacing: 0) {
                        ClassicPaywallMomentHeader(story: story)

                        PaywallPlusIncludes()
                            .padding(.top, 16)

                        checkoutChrome(section: .stack)
                    }
                    .padding(.horizontal, ClassicPaywallMetrics.horizontalInset)

                    Spacer(minLength: 16)

                    checkoutChrome(section: .footer)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        // Paper's footer sits 28pt from the physical bottom, including the home-indicator band.
        .ignoresSafeArea(edges: .bottom)
        .background { coralWash }
        .opacity(isAway ? 0 : 1)
        .allowsHitTesting(!isAway)
        .accessibilityHidden(isAway)
        .animation(
            TrialEndExtendSwap.animation(arriving: !isAway, reduceMotion: accessibilityReduceMotion),
            value: isAway
        )
    }

    private var coralWash: some View {
        let alignment: Alignment = if case .trialEnded = moment { .topLeading } else { .topTrailing }
        return Circle()
            .fill(PillieTheme.coral.opacity(0.28))
            .frame(width: 240, height: 220)
            .blur(radius: 60)
            .offset(x: alignment == .topLeading ? -80 : 80, y: -40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .ignoresSafeArea()
            .accessibilityHidden(true)
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
        .padding(.horizontal, ClassicPaywallMetrics.horizontalInset)
    }

    private func checkoutChrome(section: ClassicPaywallCheckoutSection) -> ClassicPaywallCheckoutChrome {
        ClassicPaywallCheckoutChrome(
            checkout: checkout,
            isPurchasing: isPurchasing,
            section: section,
            continueFree: continueFree,
            onSelect: onSelect,
            onPurchase: onPurchase,
            onRestore: onRestore
        )
    }

    private var continueFree: ClassicPaywallContinueFreeAction? {
        guard let onContinueFree, moment.chrome.showsContinueFree else { return nil }
        return ClassicPaywallContinueFreeAction(
            title: PillieLocalization.string(
                "trial.end.continue_free",
                table: "Commerce",
                locale: locale
            ),
            action: onContinueFree
        )
    }
}
