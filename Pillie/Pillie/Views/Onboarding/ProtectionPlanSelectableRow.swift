//
//  ProtectionPlanSelectableRow.swift
//  Pillie
//
//  Reusable selectable row for the Protection Plan plan-builder question screens
//  (Superdesign "Selectable Row And Chip Elements"). Supports multi-select
//  (checkbox) and single-select (radio) semantics with a clear coral selected
//  state and full VoiceOver support: it reads as one element that announces its
//  selected state and the right "you can pick more than one" / "choose one" hint.
//

import SwiftUI

struct ProtectionPlanSelectableRow: View {
    enum Style {
        case checkbox
        case radio
    }

    let title: String
    var subtitle: String? = nil
    var symbolName: String? = nil
    let isSelected: Bool
    let style: Style
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
            HStack(spacing: 14) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isSelected ? PillieTheme.coral : PillieTheme.textMuted)
                        .frame(width: 44, height: 44)
                        .background(
                            (isSelected ? PillieTheme.coral : PillieTheme.textMuted).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.pillie(18, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.pillie(14, weight: .regular))
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                indicator
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? PillieTheme.coralLight.opacity(0.8) : .white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        isSelected ? PillieTheme.coral : Color.black.opacity(0.07),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            }
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        switch style {
        case .checkbox:
            return isSelected ? "Selected. Double tap to remove." : "Double tap to select. You can pick more than one."
        case .radio:
            return isSelected ? "Selected." : "Double tap to choose."
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch style {
        case .checkbox:
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? PillieTheme.coral : Color.black.opacity(0.12), lineWidth: 2)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? PillieTheme.coral : Color.clear)
                )
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        case .radio:
            Circle()
                .stroke(isSelected ? PillieTheme.coral : Color.black.opacity(0.12), lineWidth: 2)
                .frame(width: 26, height: 26)
                .overlay {
                    if isSelected {
                        Circle()
                            .fill(PillieTheme.coral)
                            .frame(width: 12, height: 12)
                    }
                }
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        ProtectionPlanSelectableRow(
            title: "TikTok",
            symbolName: "music.note",
            isSelected: true,
            style: .checkbox
        ) {}
        ProtectionPlanSelectableRow(
            title: "I just forget",
            symbolName: "brain.head.profile",
            isSelected: false,
            style: .checkbox
        ) {}
        ProtectionPlanSelectableRow(
            title: "Stressful",
            isSelected: false,
            style: .radio
        ) {}
    }
    .padding()
    .background(PillieTheme.bg)
}
