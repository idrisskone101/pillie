import SwiftUI

struct AutoReminderIntervalEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedInterval: Int = 10

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.followup.interval_title", locale: locale),
            bottomPadding: 0
        ) {
            VStack(spacing: 16) {
                ForEach(PillStore.autoReminderIntervalOptions, id: \.self) { option in
                    Button {
                        selectedInterval = option
                    } label: {
                        HStack {
                            Text(SettingsPresentation.interval(minutes: option, locale: locale))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedInterval == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedInterval == option ? PillieTheme.coral : PillieTheme.textMuted)
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
                ScheduleCriticalSettingChange.saveSettingsAutoReminderInterval(
                    store: store,
                    intervalMinutes: selectedInterval
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedInterval = store.autoReminderIntervalMinutes
        }
    }
}
