//
//  PaywallMomentHeader.swift
//  Pillie
//

import SwiftUI

struct PaywallMomentHeader: View {
    let board: HonestPaywallBoard

    var body: some View {
        switch board {
        case .duringTrial(let story):
            trialActiveHeader(story)
        case .trialEnded(let story):
            trialEndedHeader(story)
        case .settingsFree(let story):
            settingsFreeHeader(story)
        }
    }

    @ViewBuilder
    private func trialActiveHeader(_ story: HonestPaywallTrialActiveStory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.pillie(28, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(story.subtitle)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            HStack(alignment: .center, spacing: 14) {
                Text("\(story.daysRemaining)")
                    .font(.pillie(36, weight: .black))
                    .foregroundStyle(PillieTheme.dark)
                    .frame(width: 72, height: 72)
                    .background(PillieTheme.coral, in: RoundedRectangle(cornerRadius: 28))
                    .rotationEffect(.degrees(-6))

                Text(story.daysStampText)
                    .font(.pillieHandwriting(size: 26))
                    .foregroundStyle(PillieTheme.patchChangeRose)
                    .rotationEffect(.degrees(-6))
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(story.benefitChips, id: \.label) { chip in
                    Text(chip.label)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(chipColor(chip.tint), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func trialEndedHeader(_ story: HonestPaywallTrialEndedStory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.pillie(28, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(story.subtitle)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            HStack(spacing: 10) {
                statTile(story.doseTile)
                statTile(story.streakTile)
            }

            if !story.handwrittenLossLine.isEmpty {
                Text(story.handwrittenLossLine)
                    .font(.pillieHandwriting(size: 26))
                    .foregroundStyle(PillieTheme.patchChangeRose)
                    .rotationEffect(.degrees(-3))
            }
        }
    }

    @ViewBuilder
    private func settingsFreeHeader(_ story: HonestPaywallSettingsStory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.pillie(28, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(story.subtitle)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            HStack(alignment: .top, spacing: 10) {
                comparisonCard(story.freeCard)
                comparisonCard(story.plusCard)
            }
        }
    }

    private func statTile(_ tile: PaywallStatTile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tile.label)
                .font(.pillie(12, weight: .semibold))
                .foregroundStyle(tile.background == .ink ? Color.white.opacity(0.7) : PillieTheme.textMuted)
            Text(tile.value)
                .font(.pillie(32, weight: .black))
                .foregroundStyle(tile.background == .ink ? PillieTheme.coral : PillieTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tileBackground(tile.background), in: RoundedRectangle(cornerRadius: 28))
    }

    private func comparisonCard(_ card: PaywallComparisonCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.tierLabel)
                .font(.pillie(11, weight: .black))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.textMuted)

            ForEach(card.bullets, id: \.self) { bullet in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PillieTheme.verifiedGreen)
                    Text(bullet)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tileBackground(card.background), in: RoundedRectangle(cornerRadius: 28))
    }

    private func chipColor(_ tint: PaywallChipTint) -> Color {
        switch tint {
        case .lavender: PillieTheme.lavender
        case .sage: PillieTheme.sage
        case .coralSoft: PillieTheme.coralLight
        }
    }

    private func tileBackground(_ background: PaywallTileBackground) -> Color {
        switch background {
        case .lavender: PillieTheme.lavender
        case .coralSoft: PillieTheme.coralLight
        case .ink: PillieTheme.dark
        }
    }
}
