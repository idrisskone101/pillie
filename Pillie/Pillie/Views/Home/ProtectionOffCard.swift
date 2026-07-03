//
//  ProtectionOffCard.swift
//  Pillie
//
//  The Protection Off State surface on Home (issue #167 / ADR 0007 /
//  CONTEXT.md): after Plus Access ends for a user with saved blocker
//  configuration, blocking has stopped and this card says so — the user must
//  never believe blocking is active when it is not. Persistent (no dismissal):
//  it is the way back to the upgrade path until access returns. Copy + gating
//  live in ProtectionOffCardContent (value-type tested).
//

import SwiftUI

struct ProtectionOffCard: View {
    let content: ProtectionOffCardContent
    let onPrimaryAction: () -> Void

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
        .accessibilityIdentifier("homeProtectionOffCard")
    }

    private var iconBadge: some View {
        Image(systemName: "shield.slash.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(PillieTheme.coral)
            .frame(width: 42, height: 42)
            .background(PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: 8) {
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
        .accessibilityIdentifier("homeProtectionOffCardCTA")
    }
}

#Preview {
    ProtectionOffCard(
        content: ProtectionOffCardContent.make(
            hasPlusAccess: false,
            blockerConfigSaved: true
        )!,
        onPrimaryAction: {}
    )
    .padding(20)
    .background(PillieTheme.bg)
}
