//
//  PersonalizationOnboardingLayout.swift
//  Pillie
//

import SwiftUI

struct PersonalizationOnboardingHeader: View {
    let appeared: Bool
    let progress: CGFloat
    let badge: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 56, height: 56)
                    .background(.white, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                Capsule()
                    .fill(PillieTheme.sage.opacity(0.65))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(PillieTheme.coral)
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
            }
            .frame(height: 7)

            Text(badge)
                .font(.pillie(14, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PillieTheme.coral)
                .frame(minWidth: 72, alignment: .trailing)
        }
    }
}

enum PersonalizationOnboardingProgress {
    static let totalSteps: CGFloat = 11

    static func fraction(for step: CGFloat) -> CGFloat {
        step / totalSteps
    }

    static func badge(for step: Int) -> String {
        "STEP \(step)/\(Int(totalSteps))"
    }
}

struct PersonalizationOptionRow: View {
    enum SelectionStyle {
        case radio
        case checkbox
        case checkmark
    }

    let title: String
    let subtitle: String?
    let symbolName: String
    let symbolTint: Color
    let isSelected: Bool
    let selectionStyle: SelectionStyle
    var minHeight: CGFloat?
    var verticalPadding: CGFloat?
    let action: () -> Void

    var body: some View {
        let compact = (minHeight ?? 100) <= 60

        Button(action: action) {
            HStack(spacing: 14) {
                if !symbolName.isEmpty {
                    Image(systemName: symbolName)
                        .font(.system(size: compact ? 19 : 21, weight: .semibold))
                        .foregroundStyle(symbolTint)
                        .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                        .background(symbolTint.opacity(0.14), in: RoundedRectangle(cornerRadius: compact ? 14 : 17))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.pillie(compact ? 19 : 20, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let subtitle {
                        Text(subtitle)
                            .font(.pillie(15, weight: .regular))
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: 10)

                selectionIndicator
            }
            .padding(.horizontal, compact ? 20 : 22)
            .padding(.vertical, verticalPadding ?? (subtitle == nil ? 10 : 11))
            .frame(maxWidth: .infinity, minHeight: minHeight ?? (subtitle == nil ? 66 : 76), alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(isSelected ? PillieTheme.coralLight.opacity(0.78) : .white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30)
                    .stroke(isSelected ? PillieTheme.coral : Color.black.opacity(0.07), lineWidth: isSelected ? 1.6 : 1)
            }
            .shadow(color: Color.black.opacity(0.055), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        switch selectionStyle {
        case .checkbox:
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? PillieTheme.coral : Color.black.opacity(0.08), lineWidth: 2)
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
                .stroke(isSelected ? PillieTheme.coral : Color.black.opacity(0.08), lineWidth: 2)
                .frame(width: 28, height: 28)
                .overlay {
                    if isSelected {
                        Circle()
                            .fill(PillieTheme.coral)
                            .frame(width: 12, height: 12)
                    }
                }
        case .checkmark:
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .frame(width: 28, height: 28)
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
        }
    }
}

struct PersonalizationFooter: View {
    let isEnabled: Bool
    let helperText: String?
    var skipTitle: String?
    var onSkip: (() -> Void)?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onContinue) {
                HStack(spacing: 16) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.pillieDark)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.38)

            if let skipTitle, let onSkip {
                Button(action: onSkip) {
                    Text(skipTitle)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(PillieTheme.textMuted.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: PillieTheme.cardShadow, radius: 12, y: 6)
            }

            if let helperText {
                Text(helperText)
                    .font(.pillie(13, weight: .regular))
                    .italic()
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }
        }
    }
}
