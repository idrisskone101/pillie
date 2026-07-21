//
//  TrialStatusSheet.swift
//  Pillie
//
//  Issue #166 (Reverse Trial 7/10 / ADR 0007): the trial's only in-trial
//  surfaces — the small persistent protection/trial indicator on
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
    static let presentationHeight: CGFloat = 680

    let content: TrialStatusSheetContent
    let onKeepPlus: () -> Void
    let onFeatureTap: (TrialActivationItem) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
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

            TrialActivationList(items: content.activationItems, onTap: onFeatureTap)
            TrialExpirySummary(items: content.expiryItems)

            Spacer(minLength: 0)

            TrialStatusFooter(
                ctaTitle: content.ctaTitle,
                onKeepPlus: onKeepPlus,
                onDismiss: onDismiss
            )
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PillieTheme.bg)
    }

}

private struct TrialActivationList: View {
    let items: [TrialActivationItem]
    let onTap: (TrialActivationItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRY YOUR PLUS FEATURES")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .kerning(1)

            ForEach(items, id: \.feature.rawValue) { item in
                TrialActivationFeatureRow(item: item) {
                    onTap(item)
                }
            }
        }
        .padding(.horizontal, 28)
    }
}

private struct TrialActivationFeatureRow: View {
    let item: TrialActivationItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(item.title)
                            .font(.pillie(14, weight: .semibold))
                            .foregroundStyle(PillieTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                            .layoutPriority(1)

                        if item.isRecommended {
                            Text("RECOMMENDED")
                                .font(.pillie(9, weight: .bold))
                                .foregroundStyle(PillieTheme.coral)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)
                        }
                    }

                    Text(item.statusTitle)
                        .font(.pillie(12, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                if let actionTitle = item.actionTitle {
                    HStack(spacing: 5) {
                        Text(actionTitle)
                            .font(.pillie(12, weight: .bold))
                            .foregroundStyle(PillieTheme.coral)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PillieTheme.coral.opacity(0.7))
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PillieTheme.verifiedGreen)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                item.isRecommended ? PillieTheme.coralLight : PillieTheme.sage.opacity(0.25),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        item.isRecommended ? PillieTheme.coral.opacity(0.55) : PillieTheme.sageHalf,
                        lineWidth: item.isRecommended ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(item.action == nil ? "" : "Opens this feature's settings")
    }

    private var accessibilityLabel: String {
        let recommendation = item.isRecommended ? ", recommended next action" : ""
        let action = item.actionTitle.map { ", action: \($0)" } ?? ""
        return "\(item.title), \(item.statusTitle)\(recommendation)\(action)"
    }
}

private struct TrialExpirySummary: View {
    let items: [String]
    private let symbols = ["nosign", "bell.fill", "checkmark.circle.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("WHEN THE TRIAL ENDS")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .kerning(1)

            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: 9) {
                    Image(systemName: symbols[min(index, symbols.count - 1)])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(width: 18)
                    Text(items[index])
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }
}

private struct TrialStatusFooter: View {
    let ctaTitle: String
    let onKeepPlus: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onKeepPlus) {
                Text(ctaTitle)
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
}

#Preview {
    TrialStatusSheet(
        content: TrialStatusPresentation(daysRemaining: 5).sheetContent,
        onKeepPlus: {},
        onFeatureTap: { _ in },
        onDismiss: {}
    )
}
