import SwiftUI

struct LanguagePickerSheet: View {
    @Environment(AppLanguagePreference.self) private var languagePreference
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.language.title", locale: locale),
            bottomPadding: 8
        ) {
            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                    if index > 0 {
                        Rectangle()
                            .fill(PillieTheme.textMuted.opacity(0.12))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                    languageRow(language)
                }
            }
            .background(PillieTheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 20)

            Text(PillieLocalization.string("settings.language.helper", locale: locale))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let selected = languagePreference.selection == language
        return Button {
            languagePreference.selection = language
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text(rowTitle(for: language))
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PillieTheme.coral)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func rowTitle(for language: AppLanguage) -> String {
        if language == .system {
            return PillieLocalization.string("settings.language.system", locale: locale)
        }
        return language.nativeName
    }
}
