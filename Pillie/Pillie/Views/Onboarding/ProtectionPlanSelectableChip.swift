//
//  ProtectionPlanSelectableChip.swift
//  Pillie
//
//  A pill-shaped, multi-select chip for the Draft Blocked Apps screen (Superdesign
//  "Draft Apps Chip Interaction"), plus a simple wrapping `Layout` so grouped chips
//  flow onto as many rows as they need. Selected chips get a clear coral fill and a
//  checkmark; each chip reads as one VoiceOver button that announces its selected
//  state and the "you can pick more than one" hint.
//

import SwiftUI

struct ProtectionPlanSelectableChip: View {
    let title: String
    let isSelected: Bool
    var allowsMultipleSelection = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let feedback = OnboardingInteractionFeedback()

    var body: some View {
        Button {
            let response = feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
            withAnimation(response.motionProfile.animation) {
                action()
            }
        } label: {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
                Text(title)
                    .font(.pillie(15, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? PillieTheme.coral : .white)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        isSelected ? PillieTheme.coral : Color.black.opacity(0.08),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            }
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        if allowsMultipleSelection {
            return isSelected
                ? PillieLocalization.string("accessibility.selection.selected_remove")
                : PillieLocalization.string("accessibility.selection.select_multiple")
        }
        return isSelected
            ? PillieLocalization.string("accessibility.selection.selected")
            : PillieLocalization.string("accessibility.selection.choose")
    }
}

/// A minimal wrapping layout: places subviews left-to-right, wrapping to a new row
/// when the next subview would overflow the proposed width. Used for the grouped
/// Draft Blocked Apps chips.
struct ProtectionPlanFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height }
            + CGFloat(max(0, rows.count - 1)) * verticalSpacing
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : width,
            height: height
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let additionalWidth = current.indices.isEmpty ? size.width : size.width + horizontalSpacing
            if !current.indices.isEmpty, current.width + additionalWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            let leadingSpace = current.indices.isEmpty ? 0 : horizontalSpacing
            current.indices.append(index)
            current.width += size.width + leadingSpace
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ProtectionPlanFlowLayout {
            ProtectionPlanSelectableChip(title: "TikTok", isSelected: true) {}
            ProtectionPlanSelectableChip(title: "Instagram", isSelected: false) {}
            ProtectionPlanSelectableChip(title: "Short videos", isSelected: true) {}
            ProtectionPlanSelectableChip(title: "Other", isSelected: false) {}
        }
    }
    .padding()
    .background(PillieTheme.bg)
}
