//
//  BlockingStatusCard.swift
//  Pillie
//
//  The "enable app blocking later" surface on Home for Reminder-Only Onboarding
//  Completion. It labels app blocking incomplete and routes the user to finish
//  Screen Time setup (entitled) or unlock with Plus (free). It is hidden once
//  Protection Plan Activation is reached. Copy + routing live in
//  BlockingStatusPresentation / BlockingStatusCardContent (value-type tested).
//

import SwiftUI

struct BlockingStatusCard: View {
    let content: BlockingStatusCardContent
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(content.detail)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                dismissButton
            }

            primaryButton
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
        .accessibilityIdentifier("homeBlockingStatusCard")
    }

    private var iconBadge: some View {
        Image(systemName: content.isLocked ? "lock.shield.fill" : "shield.lefthalf.filled")
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
        .accessibilityLabel(PillieLocalization.string("global.action.close", locale: locale))
        .accessibilityIdentifier("homeBlockingStatusCardDismiss")
    }

    private var primaryButton: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: 8) {
                if content.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(content.ctaTitle)
                    .font(.pillieBodySemibold())
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(PillieTheme.textPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeBlockingStatusCardCTA")
    }
}

#Preview {
    VStack(spacing: 16) {
        BlockingStatusCard(
            content: BlockingStatusCardContent.make(for: .incompleteEntitled)!,
            onPrimaryAction: {},
            onDismiss: {}
        )
        BlockingStatusCard(
            content: BlockingStatusCardContent.make(for: .incompleteFree)!,
            onPrimaryAction: {},
            onDismiss: {}
        )
    }
    .padding(20)
    .background(PillieTheme.bg)
}
