//
//  PaywallCheckoutChrome.swift
//  Pillie
//

import SwiftUI

enum PaywallCheckoutSection {
    case stack
    case footer
}

enum HonestPaywallLayout {
    static let horizontalInset: CGFloat = 24
    static let ctaHeight: CGFloat = 56
    static let stackTileRadius: CGFloat = 24
    static let stackTilePadding: CGFloat = 16
}

struct PaywallCheckoutChrome: View {
    let checkout: PaywallCheckoutSheet
    let isPurchasing: Bool
    var section: PaywallCheckoutSection = .stack
    let onRecurrenceChange: (PaywallRecurrence) -> Void
    let onPurchase: (PaywallPurchaseIntent) -> Void
    let onRestore: () -> Void
    let onLifetime: () -> Void

    var body: some View {
        switch section {
        case .stack:
            stackBlock
        case .footer:
            footerBlock
        }
    }

    private var stackBlock: some View {
        VStack(spacing: 10) {
            stackTile(checkout.yearTile, recurrence: .year)
            stackTile(checkout.monthTile, recurrence: .month)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    private var footerBlock: some View {
        VStack(spacing: 10) {
            purchaseButton

            if let lifetimeLink = checkout.lifetimeLink {
                Button(action: onLifetime) {
                    Text(lifetimeLink.text)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lifetimeLink.accessibilityLabel)
            }

            footerRow
        }
        .padding(.top, 20)
        .padding(.bottom, 28)
        .padding(.horizontal, HonestPaywallLayout.horizontalInset)
    }

    private func stackTile(_ tile: PaywallStackTile, recurrence: PaywallRecurrence) -> some View {
        Button {
            onRecurrenceChange(recurrence)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                radioCircle(selected: tile.isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.title)
                        .font(.pillie(16, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)

                    Text(tile.primaryLine)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let badge = tile.savingsBadge {
                    Text(badge.label)
                        .font(.pillie(11, weight: .extraBold))
                        .tracking(0.44)
                        .textCase(.uppercase)
                        .foregroundStyle(PillieTheme.dark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PillieTheme.coral, in: Capsule())
                } else if let trailing = tile.trailingPrice {
                    Text(trailing)
                        .font(.pillie(16, weight: .extraBold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
            .padding(HonestPaywallLayout.stackTilePadding)
            .background(PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: HonestPaywallLayout.stackTileRadius))
            .overlay {
                RoundedRectangle(cornerRadius: HonestPaywallLayout.stackTileRadius)
                    .strokeBorder(
                        tile.isSelected ? PillieTheme.dark : PillieTheme.sage,
                        lineWidth: tile.isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.accessibilityLabel)
        .accessibilityAddTraits(tile.isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func radioCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? PillieTheme.dark : Color(hex: "C4C0BA"), lineWidth: selected ? 0 : 2)
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
                        .font(.pillie(16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: HonestPaywallLayout.ctaHeight)
            .background(checkout.isPurchaseEnabled ? PillieTheme.dark : PillieTheme.textMuted)
            .clipShape(Capsule())
        }
        .disabled(!checkout.isPurchaseEnabled || isPurchasing)
    }

    private var footerRow: some View {
        Button(action: onRestore) {
            Text(checkout.footer.reassurance)
                .font(.pillie(12, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
