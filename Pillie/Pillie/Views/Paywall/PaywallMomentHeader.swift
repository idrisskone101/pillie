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
        VStack(alignment: .leading, spacing: 0) {
            titleBlock(title: story.title, subtitle: story.subtitle)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 10) {
                    Text("\(story.daysRemaining)")
                        .font(.pillie(40, weight: .black))
                        .tracking(-0.8)
                        .foregroundStyle(PillieTheme.dark)
                        .frame(width: 72, height: 72)
                        .background(PillieTheme.coral, in: RoundedRectangle(cornerRadius: 28))
                        .rotationEffect(.degrees(-6))

                    Text(story.daysStampText)
                        .font(.pillieHandwriting(size: 28))
                        .foregroundStyle(PillieTheme.dark)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                benefitChipStack(story.benefitChips)
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func trialEndedHeader(_ story: HonestPaywallTrialEndedStory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock(title: story.title, subtitle: story.subtitle)

            switch story.body {
            case .stats(let doseTile, let streakTile, let lossLine):
                if doseTile != nil || streakTile != nil {
                    HStack(alignment: .top, spacing: 10) {
                        if let doseTile {
                            statTile(doseTile)
                        }
                        if let streakTile {
                            statTile(streakTile)
                        }
                    }
                    .padding(.top, 16)
                }
                handwrittenAside(lossLine)
            case .comparison(let freeCard, let plusCard):
                comparisonRow(free: freeCard, plus: plusCard)
            case .chips(let chips, let aside):
                benefitChipStack(chips)
                    .padding(.top, 16)
                handwrittenAside(aside)
            }
        }
    }

    @ViewBuilder
    private func settingsFreeHeader(_ story: HonestPaywallSettingsStory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock(title: story.title, subtitle: story.subtitle)
            comparisonRow(free: story.freeCard, plus: story.plusCard)
        }
    }

    private func benefitChipStack(_ chips: [PaywallBenefitChip]) -> some View {
        VStack(spacing: 8) {
            ForEach(chips, id: \.label) { chip in
                Text(chip.label)
                    .font(.pillie(15, weight: .bold))
                    .foregroundStyle(PillieTheme.dark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(chipColor(chip.tint), in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func comparisonRow(free: PaywallComparisonCard, plus: PaywallComparisonCard) -> some View {
        HStack(alignment: .top, spacing: 10) {
            comparisonCard(free)
            comparisonCard(plus)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func handwrittenAside(_ line: String) -> some View {
        if !line.isEmpty {
            Text(line)
                .font(.pillieHandwriting(size: 26))
                .foregroundStyle(PillieTheme.dark)
                .rotationEffect(.degrees(-3))
                .padding(.top, 8)
        }
    }

    private func titleBlock(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.pillie(28, weight: .black))
                .tracking(-0.56)
                .lineSpacing(0)
                .foregroundStyle(PillieTheme.dark)
            Text(subtitle)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
    }

    private func statTile(_ tile: PaywallStatTile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tile.value)
                .font(.pillie(40, weight: .black))
                .tracking(-0.8)
                .foregroundStyle(tile.background == .ink ? PillieTheme.coral : PillieTheme.dark)
            Text(tile.label)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(tile.background == .ink ? PillieTheme.bg : PillieTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 92, alignment: .topLeading)
        .background(tileBackground(tile.background), in: RoundedRectangle(cornerRadius: 28))
    }

    private func comparisonCard(_ card: PaywallComparisonCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.tierLabel)
                .font(.pillie(12, weight: .bold))
                .tracking(0.96)
                .textCase(.uppercase)
                .foregroundStyle(card.background == .coralSoft ? PillieTheme.dark : PillieTheme.textMuted)

            ForEach(card.bullets, id: \.self) { bullet in
                Text(bullet)
                    .font(.pillie(15, weight: .bold))
                    .foregroundStyle(PillieTheme.dark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .frame(minHeight: 138, alignment: .topLeading)
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
