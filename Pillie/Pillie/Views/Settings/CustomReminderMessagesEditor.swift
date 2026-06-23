//
//  CustomReminderMessagesEditor.swift
//  Pillie
//

import SwiftUI

/// Editor for the Custom Reminder Message perk (Pillie+). Lets a subscriber write the
/// title and body of the daily Due Action Reminder, the Auto-Reminder Retry, and the
/// end-of-day Last Call Reminder. What they type is exactly what fires (WYSIWYG); a
/// blank field falls back to the default copy at fire time (see `CustomReminderCopy`).
/// Hard caps are enforced as the user types, with a live character counter. Words never
/// change reminder timing, snooze, retry cadence, or supply scheduling.
struct CustomReminderMessagesEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var titleText: String = ""
    @State private var bodyText: String = ""
    @State private var retryTitleText: String = ""
    @State private var retryBodyText: String = ""
    @State private var lastCallTitleText: String = ""
    @State private var lastCallBodyText: String = ""

    /// Identifies every editable field so a single keyboard toolbar "Done" button (and
    /// interactive scroll-to-dismiss) can resign whichever field is active.
    private enum Field: Hashable {
        case dailyTitle, dailyBody
        case retryTitle, retryBody
        case lastCallTitle, lastCallBody
    }

    @FocusState private var focusedField: Field?

    private let settingsFeedback = SettingsInteractionFeedback()

    /// The contraception method whose default copy fills any blank preview field.
    private var method: ContraceptiveMethod { store.pack.method }
    /// Same Plus gate the notification build uses, so the preview honors the entitlement.
    private var isPlus: Bool { SubscriptionManager.shared.isPlus }

    /// The method-aware default copy each field seeds with when no custom value is stored —
    /// the exact strings the notification falls back to (see `CustomReminderPreview`).
    private var defaultTitle: String { CustomReminderPreview.defaultDailyTitle(method: method) }
    private var defaultBody: String { CustomReminderPreview.defaultDailyBody(method: method) }
    private var defaultRetryTitle: String { NotificationManager.defaultRetryTitle }
    private var defaultRetryBody: String { NotificationManager.defaultRetryBody }
    private var defaultLastCallTitle: String { CustomReminderPreview.defaultLastCallTitle(method: method) }
    private var defaultLastCallBody: String { CustomReminderPreview.defaultLastCallBody(method: method) }

    /// The value to show in a field on open: the saved custom text, or the default when blank.
    private func prefilled(_ stored: String, default defaultCopy: String) -> String {
        stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultCopy : stored
    }

    /// The value to persist: an untouched default collapses back to "" so the field stays on
    /// the live default (and never pins today's wording), matching the blank→default contract.
    private func normalized(_ text: String, default defaultCopy: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == defaultCopy ? "" : text
    }

    var body: some View {
        SettingsSheetContainer(title: "Custom Messages") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Write what each reminder says. Pillie shows a live preview of exactly how it'll land on your lock screen.")
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    group(
                        index: 1,
                        header: "Daily reminder",
                        subtitle: "Your main nudge when today's dose is due.",
                        titleBinding: $titleText,
                        titleCount: titleText.count,
                        bodyBinding: $bodyText,
                        bodyCount: bodyText.count,
                        titleField: .dailyTitle,
                        bodyField: .dailyBody,
                        previewTitle: CustomReminderPreview.dailyTitle(custom: titleText, method: method, isPlus: isPlus),
                        previewBody: CustomReminderPreview.dailyBody(custom: bodyText, method: method, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-daily"
                    )

                    group(
                        index: 2,
                        header: "Follow-up nudge",
                        subtitle: "A gentle retry if you haven't logged it yet.",
                        titleBinding: $retryTitleText,
                        titleCount: retryTitleText.count,
                        bodyBinding: $retryBodyText,
                        bodyCount: retryBodyText.count,
                        titleField: .retryTitle,
                        bodyField: .retryBody,
                        previewTitle: CustomReminderPreview.retryTitle(custom: retryTitleText, isPlus: isPlus),
                        previewBody: CustomReminderPreview.retryBody(custom: retryBodyText, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-followup"
                    )

                    group(
                        index: 3,
                        header: "Last call",
                        subtitle: "A final heads-up before the day ends.",
                        titleBinding: $lastCallTitleText,
                        titleCount: lastCallTitleText.count,
                        bodyBinding: $lastCallBodyText,
                        bodyCount: lastCallBodyText.count,
                        titleField: .lastCallTitle,
                        bodyField: .lastCallBody,
                        previewTitle: CustomReminderPreview.lastCallTitle(custom: lastCallTitleText, method: method, isPlus: isPlus),
                        previewBody: CustomReminderPreview.lastCallBody(custom: lastCallBodyText, method: method, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-lastcall"
                    )

                    Text("Leave anything blank and Pillie uses its own wording.")
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    Button {
                        settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                        ScheduleCriticalSettingChange.saveSettingsCustomReminders(
                            store: store,
                            title: normalized(titleText, default: defaultTitle),
                            body: normalized(bodyText, default: defaultBody),
                            retryTitle: normalized(retryTitleText, default: defaultRetryTitle),
                            retryBody: normalized(retryBodyText, default: defaultRetryBody),
                            lastCallTitle: normalized(lastCallTitleText, default: defaultLastCallTitle),
                            lastCallBody: normalized(lastCallBodyText, default: defaultLastCallBody)
                        )
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(.pillieDark)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                // The dark CTA casts a soft drop shadow (radius 15, y 8); without room
                // below it the ScrollView clips the shadow against the beige bg, leaving
                // a hard cut-off line. Reserve enough space for the shadow to fade out.
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
        }
        .onAppear {
            // Seed every field with the wording that will actually fire: the saved custom
            // text where present, otherwise the same default the notification would use. Both
            // sections open pre-filled and editable rather than blank, while the "blank uses
            // Pillie's default" contract is preserved by re-normalizing on save.
            titleText = prefilled(store.customDueReminderTitle, default: defaultTitle)
            bodyText = prefilled(store.customDueReminderBody, default: defaultBody)
            retryTitleText = prefilled(store.customRetryReminderTitle, default: defaultRetryTitle)
            retryBodyText = prefilled(store.customRetryReminderBody, default: defaultRetryBody)
            lastCallTitleText = prefilled(store.customLastCallReminderTitle, default: defaultLastCallTitle)
            lastCallBodyText = prefilled(store.customLastCallReminderBody, default: defaultLastCallBody)
            ProductAnalyticsTelemetry.live.customRemindersSettingsOpened()
        }
    }

    @ViewBuilder
    private func group(
        index: Int,
        header: String,
        subtitle: String,
        titleBinding: Binding<String>,
        titleCount: Int,
        bodyBinding: Binding<String>,
        bodyCount: Int,
        titleField: Field,
        bodyField: Field,
        previewTitle: String,
        previewBody: String,
        previewIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(index: index, header: header, subtitle: subtitle)

            field(
                label: "Title",
                placeholder: "Pillie's default title",
                text: titleBinding,
                count: titleCount,
                cap: CustomReminderCopy.titleCap,
                axis: .horizontal,
                field: titleField
            )

            field(
                label: "Message",
                placeholder: "Pillie's default message",
                text: bodyBinding,
                count: bodyCount,
                cap: CustomReminderCopy.bodyCap,
                axis: .vertical,
                field: bodyField
            )

            previewBanner(title: previewTitle, body: previewBody, identifier: previewIdentifier)
        }
    }

    /// A numbered, two-line header so the three reminders read as an ordered sequence
    /// (daily → follow-up → last call) and each one clearly states what it does.
    @ViewBuilder
    private func sectionHeader(index: Int, header: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(index)")
                .font(.pillie(15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(PillieTheme.dark))

            VStack(alignment: .leading, spacing: 2) {
                Text(header)
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(subtitle)
                    .font(.pillieDate())
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(header). \(subtitle)")
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
                Image("HomeAvatarLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

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
            .shadow(color: PillieTheme.cardShadow, radius: 10, y: 4)
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
        axis: Axis,
        field: Field
    ) -> some View {
        let isFocused = focusedField == field
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.textMuted)
                    .tracking(1)
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
                .focused($focusedField, equals: field)
                // Hard cap: drop anything typed or pasted past the limit so the field
                // can never exceed `cap` (the count label stays in sync).
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.count > cap {
                        text.wrappedValue = String(newValue.prefix(cap))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.cardWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .stroke(isFocused ? PillieTheme.verifiedGreen : PillieTheme.sageHalf,
                                lineWidth: isFocused ? 1.5 : 1)
                )
                .shadow(color: PillieTheme.cardShadow, radius: 10, y: 4)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}
