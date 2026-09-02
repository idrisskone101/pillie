//
//  HistoryDayCorrectionSheet.swift
//  Pillie
//

import SwiftUI

struct HistoryEditableDay: Identifiable {
    var id: Date { date }
    let date: Date
    let snapshot: PillScheduleSnapshot
    let options: DayCorrectionOptions
}

struct HistoryDayCorrectionSheet: View {
    let day: HistoryEditableDay
    let onSelect: (DayCorrectionOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store

    private static let handleTopPadding: CGFloat = 12
    private static let handleHeight: CGFloat = 4
    private static let headerGap: CGFloat = 16
    private static let titleSubtitleGap: CGFloat = 4
    private static let rowSpacing: CGFloat = 8
    private static let rowVerticalPadding: CGFloat = 12
    private static let rowHeight: CGFloat = 68
    private static let bottomPadding: CGFloat = 36
    private static let horizontalPadding: CGFloat = 20

    static func height(rowCount: Int) -> CGFloat {
        let headerBlock: CGFloat = handleTopPadding + handleHeight + headerGap + 34 + titleSubtitleGap + 20 + headerGap
        let rowsBlock = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * rowSpacing
        return headerBlock + rowsBlock + bottomPadding
    }

    var body: some View {
        VStack(spacing: Self.headerGap) {
            Capsule()
                .fill(Color(hex: "E7E5E4"))
                .frame(width: 40, height: Self.handleHeight)
                .padding(.top, Self.handleTopPadding)

            VStack(spacing: Self.titleSubtitleGap) {
                Text(day.date.formatted(
                    Date.FormatStyle()
                        .weekday(.wide)
                        .day()
                        .locale(locale)
                ))
                .font(.pillieExtraBold(28))
                .tracking(-0.56)
                .foregroundStyle(PillieTheme.dark)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(HistoryPresentation.doseSubtitle(
                    snapshot: day.snapshot,
                    reminderHour: store.reminderHour,
                    reminderMinute: store.reminderMinute,
                    method: store.pack.method,
                    locale: locale
                ))
                .font(.pillieBodySemibold())
                .foregroundStyle(PillieTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: Self.rowSpacing) {
                ForEach(day.options.selectableOutcomes, id: \.self) { outcome in
                    correctionRow(outcome)
                }
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.bottom, Self.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PillieTheme.cardWhite)
    }

    @ViewBuilder
    private func correctionRow(_ outcome: DayCorrectionOutcome) -> some View {
        let isSelected = day.options.currentOutcome == outcome
        Button {
            onSelect(outcome)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                outcomeIcon(outcome)
                    .frame(width: 44, height: 44)
                    .background(outcomeTileColor(outcome))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(outcomeTitle(outcome))
                        .font(.pillie(16, weight: .semibold))
                        .foregroundStyle(PillieTheme.dark)
                    Text(outcomeSubtitle(outcome))
                        .font(.pillie(13, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                }

                Spacer(minLength: 0)

                selectionIndicator(isSelected: isSelected)
            }
            .padding(.vertical, Self.rowVerticalPadding)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? PillieTheme.coralLight.opacity(0.8) : PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isSelected ? PillieTheme.coral : Color(hex: "E7E5E4"),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func outcomeIcon(_ outcome: DayCorrectionOutcome) -> some View {
        switch outcome {
        case .taken:
            Image(systemName: "checkmark")
                .font(.pillie(18, weight: .semibold))
                .foregroundStyle(PillieTheme.verifiedGreen)
        case .unlogged:
            Image(systemName: "xmark")
                .font(.pillie(18, weight: .semibold))
                .foregroundStyle(PillieTheme.amber)
        case .breakDay:
            Image(systemName: "minus")
                .font(.pillie(18, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    private func outcomeTileColor(_ outcome: DayCorrectionOutcome) -> Color {
        switch outcome {
        case .taken: PillieTheme.sage
        case .unlogged: PillieTheme.amberFaded
        case .breakDay: PillieTheme.lavender
        }
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color(hex: "D6D3D1"), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.pillie(11, weight: .bold))
                    .foregroundStyle(PillieTheme.dark)
            }
        }
    }

    private func outcomeTitle(_ outcome: DayCorrectionOutcome) -> String {
        switch outcome {
        case .taken:
            PillieLocalization.string("history.dayCorrection.taken.title", locale: locale)
        case .unlogged:
            PillieLocalization.string("history.dayCorrection.unlogged.title", locale: locale)
        case .breakDay:
            PillieLocalization.string("history.dayCorrection.break.title", locale: locale)
        }
    }

    private func outcomeSubtitle(_ outcome: DayCorrectionOutcome) -> String {
        switch outcome {
        case .taken:
            PillieLocalization.string("history.dayCorrection.taken.subtitle", locale: locale)
        case .unlogged:
            PillieLocalization.string("history.dayCorrection.unlogged.subtitle", locale: locale)
        case .breakDay:
            PillieLocalization.string("history.dayCorrection.break.subtitle", locale: locale)
        }
    }
}
