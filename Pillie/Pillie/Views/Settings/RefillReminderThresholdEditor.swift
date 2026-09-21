import SwiftUI

struct RefillReminderThresholdEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedThreshold: Int = 5

    private let settingsFeedback = SettingsInteractionFeedback()

    private var isPatchMethod: Bool {
        store.pack.method == .patch
    }

    private var editorTitle: String {
        SettingsPresentation.supplyReminderTitle(
            method: store.pack.method,
            locale: locale
        )
    }

    private var thresholdOptions: [Int] {
        isPatchMethod ? PillStore.patchRestockReminderThresholdOptions : PillStore.refillReminderThresholdOptions
    }

    var body: some View {
        SettingsSheetContainer(title: editorTitle, bottomPadding: 0) {
            VStack(spacing: 16) {
                ForEach(thresholdOptions, id: \.self) { option in
                    Button {
                        selectedThreshold = option
                    } label: {
                        HStack {
                            Text(thresholdLabel(for: option))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedThreshold == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedThreshold == option ? PillieTheme.coral : PillieTheme.textMuted)
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
                ScheduleCriticalSettingChange.saveSettingsSupplyReminderThreshold(
                    store: store,
                    threshold: selectedThreshold
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedThreshold = isPatchMethod
                ? store.patchRestockReminderThresholdPatches
                : store.refillReminderThresholdDays
        }
    }

    private func thresholdLabel(for option: Int) -> String {
        option.formatted(.number.locale(locale))
    }
}
