//
//  HonestPaywallView.swift
//  Pillie
//

import SwiftUI

struct HonestPaywallView: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let scene: HonestPaywallScene
    let isPurchasing: Bool
    let onSelect: (PaywallPurchaseIntent) -> Void
    let onPurchase: (PaywallPurchaseIntent) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onContinueFree: (() -> Void)?
    /// The extend offer has taken the sheet's place (ENG-172).
    var isSheetAway = false

    @State private var isSheetRevealed = false
    @State private var isPhoneRevealed = false

    private var sheetOffset: CGFloat {
        isSheetRevealed || accessibilityReduceMotion ? 0 : PaywallEntrance.sheetRise
    }

    private var awayOffset: CGFloat {
        isSheetAway && !accessibilityReduceMotion ? TrialEndExtendSwap.plansDrop : 0
    }

    /// Below the sheet's edge the phone is clipped; once the sheet has gone,
    /// the whole phone shows behind the offer, so the clip lifts too.
    private var heroClipExtra: CGFloat {
        sheetOffset + (isSheetAway ? TrialEndExtendSwap.plansDrop : 0)
    }

    private var phoneOffset: CGFloat {
        isPhoneRevealed || accessibilityReduceMotion ? 0 : PaywallEntrance.phoneRise
    }

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = HonestPaywallLayout.heroHeight(safeAreaHeight: proxy.size.height)
            ZStack(alignment: .top) {
                backdrop(sheetEdge: proxy.safeAreaInsets.top + heroHeight)

                ScrollView {
                    VStack(spacing: 0) {
                        hero(height: heroHeight)
                        sheet
                    }
                    .frame(
                        minHeight: proxy.size.height + proxy.safeAreaInsets.bottom,
                        alignment: .top
                    )
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                // The sheet runs to the physical bottom, under the home indicator.
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(
            TrialEndExtendSwap.animation(arriving: !isSheetAway, reduceMotion: accessibilityReduceMotion),
            value: isSheetAway
        )
        .onAppear {
            let reduced = accessibilityReduceMotion
            withAnimation(reduced ? PaywallEntrance.fade : PaywallEntrance.sheet) { isSheetRevealed = true }
            withAnimation(reduced ? PaywallEntrance.fade : PaywallEntrance.phone) { isPhoneRevealed = true }
        }
    }

    // MARK: - Hero

    private func backdrop(sheetEdge: CGFloat) -> some View {
        LinearGradient(
            colors: [HonestPaywallLayout.backdropTop, HonestPaywallLayout.backdropSheetEdge],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: sheetEdge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HonestPaywallLayout.backdropSheetEdge)
        .ignoresSafeArea()
    }

    private func hero(height: CGFloat) -> some View {
        PaywallPhoneMockup()
            .offset(y: phoneOffset)
            .animation(accessibilityReduceMotion ? PaywallEntrance.fade : PaywallEntrance.phoneFade) {
                $0.opacity(isPhoneRevealed ? 1 : 0)
            }
            .padding(.top, HonestPaywallLayout.phoneTopInset)
            .frame(maxWidth: .infinity)
            // Clip at the sheet's moving top edge so the phone rises from behind it.
            .frame(height: height + heroClipExtra, alignment: .top)
            .clipped()
            .frame(height: height, alignment: .top)
            .overlay(alignment: .topTrailing) {
                if scene.board.chrome.showsClose {
                    closeButton
                        .padding(.top, HonestPaywallLayout.phoneTopInset)
                        .padding(.trailing, 16)
                }
            }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.9), in: Circle())
        }
        .accessibilityLabel(PillieLocalization.string(
            "global.action.close",
            locale: locale
        ))
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(scene.board.story.title)
                .font(.pillie(30, weight: .black))
                .tracking(-0.6)
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(scene.board.story.subtitle)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            planCards
                .padding(.top, 22)

            review
                .padding(.top, 20)

            Spacer(minLength: 24)

            purchaseButton

            if let onContinueFree {
                Button(action: onContinueFree) {
                    Text(PillieLocalization.string(
                        "trial.end.continue_free",
                        table: "Commerce",
                        locale: locale
                    ))
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }

            reassurance
                .padding(.top, 10)

            footerLinks
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .background {
            HonestPaywallLayout.sheetShape
                .fill(PillieTheme.bg)
                .shadow(color: .black.opacity(0.06), radius: 20, y: -4)
        }
        .offset(y: sheetOffset + awayOffset)
        .opacity(isSheetRevealed && !(isSheetAway && accessibilityReduceMotion) ? 1 : 0)
        .allowsHitTesting(!isSheetAway)
        .accessibilityHidden(isSheetAway)
    }

    private var planCards: some View {
        HStack(spacing: 8) {
            ForEach(scene.checkout.cards, id: \.intent) { card in
                planCard(card)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func planCard(_ card: PaywallPlanCard) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let secondaryInk = card.isSelected ? PillieTheme.textPrimary : PillieTheme.textMuted
        return Button {
            onSelect(card.intent)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(card.title)
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(secondaryInk)

                Text(card.price)
                    .font(.pillie(20, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 4)

                Text(card.caption)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(secondaryInk)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: .infinity, alignment: .topLeading)
            .background(card.isSelected ? PillieTheme.coralLight : Color.white, in: shape)
            .overlay {
                shape.strokeBorder(
                    card.isSelected ? PillieTheme.dark : PillieTheme.hairline,
                    lineWidth: card.isSelected ? 2 : 1
                )
            }
            .overlay(alignment: .top) {
                if let badge = card.savingsBadge {
                    Text(badge)
                        .font(.pillie(10, weight: .extraBold))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PillieTheme.dark, in: Capsule())
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityAddTraits(card.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("paywallTile.\(card.intent.pilliePlusPlan.analyticsPlan.rawValue)")
    }

    private var review: some View {
        let story = scene.board.story
        let open = locale.quotationBeginDelimiter ?? "\u{201C}"
        let close = locale.quotationEndDelimiter ?? "\u{201D}"
        return VStack(spacing: 6) {
            Text(open + story.review.quote + close)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(HonestPaywallLayout.starInk)
                .accessibilityHidden(true)

                Text(story.review.source)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Checkout

    private var purchaseButton: some View {
        Button {
            onPurchase(scene.checkout.selectedIntent)
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(scene.checkout.primaryCTA)
                        .font(.pillie(16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(scene.checkout.isPurchaseEnabled ? PillieTheme.dark : PillieTheme.textMuted)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
        .disabled(!scene.checkout.isPurchaseEnabled || isPurchasing)
    }

    private var reassurance: some View {
        Text(scene.checkout.reassurance)
            .font(.pillie(12, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            // Restore's touch slop reaches into this line; claiming the
            // tap keeps the reassurance from starting a restore.
            .contentShape(Rectangle())
            .onTapGesture {}
            .accessibilityRespondsToUserInteraction(false)
            .accessibilityIdentifier("paywallReassurance")
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button(action: onRestore) {
                footerLabel("paywall.footer.restore")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string(
                "paywall.action.restore",
                table: "Commerce",
                locale: locale
            ))
            .accessibilityIdentifier("paywallRestoreButton")

            Link(destination: PaywallLegalLinks.terms) {
                footerLabel("paywall.footer.terms")
            }
            .accessibilityIdentifier("paywallTermsLink")

            Link(destination: PaywallLegalLinks.privacy) {
                footerLabel("paywall.footer.privacy")
            }
            .accessibilityIdentifier("paywallPrivacyLink")
        }
        .frame(maxWidth: .infinity)
    }

    private func footerLabel(_ key: String) -> some View {
        Text(PillieLocalization.string(key, table: "Commerce", locale: locale))
            .font(.pillie(12, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

private enum HonestPaywallLayout {
    static let phoneTopInset: CGFloat = 12
    static let backdropTop = Color(hex: "F9DED7")
    static let backdropSheetEdge = Color(hex: "F6E3DD")
    static let starInk = Color(hex: "D8AA88")

    static let sheetShape = UnevenRoundedRectangle(
        topLeadingRadius: 32,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 32,
        style: .continuous
    )

    /// Visible hero, from the safe-area top to the sheet's top edge.
    static func heroHeight(safeAreaHeight: CGFloat) -> CGFloat {
        min(max(safeAreaHeight * 0.385, 190), 300)
    }
}

/// Option A ("Rise") from the Paper entrance storyboards on p-G-0.
private enum PaywallEntrance {
    static let sheetRise: CGFloat = 64
    static let phoneRise: CGFloat = 120
    static let sheet = Animation.spring(duration: 0.55, bounce: 0.1)
    static let phone = Animation.spring(duration: 0.6, bounce: 0.15).delay(0.08)
    static let phoneFade = Animation.easeOut(duration: 0.16).delay(0.08)
    static let fade = Animation.easeOut(duration: 0.25)
}
