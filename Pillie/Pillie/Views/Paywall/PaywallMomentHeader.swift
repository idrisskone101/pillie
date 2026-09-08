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
                    .font(.pillie(16, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(PillieTheme.coral.opacity(0.35))
                    .frame(height: 96)
                VStack(spacing: 2) {
                    Text("\(story.daysRemaining)")
                        .font(.pillie(72, weight: .black))
                        .foregroundStyle(PillieTheme.coral)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(story.daysStampText)
                        .font(.pillieHandwriting(size: 22))
                        .foregroundStyle(PillieTheme.patchChangeRose)
                }
                .rotationEffect(.degrees(-6))
            }
            .accessibilityElement(children: .combine)

            FlowLayout(spacing: 8) {
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
                    .font(.pillie(16, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            HStack(spacing: 12) {
                statTile(story.doseTile)
                statTile(story.streakTile)
            }

            Text(story.handwrittenLossLine)
                .font(.pillieHandwriting(size: 26))
                .foregroundStyle(PillieTheme.patchChangeRose)
                .rotationEffect(.degrees(-3))
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
                    .font(.pillie(16, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            HStack(alignment: .top, spacing: 12) {
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
        .background(tileBackground(tile.background), in: RoundedRectangle(cornerRadius: 20))
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
        .background(tileBackground(card.background), in: RoundedRectangle(cornerRadius: 20))
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

/// Simple horizontal wrapping for benefit chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
