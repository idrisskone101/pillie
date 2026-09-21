import SwiftUI

struct AutoReminderRetryLimitEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedLimit: Int = 3

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.followup.retry_limit_title", locale: locale),
            bottomPadding: 0
        ) {
            VStack(spacing: 16) {
                ForEach(PillStore.autoReminderRetryLimitOptions, id: \.self) { option in
                    Button {
                        selectedLimit = option
                    } label: {
                        HStack {
                            Text(optionLabel(for: option))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedLimit == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedLimit == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsAutoReminderRetryLimit(
                    store: store,
                    retryLimit: selectedLimit
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedLimit = store.autoReminderRetryLimit
        }
    }

    private func optionLabel(for option: Int) -> String {
        switch option {
        case 0:
            return PillieLocalization.string("global.status.off", locale: locale)
        default:
            return option.formatted(.number.locale(locale))
        }
    }
}
