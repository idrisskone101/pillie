import SwiftUI

struct CycleDayEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedCycleDay: Int = 1

    private let settingsFeedback = SettingsInteractionFeedback()

    private var cycleLength: Int {
        max(1, store.pack.cycleLength)
    }

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.cycle_day.title", locale: locale),
            bottomPadding: 0
        ) {
            Text(SettingsPresentation.cycleDay(
                day: selectedCycleDay,
                total: cycleLength,
                locale: locale
            ))
                .font(.pillieHeadline())
                .foregroundStyle(PillieTheme.textPrimary)

            Stepper(
                value: $selectedCycleDay,
                in: 1...cycleLength
            ) {
                Text(PillieLocalization.string("settings.cycle_day.adjust", locale: locale))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .padding(.horizontal, 20)

            Text(PillieLocalization.string("settings.cycle_day.history_note", locale: locale))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                store.updateCycleDay(selectedCycleDay)
                ProductAnalyticsTelemetry.live.cycleDaySaved()
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedCycleDay = store.currentDayIndex + 1
        }
    }
}
