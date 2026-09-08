//
//  PausedPhoneIllustration.swift
//  Pillie
//
//  Decorative paused-phone stage for the app-blocking empty state.
//  Fills the leftover hole between hero and footer; not interactive.
//

import SwiftUI

struct PausedPhoneStageLayout: Equatable {
    static let designCanvas = CGSize(width: 390, height: 442)
    static let designCircle: CGFloat = 310
    static let designCircleTop: CGFloat = 30
    static let designPhone = CGSize(width: 232, height: 300)

    static var designCircleBottomInset: CGFloat {
        designCanvas.height - (designCircleTop + designCircle)
    }

    let scale: CGFloat

    static func fitted(in size: CGSize) -> Self {
        guard size.width > 0, size.height > 0 else { return Self(scale: 1) }
        return Self(
            scale: min(
                size.width / designCanvas.width,
                size.height / designCanvas.height
            )
        )
    }
}

struct PausedPhoneIllustration: View {
    let title: String
    let unlockHint: String
    let markTaken: String

    var body: some View {
        GeometryReader { geo in
            let layout = PausedPhoneStageLayout.fitted(in: geo.size)
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(PillieTheme.coralLight)
                    .frame(
                        width: PausedPhoneStageLayout.designCircle,
                        height: PausedPhoneStageLayout.designCircle
                    )
                    .offset(y: -PausedPhoneStageLayout.designCircleBottomInset)

                PausedPhoneMock(
                    title: title,
                    unlockHint: unlockHint,
                    markTaken: markTaken
                )
            }
            .frame(
                width: PausedPhoneStageLayout.designCanvas.width,
                height: PausedPhoneStageLayout.designCanvas.height,
                alignment: .bottom
            )
            .scaleEffect(layout.scale, anchor: .bottom)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct PausedPhoneMock: View {
    let title: String
    let unlockHint: String
    let markTaken: String

    private var phoneBezel: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 36,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 36,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            genericPausedAppTile

            Text(title)
                .font(.pillie(18, weight: .bold))
                .tracking(-0.18)
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(unlockHint)
                .font(.pillie(13, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(markTaken)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(PillieTheme.dark, in: Capsule())
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 44)
        .frame(
            width: PausedPhoneStageLayout.designPhone.width,
            height: PausedPhoneStageLayout.designPhone.height,
            alignment: .top
        )
        .background(Color.white)
        .clipShape(phoneBezel)
        .overlay {
            phoneBezel.stroke(PillieTheme.dark, lineWidth: 6)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(PillieTheme.dark)
                .frame(width: 70, height: 20)
                .padding(.top, 12)
        }
        .shadow(color: PillieTheme.dark.opacity(0.1), radius: 20, y: -6)
    }

    private var genericPausedAppTile: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PillieTheme.lavender)
                .frame(width: 58, height: 58)
                .overlay {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            appGlyph(opacity: 0.35)
                            appGlyph(opacity: 0.18)
                        }
                        HStack(spacing: 3) {
                            appGlyph(opacity: 0.18)
                            appGlyph(opacity: 0.35)
                        }
                    }
                }

            ZStack {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 22, height: 22)
                HStack(spacing: 2.5) {
                    Capsule()
                        .fill(PillieTheme.dark)
                        .frame(width: 2.5, height: 8)
                    Capsule()
                        .fill(PillieTheme.dark)
                        .frame(width: 2.5, height: 8)
                }
            }
            .offset(x: 6, y: 6)
        }
        .accessibilityHidden(true)
    }

    private func appGlyph(opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(PillieTheme.dark.opacity(opacity))
            .frame(width: 8, height: 8)
    }
}
