//
//  TrialStatusSheet.swift
//  Pillie
//
//  Issue #166 (Reverse Trial 7/10 / ADR 0007): the trial's only in-trial
//  surfaces — the small persistent "Plus trial — N days left" indicator on
//  Home and the status sheet behind it. Informational, never an upsell card:
//  the sheet's quiet "Keep Plus" button and the Settings upgrade row are the
//  only purchase paths during the trial. All copy and visibility rules live in
//  `TrialStatusPresentation` (value type, boundary-tested).
//

import SwiftUI

/// The small persistent in-trial indicator. A capsule chip, informational by
/// design — it must never grow into an upsell card.
struct TrialIndicatorBadge: View {
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                Text(label)
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(PillieTheme.coralLight, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trialIndicator")
    }
}

/// The trial status sheet: remaining time, what's currently unlocked, what
/// happens at expiry, and the quiet buy-early path into the existing purchase
/// flow. Presentation-only — copy comes from `TrialStatusSheetContent`.
struct TrialStatusSheet: View {
    static let presentationHeight: CGFloat = 560

    let content: TrialStatusSheetContent
    let onKeepPlus: () -> Void
    let onDismiss: () -> Void

    /// The same perk symbols the Trial Granted Moment and update announcement
    /// use, paired positionally with the content's unlocked items.
    private static let perkSymbols = [
        "nosign", "iphone.radiowaves.left.and.right", "bell.fill", "text.bubble.fill",
    ]

    private let expirySymbols = ["nosign", "bell.fill", "checkmark.circle.fill"]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text(content.title)
                .font(.pillieExtraBold(24))
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Unlocked right now")

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(content.unlockedItems.enumerated()), id: \.element) { index, item in
                        HStack(spacing: 10) {
                            Image(systemName: Self.perkSymbols[
                                min(index, Self.perkSymbols.count - 1)
                            ])
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PillieTheme.coral)
                            Text(item)
                                .font(.pillie(13, weight: .semibold))
                                .foregroundStyle(PillieTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .background(PillieTheme.sage.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("When the trial ends")

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(content.expiryItems.enumerated()), id: \.element) { index, item in
                        HStack(spacing: 10) {
                            Image(systemName: expirySymbols[
                                min(index, expirySymbols.count - 1)
                            ])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PillieTheme.textMuted)
                            .frame(width: 18)
                            Text(item)
                                .font(.pillie(14, weight: .medium))
                                .foregroundStyle(PillieTheme.textPrimary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button(action: onKeepPlus) {
                    Text(content.ctaTitle)
                }
                .buttonStyle(.pillieDark)
                .accessibilityIdentifier("trialKeepPlus")

                Button(action: onDismiss) {
                    Text("Done")
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PillieTheme.bg)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.pillieCaptionMedium())
            .foregroundStyle(PillieTheme.textMuted)
            .kerning(1)
    }
}

#Preview {
    TrialStatusSheet(
        content: TrialStatusPresentation(daysRemaining: 5).sheetContent,
        onKeepPlus: {},
        onDismiss: {}
    )
}
