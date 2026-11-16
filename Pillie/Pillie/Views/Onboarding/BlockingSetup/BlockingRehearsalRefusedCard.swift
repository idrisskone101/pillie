//
//  BlockingRehearsalRefusedCard.swift
//  Pillie
//
//  A drawing of Apple's Screen Time alert with its Continue button ringed. It
//  reproduces none of Apple's wording, which could not be matched in every
//  language: grey bars stand in for the title and message.
//

import SwiftUI

struct BlockingRehearsalRefusedCard: View {
    /// How much of the drawing the card has room for. A long title or a short
    /// screen leaves less, and the caption says the same thing on its own.
    enum Drawing: CaseIterable {
        case full
        case compact
        case captionOnly

        fileprivate var scale: CGFloat {
            switch self {
            case .full: 1
            case .compact, .captionOnly: 0.78
            }
        }
    }

    let content: BlockingRehearsalContent
    let drawing: Drawing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringBreathes = false

    var body: some View {
        VStack(spacing: 16 * drawing.scale) {
            if drawing != .captionOnly {
                alert
                    .frame(maxWidth: 302 * drawing.scale)
                    .accessibilityHidden(true)
            }

            Text(content.refusedCaption)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(BlockingRehearsalPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("blockingRehearsalPromptPreview")
        }
        .padding(24 * drawing.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PillieTheme.lavender, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(PillieTheme.textPrimary.opacity(0.05), lineWidth: 1)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                ringBreathes = true
            }
        }
    }

    private var alert: some View {
        let scale = drawing.scale
        return VStack(alignment: .leading, spacing: 10 * scale) {
            VStack(alignment: .leading, spacing: 8 * scale) {
                bar(PillieTheme.hairlineStrong, height: 14 * scale, fractionOfColumn: 0.88)
                bar(PillieTheme.hairlineStrong, height: 14 * scale, fractionOfColumn: 0.57)
            }
            VStack(alignment: .leading, spacing: 7 * scale) {
                bar(PillieTheme.hairline, height: 9 * scale, fractionOfColumn: 1)
                bar(PillieTheme.hairline, height: 9 * scale, fractionOfColumn: 0.92)
                bar(PillieTheme.hairline, height: 9 * scale, fractionOfColumn: 0.69)
            }
            HStack(spacing: 10 * scale) {
                Text(content.continueCTA)
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundStyle(BlockingRehearsalPalette.alertLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46 * scale)
                    .background(BlockingRehearsalPalette.alertNeutralButton, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(PillieTheme.coral, lineWidth: 3)
                            .padding(-1.5)
                            .scaleEffect(ringBreathes ? 1.04 : 1)
                    }

                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 64 * scale, height: 10 * scale)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46 * scale)
                    .background(BlockingRehearsalPalette.alertTintedButton, in: Capsule())
                    .opacity(0.45)
            }
            .padding(.top, 6 * scale)
        }
        .padding(.top, 22 * scale)
        .padding(.horizontal, 20 * scale)
        .padding(.bottom, 18 * scale)
        .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius * scale, style: .continuous))
        .shadow(color: PillieTheme.textPrimary.opacity(0.14), radius: 20, y: 18)
        .dynamicTypeSize(.large)
    }

    private func bar(_ color: Color, height: CGFloat, fractionOfColumn: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * fractionOfColumn)
                }
            }
    }
}
