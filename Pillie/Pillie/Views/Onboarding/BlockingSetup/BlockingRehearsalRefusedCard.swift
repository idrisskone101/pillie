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
    let content: BlockingRehearsalContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringBreathes = false

    var body: some View {
        VStack(spacing: 16) {
            alert
                .frame(maxWidth: 302)
                .accessibilityHidden(true)

            Text(content.refusedCaption)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(BlockingRehearsalPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("blockingRehearsalPromptPreview")
        }
        .padding(24)
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                bar(PillieTheme.hairlineStrong, height: 14, radius: 7, width: 0.88)
                bar(PillieTheme.hairlineStrong, height: 14, radius: 7, width: 0.57)
            }
            VStack(alignment: .leading, spacing: 7) {
                bar(PillieTheme.hairline, height: 9, radius: 5, width: 1)
                bar(PillieTheme.hairline, height: 9, radius: 5, width: 0.92)
                bar(PillieTheme.hairline, height: 9, radius: 5, width: 0.69)
            }
            HStack(spacing: 10) {
                Text(content.continueCTA)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BlockingRehearsalPalette.alertLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(BlockingRehearsalPalette.alertNeutralButton, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(PillieTheme.coral, lineWidth: 3)
                            .padding(-1.5)
                            .scaleEffect(ringBreathes ? 1.04 : 1)
                    }

                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.85))
                    .frame(width: 64, height: 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(BlockingRehearsalPalette.alertTintedButton, in: Capsule())
                    .opacity(0.45)
            }
            .padding(.top, 6)
        }
        .padding(.top, 22)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous))
        .shadow(color: PillieTheme.textPrimary.opacity(0.14), radius: 20, y: 18)
    }

    /// `width` is a fraction of the alert's text column.
    private func bar(_ color: Color, height: CGFloat, radius: CGFloat, width: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: radius)
                        .fill(color)
                        .frame(width: proxy.size.width * width)
                }
            }
    }
}
