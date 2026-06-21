//
//  CustomReminderMessagesEditor.swift
//  Pillie
//

import SwiftUI

/// Editor for the Custom Reminder Message perk (Pillie+). Lets a subscriber write the
/// title and body of the daily Due Action Reminder. What they type is exactly what fires
/// (WYSIWYG); a blank field falls back to the default method-aware copy at fire time
/// (see `CustomReminderCopy`). Hard caps are enforced as the user types, with a live
/// character counter. Words never change reminder timing, snooze, or supply scheduling.
struct CustomReminderMessagesEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var titleText: String = ""
    @State private var bodyText: String = ""

    private let settingsFeedback = SettingsInteractionFeedback()

    private var titleBinding: Binding<String> {
        Binding(
            get: { titleText },
            set: { titleText = String($0.prefix(CustomReminderCopy.titleCap)) }
        )
    }

    private var bodyBinding: Binding<String> {
        Binding(
            get: { bodyText },
            set: { bodyText = String($0.prefix(CustomReminderCopy.bodyCap)) }
        )
    }

    var body: some View {
        SettingsSheetContainer(title: "Reminder Messages") {
            VStack(alignment: .leading, spacing: 20) {
                Text("DAILY REMINDER")
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.textMuted)
                    .tracking(2)

                field(
                    label: "Title",
                    placeholder: "Pillie's default title",
                    text: titleBinding,
                    count: titleText.count,
                    cap: CustomReminderCopy.titleCap,
                    axis: .horizontal
                )

                field(
                    label: "Message",
                    placeholder: "Pillie's default message",
                    text: bodyBinding,
                    count: bodyText.count,
                    cap: CustomReminderCopy.bodyCap,
                    axis: .vertical
                )

                Text("Leave a field blank to use Pillie's default wording.")
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .padding(.horizontal, 24)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsCustomReminders(
                    store: store,
                    title: titleText,
                    body: bodyText
                )
                dismiss()
            } label: {
                Text("Save")
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            titleText = store.customDueReminderTitle
            bodyText = store.customDueReminderBody
            ProductAnalyticsTelemetry.live.customRemindersSettingsOpened()
        }
    }

    @ViewBuilder
    private func field(
        label: String,
        placeholder: String,
        text: Binding<String>,
        count: Int,
        cap: Int,
        axis: Axis
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted)
                Spacer()
                Text("\(count)/\(cap)")
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                    .monospacedDigit()
            }

            TextField(placeholder, text: text, axis: axis)
                .lineLimit(axis == .vertical ? 3...5 : 1...1)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.cardWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .stroke(PillieTheme.sageHalf, lineWidth: 1)
                )
        }
    }
}
