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

    /// The contraception method whose default copy fills any blank preview field.
    private var method: ContraceptiveMethod { store.pack.method }
    /// Same Plus gate the notification build uses, so the preview honors the entitlement.
    private var isPlus: Bool { SubscriptionManager.shared.isPlus }

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
                        bodyCount: bodyText.count,
                        previewTitle: CustomReminderPreview.dailyTitle(custom: titleText, method: method, isPlus: isPlus),
                        previewBody: CustomReminderPreview.dailyBody(custom: bodyText, method: method, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-daily"
                    )

                    group(
                        header: "FOLLOW-UP REMINDER",
                        titleBinding: retryTitleBinding,
                        titleCount: retryTitleText.count,
                        bodyBinding: retryBodyBinding,
                        bodyCount: retryBodyText.count,
                        previewTitle: CustomReminderPreview.retryTitle(custom: retryTitleText, isPlus: isPlus),
                        previewBody: CustomReminderPreview.retryBody(custom: retryBodyText, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-followup"
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
        bodyCount: Int,
        previewTitle: String,
        previewBody: String,
        previewIdentifier: String
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

            previewBanner(title: previewTitle, body: previewBody, identifier: previewIdentifier)
        }
    }

    /// A mock lock-screen notification banner that renders the *effective* copy that will
    /// actually fire — custom text where present, the method-aware default where a field is
    /// blank. Driven entirely by `CustomReminderPreview`, so it can never diverge from the
    /// scheduled notification.
    @ViewBuilder
    private func previewBanner(title: String, body: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREVIEW")
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                .tracking(2)

            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(PillieTheme.coral)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.pillieBody())
                            .fontWeight(.semibold)
                            .foregroundStyle(PillieTheme.textPrimary)
                            .lineLimit(2)
                            .accessibilityIdentifier("\(identifier)-title")
                        Spacer(minLength: 8)
                        Text("now")
                            .font(.pillieCaption())
                            .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                    }
                    Text(body)
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(3)
                        .accessibilityIdentifier("\(identifier)-body")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                    .fill(PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
        }
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification preview. \(title). \(body)")
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
