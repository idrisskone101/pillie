//
//  ProtectionPlanRoutineCard.swift
//  Pillie
//
//  The live "Your plan so far" card threaded across Routine Method → Routine Details
//  → Reminder Time (#77). It fills in as the user commits each answer, turning three
//  setup screens into one plan being assembled rather than a run of disconnected
//  forms. Purely presentational — it renders a `ProtectionPlanRoutineSummary` value,
//  which carries the tested, method-aware copy.
//

import SwiftUI

struct ProtectionPlanRoutineCard: View {
    let summary: ProtectionPlanRoutineSummary
    var animationsEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PillieTheme.coral)
                Text(summary.cardLabel.uppercased(with: summary.locale))
                    .font(.pillie(11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(PillieTheme.textMuted)
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.85)
            }

            Text(summary.headline)
                .font(.pillie(19, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(animationsEnabled ? .easeInOut(duration: 0.25) : nil, value: summary.headline)

            if !summary.rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(summary.rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Rectangle()
                                .fill(PillieTheme.coral.opacity(0.12))
                                .frame(height: 1)
                        }
                        rowView(row)
                    }
                }
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PillieTheme.coralLight.opacity(0.55),
            in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.coral.opacity(0.22), lineWidth: 1)
        }
        .animation(animationsEnabled ? .easeInOut(duration: 0.3) : nil, value: summary.rows)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private func rowView(_ row: ProtectionPlanRoutineSummary.Row) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 24)
            Text(row.label)
                .font(.pillie(14, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
            Spacer(minLength: 10)
            Text(row.value)
                .font(.pillie(14, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var accessibilityText: String {
        (summary.accessibilityHeadings
            + summary.rows.map { "\($0.label): \($0.value)" }).joined(separator: ". ")
    }
}

extension View {
    /// The shared fade-in-up reveal used by the routine plan-builder screens (#77),
    /// expressed as a modifier so the long Routine Details / Reminder Time bodies stay
    /// readable. Honors Reduce Motion / constrained-performance via `animationsEnabled`.
    func planBuilderReveal(_ appeared: Bool, _ animationsEnabled: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: animationsEnabled ? (appeared ? 0 : 14) : 0)
            .animation(
                animationsEnabled ? PillieTheme.fadeInUpCurve.delay(delay) : .easeOut(duration: 0.25),
                value: appeared
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        ProtectionPlanRoutineCard(summary: ProtectionPlanRoutineSummary(method: .pill))
        ProtectionPlanRoutineCard(
            summary: ProtectionPlanRoutineSummary(
                method: .pill,
                scheduleSummary: "Standard · 21 active, 7 break",
                cycleDay: 14,
                reminderTimeText: "9:30 AM"
            )
        )
    }
    .padding()
    .background(PillieTheme.bg)
}
