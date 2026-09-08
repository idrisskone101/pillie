//
//  PaywallCheckoutChrome.swift
//  Pillie
//

import SwiftUI

private enum HonestPaywallLayout {
    static let ctaHeight: CGFloat = 56
    static let stackTileRadius: CGFloat = 24
    static let stackTilePadding: CGFloat = 16
}

struct PaywallCheckoutChrome: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    let checkout: PaywallCheckoutSheet
    let isPurchasing: Bool
    let onRecurrenceChange: (PaywallRecurrence) -> Void
    let onPurchase: (PaywallPurchaseIntent) -> Void
    let onRestore: () -> Void
    let onLifetime: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                stackTile(checkout.yearTile, recurrence: .year)
                stackTile(checkout.monthTile, recurrence: .month)
            }

            purchaseButton

            if let lifetimeLink = checkout.lifetimeLink {
                Button(action: onLifetime) {
                    Text(lifetimeLink.text)
                        .font(.pillie(14, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lifetimeLink.accessibilityLabel)
            }

            footerRow
        }
    }

    private func stackTile(_ tile: PaywallStackTile, recurrence: PaywallRecurrence) -> some View {
        Button {
            onRecurrenceChange(recurrence)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                radioCircle(selected: tile.isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tile.title)
                        .font(.pillie(15, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)

                    Text(tile.primaryLine)
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let trailing = tile.trailingPrice {
                    Text(trailing)
                        .font(.pillie(16, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
            .padding(HonestPaywallLayout.stackTilePadding)
            .background(PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: HonestPaywallLayout.stackTileRadius))
            .overlay {
                RoundedRectangle(cornerRadius: HonestPaywallLayout.stackTileRadius)
                    .stroke(
                        tile.isSelected ? PillieTheme.dark : PillieTheme.sage,
                        lineWidth: tile.isSelected ? 2 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if let badge = tile.savingsBadge {
                    Text(badge.label)
                        .font(.pillie(10, weight: .black))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(PillieTheme.dark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(PillieTheme.coral, in: Capsule())
                        .offset(x: -12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.accessibilityLabel)
        .accessibilityAddTraits(tile.isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func radioCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? PillieTheme.dark : PillieTheme.sage, lineWidth: selected ? 0 : 1.5)
                .frame(width: 22, height: 22)

            if selected {
                Circle()
                    .fill(PillieTheme.dark)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var purchaseButton: some View {
        Button {
            onPurchase(.subscribe(checkout.selectedRecurrence))
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(checkout.primaryCTA)
                        .font(.pillie(17, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: HonestPaywallLayout.ctaHeight)
            .background(checkout.isPurchaseEnabled ? PillieTheme.dark : PillieTheme.textMuted)
            .clipShape(Capsule())
            .shadow(color: PillieTheme.dark.opacity(0.35), radius: 10, y: 5)
        }
        .disabled(!checkout.isPurchaseEnabled || isPurchasing)
    }

    private var footerRow: some View {
        Button(action: onRestore) {
            Text(checkout.footer.reassurance)
                .font(.pillie(12, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
