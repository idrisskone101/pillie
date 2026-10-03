//
//  TrialStatusSheet.swift
//  Pillie
//
//  Issue #166 / ENG-135 (Reverse Trial / ADR 0007): the small persistent
//  trial indicator on Home and the status sheet behind it. Status and
//  commerce only: how long is left, what happens next, and the quiet
//  "Keep Plus" path. Setup lives in the Today strip. All copy comes from
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
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(PillieTheme.coralLight, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trialIndicator")
    }
}

/// The trial status sheet. Sizes itself to its content.
struct TrialStatusSheet: View {
    let content: TrialStatusSheetContent
    let onKeepPlus: () -> Void
    let onDismiss: () -> Void

    @State private var contentHeight: CGFloat = 600

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            TrialStatusHeader(
                eyebrow: content.eyebrow,
                headline: content.headline,
                until: content.until
            )
            TrialProgressBar(progress: content.progress)
            TrialTimeline(title: content.timelineTitle, rows: content.timeline)
            TrialStatusFooter(
                ctaTitle: content.ctaTitle,
                onKeepPlus: onKeepPlus,
                onDismiss: onDismiss
            )
        }
        .padding(.top, 12)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PillieTheme.bg)
        .presentationDetents([.height(contentHeight)])
    }
}

private struct TrialStatusHeader: View {
    let eyebrow: String
    let headline: String
    let until: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .accessibilityHidden(true)
                Text(eyebrow)
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            Text(headline)
                .font(.pillieExtraBold(40))
                .tracking(-0.8)
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let until {
                Text(until)
                    .font(.pillie(16))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TrialProgressBar: View {
    let progress: TrialProgress

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(1...progress.totalDays, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day <= progress.filledDays ? PillieTheme.coral : PillieTheme.coralLight)
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
            HStack {
                Text(progress.todayLabel)
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.textPrimary)
                Spacer(minLength: 8)
                if let endLabel = progress.endLabel {
                    Text(endLabel)
                        .font(.pillie(12, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TrialTimeline: View {
    let title: String
    let rows: [TrialTimelineRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(rows, id: \.date) { row in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PillieTheme.textMuted)
                            .frame(width: 32, height: 32)
                            .background(TrialStatusPalette.iconWell, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.dateText)
                                .font(.pillie(15, weight: .semibold))
                                .foregroundStyle(PillieTheme.textPrimary)
                            Text(row.text)
                                .font(.pillie(14))
                                .foregroundStyle(PillieTheme.textMuted)
                                .lineSpacing(1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 5)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct TrialStatusFooter: View {
    let ctaTitle: String
    let onKeepPlus: () -> Void
    let onDismiss: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onKeepPlus) {
                Text(ctaTitle)
            }
            .buttonStyle(.pillieDark)
            .accessibilityIdentifier("trialKeepPlus")

            Button(action: onDismiss) {
                Text(PillieLocalization.string("global.action.done", locale: locale))
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: PillieTheme.quietButtonHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}

private enum TrialStatusPalette {
    static let iconWell = Color(hex: "F5F5F4")
}

#Preview {
    TrialStatusSheet(
        content: TrialStatusPresentation(
            daysRemaining: 14,
            trialEndDate: Date().addingTimeInterval(14 * 86_400)
        ).sheetContent,
        onKeepPlus: {},
        onDismiss: {}
    )
}
