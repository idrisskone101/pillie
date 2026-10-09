//
//  TrialEndExtendOfferSheet.swift
//  Pillie
//
//  The one-time extend offer (ENG-172, Paper 3A). It rises in place of the
//  plans sheet over the same backdrop, so the phone mock never moves.
//

import SwiftUI

struct TrialEndExtendOfferSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let card: TrialEndExtendOfferCard
    let isPresented: Bool
    let isPurchasing: Bool
    let onStart: () -> Void
    let onNotNow: () -> Void

    @State private var isRevealed = false
    @State private var sheetHeight: CGFloat = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    private var isShown: Bool { isPresented && isRevealed }

    private var offset: CGFloat {
        guard !isShown, !accessibilityReduceMotion else { return 0 }
        return max(TrialEndExtendSwap.offerRise, sheetHeight)
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            sheet
            ScrollView { sheet }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .offset(y: offset)
        .opacity(accessibilityReduceMotion && !isShown ? 0 : 1)
        .animation(
            TrialEndExtendSwap.animation(arriving: isPresented, reduceMotion: accessibilityReduceMotion),
            value: isPresented
        )
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isPresented)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: isRevealed) { _, revealed in
            revealed && !accessibilityReduceMotion
        }
        .onAppear {
            withAnimation(TrialEndExtendSwap.animation(arriving: true, reduceMotion: accessibilityReduceMotion)) {
                isRevealed = true
            }
            isTitleFocused = true
        }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock

            timeline
                .padding(.top, 20)

            footer
                .padding(.top, 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Content height only: the sheet covers as much of the phone as its
        // copy needs, never the whole screen.
        .fixedSize(horizontal: false, vertical: true)
        .background {
            TrialEndExtendSwap.sheetShape
                .fill(PillieTheme.bg)
                .shadow(color: PillieTheme.dark.opacity(0.1), radius: 15, y: -12)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
    }

    // MARK: - Title

    private var titleBlock: some View {
        let gap: CGFloat = card.restoreNote == nil ? 8 : 10
        return VStack(alignment: .leading, spacing: gap) {
            if let restoreNote = card.restoreNote {
                restoreChip(restoreNote)
            }

            title
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(card.title.replacingOccurrences(of: "\n", with: " "))
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)
                .accessibilityIdentifier("extendOfferTitle")

            Text(card.subtitle)
                .font(.pillie(15, weight: .medium))
                .paperLineHeight(21, fontSize: 15)
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// SwiftUI ignores negative line spacing, so each authored line is its
    /// own Text, pulled together to Paper's 34pt line height.
    private var title: some View {
        let lineGap = 34 - 32 * 1.26
        return VStack(alignment: .leading, spacing: lineGap) {
            ForEach(Array(card.title.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.pillie(32, weight: .black))
                    .tracking(-0.96)
                    .foregroundStyle(PillieTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, lineGap / 2)
    }

    private func restoreChip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .accessibilityHidden(true)

            Text(text)
                .font(.pillie(13, weight: .semibold))
                .paperLineHeight(18, fontSize: 13)
                .foregroundStyle(TrialEndExtendSwap.chipInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 7)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .background(TrialEndExtendSwap.chipFill, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("extendOfferRestoreNote")
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(card.stops.enumerated()), id: \.offset) { index, stop in
                TimelineStopRow(stop: stop, isLast: index == card.stops.count - 1)
                    // Keyed on the entrance only, so Not now drops a full card.
                    .opacity(isRevealed || accessibilityReduceMotion ? 1 : 0)
                    .offset(y: isRevealed || accessibilityReduceMotion ? 0 : 8)
                    .animation(TrialEndExtendSwap.row(index), value: isRevealed)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Button(action: onStart) {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(card.cta)
                            .font(.pillie(16, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(PillieTheme.dark, in: Capsule())
                .shadow(color: PillieTheme.dark.opacity(0.25), radius: 7.5, y: 8)
            }
            .disabled(isPurchasing)
            .accessibilityIdentifier("extendOfferStartButton")

            Button(action: onNotNow) {
                Text(PillieLocalization.string("global.action.not_now", locale: locale))
                    .font(.pillie(15, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
            .accessibilityIdentifier("extendOfferNotNowButton")

            HStack(spacing: 18) {
                Link(destination: PaywallLegalLinks.terms) {
                    legalLabel("paywall.footer.terms")
                }
                .accessibilityIdentifier("extendOfferTermsLink")

                Link(destination: PaywallLegalLinks.privacy) {
                    legalLabel("paywall.footer.privacy")
                }
                .accessibilityIdentifier("extendOfferPrivacyLink")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legalLabel(_ key: String) -> some View {
        Text(PillieLocalization.string(key, table: "Commerce", locale: locale))
            .font(.pillie(12, weight: .medium))
            .paperLineHeight(16, fontSize: 12)
            .foregroundStyle(PillieTheme.textMuted)
            // A 44pt tap target without growing the 16pt row.
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .padding(.vertical, -14)
    }
}

private struct TimelineStopRow: View {
    let stop: TrialEndExtendOfferCard.Stop
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                node
                if !isLast {
                    Capsule()
                        .fill(TrialEndExtendSwap.railInk)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 16)
            .padding(.top, 1)
            .padding(.bottom, isLast ? 0 : 4)

            VStack(alignment: .leading, spacing: isLast ? 0 : 1) {
                Text(stop.date)
                    .font(.pillie(13, weight: .semibold))
                    .paperLineHeight(18, fontSize: 13)
                    .foregroundStyle(PillieTheme.textMuted)

                headline

                Text(stop.caption)
                    .font(.pillie(13, weight: .medium))
                    .paperLineHeight(18, fontSize: 13)
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : 16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var headline: some View {
        if case .charge(let price) = stop.kind {
            Text(TrialEndExtendSwap.chargeHeadline(stop.headline, price: price))
                .paperLineHeight(46, fontSize: 40)
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("extendOfferPrice")
        } else {
            Text(stop.headline)
                .font(.pillie(17, weight: .bold))
                .paperLineHeight(22, fontSize: 17)
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var node: some View {
        switch stop.kind {
        case .today:
            Circle()
                .fill(PillieTheme.dark)
                .frame(width: 16, height: 16)
        case .reminder, .lastDayToCancel:
            ring(fill: PillieTheme.bg)
        case .charge:
            ring(fill: PillieTheme.coral)
        }
    }

    private func ring(fill: Color) -> some View {
        Circle()
            .fill(fill)
            .overlay { Circle().strokeBorder(PillieTheme.dark, lineWidth: 2) }
            .frame(width: 16, height: 16)
    }
}

/// Paper "Notes · Offer motion": two trips, one down and one up, so the offer
/// reads as a new sheet. Reduce Motion keeps everything in place and fades.
enum TrialEndExtendSwap {
    static let plansDrop: CGFloat = 560
    static let offerRise: CGFloat = 600

    static let sheetShape = UnevenRoundedRectangle(
        topLeadingRadius: 32,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 32,
        style: .continuous
    )
    static let railInk = Color(hex: "D6D0CB")
    static let chipFill = Color(hex: "F3F0EC")
    static let chipInk = Color(hex: "57534E")

    /// The sheet that leaves drops on an ease-in; the one that arrives rises on
    /// a spring that starts while the other is still falling.
    static func animation(arriving: Bool, reduceMotion: Bool) -> Animation {
        switch (arriving, reduceMotion) {
        case (true, false): .spring(duration: 0.55, bounce: 0.12).delay(0.18)
        case (false, false): .easeIn(duration: 0.22)
        case (true, true): .easeOut(duration: 0.25).delay(0.15)
        case (false, true): .easeOut(duration: 0.15)
        }
    }

    static let priceFont = Font.pillie(40, weight: .black)
    static let periodFont = Font.pillie(20, weight: .bold)

    /// The price stays the loudest text on the card and the billing period
    /// sits beside it, smaller, on the same baseline. The price run is found
    /// in the formatted headline, so any locale word order works; a headline
    /// without it is set whole at the price size.
    static func chargeHeadline(_ headline: String, price: String) -> AttributedString {
        var text = AttributedString(headline)
        let priceRun = text.range(of: price) ?? text.startIndex..<text.endIndex
        text.font = periodFont
        text[priceRun].font = priceFont
        text[priceRun].tracking = -1.2
        return text
    }

    /// Timeline stops fade up top to bottom, so the price lands last.
    static func row(_ index: Int) -> Animation {
        .easeOut(duration: 0.24).delay(0.38 + 0.06 * Double(index))
    }
}

extension View {
    /// Paper's CSS line height for Outfit, whose natural line is 1.26 em: half
    /// the difference above and below, the rest between lines. SwiftUI drops
    /// negative line spacing, so a tighter multi-line block needs split lines.
    func paperLineHeight(_ lineHeight: CGFloat, fontSize: CGFloat) -> some View {
        let extra = lineHeight - fontSize * 1.26
        return lineSpacing(max(extra, 0)).padding(.vertical, extra / 2)
    }
}
