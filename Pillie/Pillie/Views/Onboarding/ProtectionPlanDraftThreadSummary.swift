//
//  ProtectionPlanDraftThreadSummary.swift
//  Pillie
//
//  A calm, read-only "Your protection draft" card for the Draft Blocked Apps screen
//  (issue #76 design refinement). It mirrors the user's chip selections as light
//  receipt-style tokens that grow as they pick, turning the formerly empty lower
//  third of the screen into the reward moment of the plan coming together. It owns
//  no interaction — the chips above remain the only controls — and derives entirely
//  from existing committed state, so it adds nothing to telemetry or persistence.
//

import SwiftUI

struct ProtectionPlanDraftThreadSummary: View {
    let selected: Set<DraftBlockedAppChoice>
    /// The full choice list in display order, so the unordered Set renders
    /// deterministically (categories, then apps, then Other).
    let orderedChoices: [DraftBlockedAppChoice]
    let animationsEnabled: Bool

    private let content = ProtectionPlanDraftBlockedAppsContent.default

    private var items: [DraftBlockedAppChoice] {
        orderedChoices.filter(selected.contains)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if items.isEmpty {
                emptyState
            } else {
                tokens
                caption
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PillieTheme.coral.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: PillieTheme.cardShadow, radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(content.summaryTitle.uppercased())
                .font(.pillie(13, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(PillieTheme.textMuted)

            Spacer(minLength: 8)

            if !items.isEmpty {
                Text("\(items.count)")
                    .font(.pillie(13, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(animationsEnabled ? .numericText() : .identity)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(PillieTheme.coralLight))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(PillieTheme.coral.opacity(0.22))
                .frame(width: 36, height: 2)

            Text(content.summaryEmpty)
                .font(.pillie(14, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tokens: some View {
        ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items) { choice in
                HStack(spacing: 5) {
                    Image(systemName: choice.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(choice.title)
                        .font(.pillie(13, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(PillieTheme.coralLight))
                .overlay {
                    Capsule().stroke(PillieTheme.coral.opacity(0.35), lineWidth: 1)
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .animation(animationsEnabled ? PillieTheme.fadeInUpCurve : nil, value: items)
    }

    private var caption: some View {
        Text(captionText)
            .font(.pillie(12, weight: .regular))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var captionText: String {
        items.count == 1
            ? "Pillie will guard pill time from this 1 distraction."
            : "Pillie will guard pill time from these \(items.count) distractions."
    }

    private var accessibilityLabel: String {
        guard !items.isEmpty else {
            return "\(content.summaryTitle). \(content.summaryEmpty)"
        }
        let names = items.map(\.title).joined(separator: ", ")
        let noun = items.count == 1 ? "distraction" : "distractions"
        return "\(content.summaryTitle), \(items.count) \(noun): \(names)"
    }
}

#Preview {
    VStack(spacing: 20) {
        ProtectionPlanDraftThreadSummary(
            selected: [],
            orderedChoices: DraftBlockedAppChoice.allCases,
            animationsEnabled: true
        )
        ProtectionPlanDraftThreadSummary(
            selected: [.shortVideos, .tiktok, .other],
            orderedChoices: DraftBlockedAppChoice.allCases,
            animationsEnabled: true
        )
    }
    .padding()
    .background(PillieTheme.bg)
}
