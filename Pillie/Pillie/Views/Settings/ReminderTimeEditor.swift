import SwiftUI

struct ReminderTimeEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedTime = Date()

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.reminder_time.title", locale: locale),
            bottomPadding: 0
        ) {
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, locale)
            .frame(height: 170)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                saveReminderTime()
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear { seedFromStore() }
    }

    private func seedFromStore() {
        selectedTime = ReminderTimeConverter.dateForPicker(
            hour: store.reminderHour,
            minute: store.reminderMinute
        )
    }

    private func saveReminderTime() {
        let selection = ReminderTimeConverter.hourAndMinute(from: selectedTime)
        ScheduleCriticalSettingChange.saveSettingsReminderTime(
            store: store,
            hour: selection.hour,
            minute: selection.minute
        )
    }
}
