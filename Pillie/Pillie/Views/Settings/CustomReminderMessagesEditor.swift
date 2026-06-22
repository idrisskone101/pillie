//
//  CustomReminderMessagesEditor.swift
//  Pillie
//

import SwiftUI

/// Editor for the Custom Reminder Message perk (Pillie+). Lets a subscriber write the
/// title and body of both the daily Due Action Reminder and the Auto-Reminder Retry.
/// What they type is exactly what fires (WYSIWYG); a blank field falls back to the
/// default copy at fire time (see `CustomReminderCopy`). Hard caps are enforced as the
/// user types, with a live character counter. Words never change reminder timing,
/// snooze, retry cadence, or supply scheduling.
struct CustomReminderMessagesEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var titleText: String = ""
    @State private var bodyText: String = ""
    @State private var retryTitleText: String = ""
    @State private var retryBodyText: String = ""

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

    private var retryTitleBinding: Binding<String> {
        Binding(
            get: { retryTitleText },
            set: { retryTitleText = String($0.prefix(CustomReminderCopy.titleCap)) }
        )
    }

    private var retryBodyBinding: Binding<String> {
        Binding(
            get: { retryBodyText },
            set: { retryBodyText = String($0.prefix(CustomReminderCopy.bodyCap)) }
        )
    }

    var body: some View {
        SettingsSheetContainer(title: "Reminder Messages") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    group(
                        header: "DAILY REMINDER",
                        titleBinding: titleBinding,
                        titleCount: titleText.count,
                        bodyBinding: bodyBinding,
                        bodyCount: bodyText.count
                    )

                    group(
                        header: "FOLLOW-UP REMINDER",
                        titleBinding: retryTitleBinding,
                        titleCount: retryTitleText.count,
                        bodyBinding: retryBodyBinding,
                        bodyCount: retryBodyText.count
                    )

                    Text("Leave a field blank to use Pillie's default wording.")
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)

                    Button {
                        settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                        ScheduleCriticalSettingChange.saveSettingsCustomReminders(
                            store: store,
                            title: titleText,
                            body: bodyText,
                            retryTitle: retryTitleText,
                            retryBody: retryBodyText
                        )
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(.pillieDark)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            titleText = store.customDueReminderTitle
            bodyText = store.customDueReminderBody
            retryTitleText = store.customRetryReminderTitle
            retryBodyText = store.customRetryReminderBody
            ProductAnalyticsTelemetry.live.customRemindersSettingsOpened()
        }
    }

    @ViewBuilder
    private func group(
        header: String,
        titleBinding: Binding<String>,
        titleCount: Int,
        bodyBinding: Binding<String>,
        bodyCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(header)
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            field(
                label: "Title",
                placeholder: "Pillie's default title",
                text: titleBinding,
                count: titleCount,
                cap: CustomReminderCopy.titleCap,
                axis: .horizontal
            )

            field(
                label: "Message",
                placeholder: "Pillie's default message",
                text: bodyBinding,
                count: bodyCount,
                cap: CustomReminderCopy.bodyCap,
                axis: .vertical
            )
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
