//
//  ReviewPromptCard.swift
//  Pillie
//
//  The Home Review Prompt's Sentiment Gate card (PRD #132 / ADR 0005). It appears after
//  `StatsRow` only when `ReviewPromptEligibility.evaluate` returns `.show` — an unbroken
//  Streak past a method-aware threshold, never answered before, not in cooldown or
//  capped, and no higher-priority card competing. Step one asks sentiment ("Enjoying
//  Pillie?"); the positive choice routes to Apple's Native Review Request, the negative
//  choice opens the Feedback Escape Hatch, and the close control soft-dismisses for a long
//  cooldown. Copy + gating live in `ReviewPromptCardContent` (value-type tested).
//

import SwiftUI

struct ReviewPromptCard: View {
    let content: ReviewPromptCardContent
    let onPositive: () -> Void
    let onNegative: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.headline)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(content.body)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                dismissButton
            }

            HStack(spacing: 10) {
                negativeButton
                positiveButton
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeReviewPromptCard")
    }

    private var iconBadge: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(PillieTheme.coral)
            .frame(width: 42, height: 42)
            .background(PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PillieTheme.textMuted)
                .frame(width: 26, height: 26)
                .background(PillieTheme.bg, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
        .accessibilityIdentifier("homeReviewPromptCardDismiss")
    }

    private var positiveButton: some View {
        Button(action: onPositive) {
            HStack(spacing: 6) {
                Text(content.positiveTitle)
                    .font(.pillieBodySemibold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(PillieTheme.textPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeReviewPromptCardPositive")
    }

    private var negativeButton: some View {
        Button(action: onNegative) {
            Text(content.negativeTitle)
                .font(.pillieBodySemibold())
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    Capsule().stroke(PillieTheme.sageHalf, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeReviewPromptCardNegative")
    }
}

#Preview {
    ReviewPromptCard(
        content: ReviewPromptCardContent.make(decision: .show)!,
        onPositive: {},
        onNegative: {},
        onDismiss: {}
    )
    .padding(20)
    .background(PillieTheme.bg)
}
