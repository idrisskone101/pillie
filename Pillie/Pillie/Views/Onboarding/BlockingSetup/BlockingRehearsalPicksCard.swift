//
//  BlockingRehearsalPicksCard.swift
//  Pillie
//
//  Her picks are saved, and when they pause and open again.
//

import SwiftUI

struct BlockingRehearsalPicksCard: View {
    let content: BlockingRehearsalContent
    let onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            card
            privacyLine
        }
        .onAppear {
            checked = true
            InteractionFeedback.live.perform(.success)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 22) {
            picksRow

            VStack(alignment: .leading, spacing: 14) {
                rhythmRow(
                    dot: PillieTheme.patchChangeRose,
                    title: content.pauseRowTitle,
                    detail: content.pauseRowBody
                )
                rhythmRow(
                    dot: PillieTheme.verifiedGreen,
                    title: content.resumeRowTitle,
                    detail: content.resumeRowBody
                )
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PillieTheme.textPrimary.opacity(0.1))
                    .frame(height: 1)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BlockingSetupCardSurface())
    }

    /// Says her picks are saved without drawing them. iOS draws a token's name
    /// in its own type, which this card cannot style, so it shows none.
    private var picksRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PillieTheme.verifiedGreen)
                .scaleEffect(checked || reduceMotion ? 1 : 0.5)
                .opacity(checked ? 1 : 0)
                .animation(
                    reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.6),
                    value: checked
                )
                .accessibilityHidden(true)
            Text(content.picksHeader)
                .font(.pillie(17, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("blockingRehearsalPicksCard")
            Spacer(minLength: 12)
            Button(action: onChange) {
                Text(content.changePicks)
                    .font(.pillie(15, weight: .semibold))
                    .underline()
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -12)
            .accessibilityIdentifier("blockingRehearsalChangePicks")
        }
    }

    private func rhythmRow(dot: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.pillie(16, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(detail)
                    .font(.pillie(15, weight: .regular))
                    .foregroundStyle(BlockingRehearsalPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var privacyLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
            Text(content.privacyLine)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}
