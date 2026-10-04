//
//  MethodPickerSheet.swift
//  Pillie
//

import SwiftUI

/// The Schedule sheet's "Switch" picker. Choosing only swaps the draft; nothing
/// persists until Save on the sheet underneath.
struct MethodPickerSheet: View {
    let current: ContraceptiveMethod
    let onPick: (ContraceptiveMethod) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var height: CGFloat = 440

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(PillieLocalization.string("settings.schedule.method_picker.title", locale: locale))
                    .font(.pillie(24, weight: .bold))
                    .tracking(-0.48)
                    .foregroundStyle(PillieTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(PillieLocalization.string("settings.schedule.method_picker.subtitle", locale: locale))
                    .font(.pillie(15))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .padding(.top, 6)

            VStack(spacing: 10) {
                ForEach(ContraceptiveMethod.allCases, id: \.self, content: row)
            }

            Text(PillieLocalization.string("settings.schedule.method_picker.footer", locale: locale))
                .font(.pillie(13))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 40)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(PillieTheme.bg)
    }

    private func row(_ method: ContraceptiveMethod) -> some View {
        let isCurrent = method == current
        return Button {
            settingsFeedback.chooseOption(accessibilityReduceMotion: accessibilityReduceMotion)
            if !isCurrent { onPick(method) }
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(decorative: method.iconImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: method.iconImageSize, height: method.iconImageSize)
                    .frame(width: 48, height: 48)
                    .background(
                        isCurrent ? PillieTheme.cardWhite : method.settingsTileFill,
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.localizedTitle(locale: locale))
                        .font(.pillieSubtitleBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                    Text(PillieLocalization.string("settings.schedule.method_picker.\(method.rawValue)", locale: locale))
                        .font(.pillie(14))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isCurrent {
                    Text(PillieLocalization.string("settings.schedule.method_picker.current", locale: locale))
                        .font(.pillie(12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(PillieTheme.dark, in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Self.chevron)
                        .frame(width: 20, alignment: .trailing)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 14)
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .background(
                isCurrent ? PillieTheme.coralLight : PillieTheme.cardWhite,
                in: RoundedRectangle(cornerRadius: 22)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isCurrent ? PillieTheme.coral : PillieTheme.hairline, lineWidth: isCurrent ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityIdentifier("methodPicker.\(method.rawValue)")
    }

    private static let chevron = Color(hex: "A8A29E")
}

extension ContraceptiveMethod {
    /// Paper's tinted tile behind the Quiver icon on the Schedule sheet.
    var settingsTileFill: Color {
        switch self {
        case .pill: PillieTheme.coralLight
        case .patch: Color(hex: "FBEFF1")
        case .ring: Color(hex: "FBF0EC")
        }
    }
}
