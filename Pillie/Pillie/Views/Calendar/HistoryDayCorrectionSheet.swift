//
//  HistoryDayCorrectionSheet.swift
//  Pillie
//

import SwiftUI

/// Bottom sheet that rewrites one past day's status.
///
/// Height is a fixed detent derived from the option count — not measured from
/// the sheet's own geometry. Measuring into `presentationDetents` creates a
/// feedback loop (content fills the detent → reports a larger height → detent
/// grows) that eventually expands the sheet to full screen.
struct HistoryDayCorrectionSheet: View {
    let day: HistoryEditableDay
    let onSelect: (DayCorrectionOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store
    /// A second tap while the sheet is animating out must not commit twice.
    @State private var hasSelected = false

    /// Grabber + title block + rows + bottom pad. Sized for default Dynamic
    /// Type; larger text scrolls inside the detent instead of growing it.
    private var presentationHeight: CGFloat {
        let rows = CGFloat(day.options.selectableOutcomes.count)
        return 108 + rows * 78 + 48
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Capsule()
                    .fill(PillieTheme.hairline)
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 4) {
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
                    .fixedSize(horizontal: false, vertical: true)

                    // The reminder time is the current one: past reminder times
                    // are not stored.
                    Text(HistoryPresentation.doseSubtitle(
                        reminderHour: store.reminderHour,
                        reminderMinute: store.reminderMinute,
                        method: day.method,
                        locale: locale
                    ))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    ForEach(day.options.selectableOutcomes, id: \.self) { outcome in
                        correctionRow(outcome)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .presentationDetents([.height(presentationHeight)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(PillieTheme.cardWhite)
        .presentationCornerRadius(PillieTheme.cardRadius)
    }

    @ViewBuilder
    private func correctionRow(_ outcome: DayCorrectionOutcome) -> some View {
        let isSelected = day.options.currentOutcome == outcome
        Button {
            guard !hasSelected else { return }
            hasSelected = true
            onSelect(outcome)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                outcomeIcon(outcome)
                    .frame(width: 44, height: 44)
                    .background(outcomeTileColor(outcome))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(outcomeText(outcome, "title"))
                        .font(.pillie(16, weight: .semibold))
                        .foregroundStyle(PillieTheme.dark)
                    Text(outcomeText(outcome, "subtitle"))
                        .font(.pillie(13, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                selectionIndicator(isSelected: isSelected)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? PillieTheme.coralLight.opacity(0.8) : PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isSelected ? PillieTheme.coral : PillieTheme.hairline,
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("historyDayCorrection.\(outcome.rawValue)")
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
                .font(.pillie(16, weight: .bold))
                .foregroundStyle(.white)
        case .breakDay:
            Image(systemName: "minus")
                .font(.pillie(18, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    private func outcomeTileColor(_ outcome: DayCorrectionOutcome) -> Color {
        switch outcome {
        case .taken: PillieTheme.sage
        case .unlogged: PillieTheme.amber
        case .breakDay: PillieTheme.lavender
        }
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(PillieTheme.hairlineStrong, lineWidth: 1.5)
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

    private func outcomeText(_ outcome: DayCorrectionOutcome, _ field: String) -> String {
        PillieLocalization.string(
            "history.dayCorrection.\(outcome.localizationKey).\(field)",
            locale: locale
        )
    }
}
